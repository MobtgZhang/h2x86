#!/bin/bash
# h2x86: Download x86-64 Guest images (Ubuntu, Debian, Fedora, OpenSUSE, Arch Linux)
# Usage: ./download-guest.sh [ubuntu|debian|fedora|opensuse|archlinux|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${IMAGES_DIR:-$SCRIPT_DIR/images}"
GUEST_BASE="$IMAGES_DIR/guest"

download_file() {
    local url="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
        echo "  Exists: $dest (skip)"
        return 0
    fi
    echo "  Downloading: $url"
    if command -v wget &>/dev/null; then
        wget -c -O "$dest" "$url" 2>/dev/null || wget -O "$dest" "$url"
    else
        curl -fSL -C - -o "$dest" "$url"
    fi
}

# Ubuntu 24.04 LTS (cloud image, raw)
download_ubuntu() {
    local dir="$GUEST_BASE/ubuntu"
    mkdir -p "$dir"
    local url="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    download_file "$url" "$dir/disk.img"
    echo "ubuntu" > "$dir/.distro"
    echo "✅ Ubuntu 24.04 LTS -> $dir/disk.img"
}

# Debian 12 Bookworm (nocloud for local QEMU)
download_debian() {
    local dir="$GUEST_BASE/debian"
    mkdir -p "$dir"
    local url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2"
    download_file "$url" "$dir/disk.qcow2"
    echo "debian" > "$dir/.distro"
    echo "✅ Debian 12 Bookworm -> $dir/disk.qcow2"
}

# Fedora Cloud Base 40
download_fedora() {
    local dir="$GUEST_BASE/fedora"
    mkdir -p "$dir"
    # Riken mirror
    local url="https://ftp.riken.jp/Linux/fedora/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"
    download_file "$url" "$dir/disk.qcow2"
    echo "fedora" > "$dir/.distro"
    echo "✅ Fedora Cloud 40 -> $dir/disk.qcow2"
}

# OpenSUSE Leap 15.6
download_opensuse() {
    local dir="$GUEST_BASE/opensuse"
    mkdir -p "$dir"
    local url="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.x86_64-NoCloud.qcow2"
    download_file "$url" "$dir/disk.qcow2"
    echo "opensuse" > "$dir/.distro"
    echo "✅ OpenSUSE Leap 15.6 -> $dir/disk.qcow2"
}

# Arch Linux (arch-boxes)
download_archlinux() {
    local dir="$GUEST_BASE/archlinux"
    mkdir -p "$dir"
    local url="https://mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
    download_file "$url" "$dir/disk.qcow2"
    echo "archlinux" > "$dir/.distro"
    echo "✅ Arch Linux -> $dir/disk.qcow2"
}

# 主入口
main() {
    echo "=============================================="
    echo "  h2x86 Guest Image Download"
    echo "=============================================="
    echo "Target: $GUEST_BASE"
    echo ""

    case "${1:-}" in
        ubuntu)     download_ubuntu ;;
        debian)     download_debian ;;
        fedora)     download_fedora ;;
        opensuse)   download_opensuse ;;
        archlinux)  download_archlinux ;;
        all)
            download_ubuntu
            download_debian
            download_fedora
            download_opensuse
            download_archlinux
            ;;
        "")
            echo "Usage: $0 <ubuntu|debian|fedora|opensuse|archlinux|all>"
            echo ""
            echo "Examples:"
            echo "  $0 ubuntu     # Download Ubuntu 24.04"
            echo "  $0 debian     # Download Debian 12"
            echo "  $0 fedora     # Download Fedora Cloud"
            echo "  $0 opensuse   # Download OpenSUSE Leap 15.6"
            echo "  $0 archlinux  # Download Arch Linux"
            echo "  $0 all        # Download all"
            exit 0
            ;;
        *)
            echo "Unknown distro: $1"
            echo "Supported: ubuntu, debian, fedora, opensuse, archlinux, all"
            exit 1
            ;;
    esac

    echo ""
    echo "Boot: ./boot.sh $1 | ./boot-windows.sh"
}

main "$@"
