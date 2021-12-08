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

