# Flat Cherry Selective Firmware (FCSF)

FCSF is the firmware-selection component for Flat Cherry Linux.

## Firmware policy

- **Network firmware is bundled** in the Live ISO through Void's `linux-firmware-network` package (which depends on Broadcom network firmware).
- **Additional firmware is online** and installed into the target system with XBPS.
- FCSF always selects network firmware for the installed system, then selects additional packages based on detected hardware or user choice.

## User-facing modes

- **Smart Online**: detect PCI graphics and CPU vendors, keep network firmware, and install matching additional firmware.
- **Generic Online**: install AMD, Intel, NVIDIA and network firmware packages.
- **Manual Online**: let the user select additional AMD, Intel and NVIDIA firmware packages.
- **Detect**: report detected categories without installing anything.

## Invocation

```sh
fcsf menu
fcsf detect
fcsf smart
fcsf generic
fcsf manual
```

For installer integration, initialize and mount the installed Void system at `/mnt`, connect to the internet, then run FCSF as root:

```sh
FCSF_TARGET_ROOT=/mnt fcsf menu
```

FCSF uses the target system's XBPS repository configuration. Internet access is required for packages not already available locally.

## Flatpak and FPM

The Live ISO bundles Flatpak and the FPM command-line frontend. Flathub is configured system-wide during image setup. FPM manages Flatpak applications only; XBPS remains responsible for system packages.

## Implementation status and limitations

FCSF is a firmware-selection/staging engine and is not yet wired into a graphical installer. The current repository builds a Void-based Live ISO and does not yet contain a complete installer frontend.

Hardware detection currently distinguishes PCI graphics-class devices and CPU vendors. It does not yet map every PCI/USB device ID to an exact driver/firmware requirement. Intel CPU microcode activation is not implemented here. Validate package availability and target XBPS configuration on each supported release.

The Live ISO retains network firmware so supported Wi-Fi/Ethernet devices can connect before optional firmware is downloaded. Additional firmware is installed only into the target system.
