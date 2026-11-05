#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?postsetup.sh requires the target root filesystem}"

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

echo "--- Installed LXDE / desktop-related packages ---"
if command -v xbps-query >/dev/null 2>&1; then
  xbps-query -r "$ROOTFS" -l | grep -Ei 'lxde|lxappearance|lxpanel|lxsession|pcmanfm|lxterminal|openbox|lightdm|gvfs|udisks|firefox|xorg|font-' || true
fi

echo "--- Largest firmware files (top 30) ---"
for firmware_dir in "$ROOTFS/lib/firmware" "$ROOTFS/usr/lib/firmware"; do
  if [ -d "$firmware_dir" ]; then
    find "$firmware_dir" -type f -printf '%s %p\n'
  fi
done | sort -nr | head -n 30 || true

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

# Set a recognizable live-system message without changing Void's runit setup.
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Flat Cherry Linux
Void Linux • runit • LXDE • Flatpak
EOF
