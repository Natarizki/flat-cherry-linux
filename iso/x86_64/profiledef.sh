#!/usr/bin/env bash

iso_name="flat-cherry"
iso_label="FLATCHERRY_$(date +%Y%m)"
iso_publisher="Flat Cherry Linux"
iso_application="Flat Cherry Linux Live/Install Media"
iso_version="0.1.0-alpha.1"
install_dir="flat-cherry"

buildmodes=('iso')
bootmodes=('uefi.systemd-boot' 'bios.syslinux')
arch="x86_64"

pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
file_permissions=()
