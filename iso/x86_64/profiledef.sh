#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="flat-cherry"
iso_label="FLATCHERRY_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Flat Cherry Linux"
iso_application="Flat Cherry Linux Live/Install Media"
iso_version="0.1.0-alpha.1"
install_dir="flatcherry"

bootmodes=('bios.syslinux'
           'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
file_permissions=()
