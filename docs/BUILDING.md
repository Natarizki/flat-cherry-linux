# Building Flat Cherry Linux

## Current milestone

Target release: `v0.1.0-alpha.1`

The initial target is an x86_64 Void Linux live image with LXDE, X11, runit, Flatpak, and AMD/NVIDIA firmware.

## Build environment

ISO builds run on GitHub Actions. The workflow uses the official `ghcr.io/void-linux/void-mklive` build container and the upstream `void-mklive` scripts.

The project build script:
1. Generates the LXDE live image for x86_64.
2. Adds Flatpak and the AMD/NVIDIA firmware packages.
3. Registers Flathub as a system-wide Flatpak remote.
4. Removes the upstream isohybrid MBR/GPT/APM options while retaining BIOS and UEFI El Torito boot entries.
5. Creates a SHA-256 checksum and boot reports.

## ISO mode and validation

The intended USB-writing mode is **Rufus ISO Image mode**, not DD mode.

The build workflow records:
- El Torito boot entries for BIOS and UEFI.
- The ISO system-area report.
- SHA-256 checksum.
- The removable-media UEFI fallback loaders at `/EFI/BOOT/BOOTIA32.EFI` and `/EFI/BOOT/BOOTX64.EFI`, with PE/COFF architecture checks.

The IA32 loader is GRUB for 32-bit UEFI; the x64 loader is GRUB for 64-bit UEFI. Both are exported from the upstream `void-mklive` EFI boot image into the ISO filesystem so an ISO-to-ESP writer can copy them onto a FAT32 ESP. This does not by itself prove that the x86_64 kernel can boot through every 32-bit UEFI implementation: kernel EFI mixed-mode support and real Bay Trail/Cherry Trail device testing remain separate validation items.

A generated image is still a build candidate until the reports and actual boot tests have been reviewed. Do not describe an image as fully validated merely because the build succeeded.

## Release process

- Pushes to `main` create a downloadable Actions build artifact.
- Pushing a version tag matching `v*` builds the image and publishes the ISO, checksum, and reports to GitHub Releases.

## Build locally

The supported project workflow is GitHub Actions. The build script expects:
- a working Void Linux `void-mklive` environment,
- root privileges for filesystem mounts and image creation,
- the upstream `void-mklive` checkout.

The project build script is `iso/x86_64/build.sh`.

## Firmware selection (FCSF)

The initial Flat Cherry Selective Firmware (FCSF) utility is installed at `/usr/bin/fcsf` in the Live ISO.

- `fcsf menu`: choose Smart, Generic, or Manual.
- Smart reads PCI, USB, and CPU vendor identifiers and stages matching firmware paths.
- Generic stages the complete firmware collection already present in the ISO.
- Manual asks the user to choose vendors.
- All selection is offline; no firmware is downloaded.

The current build includes the Void firmware packages pulled by the x86_64 base-system dependencies. FCSF is an initial command-line staging engine, not yet connected to an installer UI. It must be invoked with the installed target mounted, for example:

```sh
FCSF_SOURCE_ROOT=/ FCSF_TARGET_ROOT=/mnt fcsf menu
```

FCSF does not yet configure Intel CPU microcode/initramfs automatically. Intel microcode is a separate `intel-ucode` package and needs its own installation/initramfs step. The Live ISO keeps its firmware intact so devices needed during the live session remain usable.

