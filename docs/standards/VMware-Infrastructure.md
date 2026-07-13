# VMware Infrastructure Standard

## Purpose

This document defines the MedusaLab standards for virtual machines created with VMware Workstation on MEDUSA.

The standard applies to golden images, infrastructure servers, Kubernetes nodes, and temporary sandbox systems.

## Platform Baseline

| Component               | Standard                                  |
| ----------------------- | ----------------------------------------- |
| Hypervisor              | VMware Workstation 26.0.0                 |
| Windows host            | MEDUSA                                    |
| Virtual-machine storage | `D:\MedusaLab\Lab\VirtualMachines\VMware` |
| Template storage        | `D:\MedusaLab\Lab\Templates\VMware`       |
| Installation media      | `D:\MedusaLab\Lab\ISOs`                   |
| Management network      | VMnet1                                    |
| External-access network | VMnet8                                    |
| Management subnet       | `192.168.141.0/24`                        |
| NAT subnet              | `192.168.197.0/24`                        |

## Directory Standard

```text
D:\MedusaLab\Lab\
├── ISOs\
├── Templates\
│   └── VMware\
└── VirtualMachines\
    └── VMware\
        ├── Infrastructure\
        ├── Kubernetes\
        └── Sandbox\
```

### Infrastructure

Use for long-lived supporting services such as:

* DNS
* DHCP
* Identity services
* Automation controllers
* Monitoring
* Artifact repositories
* Load balancers
* Management services

### Kubernetes

Use for:

* Kubernetes control-plane nodes
* Kubernetes worker nodes
* RKE2 nodes
* Rancher systems
* OpenShift-related supporting systems

### Sandbox

Use for:

* Temporary experiments
* Short-lived training systems
* Product evaluations
* Destructive testing

Sandbox virtual machines must not become permanent infrastructure without being rebuilt or formally reclassified.

## Naming Standard

Linux hostnames must:

* Use lowercase characters.
* Use letters, numbers, and hyphens only.
* Avoid underscores.
* Describe the system role.
* Use a two-digit sequence when multiple systems share a role.

Examples:

```text
dns01
ansible01
rke2-cp01
rke2-wk01
rke2-wk02
rancher01
registry01
```

Template names must identify the operating system and release:

```text
tmpl-ubuntu-2404
tmpl-rhel-10
```

The VMware display name should normally match the operating-system hostname.

## Firmware Standard

New Linux virtual machines will use:

```text
Firmware: UEFI
Secure Boot: Enabled when supported
```

Legacy BIOS will be used only when required by the guest operating system or a specific lab exercise.

## Virtual CPU Standard

| Workload                           |         Initial vCPU |
| ---------------------------------- | -------------------: |
| Linux template                     |                    2 |
| Lightweight infrastructure service |                    2 |
| General infrastructure server      |                    4 |
| Kubernetes control-plane node      |                    4 |
| Kubernetes worker node             |                  4–8 |
| Resource-intensive sandbox         | Assigned as required |

Virtual CPUs should be increased only when workload measurements justify the change.

Virtual machines should not be assigned more CPU resources than they require merely because the host has spare capacity.

## Memory Standard

| Workload                           |       Initial memory |
| ---------------------------------- | -------------------: |
| Linux template                     |                 4 GB |
| Lightweight infrastructure service |                 4 GB |
| General infrastructure server      |                 8 GB |
| Kubernetes control-plane node      |                 8 GB |
| Kubernetes worker node             |              8–16 GB |
| Resource-intensive sandbox         | Assigned as required |

Memory must be sized according to the workload and the number of virtual machines expected to run concurrently.

## Disk Standard

The default Linux virtual disk will use:

```text
Capacity:       60 GB
Provisioning:   Growable
Storage format: Single virtual-disk file when practical
Controller:     VMware recommended SCSI or NVMe controller
```

Additional disks will be used when separation is operationally useful, such as:

* Container storage
* Kubernetes data
* Artifact storage
* Database storage
* Logging
* Backup testing

Virtual disks must remain inside the virtual machine's assigned directory unless a documented exception exists.

## Network Standard

### Adapter 1 — Management

```text
Network:          VMnet1
Addressing:       Static
Subnet:           192.168.141.0/24
Default gateway:  None
```

Recommended static allocation range:

```text
192.168.141.10–192.168.141.99
```

This adapter is used for:

* SSH
* Ansible
* Internal service access
* Cluster communication
* Monitoring
* Administrative traffic

### Adapter 2 — NAT

```text
Network:          VMnet8
Addressing:       DHCP
Default gateway:  VMware NAT
DNS:              VMware NAT DNS proxy
```

This adapter is used for:

* Package installation
* Operating-system updates
* Container registries
* Git services
* Red Hat services
* External downloads

The NAT interface normally owns the default route.

### Bridged adapters

Bridged networking is prohibited by default.

An exception must document:

* Business or lab requirement
* Physical network exposure
* Addressing method
* Firewall implications
* Removal plan

## Operating-System Standard

New Linux virtual machines must include:

* Current supported operating-system updates
* `open-vm-tools`
* SSH server
* Chrony or the distribution-standard time service
* Python 3
* `sudo`
* Vim
* Network-management utilities
* A non-root administrative account
* SSH public-key authentication

Direct root SSH access must remain disabled.

Password authentication should be disabled after SSH-key access has been validated.

## Template Standard

A golden image must be:

* Fully patched.
* Free of workload-specific software.
* Configured with `open-vm-tools`.
* Configured for SSH-key administration.
* Cleared of machine-specific identity before cloning.
* Shut down cleanly before being designated as a template.
* Documented with its operating-system release and build date.

Template network interfaces should use DHCP during image construction.

Static VMnet1 addresses are assigned only after a VM is cloned.

## Clone Standard

Full clones are preferred for long-lived infrastructure.

Linked clones may be used for:

* Temporary sandbox systems
* Short training exercises
* Disposable test environments

Linked clones must not be used for permanent infrastructure or systems expected to survive template replacement.

After cloning:

1. Assign the final hostname.
2. Generate new machine identity where required.
3. Assign the VMnet1 management address.
4. Validate VMnet8 internet access.
5. Update DNS or host mappings.
6. Add the host to Ansible inventory.
7. Run the applicable Ansible baseline.
8. Record the system in inventory documentation.

## Snapshot Standard

Snapshots are temporary recovery points, not backups.

Snapshots may be created:

* Before a risky upgrade
* Before a major configuration change
* Before destructive training exercises

Snapshots must:

* Have a descriptive name.
* Include a creation date.
* Include the reason for creation.
* Be removed after validation.
* Not remain indefinitely.

Example:

```text
2026-07-13-before-rke2-install
```

Snapshot chains should be kept as short as possible.

## Backup Standard

A VMware snapshot does not replace a backup.

Important virtual machines must be backed up by copying or exporting them while powered off or by using a documented guest-aware backup process.

Templates must be reproducible from documented build procedures even when backup copies exist.

## Lifecycle Standard

Each virtual machine must have a defined lifecycle classification:

```text
Template
Infrastructure
Kubernetes
Sandbox
Archived
Retired
```

Retired virtual machines must be removed from the VMware library.

Their files must either be:

* Deleted after approval, or
* Moved to a documented archive location

Stale VMware library entries must not be retained.

## Automation Standard

Where supported, VMware operations should use:

```text
C:\Program Files\VMware\VMware Workstation\vmrun.exe
```

Automation scripts must use explicit executable paths unless the VMware installation directory is intentionally added to the system `PATH`.

VMware configuration, VM inventory, IP allocations, and operating procedures must be maintained in the MedusaLab repository.

Secrets, private keys, virtual disks, ISO images, and VMware runtime files must not be committed to Git.

## Validation Checklist

A new VM is ready for service when:

* The expected hostname is configured.
* The VM is stored in the correct directory.
* Adapter 1 is connected to VMnet1.
* Adapter 2 is connected to VMnet8.
* VMnet1 has the assigned static address.
* VMnet1 has no default gateway.
* VMnet8 receives a DHCP address.
* The VM can reach external repositories.
* MEDUSA can reach the VMnet1 address.
* Ubuntu WSL can reach the VMnet1 address.
* SSH public-key authentication succeeds.
* Ansible can gather facts.
* `open-vm-tools` is active.
* Time synchronization is healthy.
* The system is recorded in inventory documentation.

