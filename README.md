# SolidRun's TI AM64x based  build scripts

## Introduction
Main intention of this repository is to build a buildroot based build environment for TI AM64x based product evaluation.

The build script provides ready to use images that can be deployed on micro SD.

## Build with host tools
Simply running ./runme.sh, it will check for required tools, clone and build images and place results in output/ directory.

## Deploying
In order to create a bootable SD card, plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=output/microsd-<hash>.img of=/dev/sdX
```

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

## Boot Modes

### Ethernet

In order to boot over ethernet, you'll need a TFTP server to serve the required files.

#### Setting a TFTP server (Linux)
	
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
This part assumes that you have a tftp server in the same network, and that your board is in U-boot (flashed in eMMC/SD card).

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

* Load Kernel into address 0x80480000 in RAM

```
setenv loadaddr 0x80480000
tftpboot Image
```

* Load Device Tree into address 0x83000000 in RAM.

```
setenv loadaddr 0x83000000
tftpboot am642-solidrun.dtb
```

* Load rootfs into address 0x83800000 in RAM.

```
setenv loadaddr 0x83800000
tftpboot rootfs.cpio
```

* boot

```
booti 0x80480000 0x83800000 0x83000000
```

