#!/bin/bash
# Copyright (c) 2026 ravindu644 <droidcasts@protonmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Linux 4.19 arm64 kernel build script for SM-N986N

set -euo pipefail

# cd to the repo root
KERNEL_ROOT="$(dirname "$(readlink -f "$0")")"
cd "${KERNEL_ROOT}"

# generate localversion
BUILD_VERSION=$(git log -1 --pretty=%h 2>/dev/null)
if [ -z "$BUILD_VERSION" ]; then
    export BUILD_VERSION="dev"
fi
cat << EOF > "${KERNEL_ROOT}/arch/arm64/configs/version.config"
CONFIG_LOCALVERSION_AUTO=n
CONFIG_LOCALVERSION="-ravindu644-${BUILD_VERSION}"
EOF

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
    make "${BUILD_OPTIONS[@]}" vendor/c2q_kor_singlew_defconfig custom.config version.config

    # menuconfig, only when someone is at a terminal (skipped in CI)
    [ -t 0 ] && make "${BUILD_OPTIONS[@]}" menuconfig

    # Build the kernel
    make "${BUILD_OPTIONS[@]}" || exit 1

    # Copy the built kernel to the build directory
    cp "${KERNEL_ROOT}/out/arch/arm64/boot/Image" "${KERNEL_ROOT}/dist/Image"
}

# header v2 carries the dtb in its own section and the stock kernel is a bare Image,
# so Image-dtb (UNCOMPRESSED_IMG header + appended dtbs) is not what goes in here.
# -n keeps samsung's gzip ramdisk as is, recompressing it changes the image.
# magiskboot drops samsung's SignerVer02 block, the N986N bootloader boots fine without it.
build_boot_img(){
    local work="${KERNEL_ROOT}/out/bootimg" mb="${KERNEL_ROOT}/prebuilts/magiskboot"
    rm -rf "${work}" && mkdir -p "${work}" && cd "${work}"
    "${mb}" unpack -n "${KERNEL_ROOT}/prebuilts/boot.img"
    cp "${KERNEL_ROOT}/dist/Image" kernel
    "${mb}" repack "${KERNEL_ROOT}/prebuilts/boot.img" "${KERNEL_ROOT}/dist/boot.img"
    cd "${KERNEL_ROOT}" && rm -rf "${work}"
}

build_tar(){
    # Odin-flashable tar
    cd "${KERNEL_ROOT}/dist"
    tar -cvf "SM-N986N-BakaSU-${BUILD_VERSION}.tar" boot.img && \
        echo -e "\n[INFO]: TAR BUILT SUCCESSFULLY..!\n"
    cd "${KERNEL_ROOT}"
}

download_toolchains
build_kernel
build_boot_img
build_tar
