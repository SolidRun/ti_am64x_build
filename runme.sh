#!/bin/bash
set -e

###################################################################################################################################
#							OPTIONS

# Distribution for rootfs
# - buildroot
# - debian
: ${DISTRO:=buildroot}

## Buildroot Options
: ${BUILDROOT_VERSION:=2020.02}
: ${BUILDROOT_DEFCONFIG:=am64xx_solidrun_defconfig}
: ${BR2_PRIMARY_SITE:=}

## Debian Options
: ${DEBIAN_VERSION:=bullseye}
: ${DEBIAN_ROOTFS_SIZE:=936M}

###################################################################################################################################

# Check if git user name and git email are configured
if [ -z "`git config user.name`" ] || [ -z "`git config user.email`" ]; then
			echo "git is not configured, please run:"
			echo "git config --global user.email \"you@example.com\""
			echo "git config --global user.name \"Your Name\""
			exit -1
fi


BASE_DIR=`pwd`


export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
export PATH=$BASE_DIR/build/toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin:$PATH


mkdir -p $BASE_DIR/build

# Get number of jobs in this machine to use with make command
JOBS=$(getconf _NPROCESSORS_ONLN)

###################################################################################################################################
#                                                       INSTALL Packages

PACKAGES_LIST="bc bison build-essential ca-certificates cpio crossbuild-essential-arm64 crossbuild-essential-armhf debootstrap device-tree-compiler e2tools fakeroot fdisk flex git kmod libncurses-dev libssl-dev make mtools parted python3-pyelftools qemu-system-arm rsync sudo u-boot-tools unzip wget xz-utils"

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
#							DOWNLOAD Buildroot
do_fetch_buildroot() {
	if [[ ! -d $BASE_DIR/build/buildroot ]]; then
		cd $BASE_DIR/build
		git clone https://github.com/buildroot/buildroot -b $BUILDROOT_VERSION --depth=1
		cd buildroot
		git am $BASE_DIR/patches/buildroot/*.patch
	fi
}

###################################################################################################################################




###################################################################################################################################
#							DOWNLOAD Debian
do_fetch_debian() {
	# Nothing to do here - will use debootstrap command later
	:
}

###################################################################################################################################




##################################################################################################################################
#							DOWNLOAD selected Distro
do_fetch_${DISTRO}
##################################################################################################################################



mkdir -p $BASE_DIR/tmp




###################################################################################################################################
#							BUILD ATF
PLAT=k3

cd  $BASE_DIR/build/arm-trusted-firmware
make -j${JOBS} CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64 PLAT=$PLAT TARGET_BOARD=lite SPD=opteed
cp build/k3/lite/release/bl31.bin $BASE_DIR/tmp/bl31.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD OPTEE
PLATFORM=k3-am64x

cd  $BASE_DIR/build/optee_os
make -j${JOBS} ARCH=arm PLATFORM=$PLATFORM CROSS_COMPILE32=arm-linux-gnueabihf- CFG_ARM64_core=y
cp out/arm-plat-k3/core/tee-pager_v2.bin $BASE_DIR/tmp/tee-pager_v2.bin

###################################################################################################################################




###################################################################################################################################
#							BUILD U-boot


U_BOOT_R5_DEFCONFIG=am64x_r5_solidrun_defconfig
U_BOOT_A53_DEFCONFIG=am64x_a53_solidrun_defconfig
cd $BASE_DIR/build/ti-u-boot


# 	R5

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- $U_BOOT_R5_DEFCONFIG
make -j${JOBS} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
cp tiboot3.bin $BASE_DIR/tmp/tiboot3.bin



# 	A53

make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- $U_BOOT_A53_DEFCONFIG
make -j${JOBS} ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- ATF=$BASE_DIR/tmp/bl31.bin TEE=$BASE_DIR/tmp/tee-pager_v2.bin


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
cp $BASE_DIR/configs/am64xx-solidrun-linux_defconfig $BASE_DIR/build/ti-linux-kernel/arch/arm64/configs/${LINUX_DEFCONFIG}

cd $BASE_DIR/build/ti-linux-kernel
make $LINUX_DEFCONFIG
#make menuconfig
make savedefconfig
make -j${JOBS} Image dtbs
cp arch/arm64/boot/Image $BASE_DIR/tmp/Image
cp arch/arm64/boot/dts/ti/am642-solidrun.dtb $BASE_DIR/tmp/am642-solidrun.dtb

###################################################################################################################################




##################################################################################################################################
#							BUILD Buildroot rootfs
do_build_buildroot() {
	cp $BASE_DIR/configs/am64xx-solidrun-buildroot_defconfig $BASE_DIR/build/buildroot/configs/${BUILDROOT_DEFCONFIG}
	printf 'BR2_PRIMARY_SITE="%s"\n' "${BR2_PRIMARY_SITE}" >> $BASE_DIR/build/buildroot/configs/${BUILDROOT_DEFCONFIG}

	cd $BASE_DIR/build/buildroot
	make $BUILDROOT_DEFCONFIG
	#make menuconfig
	make savedefconfig
	make -j${JOBS}

	cp $BASE_DIR/build/buildroot/output/images/rootfs.cpio.uboot $BASE_DIR/tmp/rootfs.cpio
	cp $BASE_DIR/build/buildroot/output/images/rootfs.ext4 $BASE_DIR/tmp/rootfs.ext4
}
###################################################################################################################################




##################################################################################################################################
#							BUILD Debian rootfs
do_build_debian() {
	mkdir -p $BASE_DIR/build/debian
	cd $BASE_DIR/build/debian

	# (re-)generate only if rootfs doesn't exist or runme script has changed
	if [ ! -f rootfs.e2.orig ] || [[ ${BASE_DIR}/${BASH_SOURCE[0]} -nt rootfs.e2.orig ]]; then
		rm -f rootfs.e2.orig

		# bootstrap a first-stage rootfs
		rm -rf stage1
		fakeroot debootstrap --variant=minbase \
			--arch=arm64 --components=main,contrib,non-free \
			--foreign \
			--include=apt-transport-https,busybox,ca-certificates,can-utils,command-not-found,chrony,curl,e2fsprogs,ethtool,fdisk,gpiod,haveged,i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,initramfs-tools,libiio-utils,lm-sensors,locales,nano,net-tools,ntpdate,openssh-server,psmisc,rfkill,sudo,systemd-sysv,tio,usbutils,wget,xterm,xz-utils \
			${DEBIAN_VERSION} \
			stage1 \
			https://deb.debian.org/debian

		# prepare init-script for second stage inside VM
		cat > stage1/stage2.sh << EOF
#!/bin/sh

# run second-stage bootstrap
/debootstrap/debootstrap --second-stage

# mount pseudo-filesystems
mount -vt proc proc /proc
mount -vt sysfs sysfs /sys

# configure dns
cat /proc/net/pnp > /etc/resolv.conf

# set empty root password
passwd -d root

# update command-not-found db
apt-file update
update-command-not-found

# enable optional system services
# none yet ...

# populate fstab
printf "/dev/root / ext4 defaults 0 1\\n" > /etc/fstab

# delete self
rm -f /stage2.sh

# flush disk
sync

# power-off
reboot -f
EOF
		chmod +x stage1/stage2.sh

		# create empty partition image
		dd if=/dev/zero of=rootfs.e2.orig bs=1 count=0 seek=${DEBIAN_ROOTFS_SIZE}

		# create filesystem from first stage
		mkfs.ext2 -L rootfs -E root_owner=0:0 -d stage1 rootfs.e2.orig

		# bootstrap second stage within qemu
		qemu-system-aarch64 \
			-m 1G \
			-M virt \
			-cpu cortex-a57 \
			-smp 1 \
			-netdev user,id=eth0 \
			-device virtio-net-device,netdev=eth0 \
			-drive file=rootfs.e2.orig,if=none,format=raw,id=hd0 \
			-device virtio-blk-device,drive=hd0 \
			-nographic \
			-no-reboot \
			-kernel "${BASE_DIR}/tmp/Image" \
			-append "console=ttyAMA0 root=/dev/vda rootfstype=ext2 ip=dhcp rw init=/stage2.sh" \


		:

		# convert to ext4
		tune2fs -O extents,uninit_bg,dir_index,has_journal rootfs.e2.orig
	fi;

	# export final rootfs for next steps
	cp rootfs.e2.orig "${BASE_DIR}/tmp/rootfs.ext4"
}
##################################################################################################################################




##################################################################################################################################
#							BUILD selected Distro
do_build_${DISTRO}
##################################################################################################################################



##################################################################################################################################
#							APPLY OVERLAY
do_overlay_rootfs() {
	if [ "x${DISTRO}" = "xbuildroot" ]; then
		# buildroot consumes overlay directory automatically as part of the build
		return 0
	fi

	if [ -d "${BASE_DIR}/overlay/${DISTRO}" ]; then
		# apply overlay (configuration + data files only - can't "chmod +x")
		# TODO: implement this step through qemu with full permissions
		find "${BASE_DIR}/overlay/${DISTRO}" -type f -printf "%P\n" | e2cp -G 0 -O 0 -s "${BASE_DIR}/overlay/${DISTRO}" -d "${BASE_DIR}/tmp/rootfs.ext4:" -a
	fi
}
do_overlay_rootfs
##################################################################################################################################




mkdir -p $BASE_DIR/output




###################################################################################################################################
#							Create Image file

#Image name should include the commit hash
cd $BASE_DIR
COMMIT_HASH=`git log -1 --pretty=format:%h`
IMAGE_NAME=microsd-${COMMIT_HASH}.img

# define partition offsets
# note: partition start and end sectors are inclusive, add/subtract 1 where appropriate
IMAGE_BOOTPART_START=$((4*1024*1024)) # partition start aligned to 4MiB
IMAGE_BOOTPART_END=$((64*1024*1024-1)) # bootpart size = 60MiB
IMAGE_ROOTPART_SIZE=`stat -c "%s" tmp/rootfs.ext4`
IMAGE_ROOTPART_START=$((IMAGE_BOOTPART_END+1))
IMAGE_ROOTPART_END=$((IMAGE_ROOTPART_START+IMAGE_ROOTPART_SIZE))
IMAGE_SIZE=$((IMAGE_ROOTPART_END+512)) # require 1 additional sector at end

# Create the output image, 2 partitions: 1 boot partition and one root partition
dd if=/dev/zero of=$BASE_DIR/output/$IMAGE_NAME bs=1 count=0 seek=${IMAGE_SIZE}
parted -s $BASE_DIR/output/$IMAGE_NAME -- mklabel msdos mkpart primary fat32 ${IMAGE_BOOTPART_START}B ${IMAGE_BOOTPART_END}B mkpart primary ext4 ${IMAGE_ROOTPART_START}B ${IMAGE_ROOTPART_END}B


# Create boot partition as a different file
dd if=/dev/zero of=$BASE_DIR/output/boot_$IMAGE_NAME bs=1M count=80

mformat -v boot -F -i $BASE_DIR/output/boot_$IMAGE_NAME ::

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/tiboot3.bin ::tiboot3.bin

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/tispl.bin ::tispl.bin

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/u-boot.img ::u-boot.img

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/sysfw.itb ::sysfw.itb

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/Image ::Image

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/am642-solidrun.dtb ::am642-solidrun.dtb

mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/rootfs.cpio ::rootfs.cpio


# Now find offsets in output image
FIRST_PARTITION_OFFSET=`fdisk $BASE_DIR/output/$IMAGE_NAME -l | grep img1 | awk '{print $2}'`
SECOND_PARTITION_OFFSET=`fdisk $BASE_DIR/output/$IMAGE_NAME -l | grep img2 | awk '{print $2}'`

# Write boot partition into output partition
dd if=$BASE_DIR/output/boot_$IMAGE_NAME of=$BASE_DIR/output/$IMAGE_NAME seek=$FIRST_PARTITION_OFFSET conv=notrunc

# write rootfs into second partition
dd if=$BASE_DIR/tmp/rootfs.ext4 of=$BASE_DIR/output/$IMAGE_NAME seek=$SECOND_PARTITION_OFFSET conv=notrunc

printf "\n\nImage file: $BASE_DIR/output/$IMAGE_NAME\n\n"

###################################################################################################################################
