# Flat Cherry Selective Firmware (FCSF)

FCSF is the firmware-selection component for Flat Cherry Linux.

## User-facing modes

- **Smart**: inspect the current machine's PCI, USB and CPU vendor identifiers, then stage firmware associated with detected vendors.
- **Generic**: retain the complete firmware collection already present in the ISO.
- **Manual**: let the user select firmware vendors.

All modes are offline. FCSF does not download firmware.

## Invocation

```sh
fcsf menu
fcsf detect
fcsf smart
fcsf generic
fcsf manual
```

For installer integration, mount the installed system at `/mnt` and expose the Live ISO firmware tree:

```sh
FCSF_SOURCE_ROOT=/ FCSF_TARGET_ROOT=/mnt fcsf menu
```

## Important implementation status

This is the initial selection/staging engine, not yet wired into a graphical installer. The current repository builds a Void-based Live ISO and does not yet contain an installer frontend. The installer must call FCSF after mounting the target system.

The current vendor-to-directory map is intentionally conservative and must be expanded/validated against the exact Void `linux-firmware` package contents. CPU microcode must be installed and activated using the appropriate Void package/initramfs mechanism; copying a directory alone is not sufficient. FCSF therefore reports/stages detected CPU payloads but does not claim to configure early microcode loading.

The Live ISO must retain the full offline firmware candidate set so that hardware needed during the live session (especially Wi-Fi) works before the user makes a selection. Smart selection affects the target installation, not the already-booted Live environment.
