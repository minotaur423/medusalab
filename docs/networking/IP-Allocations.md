# MedusaLab IP Allocations

## Purpose

This document records static IP-address assignments for MedusaLab infrastructure.

VMnet8 addresses are normally assigned dynamically by VMware DHCP and are not recorded unless a workload has a documented need for a fixed NAT address.

## VMware Networks

| Network | Subnet             | Purpose                                             |
| ------- | ------------------ | --------------------------------------------------- |
| VMnet1  | `192.168.141.0/24` | Private management and lab communication            |
| VMnet8  | `192.168.197.0/24` | NAT, DNS, package repositories, and external access |

## VMnet1 Addressing

| Property                | Value                             |
| ----------------------- | --------------------------------- |
| Subnet                  | `192.168.141.0/24`                |
| Windows host adapter    | `192.168.141.1`                   |
| Static allocation range | `192.168.141.10–192.168.141.99`   |
| VMware DHCP range       | `192.168.141.128–192.168.141.254` |
| Default gateway         | None                              |

VMnet1 interfaces must not install a default route.

## Static Assignments

| Address          | Hostname        | Role                               | Status          |
| ---------------- | --------------- | ---------------------------------- | --------------- |
| `192.168.141.1`  | MEDUSA          | VMware VMnet1 host adapter         | System assigned |
| `192.168.141.20` | `rhel10-test01` | RHEL golden-image validation clone | Active          |

## Allocation Policy

* Each static address must appear in this document before being assigned.
* Duplicate assignments are prohibited.
* Long-lived systems must use stable VMnet1 addresses.
* VMnet1 interfaces must not define a default gateway.
* VMnet8 normally provides DHCP, DNS, and the default route.
* Template systems use DHCP during construction and do not retain permanent addresses after sealing.
* Retired addresses must remain documented as retired until reuse is explicitly approved.

