#!/bin/bash
# Copyright (c) 2026 ravindu644 <droidcasts@protonmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Linux 4.19 arm64 kernel build script for SM-N986N

set -euo pipefail

# cd to the repo root
KERNEL_ROOT="$(dirname "$(readlink -f "$0")")"
cd "${KERNEL_ROOT}"

# create build folders
mkdir -p out dist

# export toolchain path and core variables
export PATH="${HOME}/toolchains/llvm-arm-toolchain-ship/10.0.9/bin:${PATH}"
export KBUILD_BUILD_USER="@ravindu644"
BUILD_CROSS_COMPILE="${HOME}/toolchains/aarch64-linux-android-4.9/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"

# download the toolchains if they aren't there yet
download_toolchains(){
    local base="https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains"
    if [ ! -x "${HOME}/toolchains/llvm-arm-toolchain-ship/10.0.9/bin/clang" ]; then
        echo "[INFO]: downloading llvm-arm-toolchain-ship-10.0.9..."
        mkdir -p "${HOME}/toolchains"
        wget -q --show-progress -O- "${base}/llvm-arm-toolchain-ship-10.0.9.tar.gz" | tar -xz -C "${HOME}/toolchains"
    fi
    if [ ! -x "${BUILD_CROSS_COMPILE}gcc" ]; then
        echo "[INFO]: downloading aarch64-linux-android-4.9..."
        mkdir -p "${HOME}/toolchains/aarch64-linux-android-4.9"
        wget -q --show-progress -O- "${base}/aarch64-linux-android-4.9.tar.gz" | tar -xz -C "${HOME}/toolchains/aarch64-linux-android-4.9"
    fi
}

# build options for the kernel
BUILD_OPTIONS=(
    -C "${KERNEL_ROOT}"
    O="${KERNEL_ROOT}/out"
    -j"$(nproc)"
    ARCH=arm64
    DTC_EXT="${KERNEL_ROOT}/tools/dtc"
    CONFIG_BUILD_ARM64_DT_OVERLAY=y
    CROSS_COMPILE="${BUILD_CROSS_COMPILE}"
    CC=clang
    CLANG_TRIPLE=aarch64-linux-gnu-
    LOCALVERSION=
)

build_kernel(){
    # cleanup
    # make "${BUILD_OPTIONS[@]}" clean && make "${BUILD_OPTIONS[@]}" mrproper
    
    # make default configuration.
    make "${BUILD_OPTIONS[@]}" vendor/c2q_kor_singlew_defconfig

    # menuconfig, only when someone is at a terminal (skipped in CI)
    [ -t 0 ] && make "${BUILD_OPTIONS[@]}" menuconfig

    # Build the kernel
    make "${BUILD_OPTIONS[@]}" || exit 1

    # Copy the built kernel to the build directory
    cp "${KERNEL_ROOT}/out/arch/arm64/boot/Image" "${KERNEL_ROOT}/dist/Image"
}

download_toolchains
build_kernel
