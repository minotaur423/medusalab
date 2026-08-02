# ADR-0003: VMware Networking and Storage Strategy

* **Status:** Accepted
* **Date:** 2026-07-13
* **Decision owners:** MedusaLab
* **Scope:** VMware Workstation infrastructure on MEDUSA

## Context

MedusaLab requires a repeatable VMware Workstation architecture for Linux servers, Kubernetes clusters, infrastructure services, and temporary sandbox systems.

VMware Workstation 26.0.0 is installed on the MEDUSA Windows host. The VMware installation currently provides:

* VMnet1 host-only networking
* VMnet8 NAT networking
* VMware DHCP
* VMware NAT
* VMware command-line management through `vmrun.exe`

The previous VMware library contained stale registrations for virtual machines that no longer existed on disk. Those entries were removed before establishing the new MedusaLab infrastructure standard.

A predictable network and storage design is required before creating golden images or deploying new virtual machines.

## Decision

### Management network

VMnet1 will be the standard MedusaLab private management network.

```text
Network:       192.168.141.0/24
Windows host:  192.168.141.1
Static range:  192.168.141.10–192.168.141.99
DHCP range:    192.168.141.128–192.168.141.254
Gateway:       None
```

VMnet1 will be used for:

* SSH administration
* Ansible management
* Internal DNS
* Cluster node communication
* Infrastructure service access
* Stable server addresses

VMnet1 interfaces will not define a default gateway.

### NAT network

VMnet8 will provide outbound access for MedusaLab virtual machines.

```text
Network:       192.168.197.0/24
Windows host:  192.168.197.1
NAT gateway:   192.168.197.2
DNS proxy:     192.168.197.2
DHCP range:    192.168.197.128–192.168.197.254
```

VMnet8 will be used for:

* Operating-system updates
* Package repositories
* Git services
* Container registries
* Red Hat subscription services
* Other outbound internet access

VMnet8 interfaces will normally use DHCP.

### Standard virtual-machine network layout

MedusaLab server virtual machines will normally use two network adapters:

```text
Network adapter 1:
  Network: VMnet1
  Addressing: Static
  Default gateway: None

Network adapter 2:
  Network: VMnet8
  Addressing: DHCP
  Default route: Provided by VMware NAT
```

This design provides stable management addresses while preserving outbound network access.

Single-interface virtual machines are permitted only when the workload does not require persistent management addressing.

### Bridged networking

VMnet0 bridged networking will not be used by default.

Bridged networking may expose lab systems directly to the physical network and make their behavior dependent on the current physical network, DHCP server, and firewall policy.

A workload must have a documented requirement before bridged networking is enabled.

### Additional VMware networks

VMnet2 through VMnet19 remain unassigned.

Additional VMnets may be created for:

* Dedicated Kubernetes cluster traffic
* Storage networks
* Load-balancer networks
* Security testing
* Isolated application tiers
* Routing and firewall exercises

Each additional network requires a documented purpose, subnet, DHCP policy, and routing policy.

### Virtual-machine storage

VMware virtual-machine files will be stored under:

```text
D:\MedusaLab\Lab\VirtualMachines\VMware
```

Workload categories will use the following directories:

```text
D:\MedusaLab\Lab\VirtualMachines\VMware\Infrastructure
D:\MedusaLab\Lab\VirtualMachines\VMware\Kubernetes
D:\MedusaLab\Lab\VirtualMachines\VMware\Sandbox
```

Golden images and reusable templates will be stored separately under:

```text
D:\MedusaLab\Lab\Templates\VMware
```

Installation media will remain under:

```text
D:\MedusaLab\Lab\ISOs
```

Virtual machines will not be stored inside the Git repository.

### Legacy VMware inventory

VMware library entries whose `.vmx` files no longer exist will be removed from the VMware Workstation library.

The VMware inventory file will not be edited manually during normal operations.

## Consequences

### Positive consequences

* Virtual machines receive predictable management addresses.
* Ansible can use stable VMnet1 addresses.
* Internet access remains isolated behind VMware NAT.
* Lab systems are not exposed directly to the physical network.
* Golden images are separated from active virtual machines.
* Storage paths are consistent and suitable for automation.
* New isolated networks can be added without redesigning the baseline.

### Negative consequences

* Most server virtual machines require two network adapters.
* Operating-system templates must configure multiple interfaces correctly.
* Administrators must understand which interface owns the default route.
* Services that must be accessed from the physical network may require port forwarding or an explicit bridged-network exception.

## Alternatives considered

### NAT-only networking

NAT-only networking was rejected because DHCP addresses are not sufficiently predictable for long-lived Ansible-managed infrastructure.

### Host-only networking

Host-only networking was rejected as the sole network because virtual machines would not have normal access to package repositories, registries, and external services.

### Bridged networking

Bridged networking was rejected as the default because it exposes lab systems to the physical network and makes the environment dependent on external DHCP and network policies.

### Store templates with active virtual machines

This was rejected because templates and active workloads have different lifecycle, snapshot, and change-management requirements.

## Validation

The decision is validated when:

* VMnet1 remains available at `192.168.141.1/24`.
* VMnet8 remains available at `192.168.197.1/24`.
* VMnet8 provides NAT through `192.168.197.2`.
* A test VM can obtain outbound access through VMnet8.
* The test VM can use a static VMnet1 management address.
* MEDUSA and Ubuntu WSL can reach the VMnet1 management address.
* Ansible can manage the VM through VMnet1.

