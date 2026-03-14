#!/bin/bash
# h2x86: Boot x86-64 Windows VM (separate from Linux)
# Usage: ./boot-windows.sh [iso_path] | ./boot-windows.sh --disk-only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${IMAGES_DIR:-$SCRIPT_DIR/images}"
GUEST_DIR="$IMAGES_DIR/guest/windows"

# Default paths (override via env)
WINDOWS_ISO="${WINDOWS_ISO:-$GUEST_DIR/win.iso}"
WINDOWS_DISK="${WINDOWS_DISK:-$GUEST_DIR/disk.qcow2}"
DISK_SIZE="${DISK_SIZE:-64G}"

find_qemu() {
    command -v qemu-system-x86_64 2>/dev/null || command -v qemu-system-x86_64-loongarch64 2>/dev/null || return 1
}

echo "=============================================="
echo "  h2x86: Boot x86-64 Windows (TCG)"
echo "=============================================="

QEMU=$(find_qemu) || {
    echo "Error: qemu-system-x86_64 not found"
    exit 1
}

mkdir -p "$GUEST_DIR"

# Disk-only mode (installed Windows)
if [[ "${1:-}" == "--disk-only" ]]; then
    if [[ ! -f "$WINDOWS_DISK" ]]; then
        echo "Error: Windows disk not found: $WINDOWS_DISK"
        echo "Complete Windows installation first, or specify existing VHD/qcow2"
        exit 1
    fi
    echo "Booting Windows from disk..."
    exec "$QEMU" \
        -accel tcg \
        -machine q35 \
        -cpu qemu64 \
        -m 4096 \
        -smp 2 \
        -drive "file=$WINDOWS_DISK,if=virtio,format=qcow2" \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
        -device qxl-vga,vgamem_mb=64 \
        -display gtk
fi

# ISO install mode
ISO_PATH="${1:-$WINDOWS_ISO}"
if [[ ! -f "$ISO_PATH" ]]; then
    echo ""
    echo "Error: Windows ISO not found: $ISO_PATH"
    echo ""
    echo "Download Windows ISO and run:"
    echo "  1. Get ISO from https://www.microsoft.com/software-download/windows11"
    echo "  2. Copy to: $GUEST_DIR/win.iso"
    echo "  3. Or specify: $0 /path/to/win.iso"
    echo ""
    echo "Boot from installed disk: $0 --disk-only"
    exit 1
fi

# Create disk if not exists
if [[ ! -f "$WINDOWS_DISK" ]]; then
    echo "Creating Windows disk: $WINDOWS_DISK (${DISK_SIZE})"
    qemu-img create -f qcow2 "$WINDOWS_DISK" "$DISK_SIZE"
fi

echo "  ISO:  $ISO_PATH"
echo "  Disk: $WINDOWS_DISK"
echo ""
echo "Note: Windows is slow under TCG. After install, use: $0 --disk-only"
echo "=============================================="
echo ""

exec "$QEMU" \
    -accel tcg \
    -machine q35 \
    -cpu qemu64 \
    -m 4096 \
    -smp 2 \
    -drive "file=$WINDOWS_DISK,if=virtio,format=qcow2" \
    -cdrom "$ISO_PATH" \
    -boot d \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device qxl-vga,vgamem_mb=64 \
    -display gtk
