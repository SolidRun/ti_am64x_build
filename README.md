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
