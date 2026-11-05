#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?postsetup.sh requires the target root filesystem}"

# Register Flathub system-wide so Flatpak is ready to use in the live image.
chroot "$ROOTFS" flatpak remote-add --system --if-not-exists \
  flathub https://flathub.org/repo/flathub.flatpakrepo

# Set a recognizable live-system message without changing Void's runit setup.
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Flat Cherry Linux
Void Linux • runit • LXDE • Flatpak
EOF
