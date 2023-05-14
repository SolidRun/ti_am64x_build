# SolidRun's TI AM64x based  build scripts

Main intention of this repository is to produce a reference system for TI AM64x product evaluation.
Automatic binary releases are available on [our website](https://images.solid-run.com/AM64X/ti_am64x_build) for download.

## Get Started

AM64x SoM and Carriers currently ship without OS or Bootloader preinstalled.
Please download the latest binary release from

If no operating system was installed, please download the latest binary release from [our website](https://images.solid-run.com/AM64X/ti_am64x_build).
Then follow the steps in section "Deploying -> to microSD".

Before power-on, ensure that the Board has been configured to boot from microSD according to [this table](#configure-boot-mode-dip-switch)

After flashing a microSD and booting into Linux, the serial console must be used for logging into the root account for the first time.
Simply enter "root" and press return:

    Welcome to Buildroot
    buildroot login: root
    #

## Deploying

### to microSD

In order to create a bootable SD card, plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=output/microsd-<hash>.img of=/dev/sdX
```

### to eMMC

**TODO**

## Configure Boot Mode DIP Switch

This table indicates valid boot-modes selectable via the DIP switch S1 on the HummingBoard-T Carrier.
The value 0 indicates OFF, 1 indicates the ON state and X indicates don't care.

| Switch                  | 1 | 2 | 3 | 4 | 5 | 6 |
|-------------------------|---|---|---|---|---|---|
| microSD (FAT partition) | 0 | 0 | 0 | 1 | 0 | 1 |
| microSD (RAW)           | 1 | 0 | 0 | 0 | 1 | 1 |
| eMMC                    | 1 | 0 | 0 | 1 | X | X |

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

## Booting from eMMC

The following commands can be used to download tiboot3.bin, tispl.bin and u-boot.img from an SD card and write them to the eMMC boot0 partition at respective addresses.

```
    mmc dev 0 1

    fatload mmc 1  ${loadaddr} tiboot3.bin
    mmc write ${loadaddr} 0x0 0x400

    fatload mmc 1 ${loadaddr} tispl.bin
    mmc write ${loadaddr} 0x400 0x600

    fatload mmc 1 ${loadaddr}  u-boot.img
    mmc write ${loadaddr} 0x1000  0x800

    fatload mmc 1 ${loadaddr} sysfw.itb
    mmc write ${loadaddr}  0x1800 0x200
```
eMMC layout:

```
                    boot0 partition (4 MB)
             0x0+----------------------------------+
                |           tiboot3.bin            |
           0x400+----------------------------------+
                |           tispl.bin              |
          0x1000+----------------------------------+
                |           u-boot.img             |
          0x1800+----------------------------------+
                |           sysfw                  |
          0x2000+----------------------------------+

```

To give the ROM access to the boot partition, the following commands must be used for the first time:

```
    mmc partconf 0 1 1 1
    mmc bootbus 0 2 0 0
```

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
<br>
U-boot will try to read these MAC addresses from an EEPROM in I2C bus 0, address 0x50.
<br>
* CPSW's MAC address will be read from offsets 0x00->0x05.
* First ICSSG's MAC address will be read from offsets 0x06->0x0b.
* Second ICSSG's MAC address will be read from offsets 0x0c->0x11.

If no valid MAC addresses are found, random MAC addresses will be used.
<br>
Here is an example on how to write your own MAC address from Linux:

```
# Write aa:bb:cc:dd:ee:ff as CPSW's MAC address:

i2cset -y 0 0x50 0 0xaa 0xbb 0xcc 0xdd 0xee 0xff i

# Verify by dumping the EEPROM content:

i2cdump -y 0 0x50
```

## Compiling Image from Source

### Configuration Options

The build script supports several customisation options that can be applied through environment variables:

- BOARD: Choose target Board
  - evm
  - hummingboard-t (default)
- MODULES: comma-separated list of kernel modules to include in rootfs
- DISTRO: Choose Linux distribution for rootfs
  - buildroot (default)
  - debian
- BUILDROOT_VERSION
  - 2020.02 (default)
- BUILDROOT_DEFCONFIG: Choose specific config file name from `config/` folder
  - am64xx_solidrun_defconfig (default)
- BR2_PRIMARY_SITE: Use specific (local) buildroot mirror
- DEBIAN_VERSION
  - bullseye (default)
- DEBIAN_ROOTFS_SIZE
  - 936M (default)

### With Docker (recommended)

* Build the Docker image (**Just once**):

```
docker build --build-arg user=$(whoami) --build-arg userid=$(id -u) -t ti_am64x docker/
```

To check if the image exists in you machine, you can use the following command:

```
docker images | grep ti_am64x
```

* Run the build script:
```
docker run --rm -i -t -v "$PWD":/ti_build -v /etc/gitconfig:/etc/gitconfig ti_am64x ./runme.sh
```

### on Host OS

This can only work on Debian-based host, and has been tested only on Ubuntu 20.04.

The build script will check for required tools, clone and build images and place results in output/ directory:

```
./runme.sh
```
