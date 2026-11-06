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

echo "--- Largest firmware files (top 50) ---"
for firmware_dir in "$ROOTFS/lib/firmware" "$ROOTFS/usr/lib/firmware"; do
  if [ -d "$firmware_dir" ]; then
    find "$firmware_dir" -type f -printf '%s %p\n'
  fi
done | sort -nr | sed -n '1,50p' | tee "$AUDIT_DIR/largest-firmware-files.txt"

echo "--- Firmware directory breakdown ---"
for firmware_dir in "$ROOTFS/lib/firmware" "$ROOTFS/usr/lib/firmware"; do
  if [ -d "$firmware_dir" ]; then
    du -x -B1 -d2 "$firmware_dir" 2>/dev/null
  fi
done | sort -nr | tee "$AUDIT_DIR/firmware-directory-sizes.txt"

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

# Install the FCSF selector in the Live ISO; the installer invokes it after mounting the target.
install -D -m 0755 "$SCRIPT_DIR/fcsf/fcsf" "$ROOTFS/usr/bin/fcsf"
install -D -m 0644 "$SCRIPT_DIR/fcsf/README.md" "$ROOTFS/usr/share/flatcherry/fcsf/README.md"

# Set a recognizable live-system message without changing Void's runit setup.
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Flat Cherry Linux
Void Linux • runit • LXDE • Flatpak
EOF

echo "Audit reports saved in: $AUDIT_DIR"
