# ADR-0006 — HashiCorp Vault Security Platform

## Status

Accepted

## Date

2026-07-20

## Context

MedusaLab requires a centralized system for securely storing, controlling, auditing, and distributing credentials and other sensitive configuration.

Secrets must not be stored in:

* Git repositories
* Plaintext Ansible variables
* Application configuration files
* Shell history
* Documentation
* Container images
* Kubernetes manifests

The platform must support the future OpenShift environment while also providing a standalone security service that can be managed and tested independently.

## Decision

MedusaLab will use HashiCorp Vault Community Edition as its centralized secrets-management platform.

The first Vault server is:

| Property          | Value                             |
| ----------------- | --------------------------------- |
| Hostname          | `vault01.medusalab.test`          |
| Address           | `192.168.141.12/24`               |
| Operating system  | Red Hat Enterprise Linux 10.2     |
| Vault version     | 2.0.3                             |
| API port          | TCP `8200`                        |
| Cluster port      | TCP `8201`                        |
| Storage backend   | Integrated Raft storage           |
| Seal type         | Shamir                            |
| Unseal shares     | 5                                 |
| Unseal threshold  | 3                                 |
| Authentication    | Userpass bootstrap administration |
| Audit destination | `/var/log/vault/audit.log`        |
| KV secrets mount  | `secret/` using KV version 2      |

## Network Exposure

Vault listens only on the VMnet1 management address:

```text
192.168.141.12:8200
192.168.141.12:8201
```

Vault does not listen on the VMnet8 interface.

Firewalld permits access to TCP ports `8200` and `8201` only from:

```text
192.168.141.0/24
```

## TLS

Vault API and cluster traffic use TLS.

The initial deployment uses a locally generated bootstrap certificate containing:

* `vault01.medusalab.test`
* `vault01`
* `192.168.141.12`
* `127.0.0.1`

The certificate is installed in the RHEL trust store for local CLI validation.

The TLS private key remains protected under:

```text
/opt/vault/tls
```

Regular user accounts are not granted direct access to the private key.

The bootstrap certificate will eventually be replaced with a certificate issued by the future MedusaLab internal PKI.

## Storage

Vault uses integrated Raft storage:

```text
/opt/vault/data
```

The initial Raft node ID is:

```text
vault01
```

The cluster name is:

```text
medusalab-vault
```

The current deployment contains one Raft node. This provides persistent transactional storage but does not yet provide server-level high availability.

## Memory Protection

Swap is disabled persistently on `vault01`.

Vault is configured with:

```hcl
disable_mlock = true
```

This design depends on the operating system having no active swap.

## Initialization and Unsealing

Vault was initialized with:

```text
Total shares: 5
Threshold:    3
```

Initialization output is stored only as an encrypted bundle outside the repository.

The bundle contains:

* Five Shamir unseal shares
* The original initial root token

The initial root token was used only for bootstrap configuration and was subsequently revoked.

The encrypted initialization bundle is retained because its unseal shares remain necessary after Vault restarts.

Unseal keys, tokens, and encryption passphrases must never be committed to Git or stored in project documentation.

## Administrative Authentication

Human administration uses the `userpass` authentication method.

The initial administrator identity is:

```text
minotaur423
```

The administrator receives:

```text
medusalab-admin
```

The administrator policy provides broad Vault management privileges for the lab environment.

This policy must never be assigned to applications or automated workloads.

## Audit Logging

Vault uses a file audit device:

```text
/var/log/vault/audit.log
```

The audit file is owned by:

```text
vault:vault
```

with permissions:

```text
0600
```

Audit logs are rotated through `logrotate`:

* Daily rotation
* Early rotation at 100 MB
* Thirty retained rotations
* Compression
* Delayed compression
* `SIGHUP` sent to Vault after rotation

The signal causes Vault to reopen the new audit file without restarting the service.

## Versioned Secrets

KV version 2 is enabled at:

```text
secret/
```

The engine is configured with:

| Property                   | Value    |
| -------------------------- | -------- |
| Maximum retained versions  | 10       |
| Check-and-set required     | No       |
| Automatic version deletion | Disabled |

The initial application namespace is:

```text
secret/apps/demo/
```

## Least-Privilege Policies

### `medusalab-secrets-operator`

Provides human operators with controlled lifecycle access to KV v2 secrets, including:

* Create
* Read
* Update
* Patch
* Delete
* List metadata
* Restore deleted versions
* Destroy selected versions

It does not grant general Vault system administration.

### `medusalab-demo-app`

Provides read-only access to:

```text
secret/data/apps/demo/*
```

It does not permit:

* Secret writes
* Secret deletion
* Secret-name listing
* Access to other applications
* Vault administration

## Automation

The deployment is managed through:

```text
ansible/roles/vault/
ansible/playbooks/vault-server.yml
ansible/playbooks/vault-operations.yml
ansible/playbooks/vault-kv.yml
ansible/inventory/group_vars/vault_servers.yml
```

The automation manages:

* HashiCorp RPM repository
* Vault package
* Vault configuration
* Raft storage directory
* TLS bootstrap certificate
* System trust
* Firewalld controls
* Audit directory and file
* Audit log rotation
* Administrative policy source
* KV v2 mount configuration
* Human secrets-operator policy
* Demo application policy

Sensitive authentication values are not managed in repository files.

Vault API automation uses the authenticated administrator token cached on `vault01`.

## Consequences

### Positive

* Secrets can be removed from source control and application configuration.
* Vault access is policy-controlled and audited.
* Versioned KV storage supports recovery from accidental changes.
* Application access can be restricted to specific paths.
* The platform is ready for future OpenShift authentication and secret injection.
* Deployment and operational configuration are reproducible through Ansible.

### Negative

* Vault must currently be manually unsealed after a service or system restart.
* The single Vault server is a service-level single point of failure.
* The bootstrap TLS certificate is self-signed.
* Administrative API automation currently depends on a cached human token.
* Unseal shares require careful external protection.

## Future Work

* Add additional Raft nodes.
* Replace the bootstrap certificate with an internal PKI-issued certificate.
* Implement an automated or external unseal mechanism.
* Configure Raft snapshots and protected backups.
* Add Vault availability and seal-state monitoring.
* Add AppRole authentication for non-Kubernetes automation.
* Enable Kubernetes authentication for OpenShift.
* Create OpenShift-specific application policies.
* Integrate the Vault Secrets Operator or CSI provider.
* Replace broad administrator access with more granular operational roles.

