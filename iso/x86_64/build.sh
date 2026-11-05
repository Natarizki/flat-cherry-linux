#!/usr/bin/env bash
set -euo pipefail

VOID_MKLIVE_DIR="${1:?usage: build.sh VOID_MKLIVE_DIR OUTPUT_DIR}"
OUTPUT_DIR="${2:?usage: build.sh VOID_MKLIVE_DIR OUTPUT_DIR}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
POSTSETUP="${SCRIPT_DIR}/postsetup.sh"
ISO_VERSION="${FLAT_CHERRY_VERSION:-0.1.0-alpha.1}"
ISO_PATH="${OUTPUT_DIR}/flat-cherry-${ISO_VERSION}-x86_64.iso"

mkdir -p "$OUTPUT_DIR"
chmod +x "$POSTSETUP"
cd "$VOID_MKLIVE_DIR"

# Keep BIOS and UEFI El Torito boot entries, but remove isohybrid MBR/GPT/APM
# extensions so the result is an optical-style ISO for Rufus ISO Image mode.
sed -i -e 's/-isohybrid-mbr "\$SYSLINUX_DATADIR"\/isohdpfx.bin//' -e 's/-isohybrid-gpt-basdat -isohybrid-apm-hfsplus//' -e 's/VOID_LIVE/FLATCHERRY/g' mklive.sh

# Drop optional upstream extras that inflate the live image unnecessarily.
# Keep one sans-serif font family; documentation is pruned in postsetup.sh.
# chrony is omitted, so also remove its chronyd runit service from mkiso.sh.
sed -i \
  -e 's/ udisks2 firefox/ udisks2/' \
  -e 's/dialog cryptsetup lvm2 mdadm void-docs-browse xtools-minimal xmirror chrony tmux/dialog cryptsetup lvm2 mdadm xmirror/' \
  -e 's/FONTS="font-misc-misc terminus-font dejavu-fonts-ttf"/FONTS="font-inter"/' \
  -e 's/SERVICES="sshd chronyd"/SERVICES="sshd"/' \
  mkiso.sh

if grep -Eq -- '-isohybrid-(mbr|gpt|apm)' mklive.sh; then
  echo "ERROR: isohybrid flags remain in the patched mklive script" >&2
  exit 1
fi

if grep -Eq 'SERVICES="sshd chronyd"' mkiso.sh; then
  echo "ERROR: chronyd service is still enabled although chrony is excluded" >&2
  exit 1
fi

if ! grep -Fq 'FONTS="font-inter"' mkiso.sh; then
  echo "ERROR: expected the minimal sans-serif font selection was not applied" >&2
  exit 1
fi

./mkiso.sh -a x86_64 -b lxde -- -p "flatpak linux-firmware-amd linux-firmware-nvidia" -x "$POSTSETUP" -T "Flat Cherry Linux" -o "$ISO_PATH"

test -s "$ISO_PATH"
echo "Built ISO: $ISO_PATH"
