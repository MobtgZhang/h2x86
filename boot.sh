#!/bin/bash
# h2x86: Boot x86-64 Linux VM (Ubuntu, Debian, Fedora, OpenSUSE, Arch Linux)
# Host: LoongArch64, ARM64, or RISC-V64
# Usage: ./boot.sh <distro> | ./boot.sh --direct <distro> | ./boot.sh --full [distro]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${IMAGES_DIR:-$SCRIPT_DIR/images}"
GUEST_BASE="$IMAGES_DIR/guest"

DISTROS="ubuntu debian fedora opensuse archlinux"

find_qemu() {
    for cmd in qemu-system-x86_64 qemu-system-x86_64-loongarch64; do
        if command -v "$cmd" &>/dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    return 1
}

get_guest_disk() {
    local distro="$1"
    local dir="$GUEST_BASE/$distro"
    if [[ -f "$dir/disk.qcow2" ]]; then
        echo "$dir/disk.qcow2"
    elif [[ -f "$dir/disk.img" ]]; then
        echo "$dir/disk.img"
    else
        return 1
    fi
}

get_disk_format() {
    [[ "$1" == *.qcow2 ]] && echo "qcow2" || echo "raw"
}

boot_linux() {
    local distro="$1"
    local disk
    disk=$(get_guest_disk "$distro") || {
        echo "Error: $distro image not found"
        echo "Run: ./download-guest.sh $distro"
        exit 1
    }

    local QEMU
    QEMU=$(find_qemu) || { echo "Error: qemu-system-x86_64 not found"; exit 1; }

    local fmt
    fmt=$(get_disk_format "$disk")

    echo "=============================================="
    echo "  h2x86: Boot x86-64 $distro (TCG)"
    echo "=============================================="
    echo "  Disk: $disk"
    echo "=============================================="
    echo ""

    exec "$QEMU" \
        -accel tcg \
        -machine q35 \
        -cpu qemu64 \
        -m 2048 \
        -smp 2 \
        -drive "file=$disk,if=virtio,format=$fmt" \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -nographic \
        -serial mon:stdio
}

# Map host arch to QEMU binary and params (for full mode)
get_qemu_for_host() {
    case "$1" in
        loongarch64) echo "qemu-system-loongarch64:-M virt:-cpu la464" ;;
        aarch64)     echo "qemu-system-aarch64:-M virt:-cpu cortex-a72" ;;
        riscv64)     echo "qemu-system-riscv64:-M virt:-cpu rv64" ;;
        *)           echo "" ;;
    esac
}

boot_full() {
    local distro="${1:-ubuntu}"
    local disk
    disk=$(get_guest_disk "$distro") || {
        echo "Error: $distro image not found. Run ./download-guest.sh $distro"
        exit 1
    }

    local host_arch="loongarch64"
    [[ -f "$IMAGES_DIR/.host_arch" ]] && host_arch=$(cat "$IMAGES_DIR/.host_arch")

    local spec
    spec=$(get_qemu_for_host "$host_arch")
    [[ -z "$spec" ]] && { echo "Error: Unknown host arch $host_arch"; exit 1; }

    local qemu_bin machine cpu
    IFS=: read -r qemu_bin machine cpu <<< "$spec"

    qemu_bin=$(command -v "$qemu_bin" 2>/dev/null) || {
        echo "Error: $qemu_bin not found"
        echo "Full mode requires QEMU with $host_arch support"
        exit 1
    }

    [[ -f "$IMAGES_DIR/vmlinuz" ]] || { echo "Error: Run ./build.sh first"; exit 1; }
    [[ -f "$IMAGES_DIR/initramfs.cpio" ]] || { echo "Error: Run ./build.sh first"; exit 1; }
    [[ -f "$IMAGES_DIR/host.squashfs" ]] || { echo "Error: Run ./build.sh first"; exit 1; }

    echo "=============================================="
    echo "  h2x86 Full Mode ($host_arch Host + x86 $distro)"
    echo "=============================================="

    exec "$qemu_bin" \
        $machine \
        -m 2048 \
        $cpu \
        -kernel "$IMAGES_DIR/vmlinuz" \
        -initrd "$IMAGES_DIR/initramfs.cpio" \
        -drive file="$IMAGES_DIR/host.squashfs",if=virtio,format=raw \
        -drive "file=$disk",if=virtio,format=$(get_disk_format "$disk") \
        -nographic \
        -serial mon:stdio \
        -append "console=ttyS0"
}

case "${1:-}" in
    --direct)
        shift
        [[ -n "$1" ]] || { echo "Usage: $0 --direct <$DISTROS>"; exit 1; }
        boot_linux "$1"
        ;;
    --full)
        shift
        boot_full "${1:-ubuntu}"
        ;;
    ubuntu|debian|fedora|opensuse|archlinux)
        boot_linux "$1"
        ;;
    "")
        echo "Usage: $0 <ubuntu|debian|fedora|opensuse|archlinux>"
        echo "       $0 --direct <distro>  # Direct mode"
        echo "       $0 --full [distro]    # Full mode (Host + x86 Guest)"
        echo ""
        echo "Download first: ./download-guest.sh <distro>"
        exit 0
        ;;
    *)
        echo "Unknown distro: $1"
        echo "Supported: $DISTROS"
        exit 1
        ;;
esac
