#!/usr/bin/env bash
set -euo pipefail

VOID_MKLIVE_DIR="${1:?usage: build.sh VOID_MKLIVE_DIR OUTPUT_DIR}"
OUTPUT_DIR="${2:?usage: build.sh VOID_MKLIVE_DIR OUTPUT_DIR}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
POSTSETUP="${SCRIPT_DIR}/postsetup.sh"
ISO_VERSION="${FLAT_CHERRY_VERSION:-0.1.0-alpha.1}"
ISO_PATH="${OUTPUT_DIR}/flat-cherry-${ISO_VERSION}-x86_64.iso"

mkdir -p "$OUTPUT_DIR" "$OUTPUT_DIR/audit"
export FLAT_CHERRY_AUDIT_DIR="$OUTPUT_DIR/audit"
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

# Export both removable-media UEFI fallback loaders from void-mklive's
# embedded FAT boot image into the ISO filesystem. The EFI image is created
# inside mklive.sh, so inject the export immediately after its first unmount.
awk '
  /^[[:space:]]*rm -rf "\$GRUB_EFI_TMPDIR"[[:space:]]*$/ {
    print "EFI_EXPORT_TMPDIR=\"$(mktemp --tmpdir=\"$BUILDDIR\" -dt esp-export.XXXXX)\""
    print "mount -o loop,ro \"$GRUB_DIR/efiboot.img\" \"$EFI_EXPORT_TMPDIR\" >/dev/null"
    print "mkdir -p \"$IMAGEDIR/EFI/BOOT\""
    print "install -m 0644 \"$EFI_EXPORT_TMPDIR/EFI/BOOT/BOOTIA32.EFI\" \"$IMAGEDIR/EFI/BOOT/BOOTIA32.EFI\""
    print "install -m 0644 \"$EFI_EXPORT_TMPDIR/EFI/BOOT/BOOTX64.EFI\" \"$IMAGEDIR/EFI/BOOT/BOOTX64.EFI\""
    print "umount \"$EFI_EXPORT_TMPDIR\""
    print "rmdir \"$EFI_EXPORT_TMPDIR\""
  }
  { print }
' mklive.sh > mklive.sh.esp
mv mklive.sh.esp mklive.sh

if [[ "$(grep -c '^EFI_EXPORT_TMPDIR=' mklive.sh)" -ne 1 ]]; then
  echo "ERROR: failed to add IA32/x64 fallback loaders to the ISO tree" >&2
  exit 1
fi

./mkiso.sh -a x86_64 -b lxde -- -p "flatpak linux-firmware-amd linux-firmware-nvidia" -x "$POSTSETUP" -T "Flat Cherry Linux" -o "$ISO_PATH"

test -s "$ISO_PATH"
echo "Built ISO: $ISO_PATH"
