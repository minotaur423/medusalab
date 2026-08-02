# ADR-0005 — Internal DNS High Availability

## Status

Accepted

## Date

2026-07-17

## Supersedes

This decision extends and partially supersedes ADR-0004, which established the original single-server MedusaLab internal DNS architecture.

## Context

MedusaLab initially deployed one internal DNS server:

```text
dns01.medusalab.test
192.168.141.10
```

The server provided:

* Authoritative resolution for `medusalab.test`
* Authoritative reverse resolution for `141.168.192.in-addr.arpa`
* Restricted recursive DNS for VMnet1 clients
* External forwarding and fallback recursion
* DNS services for RHEL, Ubuntu, Windows, and WSL clients

Although the original implementation was functional, `dns01` was a single point of failure. An outage of `dns01` interrupted internal authoritative resolution and could affect systems that relied exclusively on it.

MedusaLab requires internal DNS to remain available during planned maintenance, service restarts, and isolated server failures.

## Decision

MedusaLab will operate two authoritative BIND servers:

| Role          | Hostname               | Address          |
| ------------- | ---------------------- | ---------------- |
| Primary DNS   | `dns01.medusalab.test` | `192.168.141.10` |
| Secondary DNS | `dns02.medusalab.test` | `192.168.141.11` |

Both servers answer authoritatively for:

```text
medusalab.test
141.168.192.in-addr.arpa
```

The primary server owns the editable zone files.

The secondary server retrieves and maintains copies of the zones through authenticated BIND zone transfers.

## Server Roles

### `dns01`

`dns01` operates as the primary authoritative server.

Responsibilities include:

* Hosting the authoritative forward-zone source file
* Hosting the authoritative reverse-zone source file
* Maintaining the authoritative zone serial
* Sending zone-change notifications
* Permitting authenticated transfers to `dns02`
* Serving recursive queries from trusted MedusaLab clients
* Forwarding external queries to approved upstream resolvers

### `dns02`

`dns02` operates as the secondary authoritative server.

Responsibilities include:

* Receiving the forward zone from `dns01`
* Receiving the reverse zone from `dns01`
* Storing transferred zones under `/var/named/slaves`
* Serving authoritative responses when `dns01` is unavailable
* Serving recursive queries from trusted MedusaLab clients
* Forwarding external queries to approved upstream resolvers

The transferred secondary files are managed by BIND and must not be edited manually.

## Authoritative Records

Both zones publish two authoritative name servers:

```text
dns01.medusalab.test
dns02.medusalab.test
```

The initial DNS server records are:

| Record                 | Value            |
| ---------------------- | ---------------- |
| `dns01.medusalab.test` | `192.168.141.10` |
| `dns02.medusalab.test` | `192.168.141.11` |

Matching PTR records exist in the reverse zone.

## Zone Transfer Security

Zone transfers use a shared TSIG key.

The key:

* Uses HMAC-SHA256
* Is stored as an encrypted Ansible Vault variable
* Is available only to the managed DNS servers
* Is never written to documentation in plaintext
* Is never committed to Git in plaintext
* Is embedded in the generated BIND configuration with restricted file permissions

The encrypted variable is stored in:

```text
ansible/inventory/group_vars/dns_servers/vault.yml
```

The variable name is:

```text
bind_dns_transfer_secret
```

Only the primary permits transfers, and only requests authenticated with the configured TSIG key are accepted.

The secondary does not permit downstream zone transfers.

## Zone Transfer Flow

The transfer sequence is:

1. The managed zone data changes in Ansible variables.
2. The zone serial is incremented.
3. Ansible deploys and validates the new zone files on `dns01`.
4. BIND reloads the primary zones.
5. `dns01` notifies `dns02`.
6. `dns02` authenticates using the TSIG key.
7. `dns02` transfers the updated zones.
8. Both servers report the same SOA serial.
9. Queries are validated against both servers.

## Zone Serial Standard

The zone serial uses:

```text
YYYYMMDDNN
```

Example:

```text
2026071701
```

The serial must increase whenever:

* An A record changes
* A PTR record changes
* An NS record changes
* A zone parameter changes
* An authoritative record is added or removed

## Client Configuration

Linux clients receive both DNS servers in this order:

```text
192.168.141.10
192.168.141.11
```

The search domain remains:

```text
medusalab.test
```

RHEL clients receive the addresses through NetworkManager.

Ubuntu clients receive the addresses through Netplan and `systemd-resolved`.

VMnet8 DHCP-provided DNS is disabled on managed Linux clients so the internal resolver order is deterministic.

## Windows and WSL

Windows uses an NRPT rule for:

```text
.medusalab.test
```

The rule contains both name servers:

```text
192.168.141.10
192.168.141.11
```

Windows continues to use its normal DNS configuration for public namespaces.

WSL uses:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
```

Internal WSL queries follow the Windows DNS path and therefore use the dual-server NRPT configuration.

## Automation

The DNS server role supports explicit server modes:

```text
primary
secondary
```

The inventory hierarchy is:

```text
dns_servers
├── dns_primaries
│   └── dns01
└── dns_secondaries
    └── dns02
```

The primary play executes before the secondary play so that transfer authorization, zone records, and zone serials are available before the secondary requests data.

The implementation is managed through:

```text
ansible/roles/bind_dns/
ansible/playbooks/dns-server.yml
ansible/inventory/group_vars/dns_servers/
ansible/inventory/group_vars/dns_primaries.yml
ansible/inventory/group_vars/dns_secondaries.yml
```

Client redundancy is managed through:

```text
ansible/roles/dns_client/
ansible/playbooks/dns-clients.yml
```

## Validation

The implementation successfully validated:

* BIND installation and startup on `dns02`
* Primary and secondary role separation
* TSIG-authenticated zone transfers
* Forward-zone transfer
* Reverse-zone transfer
* Matching SOA serials
* Dual authoritative NS records
* Direct queries against `dns01`
* Direct queries against `dns02`
* RHEL dual-resolver configuration
* Ubuntu dual-resolver configuration
* Windows dual-server NRPT configuration
* WSL dual-server resolution
* External recursive resolution through both DNS servers
* Continued authoritative resolution while `named` was stopped on `dns01`
* Successful restoration of `dns01`
* Ansible idempotence

## Consequences

### Positive

* Internal DNS remains available during a single DNS-server outage.
* Planned maintenance can be performed without interrupting internal resolution.
* Authoritative data is automatically replicated.
* Zone transfers are authenticated.
* All supported client platforms use the same redundant resolver pair.
* The DNS architecture is suitable for future infrastructure and Kubernetes services.

### Negative

* Zone serial management remains a manual responsibility.
* Both DNS servers currently run on the same physical Windows host and VMware platform.
* A MEDUSA host or VMware platform outage will affect both DNS servers.
* The TSIG vault password must be protected and available for DNS automation.
* Windows NRPT configuration is not yet managed through Ansible.

## Future Work

* Place a future DNS server on a separate physical or virtualization host.
* Add automated DNS availability monitoring.
* Add alerts for failed zone transfers or serial mismatches.
* Automate Windows NRPT configuration.
* Add automated tests for authoritative and recursive responses.
* Evaluate internal DNSSEC signing.

