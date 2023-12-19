# SolidRun's TI AM64x based  build scripts

Main intention of this repository is to produce a reference system for TI AM64x product evaluation.
Automatic binary releases are available on [our website](https://images.solid-run.com/AM64X/ti_am64x_build) for download.

## Get Started

AM64x SoM and Carriers currently ship without OS or Bootloader preinstalled.
Please download the latest binary release from

If no operating system was installed, please download the latest binary release from [our website](https://images.solid-run.com/AM64X/ti_am64x_build).
Choose between Debian / Buildroot, annd pick the appropriate silicon revision ("sr1" / "sr2" suffix) matching your SoM.
Note: SKU "SRT6442W00D01GE008V11I**0**" is Silicon 1.0 ("sr1").
Then follow the steps in section "Deploying -> to microSD".

Before power-on, ensure that the Board has been configured to boot from microSD according to [this table](#configure-boot-mode-dip-switch)

After flashing a microSD and booting into Linux, the serial console must be used for logging into the root account for the first time.
Simply enter "root" and press return:

    Welcome to Buildroot
    buildroot login: root
    #

### Log-In via SSH

To log in via SSH, an ssh key must be installed first. Copy your favourite public key, e.g. from `~/.ssh/id_ed25519.pub`, into a new file in the root users home directory at `~/.ssh/authorized_keys`:

    # mkdir .ssh
    # cat > .ssh/authorized_keys << EOF
    ssh-ed25519 AAAAinsertyour pubkey@here
    EOF

After [network configuration](#ethernet) `ssh root@<ip>` can be used for logging in remotely.

### Expand Root Filesystem

After flashing an SD-Card or eMMC, the root filesystem is small and does not fill the complete disk.
To utilize all space, resize both the rootfs partition - and then the filesystem:

Note:
- `mmcblk0` is eMMC, rootfs is on partition #1
- `mmcblk1` is microSD, rootfs is on partition #2
Adapt instructions below accordingly.

1. inspect partitions:

   Using fdisk, view the current partitions. Take note of the start sector ("StartLBA") for partition 2!

       # fdisk /dev/mmcblk1

       The number of cylinders for this disk is set to 243096.
       There is nothing wrong with that, but this is larger than 1024,
       and could in certain setups cause problems with:
       1) software that runs at boot time (e.g., old versions of LILO)
       2) booting and partitioning software from other OSs
          (e.g., DOS FDISK, OS/2 FDISK)

       Command (m for help): p
       Disk /dev/mmcblk1: 15 GB, 15931539456 bytes, 31116288 sectors
       243096 cylinders, 4 heads, 32 sectors/track
       Units: sectors of 1 * 512 = 512 bytes

       Device       Boot StartCHS    EndCHS        StartLBA     EndLBA    Sectors  Size Id Type
       /dev/mmcblk1p1 *  16,0,1      127,3,32          2048      16383      14336 7168K  c Win95 FAT32 (LBA)
       /dev/mmcblk1p2 *  128,0,1     1023,3,32        16384     409600     393217  192M 83 Linux

       Command (m for help):

2. resize partition 2:

   Drop and re-create partition 2 at the same starting sector noted before, keeping the "Boot" flag active.
   If prompted, do not remove the ext4 signature:

       Command (m for help): d
       Partition number (1-4): 2

       Command (m for help): n
       Partition type
          p   primary partition (1-4)
          e   extended
       p
       Partition number (1-4): 2
       First sector (32-31116287, default 32): 16384
       Last sector or +size{,K,M,G,T} (16384-31116287, default 31116287):
       Using default value 31116287

       Command (m for help): a
       Partition number (1-4): 2

       Command (m for help): p
       Disk /dev/mmcblk1: 15 GB, 15931539456 bytes, 31116288 sectors
       243096 cylinders, 4 heads, 32 sectors/track
       Units: sectors of 1 * 512 = 512 bytes

       Device       Boot StartCHS    EndCHS        StartLBA     EndLBA    Sectors  Size Id Type
       /dev/mmcblk1p1 *  16,0,1      127,3,32          2048      16383      14336 7168K  c Win95 FAT32 (LBA)
       /dev/mmcblk1p2 *  128,0,1     1023,3,32        16384   31116287   31099904 14.8G 83 Linux

       Command (m for help): w
       The partition table has been altered.
       Calling ioctl() to re-read partition table
       fdisk: WARNING: rereading partition table failed, kernel still uses old table: Device or resource busy

3. If fdisk finished with the warning line above, reboot the device:

       reboot

   If there was no warning, or after reboot completed - proceed to step 4.

4. resize root filesystem:

   Linux supports online-resizing for the ext4 filesystem. Invoke `resize2fs` on partition 2 to do so:

       # resize2fs /dev/mmcblk1p2

### Install All Kernel Modules

The basic images include only a small number of kernel modules required for basic operation.
A package including all modules is generated as part of the build (`build/linux-<hash>.tar`) and available for download on [our website](https://images.solid-run.com/AM64X/ti_am64x_build).

Ensure sufficient free space on rootfs - 300MB should be sufficient, then unpack to `/`:

    tar -C / -xf linux-<hash>.tar
    sync

## Deploying

### to microSD

In order to create a bootable SD card, plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=output/microsd-<hash>.img of=/dev/sdX
```

### to eMMC

The build process generates special rootfs images for deployment on the eMMC main (data) partition: `output/emmc-<hash>.img`
Binary releases are available on [our website](https://images.solid-run.com/AM64X/ti_am64x_build) for download.

1. Boot into Linux on the target system, e.g. using SD Card

2. Download, or copy eMMC image to the target system (`wget`, `scp`, ...)

3. Decompress image if necessary (e.g. if downloaded from our website):

       xz -d emmc-<hash>.img.xz

3. Write (uncompressed) image to eMMC:

       dd if=emmc-<hash>.img of=/dev/mmcblk0 bs=4M conv=fsync

## Configure Boot Mode DIP Switch

This table indicates valid boot-modes selectable via the DIP switch S1 on the HummingBoard-T Carrier.
The value 0 indicates OFF, 1 indicates the ON state and X indicates don't care.

| Switch                  | 1 | 2 | 3 | 4 | 5 | 6 | Notes        |
|-------------------------|---|---|---|---|---|---|--------------|
| microSD (FAT partition) | 0 | 0 | 0 | 1 | 0 | 1 |              |
| microSD (RAW)           | 1 | 0 | 0 | 0 | 1 | 1 |              |
| eMMC                    | 1 | 0 | 0 | 1 | X | X |              |
| UART                    | 1 | 1 | 1 | 0 | X | X | DNP SoM R175 |

## Configure Interfaces

### Ethernet

HummingBoard-T has 3x RJ45 interfaces that can be independently controlled by Linux: `eth0`, `eth1`, `eth2`.
The standard linux tools such as `ifconfig` (legacy) and `ip` can be used to configure the network.

Examples:

- enable link:

      ip link set dev eth0 up

- acquire IP address by DHCP

      udhcpc -i eth0

- set a static IP & default Gateway

      ip addr add dev eth0 192.168.0.2/24
      ip route add default via 192.168.0.1 dev eth0

### CAN

The HummingBoard-T has 2x can interfaces: `can0`, `can1`.
Steps are identical except for replacing the name in instructions below.

1. Enable can0 netdev:

       ip link set can0 up type can bitrate 125000 up

2. Receive on can0 to a temporary file:

       touch /tmp/can_test
       candump can0 >> /tmp/can_test &

3. Send a message on can0:

       cansend can0 "123#1234"

### RS485

1. View current configuration:

       rs485conf /dev/ttyS5
       = Current configuration:
       RS485 enabled:                true
       RTS on send:                  low
       RTS after send:               high
       RTS delay before send:        0
       RTS delay after send:         0
       Receive during sending data:  false

2. Optionally change configuration as needed, e.g.:

       rs485conf /dev/ttyS5 -e 1 -o 0 -a 1

3. Receive data to a temporary file:

       touch /tmp/rs485_test
       stty -F /dev/ttyS5 raw -echo -echoe -echok
       cat /dev/ttyS5 > /tmp/rs485_test &

4. Transmit a message:

       echo "OK" > /dev/ttyS5

### m.2 Connectors

The HummingBoard-T features 2x m.2 connectors:

- M1 (E key): usb-2.0 + pci-e
- M2 (B key): usb-2.0 + usb-3.1

PCI-Express and USB-3.1 are mutually exclusive, the SoC supports only one function at a time.

#### Function Selection

Selection of specific function is achieved by setting a u-boot environment variable:

1. stop the boot process using the serial console by pressing a key at the timeout prompt:

       Hit any key to stop autoboot:  3

2. set `board_m2_function` variable according to the desired function:

   - PCI-E: `setenv board_m2_function pcie`
   - USB-3: `setenv board_m2_function usb3`
   - Neither (default): `env delete -f board_m2_function`

3. (optionally) save this choice in u-boot environment:

       => saveenv
       Saving Environment to FAT... OK

4. continue boot:

       => boot

## Booting from eMMC

The following commands can be used to download tiboot3.bin, tispl.bin and u-boot.img from a bootable SD card to the eMMC boot0 partition at appropriate offset:

```
    # select eMMC
    mmc dev 0 1

    # erase (existing) boot data
    mmc erase 0x0 0x1C00

    # optionally erase environment
    mmc erase 0x1C00 0x400

    # write tiboot3.bin
    load mmc 1 ${kernel_addr_r} tiboot3.bin
    mmc write ${kernel_addr_r} 0x0 0x400

    # write tispl.bin
    load mmc 1 ${kernel_addr_r} tispl.bin
    mmc write ${kernel_addr_r} 0x400 0xC00

    # write u-boot.img
    load mmc 1 ${kernel_addr_r}  u-boot.img
    mmc write ${kernel_addr_r} 0xC00 0x1000
```
eMMC layout:

```
                    boot0 partition (4 MB)
             0x0+----------------------------------+
                |           tiboot3.bin            |
           0x400+----------------------------------+
                |           tispl.bin              |
           0xC00+----------------------------------+
                |           u-boot.img             |
          0x1C00+----------------------------------+
                |           environment            |
          0x2000+----------------------------------+

```

Select `boot0` partition as boot source (first time only, may be changed later):

    mmc partconf 0 1 1 1

Configure bus for x8 sdr high-speed mode (first time only, may be changed later)

    mmc bootbus 0 2 1 1

Finally enable eMMC reset function (first time only, **can not be changed later**)

    mmc rst-function 0 1

## Booting from Network

In order to boot Linux kernel and rootfs over ethernet, you'll need a TFTP server to serve the required files.

### Setting a TFTP server (From a different Linux machine in the same network)

* Install tftpd, xinetd and tftp.

```
apt-get install tftpd xinetd tftp
```

* Create the directory you'll use to store the booting files.

```
mkdir /path/to/boot/dir
chmod -R 777 /path/to/boot/dir
chown -R nobody /path/to/boot/dir
```

* Create /etc/xinetd.d/tftp, and write in the file:

```
service tftp
{
protocol        = udp
port            = 69
socket_type     = dgram
wait            = yes
user            = nobody
server          = /usr/sbin/in.tftpd
server_args     = /path/to/boot/dir
disable         = no
}
```

> Edit /path/to/boot/dir according to your directory

* Restart service

```
service xinetd restart
```

* Copy booting files (which are in ti_am64x_build/tmp directory)into tftp directory

```
# Copy device tree
cp some_location/ti_am64x_build/tmp/am642-solidrun.dtb /path/to/boot/dir/

# Copy Kernel
cp some_location/ti_am64x_build/tmp/Image /path/to/boot/dir/

# Copy rootfs
cp some_location/ti_am64x_build/tmp/rootfs.cpio /path/to/boot/dir/
```


### Retrieving booting files over ethetnet.
This part assumes that you have a tftp server in the same network, and that your board is in U-boot.

* Get IP address using dhcp command (ignore the error, we are using this command to get an IP address for a DHCP server)

```
=> dhcp
link up on port 1, speed 1000, full duplex
BOOTP broadcast 1
BOOTP broadcast 2
BOOTP broadcast 3
DHCP client bound to address 192.168.15.119 (2756 ms)
*** ERROR: `serverip' not set
Cannot autoload with TFTPGET
```

* Set the tftp server IP address.

```
setenv serverip <the.server.ip.addr>
```

* Load Kernel into RAM

```
setenv loadaddr ${kernel_addr_r}
tftpboot Image
```

* Load Device Tree into RAM.

```
setenv loadaddr ${fdt_addr_r}
tftpboot am642-solidrun.dtb
```

* Load rootfs into RAM.

```
setenv loadaddr ${ramdisk_addr_r}
tftpboot rootfs.cpio
```

* boot

```
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
```


Since rootfs is loaded into RAM, all changes to the file system (creating/deleting files/directories) will be discarded every reboot.

## Features

### MAC Addresses:

This SOM has 3 Ethernet interfaces, CPSW and 2 ICSSGs, hence, needs 3 MAC addresses.
**U-boot will try to read these MAC addresses from an EEPROM in I2C bus 0, address 0x50.**

EEPROM data is stored in ONIE TLV format:
* Number of MAC addresses stored will be read from entry TLV_CODE_MAC_SIZE.
* First MAC address will be read from entry TLV_CODE_MAC_BASE.
* Consecutive MACs are calculated by incrementing first MAC.

If no valid MAC addresses are found, random MAC addresses will be used.
<br>
Here is an example on how to write your own MAC addresses from U-Boot:

```
# Write 34:88:de:e3:c0:17, 34:88:de:e3:c0:18, 34:88:de:e3:c0:19 as MAC addresses:

tlv_eeprom set 0x24 "34:88:de:e3:c0:17"
tlv_eeprom set 0x2A 3
tlv_eeprom write

# Verify by re-reading the TLV data from eeprom

tlv_eeprom read
tlv_eeprom
# TLV: 0
# TlvInfo Header:
#    Id String:    TlvInfo
#    Version:      1
#    Total Length: 18
# TLV Name             Code Len Value
# -------------------- ---- --- -----
# Base MAC Address     0x24   6 34:88:DE:E3:C0:17
# MAC Addresses        0x2A   2 3
# CRC-32               0xFE   4 0x2214EB35
```

## Compiling Image from Source

### Configuration Options

The build script supports several customisation options that can be applied through environment variables:

- BOARD: Choose target Board
  - evm
  - hummingboard-t (default)
- SOC_VERSION: Choose Silicon Revision
  - sr1 (AM6442A - SR 1.0, default)
  - sr2 (AM6442B - SR 2.0)
- SOC_TYPE: Choose SoC Type (secure boot)
  - gp (general purpose, **sr1 only**, default)
  - hs-fs (high security, field-securable - before burning customer key to efuses, **sr2 and later**)
  - hs-se (high security, security-enabled - after burning customer key to efuses, **sr2 and later**)
- DISTRO: Choose Linux distribution for rootfs
  - buildroot (default)
  - debian
- BUILDROOT_VERSION
  - 2023.02.6 (default)
- BUILDROOT_DEFCONFIG: Choose specific config file name from `config/` folder
  - am64xx_solidrun_defconfig (default)
- BR2_PRIMARY_SITE: Use specific (local) buildroot mirror
- DEBIAN_VERSION
  - bullseye (default)
- DEBIAN_ROOTFS_SIZE
  - 936M (default)

### With Docker (recommended)

A docker image providing a consistent build environment can be used as below:

1. build container image (first time only)
   ```
   docker build -t ti_am64x_build docker
   # optional with an apt proxy, e.g. apt-cacher-ng
   # docker build --build-arg APTPROXY=http://127.0.0.1:3142 -t ti_am64x_build docker
   ```

2. invoke build script in working directory
   ```
   docker run --rm -i -t -v "$PWD":/ti_build ti_am64x_build -u $(id -u) -g $(id -g)
   ```

#### rootless Podman

Due to the way podman performs user-id mapping, the root user inside the container (uid=0, gid=0) will be mapped to the user running podman (e.g. 1000:100).
Therefore in order for the build directory to be owned by current user, `-u 0 -g 0` have to be passed to *docker run*.

### on Host OS

This can only work on Debian-based host, and has been tested only on Debian 11.

The build script will check for required tools, clone and build images and place results in output/ directory:

    ./runme.sh
