# MedusaLab IP Allocations

## Purpose

This document records MedusaLab VMware network definitions, static management addresses, temporary validation allocations, and Windows TCP proxy ports used for SSH access from Ubuntu WSL.

VMnet8 guest addresses are assigned dynamically by VMware DHCP and are not recorded individually unless a workload requires a fixed address.

Templates use temporary DHCP addresses while being built. Those temporary addresses are not permanent allocations and are not included in the static assignment register.

## VMware Network Summary

| Network | Subnet             | Windows host adapter | Purpose                                                      |
| ------- | ------------------ | -------------------- | ------------------------------------------------------------ |
| VMnet1  | `192.168.141.0/24` | `192.168.141.1`      | Private management and internal lab communication            |
| VMnet8  | `192.168.197.0/24` | `192.168.197.1`      | NAT, external DNS, package repositories, and internet access |

## VMnet1 Management Network

| Property                | Value                             |
| ----------------------- | --------------------------------- |
| Network                 | `192.168.141.0/24`                |
| Netmask                 | `255.255.255.0`                   |
| Windows VMware adapter  | `192.168.141.1`                   |
| Static allocation range | `192.168.141.10–192.168.141.99`   |
| VMware DHCP range       | `192.168.141.128–192.168.141.254` |
| Broadcast address       | `192.168.141.255`                 |
| Default gateway         | None                              |
| Default-route policy    | Prohibited                        |
| External DNS policy     | Not provided by VMnet1            |

VMnet1 is a host-only management network.

Operational virtual machines receive static addresses from the documented static allocation range. Template systems may temporarily receive VMware DHCP addresses while they are being constructed.

VMnet1 interfaces must not:

* Install a default route
* Replace DNS information received through VMnet8
* Use an address from the VMware DHCP range as a permanent assignment

## VMnet8 External Network

| Property               | Value                             |
| ---------------------- | --------------------------------- |
| Network                | `192.168.197.0/24`                |
| Netmask                | `255.255.255.0`                   |
| Windows VMware adapter | `192.168.197.1`                   |
| VMware NAT gateway     | `192.168.197.2`                   |
| VMware DNS service     | `192.168.197.2`                   |
| VMware DHCP range      | `192.168.197.128–192.168.197.254` |
| Broadcast address      | `192.168.197.255`                 |
| Guest configuration    | DHCP                              |
| Default-route policy   | VMnet8 is the only default route  |

VMnet8 provides:

* Outbound internet access
* Package-repository access
* External DNS resolution
* The default route for VMware guests

VMnet8 addresses are normally dynamic and are therefore not included in the static management allocation table.

## Static Management Assignments

| Address          | Hostname        | Platform       | Purpose                               | Lifecycle status  |
| ---------------- | --------------- | -------------- | ------------------------------------- | ----------------- |
| `192.168.141.1`  | `MEDUSA`        | Windows 11     | VMware VMnet1 host adapter            | System assigned   |
| `192.168.141.10` | `dns01`         | RHEL 10        | Permanent internal DNS infrastructure | Active            |
| `192.168.141.20` | `rhel10-test01` | RHEL 10.2      | RHEL golden-image validation          | Active validation |
| `192.168.141.21` | `ubuntu-test01` | Ubuntu 24.04.4 | Ubuntu golden-image validation        | Active validation |

## Reserved Infrastructure Assignments

### `dns01`

| Property                  | Value                         |
| ------------------------- | ----------------------------- |
| Hostname                  | `dns01`                       |
| Address                   | `192.168.141.10/24`           |
| Operating system          | Red Hat Enterprise Linux 10.2 |
| Source template           | `tmpl-rhel-10`                |
| Planned role              | MedusaLab internal DNS        |
| VMware management network | VMnet1                        |
| External network          | VMnet8 using DHCP             |
| WSL SSH proxy             | `127.0.0.1:2220`              |
| Status                    | Active                        |

The address and proxy port must not be assigned to another system while `dns01` remains planned.

## Validation-System Assignments

### `rhel10-test01`

| Property             | Value                                                  |
| -------------------- | ------------------------------------------------------ |
| Management address   | `192.168.141.20/24`                                    |
| Management interface | `ens160`                                               |
| External interface   | `ens192`                                               |
| Default route        | VMnet8 through `192.168.197.2`                         |
| WSL SSH proxy        | `127.0.0.1:2211`                                       |
| Status               | Golden-image validation complete; retained temporarily |

### `ubuntu-test01`

| Property             | Value                                                  |
| -------------------- | ------------------------------------------------------ |
| Management address   | `192.168.141.21/24`                                    |
| Management interface | `ens33`                                                |
| External interface   | `ens34`                                                |
| Default route        | VMnet8 through `192.168.197.2`                         |
| WSL SSH proxy        | `127.0.0.1:2213`                                       |
| Status               | Golden-image validation complete; retained temporarily |

Validation-system addresses remain allocated until the corresponding systems are formally retired, archived, repurposed, or deleted.

## WSL-to-VMware SSH Proxy Register

Ubuntu WSL does not directly route to the VMware VMnet1 host-only network in the current mirrored-networking configuration.

Windows TCP port proxies provide access from WSL to VMnet1 SSH services.

| Windows listen address | Listen port | Destination         | SSH alias       | Status                                 |
| ---------------------- | ----------: | ------------------- | --------------- | -------------------------------------- |
| `127.0.0.1`            |      `2211` | `192.168.141.20:22` | `rhel10-test01` | Active while validation VM is retained |
| `127.0.0.1`            |      `2213` | `192.168.141.21:22` | `ubuntu-test01` | Active while validation VM is retained |
| `127.0.0.1`            |      `2220` | `192.168.141.10:22` | `dns01`         | Active                                 |

The proxy register must be updated whenever:

* A static management address changes
* A VM is retired
* A proxy port is removed
* A hostname or SSH alias changes
* A permanent infrastructure VM is deployed

## Template Addressing Policy

Golden images do not receive permanent static allocations.

During template construction:

* VMnet1 may use VMware DHCP
* VMnet8 uses VMware DHCP
* VMnet8 provides the only default route
* Temporary WSL proxy ports may be used
* Temporary addresses and proxy ports must be removed after the template is sealed

The following templates therefore do not appear in the static assignment table:

* `tmpl-rhel-10`
* `tmpl-ubuntu-2404`

## Allocation Policy

1. Every static address must be recorded before it is assigned.
2. Duplicate static assignments are prohibited.
3. Permanent and validation systems must use addresses from `192.168.141.10–192.168.141.99`.
4. Addresses in `192.168.141.128–192.168.141.254` are reserved for VMware DHCP.
5. VMnet1 interfaces must not define a default gateway.
6. VMnet8 normally provides DHCP, DNS, and the default route.
7. Template DHCP addresses must not be treated as permanent allocations.
8. WSL proxy ports must be unique.
9. Retired addresses and proxy ports must remain documented until reuse is explicitly approved.
10. Changes must be reflected in both this document and `docs/inventory/Virtual-Machines.md`.

## Lifecycle Status Definitions

| Status            | Meaning                                                |
| ----------------- | ------------------------------------------------------ |
| System assigned   | Address is owned by VMware or the Windows host         |
| Reserved          | Approved for a planned system but not yet active       |
| Active            | Assigned to an operational permanent system            |
| Active validation | Assigned to a temporary golden-image validation system |
| Retired           | No longer active but not yet approved for reuse        |
| Available         | Explicitly approved for a new allocation               |

## Current Allocation Summary

| Category                                    | Allocations |
| ------------------------------------------- | ----------: |
| System-assigned VMnet1 addresses            |           1 |
| Reserved permanent infrastructure addresses |           1 |
| Active validation addresses                 |           2 |
| Active or reserved WSL proxy ports          |           3 |

## Internal DNS Namespace

| Property	            | Value                                |
| --------------------- | ------------------------------------ |
| DNS server	        | `dns01.medusalab.test`               |
| DNS address	        | `192.168.141.10`                     |
| Forward zone	        | `medusalab.test`                     |
| Reverse zone	        | `141.168.192.in-addr.arpa`           |
| Trusted network	    | `192.168.141.0/24`                   |
| External forwarding	| `1.1.1.1`, `1.0.0.1`                 |
| Forwarding policy	    | Forward first                        |
| Windows integration   | NRPT rule for `.medusalab.test`      |
| WSL integration	    | Windows DNS path with DNS tunneling  |

The VMnet8 address 192.168.197.2 is the VMware NAT gateway. It must not be documented as a guaranteed recursive DNS resolver.

