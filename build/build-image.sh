#!/bin/bash
# Package install directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_ROOT/images"

info() { echo "[build-image] $*"; }

for f in "$IMAGES_DIR/vmlinuz" "$IMAGES_DIR/initramfs.cpio" "$IMAGES_DIR/host.squashfs"; do
    [[ -f "$f" ]] || { info "Skipping: missing $f"; exit 0; }
done

INSTALL_DIR="$PROJECT_ROOT/install"
mkdir -p "$INSTALL_DIR"
cp "$IMAGES_DIR/vmlinuz" "$IMAGES_DIR/initramfs.cpio" "$IMAGES_DIR/host.squashfs" "$INSTALL_DIR/"
[[ -f "$IMAGES_DIR/.host_arch" ]] && cp "$IMAGES_DIR/.host_arch" "$INSTALL_DIR/"
[[ -d "$IMAGES_DIR/guest" ]] && cp -r "$IMAGES_DIR/guest" "$INSTALL_DIR/"

info "Installed to $INSTALL_DIR"
ls -la "$INSTALL_DIR"
