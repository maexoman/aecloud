#!/bin/bash

OUT_DIR=out
ISO_PATH=ubuntu-24.04.2-live-server-amd64.iso

BASE_IMAGE_NAME=image
BASE_IMAGE_SIZE=7.5G

# setup working dir structure
mkdir -p $OUT_DIR/temp
mkdir -p $OUT_DIR/temp/seed # used to create the seed.iso
mkdir -p $OUT_DIR/temp/iso-mount # mount point to copy vmlinuz and initrd
mkdir -p $OUT_DIR/temp/iso-copies # use to temporarily save vmlinuz and initrd

# create the iso with the autoinstall
touch $OUT_DIR/temp/seed/meta-data
cp autoinstall.yml $OUT_DIR/temp/seed/user-data
genisoimage -output $OUT_DIR/temp/seed.iso -volid CIDATA -joliet -rock $OUT_DIR/temp/seed

rm -rf $OUT_DIR/temp/seed

# mount the ubuntu iso to get access to vmlinuz and initrd
# these two object files allow to add kernel arguments (autoinstall)
# initrd is the initial RAM layout loaded into -- you guessed it -- the RAM :)
# vmlinuz is the kernel
sudo mount -o loop $ISO_PATH $OUT_DIR/temp/iso-mount
cp $OUT_DIR/temp/iso-mount/casper/vmlinuz $OUT_DIR/temp/iso-copies/
cp $OUT_DIR/temp/iso-mount/casper/initrd $OUT_DIR/temp/iso-copies/
sudo umount $OUT_DIR/temp/iso-mount

rm -rf $OUT_DIR/temp/iso-mount

# create the base image
qemu-img create -f qcow2 $OUT_DIR/$BASE_IMAGE_NAME.qcow2 $BASE_IMAGE_SIZE

# run the install script
qemu-system-x86_64 \
	-m 8G \
	-cpu host \
	-enable-kvm \
	-smp 4 \
	-boot menu=off \
	-boot order=c \
	-drive file=$OUT_DIR/$BASE_IMAGE_NAME.qcow2,format=qcow2,cache=none,if=virtio \
	-drive file=$OUT_DIR/temp/seed.iso,format=raw,cache=none,if=virtio \
	-cdrom $ISO_PATH \
	-kernel $OUT_DIR/temp/iso-copies/vmlinuz \
	-initrd $OUT_DIR/temp/iso-copies/initrd \
	-append "autoinstall"

rm -rf $OUT_DIR/temp