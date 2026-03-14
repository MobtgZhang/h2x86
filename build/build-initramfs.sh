#!/bin/bash
# Build initramfs and fetch host kernel (no cache)
# Supports: LoongArch64, ARM64 (aarch64), RISC-V64 (riscv64)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_ROOT/images"

ALPINE_VERSION="3.21.6"
ALPINE_BASE="https://dl-cdn.alpinelinux.org/alpine"

info() { echo "[build-initramfs] $*"; }
error() { echo "[build-initramfs] ERROR: $*" >&2; exit 1; }

. "$SCRIPT_DIR/arch-common.sh"
HOST_ARCH=$(get_host_arch)
[[ -z "$HOST_ARCH" ]] && error "Unsupported host arch. Supported: loongarch64, aarch64, riscv64"

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

info "Building initramfs for $HOST_ARCH..."

mkdir -p "$IMAGES_DIR"
VMLINUZ="$IMAGES_DIR/vmlinuz"

# 1. Get host kernel
if [[ ! -f "$VMLINUZ" ]]; then
    # Use system kernel if on native host
    if [[ "$(uname -m)" == "$HOST_ARCH" ]] || [[ "$(uname -m)" == "aarch64" && "$HOST_ARCH" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" && "$HOST_ARCH" == "aarch64" ]]; then
        if [[ -f /boot/vmlinuz ]]; then
            info "Using system kernel"
            cp /boot/vmlinuz "$VMLINUZ"
        fi
    fi

    # Download from Alpine if no system kernel
    if [[ ! -f "$VMLINUZ" ]]; then
        if [[ "$HOST_ARCH" == "loongarch64" ]] || [[ "$HOST_ARCH" == "aarch64" ]]; then
            info "Downloading Alpine ${HOST_ARCH} ISO..."
            url="${ALPINE_BASE}/v3.21/releases/${HOST_ARCH}/alpine-standard-${ALPINE_VERSION}-${HOST_ARCH}.iso"
            (command -v wget &>/dev/null && wget -q -O "$TMP/iso" "$url") || \
            (command -v curl &>/dev/null && curl -sSL -o "$TMP/iso" "$url") || \
            error "wget or curl required"

            info "Extracting kernel from ISO..."
            mkdir -p "$TMP/isoext"
            if command -v bsdtar &>/dev/null; then
                bsdtar -xf "$TMP/iso" -C "$TMP/isoext" 2>/dev/null || true
            elif command -v 7z &>/dev/null; then
                7z x -o"$TMP/isoext" "$TMP/iso" 2>/dev/null || true
            fi

            VMLINUZ_SRC=$(find "$TMP/isoext" -type f \( -name "vmlinuz*" -o -name "vmlinux*" \) 2>/dev/null | head -1)
            if [[ -n "$VMLINUZ_SRC" ]] && [[ -f "$VMLINUZ_SRC" ]]; then
                cp "$VMLINUZ_SRC" "$VMLINUZ"
            fi
        elif [[ "$HOST_ARCH" == "riscv64" ]]; then
            # riscv64: try alpine-uboot (contains kernel) or netboot
            info "Downloading Alpine riscv64 uboot..."
            url="${ALPINE_BASE}/v3.21/releases/riscv64/alpine-uboot-${ALPINE_VERSION}-riscv64.tar.gz"
            (command -v wget &>/dev/null && wget -q -O "$TMP/uboot.tar.gz" "$url") || \
            (command -v curl &>/dev/null && curl -sSL -o "$TMP/uboot.tar.gz" "$url") || true

            if [[ -f "$TMP/uboot.tar.gz" ]]; then
                mkdir -p "$TMP/uboot"
                tar -xzf "$TMP/uboot.tar.gz" -C "$TMP/uboot"
                VMLINUZ_SRC=$(find "$TMP/uboot" -type f \( -name "Image*" -o -name "vmlinuz*" -o -name "vmlinux*" \) 2>/dev/null | head -1)
                [[ -n "$VMLINUZ_SRC" ]] && [[ -f "$VMLINUZ_SRC" ]] && cp "$VMLINUZ_SRC" "$VMLINUZ"
            fi
        fi

        if [[ ! -f "$VMLINUZ" ]]; then
            error "Cannot get kernel. Place vmlinuz at $VMLINUZ manually (or run build on native $HOST_ARCH)"
        fi
    fi
fi

info "Kernel: $VMLINUZ"

# 2. Build initramfs
info "Downloading minirootfs (extract busybox)..."
url="${ALPINE_BASE}/v3.21/releases/${HOST_ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${HOST_ARCH}.tar.gz"
(command -v wget &>/dev/null && wget -q -O "$TMP/minirootfs.tar.gz" "$url") || \
curl -sSL -o "$TMP/minirootfs.tar.gz" "$url"

mkdir -p "$TMP/initramfs"/{bin,dev,proc,sys,newroot}
mkdir -p "$TMP/initramfs-extract"
tar -xzf "$TMP/minirootfs.tar.gz" -C "$TMP/initramfs-extract"

if [[ -f "$TMP/initramfs-extract/bin/busybox" ]]; then
    cp "$TMP/initramfs-extract/bin/busybox" "$TMP/initramfs/bin/"
elif [[ -f "$TMP/initramfs-extract/busybox" ]]; then
    cp "$TMP/initramfs-extract/busybox" "$TMP/initramfs/bin/"
else
    error "busybox not found in minirootfs"
fi
chmod +x "$TMP/initramfs/bin/busybox"
ln -sf busybox "$TMP/initramfs/bin/sh" 2>/dev/null || true
ln -sf busybox "$TMP/initramfs/bin/mount" 2>/dev/null || true
ln -sf busybox "$TMP/initramfs/bin/switch_root" 2>/dev/null || true

# Early init
cat > "$TMP/initramfs/init" << 'EARLYINIT'
#!/bin/sh
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -b /dev/vda ] && break
    [ -b /dev/sda ] && break
    sleep 0.5
done
SQUASH_DEV=""
[ -b /dev/vda ] && SQUASH_DEV=/dev/vda
[ -b /dev/sda ] && SQUASH_DEV=/dev/sda
[ -z "$SQUASH_DEV" ] && { echo "squashfs device not found"; exec /bin/sh; }
mount -t squashfs "$SQUASH_DEV" /newroot || { echo "mount failed"; exec /bin/sh; }
cd /newroot
exec switch_root /newroot /init
EARLYINIT
chmod +x "$TMP/initramfs/init"

# Pack
info "Packing initramfs..."
(cd "$TMP/initramfs" && find . | cpio -o -H newc) > "$IMAGES_DIR/initramfs.cpio"
gzip -9 -c "$IMAGES_DIR/initramfs.cpio" > "$IMAGES_DIR/initramfs.cpio.gz"

info "Done: $IMAGES_DIR/initramfs.cpio"
ls -lh "$IMAGES_DIR/initramfs.cpio"
