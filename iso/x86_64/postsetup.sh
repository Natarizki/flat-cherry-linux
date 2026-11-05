#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?postsetup.sh requires the target root filesystem}"

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

# Set a recognizable live-system message without changing Void's runit setup.
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Flat Cherry Linux
Void Linux • runit • LXDE • Flatpak
EOF
