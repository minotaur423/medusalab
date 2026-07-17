# Virtual Machine Inventory

## Purpose

This document records the VMware virtual machines and reusable golden images managed as part of MedusaLab.

The Git repository stores only configuration, inventory, automation, standards, and operational documentation.

The following items are not stored in Git:

* Virtual disks
* VMware runtime files
* Snapshots
* ISO images
* Credentials
* Activation keys
* Private SSH keys
* Secret files

## VMware Platform

| Component                 | Value                                                    |
| ------------------------- | -------------------------------------------------------- |
| Hypervisor                | VMware Workstation 26.0.0                                |
| Windows host              | `MEDUSA`                                                 |
| Template storage          | `D:\MedusaLab\Lab\Templates\VMware`                      |
| Infrastructure VM storage | `D:\MedusaLab\Lab\VirtualMachines\VMware\Infrastructure` |
| Kubernetes VM storage     | `D:\MedusaLab\Lab\VirtualMachines\VMware\Kubernetes`     |
| Sandbox VM storage        | `D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox`        |
| Management network        | VMnet1 — `192.168.141.0/24`                              |
| External network          | VMnet8 — `192.168.197.0/24`                              |
| Static management range   | `192.168.141.10–192.168.141.99`                          |
| VMnet8 gateway            | `192.168.197.2`                                          |

## Network Standard

MedusaLab VMware systems use two network adapters.

| Adapter purpose | VMware network | Configuration                                            |
| --------------- | -------------- | -------------------------------------------------------- |
| Management      | VMnet1         | Static address for operational systems; no default route |
| External access | VMnet8         | VMware DHCP; provides default route and external DNS     |

Templates may temporarily use DHCP on VMnet1 while they are being built.

Permanent clones receive a unique static VMnet1 address before being added to active inventory.

Ubuntu WSL reaches VMnet1 guests through Windows TCP port proxies because WSL mirrored networking does not route directly to the VMware host-only network.

# Golden Images

## `tmpl-rhel-10`

| Property                | Value                                            |
| ----------------------- | ------------------------------------------------ |
| Lifecycle               | Sealed golden image                              |
| Operating system        | Red Hat Enterprise Linux 10.2                    |
| Architecture            | x86-64                                           |
| Virtualization platform | VMware Workstation                               |
| Location                | `D:\MedusaLab\Lab\Templates\VMware\tmpl-rhel-10` |
| Virtual CPUs            | 2                                                |
| Memory                  | 4 GB                                             |
| Virtual disk            | 60 GB growable                                   |
| Management adapter      | VMnet1                                           |
| External adapter        | VMnet8                                           |
| Administrative user     | `minotaur423`                                    |
| SSH public-key access   | Configured                                       |
| Ansible baseline        | Applied and validated                            |
| Red Hat registration    | Removed before sealing                           |
| Machine identity        | Cleared before sealing                           |
| SSH host keys           | Removed before sealing                           |
| Package cache           | Cleaned before sealing                           |
| Current state           | Powered off                                      |

### Usage Rules

* The template must remain powered off.
* New RHEL systems must be created as full clones.
* Select **I copied it** if VMware asks whether the VM was moved or copied.
* Every clone must receive a unique hostname.
* Every clone must receive a unique static VMnet1 address.
* Every clone must generate a unique machine identity.
* Every clone must generate unique SSH server host keys.
* Every operational clone must be registered independently with Red Hat.
* The RHEL Ansible baseline must be applied after cloning.

## `tmpl-ubuntu-2404`

| Property                  | Value                                                |
| ------------------------- | ---------------------------------------------------- |
| Lifecycle                 | Sealed golden image                                  |
| Operating system          | Ubuntu Server 24.04.4 LTS                            |
| Architecture              | AMD64                                                |
| Virtualization platform   | VMware Workstation                                   |
| Location                  | `D:\MedusaLab\Lab\Templates\VMware\tmpl-ubuntu-2404` |
| Virtual CPUs              | 2                                                    |
| Memory                    | 4 GB                                                 |
| Virtual disk              | 60 GB growable                                       |
| Management interface      | `ens33` on VMnet1                                    |
| External interface        | `ens34` on VMnet8                                    |
| Administrative user       | `minotaur423`                                        |
| SSH public-key access     | Configured                                           |
| Ansible baseline          | Applied and validated                                |
| Cloud-init                | Disabled before sealing                              |
| Machine identity          | Cleared before sealing                               |
| SSH host keys             | Removed before sealing                               |
| SSH host-key regeneration | Configured through systemd                           |
| Package cache             | Cleaned before sealing                               |
| Current state             | Powered off                                          |

### SSH Host-Key Regeneration

The Ubuntu template contains:

```text
/etc/systemd/system/medusalab-ssh-hostkeys.service
```

The service runs:

```text
/usr/bin/ssh-keygen -A
```

The SSH service dependency is configured in:

```text
/etc/systemd/system/ssh.service.d/10-medusalab-hostkeys.conf
```

This ensures that missing SSH host keys are regenerated before the SSH daemon starts on the first boot of each clone.

### Usage Rules

* The template must remain powered off.
* New Ubuntu systems must be created as full clones.
* Select **I copied it** if VMware asks whether the VM was moved or copied.
* Every clone must receive a unique hostname.
* Every clone must receive a unique static VMnet1 address.
* Every clone must generate a unique machine identity.
* Every clone must generate unique SSH server host keys.
* VMnet8 must remain the only default route.
* The Ubuntu Ansible baseline must be applied after cloning.

# Validation Systems

## `rhel10-test01`

| Property               | Value                                                           |
| ---------------------- | --------------------------------------------------------------- |
| Lifecycle              | Golden-image validation system                                  |
| Operating system       | Red Hat Enterprise Linux 10.2                                   |
| Architecture           | x86-64                                                          |
| Location               | `D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox\rhel10-test01` |
| Source template        | `tmpl-rhel-10`                                                  |
| Clone type             | Full clone                                                      |
| Hostname               | `rhel10-test01`                                                 |
| Management address     | `192.168.141.20/24`                                             |
| Management interface   | `ens160` on VMnet1                                              |
| External interface     | `ens192` on VMnet8                                              |
| Default gateway        | `192.168.197.2` through VMnet8                                  |
| Red Hat registration   | Independently registered                                        |
| SSH authentication     | MedusaLab ED25519 key                                           |
| WSL proxy              | `127.0.0.1:2211`                                                |
| Ansible inventory path | `rhel_managed` → `rhel_sandbox`                                 |
| Ansible baseline       | Applied                                                         |
| Idempotence validation | Passed                                                          |
| Current state          | Validation complete; retained temporarily                       |

### Validation Results

The `rhel10-test01` clone successfully demonstrated:

* Unique machine identity generation
* Unique SSH server host-key generation
* Static VMnet1 management addressing
* VMnet8 DHCP and outbound connectivity
* Connectivity between the VM and Windows host
* SSH access from Ubuntu WSL through a Windows TCP proxy
* Independent Red Hat registration
* Python availability for Ansible
* Successful Ansible fact gathering
* Successful application of the RHEL baseline
* Idempotent second Ansible execution with no changes

## `ubuntu-test01`

| Property               | Value                                                           |
| ---------------------- | --------------------------------------------------------------- |
| Lifecycle              | Golden-image validation system                                  |
| Operating system       | Ubuntu Server 24.04.4 LTS                                       |
| Architecture           | AMD64                                                           |
| Location               | `D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox\ubuntu-test01` |
| Source template        | `tmpl-ubuntu-2404`                                              |
| Clone type             | Full clone                                                      |
| Hostname               | `ubuntu-test01`                                                 |
| Management address     | `192.168.141.21/24`                                             |
| Management interface   | `ens33` on VMnet1                                               |
| External interface     | `ens34` on VMnet8                                               |
| Default gateway        | `192.168.197.2` through VMnet8                                  |
| SSH authentication     | MedusaLab ED25519 key                                           |
| WSL proxy              | `127.0.0.1:2213`                                                |
| Ansible inventory path | `ubuntu_managed` → `ubuntu_sandbox`                             |
| Ansible baseline       | Applied                                                         |
| Idempotence validation | Passed                                                          |
| Current state          | Validation complete; retained temporarily                       |

### Validation Results

The `ubuntu-test01` clone successfully demonstrated:

* Unique machine identity generation
* Automatic regeneration of unique SSH server host keys
* Successful execution of the MedusaLab SSH host-key systemd service
* Static VMnet1 management addressing
* VMnet8 DHCP and outbound connectivity
* VMnet8 as the only default route
* Connectivity between the VM and Windows host
* SSH access from Ubuntu WSL through a Windows TCP proxy
* Public-key authentication
* Python availability for Ansible
* Successful Ansible fact gathering
* Successful application of the Ubuntu baseline
* Idempotent second Ansible execution with no changes

# Infrastructure Systems

## `dns01`

| Property               | Value                                                          |
| ---------------------- | -------------------------------------------------------------- |
| Lifecycle              | Permanent infrastructure system                                |
| Operating system       | Red Hat Enterprise Linux 10.2                                  |
| Architecture           | x86-64                                                         |
| Location               | `D:\MedusaLab\Lab\VirtualMachines\VMware\Infrastructure\dns01` |
| Source template        | `tmpl-rhel-10`                                                 |
| Clone type             | Full clone                                                     |
| Hostname               | `dns01.medusalab.test`                                         |
| Management address     | `192.168.141.10/24`                                            |
| Management Interface   | `ens160` on VMnet1                                             |
| External Interface     | `ens192` on VMnet8                                             |
| Default gateway        | `192.168.197.2` through VMnet8                                 |
| Red Hat registration   | Independently registered                                       |
| SSH authentication     | MedusaLab ED25519 key                                          |
| WSL proxy              | `127.0.0.1:2220`                                               |
| Ansible inventory path | `rhel_managed` → `rhel_infrastructure` → `dns_servers`         |
| RHEL baseline          | Applied and idempotent                                         |
| Infrastructure role    | Internal authoritative and recursive                           |
| DNS software	         | BIND                                                           |
| Forward zone	         | medusalab.test                                                 |
| Reverse zone	         | 141.168.192.in-addr.arpa                                       |
| Current state          | Active                                                         |

### Validation Results

The dns01 deployment successfully demonstrated:

* Unique machine identity and SSH server host keys
* Independent Red Hat registration
* Static VMnet1 management addressing
* VMnet8 DHCP and outbound connectivity
* WSL SSH access through Windows TCP proxy port 2220
* Successful RHEL baseline automation
* Successful BIND installation and configuration
* SELinux-enforcing operation
* Firewalld DNS access
* Valid forward and reverse zones
* Restricted recursive DNS
* External name resolution
* RHEL client integration
* Ubuntu client integration
* Windows NRPT integration
* WSL DNS-tunneling integration
* Ansible idempotence

# Lifecycle Policy

Golden-image validation systems may be retained temporarily for troubleshooting and comparison.

After the corresponding golden-image workflow is fully documented and a permanent infrastructure system has been successfully deployed, validation systems should be:

* Powered off and archived
* Repurposed intentionally
* Or removed from VMware and active Ansible inventory

Their static IP and WSL proxy allocations must be updated in `docs/networking/IP-Allocations.md` when their lifecycle changes.

# Inventory Maintenance

Update this document whenever:

* A template is created, replaced, resealed, or retired
* A VM is created, renamed, moved, repurposed, or removed
* CPU, memory, disk, or network assignments change
* A static management address changes
* A WSL proxy port changes
* An Ansible inventory group changes
* A system changes lifecycle state

