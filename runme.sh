#!/bin/bash
set -e

BASE_DIR=`pwd`


export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
export PATH=$BASE_DIR/build/toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin:$PATH


mkdir -p $BASE_DIR/build

###################################################################################################################################
#							DOWNLOAD Toolchain

if [[ ! -d $BASE_DIR/build/toolchain ]]; then
	mkdir $BASE_DIR/build/toolchain
	cd $BASE_DIR/build/toolchain
	wget https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
	tar -xvf gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE K3 Image Gen
IMAGE_GEN_TAG=08.00.00.004

if [[ ! -d $BASE_DIR/build/k3-image-gen ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/k3-image-gen/k3-image-gen.git -b $IMAGE_GEN_TAG --depth=1
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE ATF
ATF_TAG=08.00.00.004

if [[ ! -d $BASE_DIR/build/arm-trusted-firmware ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/atf/arm-trusted-firmware.git -b $ATF_TAG --depth=1
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE U-boot
U_BOOT_TAG=08.00.00.004

if [[ ! -d $BASE_DIR/build/ti-u-boot ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/ti-u-boot/ti-u-boot.git -b $U_BOOT_TAG --depth=1
	
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE Linux Kernel
KERNEL_TAG=08.00.00.004

if [[ ! -d $BASE_DIR/build/ti-linux-kernel ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/ti-linux-kernel/ti-linux-kernel.git	-b $KERNEL_TAG --depth=1
	cd ti-linux-kernel
	git am $BASE_DIR/patches/linux/*.patch
fi

###################################################################################################################################


mkdir -p $BASE_DIR/images


###################################################################################################################################
#							BUILD SYSFW
SOC=am64x

cd $BASE_DIR/build/k3-image-gen
make -j32 SOC=$SOC
cp sysfw-${SOC}-evm.itb  $BASE_DIR/images/sysfw.itb

###################################################################################################################################




###################################################################################################################################
#							BUILD BL31 
PLAT=k3

cd  $BASE_DIR/build/arm-trusted-firmware
make -j32 PLAT=$PLAT bl31
cp build/k3/generic/release/bl31.bin $BASE_DIR/images/bl31.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD U-boot
U_BOOT_DEFCONFIG=am64x_evm_a53_defconfig

cd $BASE_DIR/build/ti-u-boot
make -j32 $U_BOOT_DEFCONFIG
make  -j32 ATF=$BASE_DIR/images/bl31.bin
cp u-boot.bin $BASE_DIR/images/u-boot.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD Linux
LINUX_DEFCONFIG=tisdk_am64xx-evm_defconfig

cd $BASE_DIR/build/ti-linux-kernel
make -j32 $LINUX_DEFCONFIG
make  -j32 Image dtbs
cp arch/arm64/boot/Image $BASE_DIR/images/Image
cp arch/arm64/boot/dts/ti/k3-am642-evm.dtb $BASE_DIR/images/k3-am642-evm.dtb

###################################################################################################################################
