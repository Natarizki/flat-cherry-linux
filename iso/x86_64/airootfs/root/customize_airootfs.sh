#!/usr/bin/env bash
set -euo pipefail

# Keep the live image English-only and remove non-runtime documentation.
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
  ! -name 'en_US' -exec rm -rf -- {} + 2>/dev/null || true

rm -rf /usr/share/man/* /usr/share/info/* /usr/share/gtk-doc/* /usr/share/doc/*
rm -rf /var/cache/pacman/pkg/*

# Development-only files are not needed in the live desktop.
rm -rf /usr/include/*
find /usr/lib -type f -name '*.a' -delete 2>/dev/null || true
find /usr/lib -type d -name pkgconfig -prune -exec rm -rf -- {} + 2>/dev/null || true
find /usr/share -type d -name pkgconfig -prune -exec rm -rf -- {} + 2>/dev/null || true
