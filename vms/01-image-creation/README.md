# Image Creation

## Motivation
I would like to minimize the manual labor required to set up new vms.\
Previously I used to manually install the Ubuntu ISO into a new qcow2 vm image drive providing a user and random password.\
Afterwards I let Ansible Scripts run to upgrade the system, add a new user, setting authorized keys and hardening the system.\
I've learned even cloud providers like AWS seem to use pre-installed base images. When starting a newly created VM something like cloud-init doing some of the things I used ansible for.\
First I would need to create a base image. I also want to automate this step so no more manual labor is required :)\
As I've learned this can be used with autoinstall.\
\
I know that there are applications like hashicorps packer to provide abstrations making this easier.\
I would like to try creating a similar but more basic version myself. This way I get to learn how Packer works under the hood.
