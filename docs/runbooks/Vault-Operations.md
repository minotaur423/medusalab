# MedusaLab Vault Operations Runbook

## Purpose

This runbook documents routine operation, authentication, unsealing, auditing, policy management, KV v2 operation, and recovery procedures for the MedusaLab Vault service.

## Service Identity

| Property         | Value                                 |
| ---------------- | ------------------------------------- |
| Hostname         | `vault01.medusalab.test`              |
| Address          | `192.168.141.12`                      |
| API endpoint     | `https://vault01.medusalab.test:8200` |
| Cluster endpoint | `https://vault01.medusalab.test:8201` |
| Storage          | Integrated Raft                       |
| Raft path        | `/opt/vault/data`                     |
| Configuration    | `/etc/vault.d/vault.hcl`              |
| TLS directory    | `/opt/vault/tls`                      |
| Audit log        | `/var/log/vault/audit.log`            |
| Policies         | `/etc/vault.d/policies`               |

## Security Rules

Never place any of the following in Git, documentation, shell history, tickets, or chat:

* Unseal keys
* Vault tokens
* Userpass passwords
* Initialization JSON
* Decrypted initialization bundles
* TLS private keys
* Application secret values

The encrypted initialization bundle must remain outside the repository.

## Connect to Vault

```bash
ssh vault01
```

Set the CLI environment:

```bash
export VAULT_ADDR="https://vault01.medusalab.test:8200"
export VAULT_CACERT="/etc/pki/ca-trust/source/anchors/medusalab-vault-bootstrap.pem"
```

## Check Service Health

```bash
systemctl is-enabled vault
systemctl is-active vault

sudo ss -lntp | grep -E ':8200|:8201'

vault status
```

Expected operational state:

```text
Initialized    true
Sealed         false
Storage Type   raft
HA Mode        active
```

## Authenticate as Administrator

```bash
vault login \
  -method=userpass \
  -no-print \
  username=minotaur423
```

Enter the Vault password at the hidden prompt.

Verify the token:

```bash
vault token lookup |
grep -E 'display_name|policies|ttl|renewable'
```

The policies should include:

```text
medusalab-admin
```

## Unseal Vault

Vault requires three distinct unseal shares.

Check status:

```bash
vault status
```

When sealed, submit each share using the hidden prompt:

```bash
vault operator unseal
vault operator unseal
vault operator unseal
```

Do not place a key directly after the command.

After the third share:

```bash
vault status
```

Expected:

```text
Sealed    false
```

## Restart Vault

Restarting Vault causes it to return in a sealed state:

```bash
sudo systemctl restart vault
```

Confirm:

```bash
systemctl is-active vault
vault status
```

Complete the three-share unseal procedure before normal use.

## Audit Device

List configured audit devices:

```bash
vault audit list -detailed
```

Expected device:

```text
file/
```

Expected destination:

```text
/var/log/vault/audit.log
```

Inspect file state:

```bash
sudo ls -lh /var/log/vault
sudo wc -l /var/log/vault/audit.log
```

Do not manually modify the audit log.

## Test Audit Logging

Use an authenticated request:

```bash
vault token lookup >/dev/null
```

Then:

```bash
sudo wc -l /var/log/vault/audit.log
```

The unauthenticated seal-status endpoint may not create an audit entry, so `vault status` alone is not a sufficient audit test.

## Audit Log Rotation

Review the configuration:

```bash
sudo cat /etc/logrotate.d/vault-audit
```

Dry run:

```bash
sudo logrotate \
  --debug \
  /etc/logrotate.d/vault-audit
```

Force a controlled rotation:

```bash
sudo logrotate \
  --force \
  /etc/logrotate.d/vault-audit
```

Generate an authenticated request:

```bash
vault token lookup >/dev/null
```

Verify:

```bash
sudo ls -lh /var/log/vault
sudo wc -l /var/log/vault/audit.log
systemctl is-active vault
```

If Vault does not reopen the active audit file:

```bash
sudo systemctl kill \
  --signal=HUP \
  --kill-who=main \
  vault.service
```

Repeat the authenticated request and recheck the log.

## List Policies

```bash
vault policy list
```

Expected MedusaLab policies include:

```text
medusalab-admin
medusalab-secrets-operator
medusalab-demo-app
```

Read a policy:

```bash
vault policy read medusalab-secrets-operator
```

Repository policy definitions are stored under:

```text
ansible/roles/vault/files/
```

Do not edit the deployed copies directly.

## KV Version 2

List the secrets engines:

```bash
vault secrets list -detailed
```

The output should include:

```text
secret/    kv
```

Read the KV configuration:

```bash
vault read secret/config
```

Expected settings include:

```text
max_versions            10
cas_required            false
delete_version_after    0s
```

## Create a Secret Safely

Avoid placing secret values directly on the command line.

Example:

```bash
read -rsp "Secret value: " SECRET_VALUE
echo

printf '%s' "$SECRET_VALUE" |
vault kv put \
  -mount=secret \
  apps/example/config \
  value=-

unset SECRET_VALUE
```

## Read a Secret Field

```bash
vault kv get \
  -mount=secret \
  -field=value \
  apps/example/config
```

Only display secret values when operationally necessary.

## View Secret Metadata

```bash
vault kv metadata get \
  -mount=secret \
  apps/example/config
```

## Read a Specific Version

```bash
vault kv get \
  -mount=secret \
  -version=1 \
  apps/example/config
```

## Soft-Delete a Version

```bash
vault kv delete \
  -mount=secret \
  -versions=1 \
  apps/example/config
```

## Restore a Deleted Version

```bash
vault kv undelete \
  -mount=secret \
  -versions=1 \
  apps/example/config
```

## Permanently Destroy a Version

Permanent destruction cannot be reversed:

```bash
vault kv destroy \
  -mount=secret \
  -versions=1 \
  apps/example/config
```

Use destruction only after confirming the version is no longer required.

## Apply Vault Automation

### Server Configuration

```bash
cd ~/lab/medusalab

./scripts/run-ansible.sh \
  playbooks/vault-server.yml \
  --ask-become-pass
```

### Audit and Administrative Policy

```bash
./scripts/run-ansible.sh \
  playbooks/vault-operations.yml \
  --ask-become-pass
```

### KV and Least-Privilege Policies

```bash
./scripts/run-ansible.sh \
  playbooks/vault-kv.yml \
  --ask-become-pass
```

Run each playbook a second time and verify:

```text
changed=0
unreachable=0
failed=0
```

## Service Logs

```bash
sudo journalctl \
  -u vault \
  -n 100 \
  --no-pager
```

Follow live logs:

```bash
sudo journalctl \
  -u vault \
  -f
```

Service logs and audit logs serve different purposes:

* `journalctl -u vault` records service and operational events.
* `/var/log/vault/audit.log` records Vault API activity.

## Raft Status

```bash
vault operator raft list-peers
```

The initial deployment should show:

```text
vault01
```

Inspect autopilot state:

```bash
vault operator raft autopilot state
```

## Raft Snapshots

A protected backup procedure must be completed before relying on Vault for production-like secrets.

Create a snapshot only in an encrypted, non-repository location:

```bash
umask 077

vault operator raft snapshot save \
  "$HOME/.vault-secrets/vault01-raft.snap"
```

Never place snapshots in the Git repository.

Verify the snapshot:

```bash
vault operator raft snapshot inspect \
  "$HOME/.vault-secrets/vault01-raft.snap"
```

## Recovery Notes

### Vault service is inactive

```bash
sudo systemctl status vault
sudo journalctl -u vault -n 100 --no-pager
sudo vault server -config=/etc/vault.d/vault.hcl -verify-only
```

### Vault is sealed

Submit three valid unseal shares.

### TLS verification fails

```bash
ls -l \
  /etc/pki/ca-trust/source/anchors/medusalab-vault-bootstrap.pem

sudo update-ca-trust
```

Confirm:

```bash
openssl s_client \
  -connect vault01.medusalab.test:8200 \
  -servername vault01.medusalab.test \
  -CAfile /etc/pki/ca-trust/source/anchors/medusalab-vault-bootstrap.pem \
  -verify_return_error \
  </dev/null
```

### Cached token expired

Authenticate again with userpass:

```bash
vault login \
  -method=userpass \
  -no-print \
  username=minotaur423
```

### Audit destination is unavailable

Restore ownership and permissions:

```bash
sudo chown vault:vault /var/log/vault/audit.log
sudo chmod 0600 /var/log/vault/audit.log
sudo restorecon -RF /var/log/vault

sudo systemctl kill \
  --signal=HUP \
  --kill-who=main \
  vault.service
```

## Current Limitations

* One Vault server
* Manual Shamir unseal
* Bootstrap self-signed TLS
* No automated snapshot schedule
* No external monitoring
* No OpenShift authentication integration

