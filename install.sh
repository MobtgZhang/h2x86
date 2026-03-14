#!/bin/bash
# h2x86: Install script - copy build outputs to target directory
# Usage: ./install.sh [install_dir]
# Default: /opt/vd-boot-loong

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
IMAGES_DIR="$PROJECT_ROOT/images"
INSTALL_PREFIX="${1:-/opt/vd-boot-loong}"

echo "=============================================="
echo "  h2x86 Install"
echo "=============================================="
echo "Target: $INSTALL_PREFIX"
echo ""

for f in "$IMAGES_DIR/vmlinuz" "$IMAGES_DIR/initramfs.cpio" "$IMAGES_DIR/host.squashfs"; do
    [[ -f "$f" ]] || {
        echo "Error: $f not found. Run ./build.sh first"
        exit 1
    }
done

mkdir -p "$INSTALL_PREFIX"
cp -v "$IMAGES_DIR/vmlinuz" "$INSTALL_PREFIX/"
cp -v "$IMAGES_DIR/initramfs.cpio" "$INSTALL_PREFIX/"
cp -v "$IMAGES_DIR/host.squashfs" "$INSTALL_PREFIX/"
[[ -f "$IMAGES_DIR/.host_arch" ]] && cp "$IMAGES_DIR/.host_arch" "$INSTALL_PREFIX/"
[[ -d "$IMAGES_DIR/guest" ]] && cp -rv "$IMAGES_DIR/guest" "$INSTALL_PREFIX/"

cat > "$INSTALL_PREFIX/run-linux.sh" << 'RUNSCRIPT'
#!/bin/sh
# Run Linux Guest: ./run-linux.sh ubuntu|debian|fedora|opensuse|archlinux
INSTALL_PREFIX="$(cd "$(dirname "$0")" && pwd)"
DISTRO="${1:-ubuntu}"
DISK=""
[ -f "$INSTALL_PREFIX/guest/$DISTRO/disk.qcow2" ] && DISK="$INSTALL_PREFIX/guest/$DISTRO/disk.qcow2"
[ -f "$INSTALL_PREFIX/guest/$DISTRO/disk.img" ] && DISK="$INSTALL_PREFIX/guest/$DISTRO/disk.img"
[ -z "$DISK" ] && { echo "$DISTRO image not found. Run download-guest.sh $DISTRO"; exit 1; }
FMT=$(echo "$DISK" | grep -q qcow2 && echo qcow2 || echo raw)
exec qemu-system-x86_64 -accel tcg -machine q35 -cpu qemu64 -m 2048 \
    -drive "file=$DISK,if=virtio,format=$FMT" \
    -nographic -serial mon:stdio
RUNSCRIPT
chmod +x "$INSTALL_PREFIX/run-linux.sh"

echo ""
echo "=============================================="
echo "  Install Complete"
echo "=============================================="
echo ""
echo "Location: $INSTALL_PREFIX"
echo ""
echo "Boot Linux: $INSTALL_PREFIX/run-linux.sh <ubuntu|debian|fedora|opensuse|archlinux>"
echo "  (Download first: ./download-guest.sh <distro>)"
echo ""
echo "Boot params (firmware/GRUB):"
echo "  kernel $INSTALL_PREFIX/vmlinuz console=ttyS0"
echo "  initrd $INSTALL_PREFIX/initramfs.cpio"
echo "  disk: $INSTALL_PREFIX/host.squashfs"
echo ""
