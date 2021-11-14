#!/bin/bash
set -e

BASE_DIR=`pwd`


export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
export PATH=$BASE_DIR/build/toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin:$PATH


mkdir -p $BASE_DIR/build


###################################################################################################################################
#                                                       INSTALL Packages

PACKAGES_LIST="sudo git make mtools coreutils u-boot-tools gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu python3 python3-pyelftools libssl-dev build-essential device-tree-compiler bc unzip tar util-linux binutils e2fsprogs gawk wget diffstat texinfo chrpath sed g++ bash patch cpio python2 rsync file python3-pip"

set +e
for i in $PACKAGES_LIST; do
	
	#Check if package is installed
	dpkg -s $i > /dev/null  2>&1
	
	#If exit code is not 0 - package is not installed
	if [ $? -ne 0 ]; then


		echo "Package $i is not installed"
		echo "If using apt package manager, you can install this tool using:"
		echo "	sudo apt install $i"
		echo "You can install all needed packages using:"
		echo "	sudo apt install $PACKAGES_LIST"

		exit -1
	fi

done

# Check if needed Python modules are installed

PYTHON_MODULES="pycryptodome"

for i in $PYTHON_MODULES; do

        #Check if module is installed
        pip3 list | grep $i > /dev/null 2>&1

        #If exit code is not 0 - module is not installed
        if [ $? -ne 0 ]; then


                echo "Python module $i is not installed"
                echo "Please install it using:"
                echo "  pip3 install $i"

                exit -1
        fi

done

set -e

###################################################################################################################################




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
	cd ti-u-boot
	git am $BASE_DIR/patches/uboot/*.patch
	
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
	cd buildroot
	git am $BASE_DIR/patches/buildroot/*.patch
fi

###################################################################################################################################


mkdir -p $BASE_DIR/tmp




###################################################################################################################################
#							BUILD ATF 
PLAT=k3

cd  $BASE_DIR/build/arm-trusted-firmware
make -j32 CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 PLAT=$PLAT TARGET_BOARD=lite SPD=opteed
cp build/k3/lite/release/bl31.bin $BASE_DIR/tmp/bl31.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD OPTEE
PLATFORM=k3-am64x

cd  $BASE_DIR/build/optee_os
make -j32  ARCH=arm PLATFORM=$PLATFORM CROSS_COMPILE32=arm-linux-gnueabihf- CFG_ARM64_core=y
cp out/arm-plat-k3/core/tee-pager_v2.bin $BASE_DIR/tmp/tee-pager_v2.bin 

###################################################################################################################################




###################################################################################################################################
#							BUILD U-boot


U_BOOT_R5_DEFCONFIG=am64x_r5_solidrun_defconfig
U_BOOT_A53_DEFCONFIG=am64x_a53_solidrun_defconfig
cd $BASE_DIR/build/ti-u-boot


# 	R5

make -j32 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- $U_BOOT_R5_DEFCONFIG
make -j32 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
cp tiboot3.bin $BASE_DIR/tmp/tiboot3.bin



# 	A53

make -j32 ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- $U_BOOT_A53_DEFCONFIG
make -j32 ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- ATF=$BASE_DIR/tmp/bl31.bin TEE=$BASE_DIR/tmp/tee-pager_v2.bin


cp tispl.bin $BASE_DIR/tmp/tispl.bin
cp u-boot.img $BASE_DIR/tmp/u-boot.img

###################################################################################################################################




###################################################################################################################################
#							BUILD SYSFW
SOC=am64x

cd $BASE_DIR/build/k3-image-gen
make CROSS_COMPILE=arm-linux-gnueabihf- SOC=$SOC
cp sysfw-${SOC}-evm.itb  $BASE_DIR/tmp/sysfw.itb

###################################################################################################################################




###################################################################################################################################
#							BUILD Linux
LINUX_DEFCONFIG=am64xx-solidrun_defconfig

cd $BASE_DIR/build/ti-linux-kernel
make -j32 $LINUX_DEFCONFIG
make  -j32 Image dtbs
cp arch/arm64/boot/Image $BASE_DIR/tmp/Image
cp arch/arm64/boot/dts/ti/am642-solidrun.dtb $BASE_DIR/tmp/am642-solidrun.dtb

###################################################################################################################################




##################################################################################################################################
#							BUILD Buildroot
BUILDROOT_DEFCONFIG=am64x_solidrun_defconfig

cd $BASE_DIR/build/buildroot
make -j32 $BUILDROOT_DEFCONFIG
make -j32

cp $BASE_DIR/build/buildroot/output/images/rootfs.cpio.uboot $BASE_DIR/tmp/rootfs.cpio

###################################################################################################################################


mkdir -p $BASE_DIR/output




###################################################################################################################################
#							Create Image file

#Image name should include the commit hash
cd $BASE_DIR
COMMIT_HASH=`git log -1 --pretty=format:%h`
IMAGE_NAME=microsd-${COMMIT_HASH}.img


dd if=/dev/zero of=$BASE_DIR/output/$IMAGE_NAME bs=1M count=300

mformat -F -i $BASE_DIR/output/$IMAGE_NAME ::

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/tiboot3.bin ::tiboot3.bin

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/tispl.bin ::tispl.bin

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/u-boot.img ::u-boot.img

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/sysfw.itb ::sysfw.itb

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/Image ::Image

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/am642-solidrun.dtb ::am642-solidrun.dtb

mcopy -i $BASE_DIR/output/$IMAGE_NAME $BASE_DIR/tmp/rootfs.cpio ::rootfs.cpio

printf "\n\nImage file: $BASE_DIR/output/$IMAGE_NAME\n\n"

###################################################################################################################################


