# Ubuntu 24.04 Golden Image

## Purpose

This runbook documents the creation, sealing, cloning, and validation of the MedusaLab Ubuntu Server golden image for VMware Workstation.

The image provides a standardized Ubuntu foundation for future infrastructure, Kubernetes, automation, and sandbox virtual machines.

## Golden Image Standard

| Setting             | Value                                                |
| ------------------- | ---------------------------------------------------- |
| Template name       | `tmpl-ubuntu-2404`                                   |
| Operating system    | Ubuntu Server 24.04.4 LTS                            |
| Architecture        | AMD64                                                |
| VMware firmware     | UEFI with Secure Boot                                |
| Virtual CPUs        | 2                                                    |
| Memory              | 4 GB                                                 |
| Disk                | 60 GB, growable                                      |
| Template location   | `D:\MedusaLab\Lab\Templates\VMware\tmpl-ubuntu-2404` |
| Administrative user | `minotaur423`                                        |
| Management network  | VMnet1                                               |
| NAT network         | VMnet8                                               |
| Provisioning method | Ansible                                              |
| Cloud-init          | Disabled before sealing                              |

## Network Design

The template contains two VMware network adapters.

| Interface | VMware network | Purpose                     | Configuration                       |
| --------- | -------------- | --------------------------- | ----------------------------------- |
| `ens33`   | VMnet1         | Management                  | DHCP while the system is a template |
| `ens34`   | VMnet8         | Internet and package access | DHCP with the default route         |

VMnet1 must not provide the default route or DNS service.

VMnet8 is the only interface that provides the system default route.

The template Netplan configuration is stored in:

```text
/etc/netplan/01-medusalab-template.yaml
```

Permanent clones replace the template configuration with a static VMnet1 management address while retaining DHCP on VMnet8.

## Baseline Packages

The Ubuntu baseline installs and manages the following packages:

* `bash-completion`
* `ca-certificates`
* `chrony`
* `curl`
* `dnsutils`
* `git`
* `iproute2`
* `open-vm-tools`
* `openssh-server`
* `python3`
* `python3-apt`
* `sudo`
* `tar`
* `unzip`
* `vim`
* `wget`

The following services must be enabled and running:

* `chrony`
* `open-vm-tools`
* `ssh`

## Ansible Components

The Ubuntu baseline is maintained through:

```text
ansible/roles/ubuntu_baseline/
ansible/playbooks/ubuntu-template-baseline.yml
ansible/playbooks/ubuntu-baseline.yml
```

The template playbook targets temporary Ubuntu template inventory entries.

The managed-system playbook targets the `ubuntu_managed` inventory group.

The baseline must be executed twice before an image is sealed. The second execution must report:

```text
changed=0
unreachable=0
failed=0
```

## SSH Client Authentication

The MedusaLab SSH public key is retained in:

```text
/home/minotaur423/.ssh/authorized_keys
```

The corresponding private key remains only on the WSL engineering workstation:

```text
~/.ssh/medusalab_ed25519
```

Private keys and passphrases must never be copied into templates, virtual machines, documentation, or Git.

## SSH Host-Key Regeneration

SSH server host keys must be unique for every clone.

The template contains this systemd service:

```text
/etc/systemd/system/medusalab-ssh-hostkeys.service
```

The service runs:

```text
/usr/bin/ssh-keygen -A
```

The SSH service contains this dependency override:

```text
/etc/systemd/system/ssh.service.d/10-medusalab-hostkeys.conf
```

This dependency ensures missing SSH host keys are generated before `ssh.service` starts.

During sealing, all existing files matching the following pattern are removed:

```text
/etc/ssh/ssh_host_*
```

The public client authorization key in the user account is not removed.

On the first boot of a clone, the systemd service generates new RSA, ECDSA, and ED25519 SSH host keys.

## Machine Identity

Before the template is powered off, `/etc/machine-id` is truncated to an empty file.

The following symlink is maintained:

```text
/var/lib/dbus/machine-id -> /etc/machine-id
```

The systemd random seed is also removed.

When a clone starts, systemd generates and stores a new machine identity.

Each clone must be verified to have:

* A nonempty 32-character machine ID
* Newly generated SSH host keys
* A unique VMware identity
* A unique hostname
* A unique static VMnet1 address

## Cloud-Init Policy

Cloud-init is disabled on this template because permanent MedusaLab configuration is performed through Ansible.

The disable marker is:

```text
/etc/cloud/cloud-init.disabled
```

Cloud-init state is removed before the template is sealed.

## Sealing Requirements

Immediately before shutdown, the template must have:

* Current operating-system packages
* A successful Ansible baseline
* A second idempotent Ansible run
* SSH public-key access
* The SSH host-key regeneration service
* Cloud-init disabled
* SSH server host keys removed
* An empty machine ID
* Package caches removed
* Logs and shell history cleaned
* The installation ISO disconnected

The template must then be powered off.

A sealed template must not be booted directly again.

## Clone Procedure

All operational systems must be created as full clones.

When VMware asks whether the VM was moved or copied, select:

```text
I copied it
```

After the clone starts:

1. Set its permanent hostname.
2. Confirm that `/etc/machine-id` contains a new identity.
3. Confirm that new SSH host keys exist.
4. Assign a static address to the VMnet1 interface.
5. Retain VMnet8 DHCP and the default route.
6. Create a Windows TCP port proxy for WSL SSH access.
7. Add an SSH alias in `~/.ssh/config`.
8. Add the host to Ansible inventory.
9. Apply the Ubuntu baseline twice.
10. Confirm the second Ansible execution is idempotent.

## Validation Clone

The golden image was validated using:

| Setting        | Value                                                           |
| -------------- | --------------------------------------------------------------- |
| Clone name     | `ubuntu-test01`                                                 |
| Clone type     | Full clone                                                      |
| Location       | `D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox\ubuntu-test01` |
| VMnet1 address | `192.168.141.21/24`                                             |
| VMnet8 address | VMware DHCP                                                     |
| WSL SSH proxy  | `127.0.0.1:2213`                                                |
| Ansible group  | `ubuntu_managed`                                                |

Validation confirmed:

* Unique machine identity
* Newly generated SSH host keys
* Static VMnet1 management connectivity
* VMnet8 outbound connectivity
* Windows-to-VM SSH connectivity
* WSL-to-VM SSH connectivity
* Public-key authentication
* Successful Ansible baseline
* Ansible idempotence

## Operational Rule

The sealed `tmpl-ubuntu-2404` image must remain powered off.

Changes to the Ubuntu standard must be implemented through an intentional template-maintenance cycle or by creating a replacement version of the template.

