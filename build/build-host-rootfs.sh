#!/bin/bash
# Build Host RootFS: download -> extract -> build -> cleanup (no cache)
# Supports: LoongArch64, ARM64 (aarch64), RISC-V64 (riscv64)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_ROOT/images"

ALPINE_VERSION="3.21.6"
ALPINE_BASE="https://dl-cdn.alpinelinux.org/alpine"

info() { echo "[build-host-rootfs] $*"; }
error() { echo "[build-host-rootfs] ERROR: $*" >&2; exit 1; }

# Source arch helpers
. "$SCRIPT_DIR/arch-common.sh"
HOST_ARCH=$(get_host_arch)
[[ -z "$HOST_ARCH" ]] && error "Unsupported host arch: $(uname -m). Supported: loongarch64, aarch64, riscv64"

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

info "Building Host RootFS for $HOST_ARCH..."

# 1. Download minirootfs for host arch
info "Downloading Alpine ${HOST_ARCH} minirootfs..."
url="${ALPINE_BASE}/v3.21/releases/${HOST_ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${HOST_ARCH}.tar.gz"
(command -v wget &>/dev/null && wget -q -O "$TMP/minirootfs.tar.gz" "$url") || \
(command -v curl &>/dev/null && curl -sSL -o "$TMP/minirootfs.tar.gz" "$url") || \
error "wget or curl required"

# 2. Extract
info "Extracting..."
mkdir -p "$TMP/rootfs"
tar -xzf "$TMP/minirootfs.tar.gz" -C "$TMP/rootfs"
rm -f "$TMP/minirootfs.tar.gz"

# 3. Create directories
mkdir -p "$TMP/rootfs/usr/bin" "$TMP/rootfs/launcher" \
         "$TMP/rootfs/dev" "$TMP/rootfs/proc" "$TMP/rootfs/sys" \
         "$TMP/rootfs/run" "$TMP/rootfs/tmp"

# 4. Install host init
cat > "$TMP/rootfs/init" << 'HOSTINIT'
#!/bin/sh
export PATH=/usr/bin:/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mdev -s
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts 2>/dev/null || true
echo "h2x86: Host ready, starting x86-64 VM..."
exec /launcher/start-x86.sh
HOSTINIT
chmod +x "$TMP/rootfs/init"

# 5. Install launcher
mkdir -p "$TMP/rootfs/launcher"
cat > "$TMP/rootfs/launcher/start-x86.sh" << 'LAUNCHER'
#!/bin/sh
QEMU="${QEMU:-/usr/bin/qemu-system-x86_64}"
GUEST_DISK="${GUEST_DISK:-/dev/vdb}"
[ ! -x "$QEMU" ] && { echo "Error: $QEMU not found"; exec /bin/sh; }
[ ! -b "$GUEST_DISK" ] && { echo "Error: Guest disk $GUEST_DISK not found"; exec /bin/sh; }
echo "Starting x86-64 (QEMU TCG)..."
exec "$QEMU" -accel tcg -machine q35 -cpu qemu64 -m 2048 \
    -drive "file=$GUEST_DISK,if=virtio,format=raw" \
    -nographic -serial mon:stdio
LAUNCHER
chmod +x "$TMP/rootfs/launcher/start-x86.sh"

# 6. Copy QEMU
if command -v qemu-system-x86_64 &>/dev/null; then
    info "Copying QEMU..."
    cp "$(command -v qemu-system-x86_64)" "$TMP/rootfs/usr/bin/qemu-system-x86_64"
    chmod +x "$TMP/rootfs/usr/bin/qemu-system-x86_64"
else
    info "qemu-system-x86_64 not found, install on target system"
    touch "$TMP/rootfs/usr/bin/.qemu-placeholder"
fi

# 7. Create SquashFS
mkdir -p "$IMAGES_DIR"
info "Creating host.squashfs..."
mksquashfs "$TMP/rootfs" "$IMAGES_DIR/host.squashfs" -noappend -comp xz -b 1M 2>/dev/null || \
mksquashfs "$TMP/rootfs" "$IMAGES_DIR/host.squashfs" -noappend -comp gzip 2>/dev/null || \
error "mksquashfs (squashfs-tools) required"

# Save host arch for boot.sh
echo "$HOST_ARCH" > "$IMAGES_DIR/.host_arch"

info "Done: $IMAGES_DIR/host.squashfs"
ls -lh "$IMAGES_DIR/host.squashfs"
