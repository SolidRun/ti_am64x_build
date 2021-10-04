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
#							CLONE OPTEE
OPTEE_HASH=e4ca953c381e176bafe5a703c0cd18dd21aa5af5

if [[ ! -d $BASE_DIR/build/optee_os ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/OP-TEE/optee_os.git
	cd optee_os
	git reset --hard $OPTEE_HASH
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




###################################################################################################################################
#							CLONE Buildroot
BUILDROOT_VERSION=2020.02

if [[ ! -d $BASE_DIR/build/buildroot ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/buildroot/buildroot -b $BUILDROOT_VERSION --depth=1
fi

###################################################################################################################################


mkdir -p $BASE_DIR/images




###################################################################################################################################
#							BUILD ATF 
PLAT=k3

cd  $BASE_DIR/build/arm-trusted-firmware
make -j32 CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 PLAT=$PLAT TARGET_BOARD=generic SPD=opteed
cp build/k3/generic/release/bl31.bin $BASE_DIR/images/bl31.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD OPTEE
PLATFORM=k3-am64x

cd  $BASE_DIR/build/optee_os
make -j32  ARCH=arm PLATFORM=$PLATFORM CROSS_COMPILE32=arm-linux-gnueabihf- CFG_ARM64_core=y
cp out/arm-plat-k3/core/tee-pager_v2.bin $BASE_DIR/images/tee-pager_v2.bin 

###################################################################################################################################




###################################################################################################################################
#							BUILD U-boot


U_BOOT_R5_DEFCONFIG=am64x_evm_r5_defconfig
U_BOOT_A53_DEFCONFIG=am64x_evm_a53_defconfig
cd $BASE_DIR/build/ti-u-boot


# 	R5

make -j32 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- $U_BOOT_R5_DEFCONFIG
make -j32 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
cp spl/u-boot-spl.bin $BASE_DIR/images/u-boot-spl.bin
cp tiboot3.bin $BASE_DIR/images/tiboot3.bin



# 	A53

make -j32 ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- $U_BOOT_A53_DEFCONFIG
make -j32 ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- ATF=$BASE_DIR/images/bl31.bin TEE=$BASE_DIR/images/tee-pager_v2.bin

cp tispl.bin $BASE_DIR/images/tispl.bin
cp u-boot.img $BASE_DIR/images/u-boot.img

###################################################################################################################################




###################################################################################################################################
#							BUILD SYSFW
SOC=am64x

cd $BASE_DIR/build/k3-image-gen
#make -j32 SOC=$SOC SBL=$BASE_DIR/images/u-boot-spl.bin
make CROSS_COMPILE=arm-linux-gnueabihf- SOC=$SOC
cp sysfw-${SOC}-evm.itb  $BASE_DIR/images/sysfw.itb
#cp tiboot3.bin  $BASE_DIR/images/tiboot3.bin

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




##################################################################################################################################
#							BUILD Buildroot

cd $BASE_DIR/build/buildroot
cp $BASE_DIR/configs/buildroot_defconfig configs/am64x_solidrun_defconfig

make -j32 am64x_solidrun_defconfig
make -j32

cp $BASE_DIR/build/buildroot/output/images/rootfs.cpio.uboot $BASE_DIR/images/rootfs.cpio

###################################################################################################################################
