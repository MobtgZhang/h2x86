#!/bin/bash
# h2x86 / vd-boot-loong: Main build script
# Builds minimal LoongArch64 core (initramfs + SquashFS) -> QEMU -> x86-64
#
# Outputs: images/host.squashfs, initramfs.cpio, vmlinuz-loongarch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
IMAGES_DIR="$PROJECT_ROOT/images"

ALPINE_LA_VERSION="3.21.6"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

check_deps() {
    local missing=""
    command -v mksquashfs &>/dev/null || missing="squashfs-tools"
    command -v wget &>/dev/null || command -v curl &>/dev/null || missing="$missing wget or curl"
    command -v cpio &>/dev/null || missing="$missing cpio"
    command -v tar &>/dev/null || missing="$missing tar"
    if [[ -n "$missing" ]]; then
        echo "Missing: $missing"
        echo "Install (Debian/Ubuntu): sudo apt install squashfs-tools cpio"
        exit 1
    fi
}

# 主流程
main() {
    echo "=============================================="
    echo "  h2x86 Build"
    echo "=============================================="
    echo ""

    check_deps
    mkdir -p "$BUILD_DIR" "$IMAGES_DIR"

    "$SCRIPT_DIR/build/build-host-rootfs.sh"
    "$SCRIPT_DIR/build/build-initramfs.sh"
    "$SCRIPT_DIR/build/build-image.sh"

    echo ""
    echo "=============================================="
    echo "  Build Complete"
    echo "=============================================="
    echo ""
    echo "Outputs:"
    echo "  - $IMAGES_DIR/vmlinuz"
    echo "  - $IMAGES_DIR/initramfs.cpio"
    echo "  - $IMAGES_DIR/host.squashfs"
    echo ""
    echo "Download Guest: ./download-guest.sh ubuntu|debian|fedora|opensuse|archlinux|all"
    echo "Boot: ./boot.sh ubuntu | ./boot.sh --full ubuntu | ./boot-windows.sh"
    echo ""
}

main "$@"
