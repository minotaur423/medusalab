# MedusaLab DNS High-Availability Runbook

## Purpose

This runbook documents the operation, validation, failover testing, zone-transfer verification, and recovery of the MedusaLab primary and secondary DNS servers.

## Architecture

| Role      | Hostname               | VMnet1 address      | WSL proxy        |
| --------- | ---------------------- | ------------------- | ---------------- |
| Primary   | `dns01.medusalab.test` | `192.168.141.10/24` | `127.0.0.1:2220` |
| Secondary | `dns02.medusalab.test` | `192.168.141.11/24` | `127.0.0.1:2221` |

Both servers are authoritative for:

```text
medusalab.test
141.168.192.in-addr.arpa
```

Both servers also provide restricted recursive resolution to:

```text
127.0.0.1
192.168.141.0/24
```

## Inventory Hierarchy

```text
dns_servers
├── dns_primaries
│   └── dns01
└── dns_secondaries
    └── dns02
```

## Managed Repository Files

```text
ansible/playbooks/dns-server.yml
ansible/playbooks/dns-clients.yml
ansible/roles/bind_dns/
ansible/roles/dns_client/
ansible/inventory/group_vars/dns_servers/main.yml
ansible/inventory/group_vars/dns_servers/vault.yml
ansible/inventory/group_vars/dns_primaries.yml
ansible/inventory/group_vars/dns_secondaries.yml
```

## TSIG Secret

Zone transfers use the encrypted variable:

```text
bind_dns_transfer_secret
```

It is stored in:

```text
ansible/inventory/group_vars/dns_servers/vault.yml
```

The file may be committed only while the value remains encrypted with Ansible Vault.

Never:

* Display the decrypted value in terminal output
* Store the plaintext value in documentation
* Place the plaintext value in an unencrypted YAML file
* Commit a Vault password
* Add the secret to shell history

## Routine Health Check

From Ubuntu WSL:

```bash
ssh dns01 'systemctl is-active named'
ssh dns02 'systemctl is-active named'
```

Expected:

```text
active
active
```

Check the authoritative SOA serials:

```bash
dig @192.168.141.10 medusalab.test SOA +short
dig @192.168.141.11 medusalab.test SOA +short

dig @192.168.141.10 141.168.192.in-addr.arpa SOA +short
dig @192.168.141.11 141.168.192.in-addr.arpa SOA +short
```

The primary and secondary responses must report the same serial.

## Validate Authoritative Name Servers

```bash
dig @192.168.141.10 medusalab.test NS +short
dig @192.168.141.11 medusalab.test NS +short
```

Both servers must return:

```text
dns01.medusalab.test.
dns02.medusalab.test.
```

## Validate Server Records

```bash
dig @192.168.141.10 dns01.medusalab.test A +short
dig @192.168.141.10 dns02.medusalab.test A +short

dig @192.168.141.11 dns01.medusalab.test A +short
dig @192.168.141.11 dns02.medusalab.test A +short
```

Expected:

```text
192.168.141.10
192.168.141.11
```

Validate reverse records:

```bash
dig @192.168.141.10 -x 192.168.141.10 +short
dig @192.168.141.10 -x 192.168.141.11 +short

dig @192.168.141.11 -x 192.168.141.10 +short
dig @192.168.141.11 -x 192.168.141.11 +short
```

Expected:

```text
dns01.medusalab.test.
dns02.medusalab.test.
```

## Validate Secondary Zone Files

Connect:

```bash
ssh dns02
```

Check transferred files:

```bash
sudo ls -lh /var/named/slaves
```

Expected files include:

```text
medusalab.test.zone
141.168.192.in-addr.arpa.zone
```

The files are managed by BIND and may use BIND’s raw secondary-zone format.

Do not edit them.

Review recent transfer events:

```bash
sudo journalctl \
  -u named \
  --since "1 hour ago" \
  --no-pager |
grep -Ei 'transfer|transferred|loaded serial|notify'
```

## Deploy DNS Changes

Edit:

```bash
vim ansible/inventory/group_vars/dns_servers/main.yml
```

Modify the appropriate record lists:

```yaml
bind_dns_forward_records:
bind_dns_reverse_records:
```

Increment:

```yaml
bind_dns_zone_serial:
```

Validate:

```bash
git diff --check

./scripts/run-ansible.sh \
  playbooks/dns-server.yml \
  --syntax-check \
  --ask-vault-pass
```

Apply:

```bash
./scripts/run-ansible.sh \
  playbooks/dns-server.yml \
  --ask-vault-pass \
  --ask-become-pass
```

The playbook configures the primary first and the secondary second.

Run it again and confirm:

```text
changed=0
unreachable=0
failed=0
```

## Verify a Zone Transfer

After deploying a serial increase:

```bash
dig @192.168.141.10 medusalab.test SOA +short
dig @192.168.141.11 medusalab.test SOA +short
```

If the serials do not match, inspect `dns02`:

```bash
ssh dns02
```

```bash
sudo journalctl -u named -n 100 --no-pager
sudo rndc zonestatus medusalab.test
sudo rndc zonestatus 141.168.192.in-addr.arpa
```

Check connectivity to the primary:

```bash
ping -c 3 192.168.141.10

dig @192.168.141.10 medusalab.test SOA +short
```

## Linux Resolver Validation

### RHEL

```bash
ssh rhel10-test01
```

```bash
cat /etc/resolv.conf

nmcli -g ipv4.dns \
  connection show vmnet1-mgmt
```

Expected order:

```text
192.168.141.10
192.168.141.11
```

### Ubuntu

```bash
ssh ubuntu-test01
```

```bash
resolvectl status ens33
```

Expected:

```text
DNS Servers: 192.168.141.10 192.168.141.11
DNS Domain: medusalab.test
```

## Windows Resolver Validation

Run in Administrator PowerShell:

```powershell
Get-DnsClientNrptRule |
Where-Object DisplayName -eq "MedusaLab Internal DNS" |
Format-List DisplayName, Namespace, NameServers
```

Expected:

```text
Namespace   : {.medusalab.test}
NameServers : {192.168.141.10, 192.168.141.11}
```

## WSL Resolver Validation

WSL requires:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
```

Validate:

```bash
getent hosts dns01.medusalab.test
getent hosts dns02.medusalab.test
getent hosts rhel10-test01.medusalab.test
getent hosts ubuntu-test01.medusalab.test
getent hosts www.redhat.com
```

## Controlled Primary Failover Test

Confirm both servers are active:

```bash
ssh dns01 'systemctl is-active named'
ssh dns02 'systemctl is-active named'
```

Stop the primary:

```bash
ssh dns01
```

```bash
sudo systemctl stop named
systemctl is-active named
exit
```

Expected primary state:

```text
inactive
```

Clear client caches where appropriate and test:

```bash
getent hosts dns01.medusalab.test
getent hosts dns02.medusalab.test
getent hosts rhel10-test01.medusalab.test
getent hosts ubuntu-test01.medusalab.test
getent hosts www.redhat.com
```

Windows validation:

```powershell
Clear-DnsClientCache

Resolve-DnsName dns01.medusalab.test -Type A
Resolve-DnsName dns02.medusalab.test -Type A
Resolve-DnsName ubuntu-test01.medusalab.test -Type A
```

Confirm `dns02` directly:

```powershell
Resolve-DnsName `
  dns01.medusalab.test `
  -Server 192.168.141.11 `
  -Type A
```

Restore the primary immediately after testing:

```bash
ssh dns01
```

```bash
sudo systemctl start named
systemctl is-active named
exit
```

Confirm both servers:

```bash
ssh dns01 'systemctl is-active named'
ssh dns02 'systemctl is-active named'
```

## Failure Recovery

### `dns01` is unavailable

* Confirm `dns02` remains active.
* Verify clients continue resolving.
* Do not promote `dns02` manually unless an extended primary outage requires a formally documented recovery procedure.
* Restore `dns01`.
* Verify matching SOA serials.

### `dns02` is unavailable

* Confirm `dns01` remains active.
* Restore connectivity or the `named` service on `dns02`.
* Reapply the DNS server playbook.
* Verify transferred-zone serials.

### Zone transfer fails

On `dns01`:

```bash
sudo named-checkconf -z
sudo journalctl -u named -n 100 --no-pager
```

On `dns02`:

```bash
sudo journalctl -u named -n 100 --no-pager
```

Confirm:

* Both systems received the same encrypted TSIG variable
* The primary permits TSIG-authenticated transfers
* Port 53 is permitted through firewalld
* `dns02` can reach `192.168.141.10`
* The primary zone serial increased
* Both clocks are synchronized

## Availability Limitation

The DNS service is redundant at the virtual-machine level but both servers currently reside on:

```text
MEDUSA
VMware Workstation
```

A physical MEDUSA outage or VMware platform outage will affect both servers.

