# Building Flat Cherry Linux

## Current milestone

Target release: `v0.1.0-alpha.1`

The first milestone focuses on an x86_64 live image based on Arch Linux, using LXQt, X11, and systemd.

## Build environment

ISO builds are intended to run on GitHub Actions rather than on the project maintainer's phone.

The initial workflow should:
1. Run on an Ubuntu GitHub-hosted runner.
2. Use an Arch Linux container to install Archiso and build dependencies.
3. Build the x86_64 profile with `mkarchiso`.
4. Upload the resulting ISO and SHA-256 checksum as a workflow artifact.

## Release validation gates

A successful `mkarchiso` run alone does not make an image release-ready.

Before calling the image non-hybrid and publishing it as a supported release, validate:

- El Torito boot catalog and boot entries.
- Absence of unintended isohybrid MBR/GPT structures.
- UEFI boot in QEMU.
- BIOS boot in QEMU, if BIOS support is included in the milestone.
- SHA-256 checksum generation and verification.

## Important status

The non-hybrid conversion and validation process is not implemented yet. Until those checks pass, generated images must be treated as build candidates, not confirmed non-hybrid releases.
