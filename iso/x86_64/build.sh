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

# Keep the upstream BIOS and UEFI El Torito boot entries, but remove the
# isohybrid MBR/GPT/APM extensions. This produces an optical-style ISO that
# can be written by tools such as Rufus in ISO Image mode.
sed -i \
  -e 's/-isohybrid-mbr "\$SYSLINUX_DATADIR"\/isohdpfx.bin//' \
  -e 's/-isohybrid-gpt-basdat -isohybrid-apm-hfsplus//' \
  -e 's/VOID_LIVE/FLATCHERRY/g' \
  mklive.sh

if grep -Eq -- '-isohybrid-(mbr|gpt|apm)' mklive.sh; then
  echo "ERROR: isohybrid flags remain in the patched mklive script" >&2
  exit 1
fi

./mkiso.sh \
  -a x86_64 \
  -b lxde \
  -- \
  -p "flatpak linux-firmware-amd linux-firmware-nvidia" \
  -x "$POSTSETUP" \
  -T "Flat Cherry Linux" \
  -o "$ISO_PATH"

test -s "$ISO_PATH"
echo "Built ISO: $ISO_PATH"
