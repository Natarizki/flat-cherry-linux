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
