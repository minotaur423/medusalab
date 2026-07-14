# Virtual Machine Inventory

## Purpose

This document records the virtual machines and reusable templates managed as part of MedusaLab.

Virtual disks, VMware runtime files, snapshots, ISO images, credentials, and private keys are not stored in the Git repository.

## VMware Platform

| Component          | Value                                     |
| ------------------ | ----------------------------------------- |
| Hypervisor         | VMware Workstation 26.0.0                 |
| Windows host       | MEDUSA                                    |
| Template storage   | `D:\MedusaLab\Lab\Templates\VMware`       |
| Active VM storage  | `D:\MedusaLab\Lab\VirtualMachines\VMware` |
| Management network | VMnet1 — `192.168.141.0/24`               |
| External network   | VMnet8 — `192.168.197.0/24`               |

## Templates

### tmpl-rhel-10

| Property              | Value                                            |
| --------------------- | ------------------------------------------------ |
| Lifecycle             | Template                                         |
| Operating system      | Red Hat Enterprise Linux 10.2                    |
| Architecture          | x86-64                                           |
| Virtualization        | VMware                                           |
| Location              | `D:\MedusaLab\Lab\Templates\VMware\tmpl-rhel-10` |
| Virtual CPUs          | 2                                                |
| Memory                | 4 GB                                             |
| Virtual disk          | 60 GB growable                                   |
| Adapter 1             | VMnet1 management                                |
| Adapter 2             | VMnet8 NAT                                       |
| Administrative user   | `minotaur423`                                    |
| SSH public-key access | Configured                                       |
| Ansible baseline      | Applied and validated                            |
| Red Hat registration  | Removed before sealing                           |
| Machine identity      | Cleared before sealing                           |
| SSH host keys         | Removed before sealing                           |
| Current state         | Powered off and sealed                           |

The template must remain powered off. New systems must be created as full clones and receive new machine identity, SSH host keys, hostname, IP address, and Red Hat registration.

## Active Virtual Machines

### rhel10-test01

| Property               | Value                                                           |
| ---------------------- | --------------------------------------------------------------- |
| Lifecycle              | Sandbox validation system                                       |
| Operating system       | Red Hat Enterprise Linux 10.2                                   |
| Architecture           | x86-64                                                          |
| Location               | `D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox\rhel10-test01` |
| Source template        | `tmpl-rhel-10`                                                  |
| Clone type             | Full clone                                                      |
| Hostname               | `rhel10-test01`                                                 |
| Management address     | `192.168.141.20/24`                                             |
| Management interface   | `ens160` on VMnet1                                              |
| External interface     | `ens192` on VMnet8                                              |
| Default gateway        | VMware NAT through `192.168.197.2`                              |
| Red Hat registration   | Independently registered                                        |
| SSH access             | MedusaLab ED25519 key                                           |
| WSL proxy port         | `127.0.0.1:2211`                                                |
| Ansible group          | `rhel_sandbox`                                                  |
| Ansible baseline       | Applied                                                         |
| Idempotence validation | Passed                                                          |
| Current role           | Golden-image clone validation                                   |

## Validation Results

The `rhel10-test01` clone successfully demonstrated:

* Independent machine identity generation
* Independent SSH host-key generation
* Static VMnet1 management addressing
* VMnet8 DHCP and outbound internet access
* Connectivity between the VM and the Windows host
* SSH access from Ubuntu WSL through a Windows TCP proxy
* Independent Red Hat registration
* Python availability for Ansible
* Successful Ansible fact gathering
* Successful application of the RHEL baseline role
* Idempotent second Ansible run with no changes

