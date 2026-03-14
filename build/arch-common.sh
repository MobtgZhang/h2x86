#!/bin/bash
# h2x86: Architecture detection and Alpine mapping
# Supported hosts: LoongArch64, ARM64 (aarch64), RISC-V64 (riscv64)

# Map uname -m to Alpine release arch name
get_alpine_arch() {
    local m="${1:-$(uname -m)}"
    case "$m" in
        loongarch64)     echo "loongarch64" ;;
        aarch64|arm64)   echo "aarch64" ;;
        riscv64)         echo "riscv64" ;;
        *)               echo "" ;;
    esac
}

# Get host arch (for build), allow override via HOST_ARCH
get_host_arch() {
    local m="${HOST_ARCH:-$(uname -m)}"
    case "$m" in
        loongarch64)     echo "loongarch64" ;;
        aarch64|arm64)   echo "aarch64" ;;
        riscv64)         echo "riscv64" ;;
        *)               echo "" ;;
    esac
}

# QEMU machine type for host emulation
get_qemu_machine() {
    case "$1" in
        loongarch64)  echo "virt" ;;
        aarch64)      echo "virt" ;;
        riscv64)      echo "virt" ;;
        *)            echo "virt" ;;
    esac
}

# QEMU CPU type for host emulation
get_qemu_cpu() {
    case "$1" in
        loongarch64)  echo "la464" ;;
        aarch64)      echo "cortex-a72" ;;
        riscv64)      echo "rv64" ;;
        *)            echo "max" ;;
    esac
}

# QEMU binary for host emulation (full mode)
get_qemu_host() {
    case "$1" in
        loongarch64)  echo "qemu-system-loongarch64" ;;
        aarch64)      echo "qemu-system-aarch64" ;;
        riscv64)      echo "qemu-system-riscv64" ;;
        *)            echo "" ;;
    esac
}
