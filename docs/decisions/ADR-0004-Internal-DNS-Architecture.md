# ADR-0004 — Internal DNS Architecture

## Status

Accepted

## Date

2026-07-17

## Context

MedusaLab requires stable name resolution for VMware infrastructure, automation targets, Kubernetes systems, platform services, and future enterprise integrations.

The VMware networks provide separate functions:

* VMnet1 provides private management and lab communication.
* VMnet8 provides NAT, external DNS, package-repository access, and internet connectivity.

VMnet1 does not provide a default gateway and should not depend on dynamically assigned hostnames. Static infrastructure addresses therefore require an authoritative internal DNS service.

The DNS design must support:

* Forward resolution for MedusaLab systems
* Reverse resolution for VMnet1 addresses
* Recursive resolution for external names
* Linux clients managed through Ansible
* Windows namespace-specific resolution
* WSL resolution through the Windows DNS path
* Restricted recursion
* SELinux and firewalld enforcement
* Repeatable configuration and validation

## Decision

MedusaLab will use BIND on a dedicated RHEL infrastructure server named:

```text
dns01.medusalab.test
```

The DNS server uses:

```text
Hostname:       dns01.medusalab.test
VMnet1 address: 192.168.141.10/24
VMnet8 address: VMware DHCP
Operating OS:   Red Hat Enterprise Linux 10.2
```

The internal forward namespace is:

```text
medusalab.test
```

The reverse zone is:

```text
141.168.192.in-addr.arpa
```

The `.test` namespace is reserved for testing and private-use environments and will not conflict with a publicly registered MedusaLab domain.

## Authoritative Zones

BIND is authoritative for:

```text
medusalab.test
141.168.192.in-addr.arpa
```

Initial records include:

| Hostname                       | Address          |
| ------------------------------ | ---------------- |
| `dns01.medusalab.test`         | `192.168.141.10` |
| `rhel10-test01.medusalab.test` | `192.168.141.20` |
| `ubuntu-test01.medusalab.test` | `192.168.141.21` |

Matching PTR records are maintained in the reverse zone.

## Recursive Resolution

BIND provides recursive resolution only to trusted local clients.

Permitted clients are:

```text
127.0.0.1
192.168.141.0/24
```

The configured upstream forwarders are:

```text
1.1.1.1
1.0.0.1
```

The forwarding mode is:

```text
forward first
```

BIND attempts the configured forwarders first and may perform normal recursive resolution if the forwarders do not answer.

## Security Controls

The DNS service must operate with:

* SELinux enabled and enforcing
* The standard RHEL `named` service
* DNS enabled in the active firewalld zone
* Queries restricted to trusted MedusaLab networks
* Recursion restricted to trusted MedusaLab networks
* Zone transfers disabled
* IPv6 listening disabled until an IPv6 design is approved
* Configuration and zone validation before deployment
* Ansible ownership of all managed files

Credentials, private keys, activation keys, and secret values must not be stored in DNS configuration or Git.

## Automation

The authoritative DNS service is managed through:

```text
ansible/roles/bind_dns/
ansible/playbooks/dns-server.yml
ansible/inventory/group_vars/dns_servers.yml
```

Linux DNS clients are managed through:

```text
ansible/roles/dns_client/
ansible/playbooks/dns-clients.yml
ansible/inventory/host_vars/
```

Zone serials use:

```text
YYYYMMDDNN
```

The serial must be incremented whenever authoritative zone records change.

## Client Integration

### RHEL

NetworkManager configures `dns01` on the VMnet1 management connection with a higher DNS priority than the VMnet8 connection.

The search domain is:

```text
medusalab.test
```

VMnet8 remains available for external network access and fallback DNS behavior.

### Ubuntu

Netplan configures:

* `dns01` as the DNS server on the VMnet1 management interface
* `medusalab.test` as the search domain
* VMnet8 as the only default route

### Windows

Windows uses a Name Resolution Policy Table rule for:

```text
.medusalab.test
```

Queries for that namespace are sent to:

```text
192.168.141.10
```

Normal Windows internet DNS settings are otherwise unchanged.

### WSL

WSL uses:

```text
networkingMode=mirrored
dnsTunneling=true
```

WSL internal DNS requests pass through the Windows DNS path and use the Windows NRPT rule for the MedusaLab namespace.

## Validation

The completed implementation validated:

* BIND configuration syntax
* Forward-zone syntax
* Reverse-zone syntax
* The `named` service
* UDP and TCP port 53 listeners
* Firewalld DNS access
* Forward A records
* Reverse PTR records
* External recursive resolution
* RHEL short-name resolution
* RHEL FQDN resolution
* Ubuntu short-name resolution
* Ubuntu FQDN resolution
* Windows NRPT resolution
* WSL DNS-tunneled resolution
* Continued external name resolution
* Ansible idempotence

## Consequences

### Positive

* Infrastructure systems receive stable names.
* Ansible inventories can transition from address-based management to names.
* Kubernetes and future platform services have an internal naming foundation.
* Windows uses split DNS without replacing normal internet DNS.
* Linux configuration is repeatable and version controlled.
* Forward and reverse records share one controlled source of truth.

### Negative

* `dns01` is currently a single DNS server and therefore a single point of failure.
* Zone serials must be maintained correctly.
* Windows NRPT and WSL DNS tunneling are host-level settings outside the Linux Ansible inventory.
* A second DNS server will be required before the environment can be considered highly available.

## Future Work

* Add a secondary authoritative DNS server.
* Automate Windows NRPT configuration.
* Add monitoring for DNS availability and response correctness.
* Integrate future infrastructure records into the managed zones.
* Evaluate DNSSEC signing for internal zones.
* Evaluate dynamic DNS only if a controlled automation requirement emerges.

