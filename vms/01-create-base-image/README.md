# Image Creation

## Motivation
I would like to minimize the manual labor required to set up new vms.\
Previously I used to manually install the Ubuntu ISO into a new qcow2 vm image drive providing a user and random password.\
Afterwards I let Ansible Scripts run to upgrade the system, add a new user, setting authorized keys and hardening the system.\
I've learned even cloud providers like AWS seem to use pre-installed base images. When starting a newly created VM something like autoinstall and cloud-init allow me to automate some of the things right while installing the image for the first time.\
First I would need to create a base image. I also want to automate this step so no more manual labor is required :)\
I'll install the pure iso to a new image using autoinstall. Afterwards I'll restart the vm providing seed files for cloud-init to do the ssh hardening and updating the system for the first time.\
\
I know that there are applications like hashicorps packer to provide abstrations making this easier.\
I would like to try creating a similar but more basic version myself. This way I get to learn how Packer works under the hood.

## Requirements
Packages required for this module:
- genisoimage

Files required for this module:
- ISO for installation (it has only been tested with Ubuntu Server 24.04.2)

## Usage
You'll have to provide a valid public-key-path and an iso path and a random mac address to create an image.\
You can also provide a hostname and username if you prefer.

```bash
# the "simples" command:
./create-base-image.sh \
    --public-key-file ./path/to/key.pub \
    --iso ./path/to/ubuntu.iso \
    --mac AA:BB:CC:DD:EE:FF
```

Or just see what else you can change:
```bash
./create-base-image.sh --help
```

Please use sensible values as they will not be validated yet.

## How does it work?
This module uses autoinstall provided by Ubuntu. The configuration file is needed inside a seperate ISO which will also be provided to QEMU when installing.\
Unfortunetly I needed to read the files `vmlinuz` and `initrd` from the original Ubuntu ISO to be able to add the autoinstall argument as a kernel arg.\
These two files will temporarily be copied to the working directory stored in the out folder.\
Both files will be provided to qemu and the `autoinstall` will be appended.\
Afterwards I'll restart the vm providing a different ISO which contains a setup configuration for cloud-init.