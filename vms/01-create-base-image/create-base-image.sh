#!/bin/bash

# template folder is relative to this script not the position where its called
SCRIPT_BASE=$(dirname "$0")

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

# I noticed sometimes the login wont work if the comment is still present.
# Thats why I'm cleaning it to only add the key type and key data to the authorized_keys section.
UNCLEAN_PUBLIC_KEY=$(cat $PUBLIC_KEY_FILE)
PUBLIC_KEY=$(echo "$UNCLEAN_PUBLIC_KEY" | awk '{print $1, $2}')




# Setup a working directory to create the isos, mounting the installing scripts etc...
TEMP_DIR_RANDOM=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 4; echo)
TEMP_DIR=$(echo "out/img-$TEMP_DIR_RANDOM")

# cleanup if any previous images have been created
if [ -d "$TEMP_DIR" ]; then
	rm -rf $TEMP_DIR
fi

mkdir -p $TEMP_DIR




# create the autoinstall iso
mkdir -p $TEMP_DIR/autoinstall-iso

touch $TEMP_DIR/autoinstall-iso/meta-data
cp $SCRIPT_BASE/templates/install/autoinstall.template.yml $TEMP_DIR/autoinstall-iso/user-data

# replace template placeholder
sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/autoinstall-iso/user-data 

genisoimage -output $TEMP_DIR/autoinstall.iso -volid CIDATA -joliet -rock $TEMP_DIR/autoinstall-iso

# rm -rf $TEMP_DIR/autoinstall-iso




# create the cloud-init iso
mkdir -p $TEMP_DIR/cloud-init-iso # used to create the cloud-init-iso.iso

cp $SCRIPT_BASE/templates/setup/user-data.template.yml $TEMP_DIR/cloud-init-iso/user-data
cp $SCRIPT_BASE/templates/setup/meta-data.template.yml $TEMP_DIR/cloud-init-iso/meta-data
cp $SCRIPT_BASE/templates/setup/vendor-data.template.yml $TEMP_DIR/cloud-init-iso/vendor-data

# replace template placeholder
sed -i -e "s|__MAC_ADDRESS__|$MAC_ADDRESS|" $TEMP_DIR/cloud-init-iso/meta-data
sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/cloud-init-iso/meta-data

sed -i -e "s|__HOSTNAME__|$HOSTNAME|" $TEMP_DIR/cloud-init-iso/vendor-data
sed -i -e "s|__USERNAME__|$USERNAME|" $TEMP_DIR/cloud-init-iso/vendor-data
sed -i -e "s|__PUBLIC_KEY__|$PUBLIC_KEY|" $TEMP_DIR/cloud-init-iso/vendor-data

genisoimage -output $TEMP_DIR/cloud-init.iso -volid CIDATA -joliet -rational-rock $TEMP_DIR/cloud-init-iso

# rm -rf $TEMP_DIR/cloud-init-iso




# mount the ubuntu iso to get access to vmlinuz and initrd
# these two object files allow to add kernel arguments (autoinstall)
# initrd is the initial RAM layout loaded into -- you guessed it -- the RAM :)
# vmlinuz is the kernel
mkdir -p $TEMP_DIR/os-installer-iso-mount # mount point to copy vmlinuz and initrd
sudo mount -ro loop $ISO_PATH $TEMP_DIR/os-installer-iso-mount

cp $TEMP_DIR/os-installer-iso-mount/casper/vmlinuz $TEMP_DIR/
cp $TEMP_DIR/os-installer-iso-mount/casper/initrd $TEMP_DIR/

sudo umount $TEMP_DIR/os-installer-iso-mount
rm -rf $TEMP_DIR/os-installer-iso-mount




# create the qemu image
qemu-img create -f qcow2 $TEMP_DIR/image.qcow2 $IMAGE_SIZE

# run the install script
qemu-system-x86_64 \
	-m 8G \
	-cpu host \
	-enable-kvm \
	-smp 4 \
	-boot menu=off \
	-boot order=c \
	-drive file=$TEMP_DIR/image.qcow2,format=qcow2,cache=none,if=virtio \
	-drive file=$TEMP_DIR/autoinstall.iso,format=raw,cache=none,if=virtio \
	-cdrom $ISO_PATH \
	-kernel $TEMP_DIR/vmlinuz \
	-initrd $TEMP_DIR/initrd \
	-append "autoinstall"

# run the cloud-init script
qemu-system-x86_64 \
	-m 8G \
	-cpu host \
	-enable-kvm \
	-smp 4 \
	-drive file=$TEMP_DIR/image.qcow2,index=0,format=qcow2,media=disk,cache=none,if=virtio \
	-cdrom $TEMP_DIR/cloud-init.iso

# move the finished image
mv $TEMP_DIR/image.qcow2 $IMAGE_OUT
rm -rf $TEMP_DIR