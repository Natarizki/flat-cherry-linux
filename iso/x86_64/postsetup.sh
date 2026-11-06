#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?postsetup.sh requires the target root filesystem}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_DIR="${FLAT_CHERRY_AUDIT_DIR:-/tmp/flat-cherry-audit}"
mkdir -p "$AUDIT_DIR"
AUDIT_LOG="$AUDIT_DIR/rootfs-audit.txt"
: > "$AUDIT_LOG"
exec > >(tee -a "$AUDIT_LOG") 2>&1

echo "=== Flat Cherry pre-prune size audit ==="
for path in \
  "$ROOTFS/usr/share/fonts" \
  "$ROOTFS/usr/share/doc" \
  "$ROOTFS/usr/share/man" \
  "$ROOTFS/usr/share/info" \
  "$ROOTFS/usr/share/gtk-doc" \
  "$ROOTFS/usr/share/help" \
  "$ROOTFS/lib/firmware" \
  "$ROOTFS/usr/lib/firmware"; do
  if [ -e "$path" ]; then
    du -sh "$path"
  fi
done

echo "--- Largest root filesystem directories (top 60) ---"
du -x -B1 -d2 "$ROOTFS" 2>/dev/null | sort -nr | sed -n '1,60p' | tee "$AUDIT_DIR/largest-directories.txt"

echo "--- Installed package sizes (largest first) ---"
if command -v xbps-query >/dev/null 2>&1; then
  while read -r state pkgver; do
    [ "$state" = "ii" ] || continue
    size="$(xbps-query -r "$ROOTFS" -p installed_size "$pkgver" 2>/dev/null | tr -d '[:space:]' || true)"
    printf '%s\t%s\n' "${size:-0}" "$pkgver"
  done < <(xbps-query -r "$ROOTFS" -l) | sort -nr -k1,1 | tee "$AUDIT_DIR/package-sizes.tsv"

  echo "--- Installed LXDE / desktop-related packages ---"
  xbps-query -r "$ROOTFS" -l | grep -Ei 'lxde|lxappearance|lxpanel|lxsession|pcmanfm|lxterminal|openbox|lightdm|gvfs|udisks|firefox|xorg|font-|gtk' | tee "$AUDIT_DIR/desktop-packages.txt" || true
else
  echo "WARNING: xbps-query unavailable; package-level audit skipped"
fi

# Resolve the firmware tree once: on Void, /lib/firmware may point to
# /usr/lib/firmware. Auditing both paths would double-count every blob.
FIRMWARE_DIR=""
for candidate in "$ROOTFS/usr/lib/firmware" "$ROOTFS/lib/firmware"; do
  if [ -d "$candidate" ]; then
    FIRMWARE_DIR="$(readlink -f "$candidate")"
    break
  fi
done


# The image chroot does not automatically inherit the build container's DNS
# resolver. Temporarily provide it so Flatpak can download Flathub's signed
# repository definition, then restore the target image's original resolver.
RESOLV_BACKUP="$(mktemp -d)"
HAD_RESOLV=no
if [ -e "$ROOTFS/etc/resolv.conf" ] || [ -L "$ROOTFS/etc/resolv.conf" ]; then
  cp -a "$ROOTFS/etc/resolv.conf" "$RESOLV_BACKUP/resolv.conf"
  HAD_RESOLV=yes
fi

restore_resolver() {
  rm -f "$ROOTFS/etc/resolv.conf"
  if [ "$HAD_RESOLV" = yes ]; then
    cp -a "$RESOLV_BACKUP/resolv.conf" "$ROOTFS/etc/resolv.conf"
  fi
  rm -rf "$RESOLV_BACKUP"
}
trap restore_resolver EXIT

cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# Register Flathub system-wide using its official signed repository definition.
chroot "$ROOTFS" flatpak remote-add --system --if-not-exists \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

restore_resolver
trap - EXIT

# Keep network bootstrap firmware and firmware required by the base system.
# In particular, linux-firmware-intel also carries Intel Wi-Fi firmware, while
# linux-firmware-nvidia is a dependency of linux-base in this Void package set.
# Only remove the optional AMD GPU firmware package from the Live rootfs.
if command -v xbps-query >/dev/null 2>&1 && command -v xbps-remove >/dev/null 2>&1; then
  AMD_FIRMWARE_INSTALLED=no
  while read -r state pkgver _description; do
    [ "$state" = "ii" ] || continue
    pkgname="${pkgver%-[0-9]*}"
    if [ "$pkgname" = "linux-firmware-amd" ]; then
      AMD_FIRMWARE_INSTALLED=yes
      break
    fi
  done < <(xbps-query -r "$ROOTFS" -l)

  if [ "$AMD_FIRMWARE_INSTALLED" = yes ]; then
    echo "Removing optional AMD GPU firmware from Live ISO: linux-firmware-amd"
    if ! xbps-remove -r "$ROOTFS" -fy linux-firmware-amd; then
      echo "WARNING: could not remove linux-firmware-amd; keeping it in the Live ISO"
    fi
  else
    echo "linux-firmware-amd is not installed; nothing to remove"
  fi
fi

# Marvell Prestera firmware targets switch ASICs, not ordinary client
# Ethernet/Wi-Fi adapters. Keep the rest of linux-firmware-network in the Live
# ISO so Intel Wi-Fi, Broadcom, Realtek, Atheros, and common NICs can bootstrap
# internet access. FCSF installs the complete network package into the target.
if [ -n "$FIRMWARE_DIR" ] && [ -d "$FIRMWARE_DIR/mrvl/prestera" ]; then
  PRESTERA_BYTES="$(du -sb "$FIRMWARE_DIR/mrvl/prestera" | awk '{print $1}')"
  rm -rf "$FIRMWARE_DIR/mrvl/prestera"
  printf 'Pruned Live-only Marvell Prestera switch firmware: %s bytes\n' \
    "$PRESTERA_BYTES" | tee "$AUDIT_DIR/firmware-prune-report.txt"
else
  echo "Marvell Prestera firmware not present; nothing to prune" \
    | tee "$AUDIT_DIR/firmware-prune-report.txt"
fi

echo "--- Firmware audit root ---"
if [ -n "$FIRMWARE_DIR" ]; then
  printf '%s\n' "$FIRMWARE_DIR" | tee "$AUDIT_DIR/firmware-root.txt"

  echo "--- Largest unique firmware files (top 50) ---"
  find "$FIRMWARE_DIR" -type f -printf '%s %p\n' \
    | sort -nr | sed -n '1,50p' \
    | tee "$AUDIT_DIR/largest-firmware-files.txt"

  echo "--- Firmware directory breakdown (bytes) ---"
  du -x -B1 -d2 "$FIRMWARE_DIR" 2>/dev/null \
    | sort -nr | tee "$AUDIT_DIR/firmware-directory-sizes.txt"

  echo "--- Intel firmware breakdown (bytes) ---"
  if [ -d "$FIRMWARE_DIR/intel" ]; then
    du -x -B1 -d2 "$FIRMWARE_DIR/intel" 2>/dev/null \
      | sort -nr | tee "$AUDIT_DIR/intel-firmware-directory-sizes.txt"
    echo "--- Largest Intel firmware files (top 60) ---"
    find "$FIRMWARE_DIR/intel" -type f -printf '%s %p\n' \
      | sort -nr | sed -n '1,60p' \
      | tee "$AUDIT_DIR/largest-intel-firmware-files.txt"
  else
    echo "No intel/ firmware directory found" \
      | tee "$AUDIT_DIR/intel-firmware-directory-sizes.txt"
  fi
else
  echo "WARNING: no firmware directory found" | tee "$AUDIT_DIR/firmware-root.txt"
fi


# Remove non-essential documentation while preserving licenses and package metadata.
for path in \
  "$ROOTFS/usr/share/doc" \
  "$ROOTFS/usr/share/man" \
  "$ROOTFS/usr/share/info" \
  "$ROOTFS/usr/share/gtk-doc" \
  "$ROOTFS/usr/share/help"; do
  rm -rf "$path"
done

echo "=== Flat Cherry post-prune size audit ==="
for path in "$ROOTFS/usr/share/fonts" "$ROOTFS/usr/share/doc" "$ROOTFS/usr/share/man" "$ROOTFS/usr/share/info" "$ROOTFS/usr/share/gtk-doc" "$ROOTFS/usr/share/help"; do
  if [ -e "$path" ]; then
    du -sh "$path"
  else
    echo "Removed: ${path#"$ROOTFS"}"
  fi
done

# Install FPM, the Flat Cherry frontend for Flatpak (XBPS remains native).
install -D -m 0755 "$SCRIPT_DIR/fpm/fpm" "$ROOTFS/usr/bin/fpm"

# Install the FCSF selector in the Live ISO; the installer invokes it after mounting the target.
install -D -m 0755 "$SCRIPT_DIR/fcsf/fcsf" "$ROOTFS/usr/bin/fcsf"
install -D -m 0644 "$SCRIPT_DIR/fcsf/README.md" "$ROOTFS/usr/share/flatcherry/fcsf/README.md"

# Set a recognizable live-system message without changing Void's runit setup.
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Flat Cherry Linux
Void Linux • runit • LXDE • Flatpak
EOF

echo "Audit reports saved in: $AUDIT_DIR"
