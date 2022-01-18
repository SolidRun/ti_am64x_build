# SolidRun's TI AM64x based  build scripts

## Introduction
Main intention of this repository is to build a buildroot based build environment for TI AM64x based product evaluation.

The build script provides ready to use images that can be deployed on a micro SD card.

## Build with host tools
Simply running ./runme.sh, it will check for required tools, clone and build images and place results in output/ directory.

## Deploying
In order to create a bootable SD card, plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=output/microsd-<hash>.img of=/dev/sdX
```


## Booting Linux and Rootfs

### SD card

By default, Linux will read rootfs from SD card, partition 2.<br>
In order to load rootfs into RAM, please run the following command in U-boot:

```
Hit any key to stop autoboot:  0
=> run load_rootfs; boot

```

In this case, Linux won't load the rootfs from SD card.<br>
Please note that all changes to the file system (creating/deleting files/directories) will be discarded every reboot.


### Ethernet

In order to boot Linux kernel and rootfs over ethernet, you'll need a TFTP server to serve the required files.

#### Setting a TFTP server (From a different Linux machine in the same network)

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


#### Retrieving booting files over ethetnet.
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
