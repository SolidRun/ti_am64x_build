#!/bin/bash

# we don't have status code checks for each step - use "-e" with a trap instead
function error() {
	status=$?
	printf "ERROR: Line %i failed with status %i: %s\n" $BASH_LINENO $status "$BASH_COMMAND" >&2
	exit $status
}
trap error ERR
set -e

###################################################################################################################################
#							OPTIONS

# Distribution for rootfs
# - buildroot
# - debian
: ${DISTRO:=buildroot}

# Target Board
# - evm: TI TMDS64GPEVM AM64 EVK
# - hummingboard-t: SolidRun AM6442 HummingBoard T
: ${BOARD:=hummingboard-t}

# Silicon Revision
# - sr1: AM6442A - SR 1.0
# - sr2: AM6442B - SR 2.0
: ${SOC_VERSION:=sr2}

# Silicon Type
# - gp: general purpose (ONLY sr1)
# - hs-fs: high security, field-securable (before burning customer key to efuses, sr2 and later only)
# - hs-se: high security, security enabled (after burning customer key to efuses, sr2 and later only)
: ${SOC_TYPE:=hs-fs}

# Secure-Boot Signing Key
: ${SIGNING_KEY:=}

## Buildroot Options
: ${BUILDROOT_VERSION:=2023.02.11}
: ${BUILDROOT_DEFCONFIG:=am64xx_solidrun_defconfig}
: ${BR2_PRIMARY_SITE:=}

## Debian Options
: ${DEBIAN_VERSION:=bookworm}
: ${DEBIAN_ROOTFS_SIZE:=1192M}

###################################################################################################################################

# Check if git user name and git email are configured
if [ -z "`git config user.name`" ] || [ -z "`git config user.email`" ]; then
			echo "git is not configured, please run:"
			echo "git config --global user.email \"you@example.com\""
			echo "git config --global user.name \"Your Name\""
			exit -1
fi


BASE_DIR=`pwd`


export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64


mkdir -p $BASE_DIR/build

# Get number of jobs in this machine to use with make command
JOBS=$(getconf _NPROCESSORS_ONLN)

# get commit hash
COMMIT_HASH=`git log -1 --pretty=format:%h`

###################################################################################################################################
#                                                       INSTALL Packages

PACKAGES_LIST="bc bison build-essential ca-certificates cmake cpio crossbuild-essential-arm64 crossbuild-essential-armhf debootstrap device-tree-compiler e2tools fakeroot fdisk flex git kmod libncurses-dev libssl-dev make mtools parted python3-dev python3-pyelftools qemu-system-arm rsync sudo swig u-boot-tools unzip wget xz-utils"

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

PYTHON_MODULES="pycryptodome:Cryptodome"

for i in $PYTHON_MODULES; do
        #Check if module is installed
        IFS=':' read -r -a m <<< "$i"
        python3 -c "import ${m[1]}" > /dev/null 2>&1

        #If exit code is not 0 - module is not installed
        if [ $? -ne 0 ]; then


                echo "Python module ${m[1]} is not installed"
                echo "Please install it using:"
                echo "  pip3 install ${m[0]}"

                exit -1
        fi

done

set -e

###################################################################################################################################




###################################################################################################################################
#							CLONE K3 Firmware
FIRMWARE_TAG=10.01.08

if [[ ! -d $BASE_DIR/build/ti-linux-firmware ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/processor-firmware/ti-linux-firmware.git -b $FIRMWARE_TAG --depth=1
fi
###################################################################################################################################




###################################################################################################################################
#							CLONE ATF
ATF_BRANCH=master
ATF_HEAD=58b25570c9

if [[ ! -d $BASE_DIR/build/arm-trusted-firmware ]]; then
	cd $BASE_DIR/build
	git clone https://review.trustedfirmware.org/TF-A/trusted-firmware-a.git -b $ATF_BRANCH arm-trusted-firmware
	cd arm-trusted-firmware
	git reset --hard $ATF_HEAD
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE OPTEE
OPTEE_BRANCH=master
OPTEE_HEAD=8f645256ef

if [[ ! -d $BASE_DIR/build/optee_os ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/OP-TEE/optee_os.git -b $OPTEE_BRANCH
	cd optee_os
	git reset --hard $OPTEE_HEAD
fi

###################################################################################################################################




##################################################################################################################################
#                                                      CLONE OPTEE fTPM TA
if [[ ! -d $BASE_DIR/build/ftpm ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/Microsoft/MSRSec.git ftpm
	cd ftpm
	test -d $BASE_DIR/patches/ftpm && git am $BASE_DIR/patches/ftpm/*.patch
fi
###################################################################################################################################




###################################################################################################################################
#							CLONE U-boot
U_BOOT_TAG=10.01.10

if [[ ! -d $BASE_DIR/build/ti-u-boot ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/ti-u-boot/ti-u-boot.git -b $U_BOOT_TAG --depth=1
	cd ti-u-boot
	git am $BASE_DIR/patches/uboot/*.patch

fi

###################################################################################################################################




###################################################################################################################################
#							CLONE k3conf Tool
K3CONF_BRANCH=master
K3CONF_HEAD=30a1d5b2d0

if [[ ! -d $BASE_DIR/build/k3conf ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/k3conf/k3conf.git -b $K3CONF_BRANCH
	cd k3conf
	git reset --hard $K3CONF_HEAD
	test -d $BASE_DIR/patches/k3conf && git am $BASE_DIR/patches/k3conf/*.patch
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE Linux Kernel
KERNEL_TAG=10.01.10

if [[ ! -d $BASE_DIR/build/ti-linux-kernel ]]; then
	cd $BASE_DIR/build
	git clone git://git.ti.com/ti-linux-kernel/ti-linux-kernel.git	-b $KERNEL_TAG --depth=1
	cd ti-linux-kernel
	git am $BASE_DIR/patches/linux/*.patch
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE acontis atemsys module sources
ATEMSYS_TAG=v1.4.29

if [[ ! -d $BASE_DIR/build/atemsys ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/acontis/atemsys.git
	cd atemsys
	test -d $BASE_DIR/patches/atemsys && git am $BASE_DIR/patches/atemsys/*.patch
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
build_optee_ftpm() {
	local DEVKIT="$1"
	local CROSS_COMPILE=$2

	cd $BASE_DIR/build/ftpm/TAs/optee_ta
	make -j1 \
		CFG_FTPM_USE_WOLF=y \
		TA_CPU=cortex-a53 \
		TA_CROSS_COMPILE=$CROSS_COMPILE \
		TA_DEV_KIT_DIR="$DEVKIT" \
		CFG_TEE_TA_LOG_LEVEL=2 \
		ftpm

	mkdir -p $BASE_DIR/tmp/optee
	cp -v out/*/*.ta $BASE_DIR/tmp/optee/
}

build_optee() {
	local PLATFORM=k3-am64x

	rm -rf $BASE_DIR/tmp/optee
	mkdir -p $BASE_DIR/tmp/optee

	# build optee devkit
	cd  $BASE_DIR/build/optee_os
	rm -rf out
	make -j${JOBS} \
		ARCH=arm \
		PLATFORM=$PLATFORM \
		CROSS_COMPILE64=aarch64-linux-gnu- \
		CROSS_COMPILE32=arm-linux-gnueabihf- \
		CFG_ARM64_core=y \
		ta_dev_kit

	# build TAs
	build_optee_ftpm $BASE_DIR/build/optee_os/out/arm-plat-k3/export-ta_arm32 arm-linux-gnueabihf-

	# RPMB_FS OPTIONS:
	# - CFG_RPMB_FS:
	#   Enable or disable RPMB Filesystem Feature.
	#   Disabled for now due to unstable access from Linux.
	# - WRITE_KEY:
	#   Disabled by default to avoid accidental programming of key,
	#   enable if optee-os shall use rpmb for secure storage.
	RPMB_FS="CFG_RPMB_FS=n"

	# build optee os
	cd  $BASE_DIR/build/optee_os
	make -j${JOBS} \
		ARCH=arm \
		PLATFORM=$PLATFORM \
		CROSS_COMPILE64=aarch64-linux-gnu- \
		CROSS_COMPILE32=arm-linux-gnueabihf- \
		CFG_ARM64_core=y \
		CFG_EARLY_TA=y \
		CFG_IN_TREE_EARLY_TAS=avb/023f8f1a-292a-432b-8fc4-de8471358067 \
		EARLY_TA_PATHS="$BASE_DIR/build/ftpm/TAs/optee_ta/out/fTPM/bc50d971-d4c9-42c4-82cb-343fb7f37896.stripped.elf" \
		$RPMB_FS

	cp out/arm-plat-k3/core/tee-pager_v2.bin $BASE_DIR/tmp/optee/
}
build_optee

###################################################################################################################################




###################################################################################################################################
#							BUILD U-boot

case ${BOARD} in
	evm)
		U_BOOT_R5_DEFCONFIG=am64x_evm_r5_defconfig
		U_BOOT_A53_DEFCONFIG=am64x_evm_a53_defconfig
		;;
	hummingboard-t)
		U_BOOT_R5_DEFCONFIG=am64som_r5_defconfig
		U_BOOT_A53_DEFCONFIG=am64som_a53_defconfig
		;;
	*)
		echo "ERROR: Board \"${BOARD}\" not supported!"
		exit 1
		;;
esac
cd $BASE_DIR/build/ti-u-boot


# 	R5

make ARCH=arm $U_BOOT_R5_DEFCONFIG
test -n "${SIGNING_KEY}" && ./scripts/config --set-str SYS_K3_KEY "${BASE_DIR}/${SIGNING_KEY}"
#make ARCH=arm menuconfig
make ARCH=arm savedefconfig
mv defconfig defconfig_r5
make \
	-j${JOBS} \
	ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
	BINMAN_INDIRS="./board/ti/am64x $BASE_DIR/build/ti-linux-firmware"
case ${SOC_VERSION}_${SOC_TYPE} in
	sr1_gp)
		TIBOOT3=tiboot3-am64x-gp-sr-som.bin
	;;
	sr2_hs-fs)
		TIBOOT3=tiboot3-am64x_sr2-hs-fs-sr-som.bin
	;;
	sr2_hs-se)
		TIBOOT3=tiboot3-am64x_sr2-hs-sr-som.bin
	;;
	*)
		echo "Error: Silicon \"${SOC_VERSION}\" type \"${SOC_TYPE}\" is not supported!"
esac
cp ${TIBOOT3} $BASE_DIR/tmp/tiboot3.bin



# 	A53

make ARCH=arm $U_BOOT_A53_DEFCONFIG
test -n "${SIGNING_KEY}" && ./scripts/config --set-str SYS_K3_KEY "${BASE_DIR}/${SIGNING_KEY}"
#make ARCH=arm menuconfig
make ARCH=arm savedefconfig
mv defconfig defconfig_a53
make \
	-j${JOBS} \
	ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- \
	BINMAN_INDIRS="./board/ti/am64x $BASE_DIR/build/ti-linux-firmware" \
	BL31=$BASE_DIR/tmp/bl31.bin \
	TEE=$BASE_DIR/tmp/optee/tee-pager_v2.bin


cp tispl.bin $BASE_DIR/tmp/tispl.bin
cp u-boot.img $BASE_DIR/tmp/u-boot.img

###################################################################################################################################




###################################################################################################################################
#							BUILD k3conf Tool
cd $BASE_DIR/build/k3conf
rm -rf build $BASE_DIR/tmp/k3conf
mkdir build; cd build
cmake  .. -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=/usr
make -j${JOBS}
make DESTDIR=$BASE_DIR/tmp/k3conf install

###################################################################################################################################




###################################################################################################################################
#							BUILD Linux
build_kernel() {
	cd $BASE_DIR/build/ti-linux-kernel
	./scripts/kconfig/merge_config.sh -O "${BASE_DIR}/build/ti-linux-kernel" -m arch/arm64/configs/defconfig kernel/configs/ti_arm64_prune.config "${BASE_DIR}/configs/kernel.extra"
	make olddefconfig
	#make menuconfig
	make savedefconfig
	make -j${JOBS} dtbs Image modules
	rm -rf "${BASE_DIR}/tmp/linux"
	mkdir -p "${BASE_DIR}/tmp/linux/boot/ti"
	cp arch/arm64/boot/Image "${BASE_DIR}/tmp/linux/boot/Image"
	cp arch/arm64/boot/dts/ti/*.dtb "${BASE_DIR}/tmp/linux/boot/ti/"
	cp .config "${BASE_DIR}/tmp/linux/boot/config"
	cp System.map "${BASE_DIR}/tmp/linux/boot/System.map"
	make -j${JOBS} INSTALL_MOD_PATH="${BASE_DIR}/tmp/linux/usr" modules_install
}

# export linux headers
build_kernel_headers() {
	# Build external Linux Headers package for compiling modules
	cd "${BASE_DIR}/build/ti-linux-kernel"
	rm -rf "${BASE_DIR}/tmp/linux-headers"
	mkdir -p ${BASE_DIR}/tmp/linux-headers
	tempfile=$(mktemp)
	find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl > $tempfile
	find arch/arm64/include include scripts -type f >> $tempfile
	tar -c -f - -T $tempfile | tar -C "${BASE_DIR}/tmp/linux-headers" -xf -
	cd "${BASE_DIR}/build/ti-linux-kernel"
	find arch/arm64/include .config Module.symvers include scripts -type f > $tempfile
	tar -c -f - -T $tempfile | tar -C "${BASE_DIR}/tmp/linux-headers" -xf -
	rm -f $tempfile
	unset tempfile
}

build_kernel
build_kernel_headers

KRELEASE=`make -s -C "${BASE_DIR}/build/ti-linux-kernel" kernelrelease`
###################################################################################################################################




###################################################################################################################################
#							BUILD External Kernel Modules
build_atemsys() {
	# acontis ethercat support module
	cd $BASE_DIR/build/atemsys
	make -C "${BASE_DIR}/tmp/linux-headers" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M="$PWD" clean
	make -C "${BASE_DIR}/tmp/linux-headers" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M="$PWD" modules
	install -v -m644 -D atemsys.ko "${BASE_DIR}/tmp/linux/usr/lib/modules/${KRELEASE}/extra/atemsys.ko"
}

update_moddeps() {
	# regenerate modules dependencies
	depmod -b "${BASE_DIR}/tmp/linux/usr" -F "${BASE_DIR}/tmp/linux/boot/System.map" ${KRELEASE}
}

build_atemsys
update_moddeps
###################################################################################################################################




##################################################################################################################################
#							BUILD Buildroot rootfs
do_build_buildroot() {
	cp $BASE_DIR/configs/am64xx-solidrun-buildroot_defconfig $BASE_DIR/build/buildroot/configs/${BUILDROOT_DEFCONFIG}
	printf 'BR2_PRIMARY_SITE="%s"\n' "${BR2_PRIMARY_SITE}" >> $BASE_DIR/build/buildroot/configs/${BUILDROOT_DEFCONFIG}

	# ensure overlay  directory exists even if empty
	mkdir -p $BASE_DIR/overlay/buildroot

	cd $BASE_DIR/build/buildroot
	make $BUILDROOT_DEFCONFIG
	#make menuconfig
	make savedefconfig BR2_DEFCONFIG="${BASE_DIR}/build/buildroot/defconfig"
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

		local PKGS=apt-transport-https,busybox,ca-certificates,can-utils,command-not-found,chrony,curl,e2fsprogs,ethtool,fdisk,gpiod,haveged,i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,initramfs-tools,libiio-utils,lm-sensors,locales,nano,net-tools,ntpdate,openssh-server,psmisc,rfkill,sudo,systemd-sysv,tio,usbutils,wget,xterm,xz-utils
		if [ ${DEBIAN_VERSION} != "bullseye" ]; then
			PKGS=$PKGS,tee-supplicant
		fi

		# bootstrap a first-stage rootfs
		rm -rf stage1
		fakeroot debootstrap --variant=minbase \
			--arch=arm64 --components=main,contrib,non-free,non-free-firmware \
			--foreign \
			--include=$PKGS \
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
			-cpu max,pauth-impdef=on,sve=off \
			-smp 4 \
			-rtc base=utc,clock=host \
			-device virtio-rng-device \
			-netdev user,id=eth0 \
			-device virtio-net-device,netdev=eth0 \
			-drive file=rootfs.e2.orig,if=none,format=raw,id=hd0,discard=unmap \
			-device virtio-blk-device,drive=hd0 \
			-nographic \
			-no-reboot \
			-kernel "${BASE_DIR}/tmp/linux/boot/Image" \
			-append "earlycon console=ttyAMA0 root=/dev/vda rootfstype=ext2 ip=dhcp rw init=/stage2.sh" \


		:

		# convert to ext4
		tune2fs -O extents,uninit_bg,dir_index,has_journal rootfs.e2.orig
	fi;

	# export final rootfs for next steps
	cp --sparse=always rootfs.e2.orig "${BASE_DIR}/tmp/rootfs.ext4"
}
##################################################################################################################################




##################################################################################################################################
#							BUILD selected Distro
do_build_${DISTRO}
##################################################################################################################################




##################################################################################################################################
#                                                      Install OPTEE TAs
do_optee_ta_rootfs() {
	for ta in ${BASE_DIR}/tmp/optee/*.ta; do
		e2cp -G 0 -O 0 -d "${BASE_DIR}/tmp/rootfs.ext4:/lib/" -v $ta
	done
}
do_optee_ta_rootfs
##################################################################################################################################




##################################################################################################################################
#							APPLY TI Firmware
do_ti_firmware_rootfs() {
	for fw in ti-pruss/am65x-sr2-{pru,rtu,txpru}{0,1}-prueth-fw.elf; do
		echo $fw | e2cp -G 0 -O 0 -s "${BASE_DIR}/build/ti-linux-firmware/" -d "${BASE_DIR}/tmp/rootfs.ext4:/usr/lib/firmware" -a -v
	done
}
do_ti_firmware_rootfs
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
#							Create Kernel & Modules Package
do_package_kernel() {
	cd ${BASE_DIR}/tmp/linux
	tar --numeric-owner --owner=0 --group=0 --create --file ${BASE_DIR}/output/linux-${COMMIT_HASH}.tar *
}
do_package_kernel
###################################################################################################################################




###################################################################################################################################
#							Create Kernel Headers Package
function do_package_kernel_headers() {
	cd "${BASE_DIR}/tmp/linux-headers"
	tar cpf "${BASE_DIR}/output/linux-headers-${COMMIT_HASH}.tar" --transform "s;^;linux-headers-${COMMIT_HASH}/;" *
}
do_package_kernel_headers
###################################################################################################################################




###################################################################################################################################
#							Generate extlinux.conf for U-Boot Distro-Boot Feature
do_generate_extlinux() {
	local PARTNUMBER=$1
	local PARTUUID=`blkid -s PTUUID -o value ${BASE_DIR}/output/${IMAGE_NAME}`
	PARTUUID=${PARTUUID}'-0'${PARTNUMBER} # specific partition uuid

	mkdir -p ${BASE_DIR}/tmp/extlinux
	cat > ${BASE_DIR}/tmp/extlinux/extlinux.conf << EOF
TIMEOUT 1
DEFAULT default
MENU TITLE SolidRun AM64 Reference BSP
LABEL default
	MENU LABEL default
	LINUX ../Image
	FDTDIR ../
	APPEND earlycon=ns16550a,mmio32,0x02800000 console=ttyS2,115200n8 log_level=9 root=PARTUUID=$PARTUUID rw rootwait pcie_aspm=off ath9k.use_msi=1
EOF
}
###################################################################################################################################




###################################################################################################################################
#							Integrate Artifacts on rootfs

echo "copying \"k3conf\" ..."
e2cp -G 0 -O 0 -P 755 -s "$BASE_DIR/tmp/k3conf/usr/bin" -d "${BASE_DIR}/tmp/rootfs.ext4:/usr/bin" -a -v k3conf

echo "copying kernel ..."
e2cp -G 0 -O 0 -P 644 -a -d "${BASE_DIR}/tmp/rootfs.ext4:" -s "${BASE_DIR}/tmp/linux" -v boot/Image
find "${BASE_DIR}/tmp/linux/boot/ti" -type f -name "*.dtb" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${BASE_DIR}/tmp/linux/boot/ti" -d "${BASE_DIR}/tmp/rootfs.ext4:boot/ti" -a -v

echo "copying kernel modules ..."
find "${BASE_DIR}/tmp/linux/usr/lib/modules" -type f -not -name "*.ko*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${BASE_DIR}/tmp/linux/usr/lib/modules" -d "${BASE_DIR}/tmp/rootfs.ext4:usr/lib/modules" -a
find "${BASE_DIR}/tmp/linux/usr/lib/modules" -type f -name "*.ko*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${BASE_DIR}/tmp/linux/usr/lib/modules" -d "${BASE_DIR}/tmp/rootfs.ext4:usr/lib/modules" -a -v
###################################################################################################################################




###################################################################################################################################
#							Create SD Image file
function do_assemble_sd() {
	local IMAGE_NAME=microsd-${COMMIT_HASH}.img

	cd $BASE_DIR
	mkdir -p "$BASE_DIR/output"

	# define partition offsets
	# note: partition start and end sectors are inclusive, add/subtract 1 where appropriate
	IMAGE_BOOTPART_START=$((1*1024*1024)) # partition start aligned to 1MiB
	IMAGE_BOOTPART_END=$((8*1024*1024-1)) # bootpart size = 7MiB
	IMAGE_ROOTPART_SIZE=`stat -c "%s" tmp/rootfs.ext4`
	IMAGE_ROOTPART_START=$((IMAGE_BOOTPART_END+1))
	IMAGE_ROOTPART_END=$((IMAGE_ROOTPART_START+IMAGE_ROOTPART_SIZE-1))
	IMAGE_SIZE=$((IMAGE_ROOTPART_END+512)) # require 1 additional sector at end

	# Create the output image, 2 partitions: 1 boot partition and one root partition
	dd if=/dev/zero of=$BASE_DIR/output/$IMAGE_NAME bs=1 count=0 seek=${IMAGE_SIZE}
	parted -s $BASE_DIR/output/$IMAGE_NAME -- mklabel msdos mkpart primary fat32 ${IMAGE_BOOTPART_START}B ${IMAGE_BOOTPART_END}B mkpart primary ext4 ${IMAGE_ROOTPART_START}B ${IMAGE_ROOTPART_END}B

	# mark both partitions bootable:
	# 1. for SoC Boot-ROM (tiboot3.bin on FAT part)
	# 2. for U-Boot (extlinux.conf on rootfs)
	sfdisk -A output/${IMAGE_NAME} 1 2

	# generate extlinux.conf after partition table exists and partition uuids are known
	do_generate_extlinux 2
	e2cp -G 0 -O 0 -P 644 -a -d "${BASE_DIR}/tmp/rootfs.ext4:/boot" -s "${BASE_DIR}/tmp" -v extlinux/extlinux.conf

	# Create boot partition as a different file
	dd if=/dev/zero of=$BASE_DIR/output/boot_$IMAGE_NAME bs=1M count=0 seek=7

	mformat -v boot -i $BASE_DIR/output/boot_$IMAGE_NAME ::

	mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/tispl.bin ::tispl.bin

	mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/tiboot3.bin ::tiboot3.bin

	mcopy -i $BASE_DIR/output/boot_$IMAGE_NAME $BASE_DIR/tmp/u-boot.img ::u-boot.img

	# Now find offsets in output image
	FIRST_PARTITION_OFFSET=`fdisk $BASE_DIR/output/$IMAGE_NAME -l | grep img1 | awk '{print $3}'`
	SECOND_PARTITION_OFFSET=`fdisk $BASE_DIR/output/$IMAGE_NAME -l | grep img2 | awk '{print $3}'`

	# Write boot partition into output partition
	dd if=$BASE_DIR/output/boot_$IMAGE_NAME of=$BASE_DIR/output/$IMAGE_NAME seek=$FIRST_PARTITION_OFFSET conv=sparse

	# write rootfs into second partition
	dd if=$BASE_DIR/tmp/rootfs.ext4 of=$BASE_DIR/output/$IMAGE_NAME seek=$SECOND_PARTITION_OFFSET conv=sparse
}
do_assemble_sd
###################################################################################################################################




###################################################################################################################################
#							Create eMMC Image file (rootfs)
function do_assemble_emmc_bootpart() {
	local BUNDLE="$BASE_DIR/output/boot_emmc-${COMMIT_HASH}.img"

	cd $BASE_DIR
	mkdir -p "$BASE_DIR/output"

	# size-check files
	if [ $(stat -c %s "$BASE_DIR/tmp/tiboot3.bin") -gt $((0x400*0x200)) ]; then
		echo "ERROR: \"tiboot3.bin\" is too large!\n"
		return 1
	fi
	if [ $(stat -c %s "$BASE_DIR/tmp/tispl.bin") -gt $((0x800*0x200)) ]; then
		echo "ERROR: \"tispl.bin\" is too large!\n"
		return 1
	fi
	if [ $(stat -c %s "$BASE_DIR/tmp/u-boot.img") -gt $((0x1000*0x200)) ]; then
		echo "ERROR: \"u-boot.img\" is too large!\n"
		return 1
	fi

	truncate -s 4M "$BUNDLE"
	dd of="$BUNDLE" bs=512 conv=notrunc seek=0    if="$BASE_DIR/tmp/tiboot3.bin"
	dd of="$BUNDLE" bs=512 conv=notrunc seek=1024 if="$BASE_DIR/tmp/tispl.bin"
	dd of="$BUNDLE" bs=512 conv=notrunc seek=3072 if="$BASE_DIR/tmp/u-boot.img"
}

function do_assemble_emmc() {
	local IMAGE_NAME=emmc-${COMMIT_HASH}.img

	cd $BASE_DIR
	mkdir -p "$BASE_DIR/output"

	# define partition offsets
	# note: partition start and end sectors are inclusive, add/subtract 1 where appropriate
	IMAGE_ROOTPART_SIZE=`stat -c "%s" tmp/rootfs.ext4`
	IMAGE_ROOTPART_START=$((4*1024*1024)) # partition start aligned to 4MiB
	IMAGE_ROOTPART_END=$((IMAGE_ROOTPART_START+IMAGE_ROOTPART_SIZE))
	IMAGE_SIZE=$((IMAGE_ROOTPART_END+512)) # require 1 additional sector at end

	# Create the output image, 1 partition: rootfs, no boot partition
	dd if=/dev/zero of=$BASE_DIR/output/$IMAGE_NAME bs=1 count=0 seek=${IMAGE_SIZE}
	parted -s $BASE_DIR/output/$IMAGE_NAME -- mklabel msdos mkpart primary ext4 ${IMAGE_ROOTPART_START}B ${IMAGE_ROOTPART_END}B set 1 boot on

	# generate extlinux.conf after partition table exists and partition uuids are known
	do_generate_extlinux 1
	e2cp -G 0 -O 0 -P 644 -a -d "${BASE_DIR}/tmp/rootfs.ext4:/boot" -s "${BASE_DIR}/tmp" -v extlinux/extlinux.conf

	# Now find offsets in output image
	FIRST_PARTITION_OFFSET=`fdisk $BASE_DIR/output/$IMAGE_NAME -l | grep img1 | awk '{print $3}'`

	# write rootfs into first partition
	dd if=$BASE_DIR/tmp/rootfs.ext4 of=$BASE_DIR/output/$IMAGE_NAME seek=$FIRST_PARTITION_OFFSET conv=sparse
}
do_assemble_emmc_bootpart
do_assemble_emmc
###################################################################################################################################




###################################################################################################################################
#							Print Report

printf "\n\nSD bootable image: $BASE_DIR/output/microsd-${COMMIT_HASH}.img\n\n"
printf "\n\neMMC rootfs image: $BASE_DIR/output/emmc-${COMMIT_HASH}.img\n\n"
printf "\n\neMMC bootpart image: $BASE_DIR/output/boot_emmc-${COMMIT_HASH}.img\n\n"
printf "\n\nImage file: $BASE_DIR/output/$IMAGE_NAME\n\n"
printf "\n\nKernel package: $BASE_DIR/output/linux-${COMMIT_HASH}.tar\n\n"

###################################################################################################################################
