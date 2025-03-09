# VM Setup (first user vm start)

## Motivation
After creating the base image for the vm I'll have to provide user specific data on first start.\
This will upgrade the system, setup a customer user and harden the system (ssh, firewall etc).\
I decided to keep this seperate from the autoinstall because it allows for more flexibility later on.\
This way I get to copy the base image multiple times and run instance-specific cloud-init configs with provided user-data.

## Further Reading
- how to provide cloud-init into qemu vm: https://cloudinit.readthedocs.io/en/latest/howto/launch_qemu.html#launch-qemu