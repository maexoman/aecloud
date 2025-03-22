#!/bin/bash

# provide sensible defaults:
HOSTNAME=aecloud
USERNAME=aecloud-admin

IMAGE_SIZE=5G

IMAGE_OUT=image.qcow2

# parse the arguments provided to the script
while [[ $# -gt 0 ]]; do
  case $1 in
	-h|--help)
	  echo "here are the allowed options:"
	  echo " --public-key-file >> path to the public key file"
	  echo " --iso >> path to the ISO file"
	  echo " --mac >> mac address of new vm"
	  echo " --hostname >> hostname for the new machine"
	  echo " --username >> username for the new machine"
	  echo " -o,--out >> path on where to store the image"
	  echo " --image-size >> required size of the image"
	  echo ""
	  echo " --public-key-file and --iso are required"
	  exit 0
	  ;;
	--public-key-file)
	  PUBLIC_KEY_FILE="$2"
	  shift # past argument
	  shift # past value
	  ;;
	--iso)
	  ISO_PATH="$2"
	  shift # past argument
	  shift # past value
	  ;;
	--mac)
	  MAC_ADDRESS="$2"
	  shift # past argument
	  shift # past value
	  ;;
	--hostname)
	  HOSTNAME="$2"
	  shift # past argument
	  shift # past value
	  ;;
	--username)
	  USERNAME="$2"
	  shift # past argument
	  shift # past value
	  ;;
	-o|--out)
	  IMAGE_OUT="$2"
	  shift # past argument
	  shift # past value
	  ;;
	--image-size)
	  IMAGE_SIZE="$2"
	  shift # past argument
	  shift # past value
	  ;;

	-*|--*)
	  echo "Unknown option $1"
	  exit 1
	  ;;
	*)
	  echo "Unknown option $1"
	  exit 1
	  ;;
  esac
done

# Check the required variables
if [ -z "${PUBLIC_KEY_FILE}" ]; then
	echo "Please provide the --public-key-file"
	exit 1
fi
if [ -z "${ISO_PATH}" ]; then
	echo "Please provide the --iso"
	exit 1
fi
if [ -z "${MAC_ADDRESS}" ]; then
	echo "Please provide the --mac"
	exit 1
fi

# validation would be awesome.... :D
UNCLEANED_PUBLIC_KEY=$(cat $PUBLIC_KEY_FILE)
PUBLIC_KEY=$(echo "$UNCLEANED_PUBLIC_KEY" | awk '{print $1, $2}')

TEMP_DIR_RANDOM=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 4; echo)
TEMP_DIR=$(echo "temp-$TEMP_DIR_RANDOM")

# cleanup if any previous images have been created
if [ -d "$TEMP_DIR" ]; then
	rm -rf $TEMP_DIR
fi

# setup working dir structure
mkdir -p $TEMP_DIR/workdir
mkdir -p $TEMP_DIR/workdir/seed # used to create the seed.iso
mkdir -p $TEMP_DIR/workdir/iso-mount # mount point to copy vmlinuz and initrd
mkdir -p $TEMP_DIR/workdir/iso-copies # use to temporarily save vmlinuz and initrd

# create the iso with the autoinstall
cp templates/autoinstall.template.yml $TEMP_DIR/workdir/seed/autoinstall
cp templates/meta-data.template.yml $TEMP_DIR/workdir/seed/meta-data
cp templates/vendor-data.template.yml $TEMP_DIR/workdir/seed/vendor-data

# replace the template strings

# the autoinstall script only has HOSTNAME
sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/workdir/seed/autoinstall

# meta-data contains only the mac address and the hostname
sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/workdir/seed/meta-data
sed -i -e "s|__MAC_ADDRESS__|$MAC_ADDRESS|" $TEMP_DIR/workdir/seed/meta-data

# the vendordata contains all the user data
# the public key might contain a / meaning it would end the basic sed s/foo/bar/ -> use # instead
sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/workdir/seed/vendor-data
sed -i -e "s|__USERNAME__|$USERNAME|" $TEMP_DIR/workdir/seed/vendor-data
sed -i -e "s|__PUBLIC_KEY__|$PUBLIC_KEY|" $TEMP_DIR/workdir/seed/vendor-data

genisoimage -output $TEMP_DIR/workdir/seed.iso -volid CIDATA -joliet -rock $TEMP_DIR/workdir/seed

rm -rf $TEMP_DIR/workdir/seed

# mount the ubuntu iso to get access to vmlinuz and initrd
# these two object files allow to add kernel arguments (autoinstall)
# initrd is the initial RAM layout loaded into -- you guessed it -- the RAM :)
# vmlinuz is the kernel
sudo mount -ro loop $ISO_PATH $TEMP_DIR/workdir/iso-mount
cp $TEMP_DIR/workdir/iso-mount/casper/vmlinuz $TEMP_DIR/workdir/iso-copies/
cp $TEMP_DIR/workdir/iso-mount/casper/initrd $TEMP_DIR/workdir/iso-copies/
sudo umount $TEMP_DIR/workdir/iso-mount

rm -rf $TEMP_DIR/workdir/iso-mount

# create the qemu image
qemu-img create -f qcow2 $TEMP_DIR/temp-image.qcow2 $IMAGE_SIZE

# run the install script
qemu-system-x86_64 \
	-m 8G \
	-cpu host \
	-enable-kvm \
	-smp 4 \
	-boot menu=off \
	-boot order=c \
	-drive file=$TEMP_DIR/temp-image.qcow2,format=qcow2,cache=none,if=virtio \
	-drive file=$TEMP_DIR/workdir/seed.iso,format=raw,cache=none,if=virtio \
	-cdrom $ISO_PATH \
	-kernel $TEMP_DIR/workdir/iso-copies/vmlinuz \
	-initrd $TEMP_DIR/workdir/iso-copies/initrd \
	-append "autoinstall"

mv $TEMP_DIR/temp-image.qcow2 $IMAGE_OUT

rm -rf $TEMP_DIR
