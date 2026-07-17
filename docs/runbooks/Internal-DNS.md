# MedusaLab Internal DNS Runbook

## Purpose

This runbook documents the operation, validation, modification, and recovery of the MedusaLab internal DNS service.

## Service Summary

| Property               | Value                         |
| ---------------------- | ----------------------------- |
| Server                 | `dns01.medusalab.test`        |
| Operating system       | Red Hat Enterprise Linux 10.2 |
| Management address     | `192.168.141.10/24`           |
| DNS software           | BIND                          |
| Service                | `named`                       |
| Forward zone           | `medusalab.test`              |
| Reverse zone           | `141.168.192.in-addr.arpa`    |
| Trusted client network | `192.168.141.0/24`            |
| WSL SSH alias          | `dns01`                       |
| Windows SSH proxy      | `127.0.0.1:2220`              |

## Managed Repository Components

```text
ansible/playbooks/dns-server.yml
ansible/playbooks/dns-clients.yml
ansible/roles/bind_dns/
ansible/roles/dns_client/
ansible/inventory/group_vars/dns_servers.yml
ansible/inventory/host_vars/rhel10-test01.yml
ansible/inventory/host_vars/ubuntu-test01.yml
```

## Managed Server Files

```text
/etc/named.conf
/var/named/medusalab.test.zone
/var/named/141.168.192.in-addr.arpa.zone
```

Manual changes to these files will be overwritten by Ansible.

## Routine Service Validation

Connect:

```bash
ssh dns01
```

Check the service:

```bash
systemctl is-active named
systemctl is-enabled named
```

Validate the full configuration:

```bash
sudo named-checkconf -z
```

Check DNS listeners:

```bash
sudo ss -lntup | grep ':53'
```

Check the firewall:

```bash
sudo firewall-cmd \
  --zone=public \
  --query-service=dns
```

Expected firewall result:

```text
yes
```

## Authoritative Resolution Tests

Forward lookup:

```bash
dig @192.168.141.10 dns01.medusalab.test A +short
dig @192.168.141.10 rhel10-test01.medusalab.test A +short
dig @192.168.141.10 ubuntu-test01.medusalab.test A +short
```

Expected:

```text
192.168.141.10
192.168.141.20
192.168.141.21
```

Reverse lookup:

```bash
dig @192.168.141.10 -x 192.168.141.10 +short
dig @192.168.141.10 -x 192.168.141.20 +short
dig @192.168.141.10 -x 192.168.141.21 +short
```

Expected:

```text
dns01.medusalab.test.
rhel10-test01.medusalab.test.
ubuntu-test01.medusalab.test.
```

## Recursive Resolution Test

```bash
dig @192.168.141.10 www.redhat.com A +short
```

The command must return at least one external address.

## Linux Client Tests

### RHEL

```bash
ssh rhel10-test01
```

```bash
getent hosts dns01
getent hosts dns01.medusalab.test
getent hosts ubuntu-test01
getent hosts ubuntu-test01.medusalab.test
getent hosts www.redhat.com
```

### Ubuntu

```bash
ssh ubuntu-test01
```

```bash
resolvectl status ens33

getent hosts dns01
getent hosts dns01.medusalab.test
getent hosts rhel10-test01
getent hosts rhel10-test01.medusalab.test
getent hosts www.redhat.com
```

## Windows Tests

Run in Windows PowerShell:

```powershell
Resolve-DnsName dns01.medusalab.test -Type A
Resolve-DnsName rhel10-test01.medusalab.test -Type A
Resolve-DnsName ubuntu-test01.medusalab.test -Type A
```

Review the MedusaLab NRPT rule:

```powershell
Get-DnsClientNrptRule |
Where-Object DisplayName -eq "MedusaLab Internal DNS" |
Format-List DisplayName, Namespace, NameServers
```

Expected namespace and DNS server:

```text
.medusalab.test
192.168.141.10
```

## WSL Tests

```bash
getent hosts dns01.medusalab.test
getent hosts rhel10-test01.medusalab.test
getent hosts ubuntu-test01.medusalab.test
getent hosts www.redhat.com
```

WSL requires:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
```

## Adding or Changing a DNS Record

Edit:

```bash
vim ansible/inventory/group_vars/dns_servers.yml
```

Add or modify the required entries in:

```yaml
bind_dns_forward_records:
bind_dns_reverse_records:
```

Every static address should normally have both:

* An A record
* A matching PTR record

Increment:

```yaml
bind_dns_zone_serial:
```

Use:

```text
YYYYMMDDNN
```

Example:

```text
2026071701
2026071702
```

Validate the repository:

```bash
git diff --check

./scripts/run-ansible.sh \
  playbooks/dns-server.yml \
  --syntax-check
```

Apply the change:

```bash
./scripts/run-ansible.sh \
  playbooks/dns-server.yml \
  --ask-become-pass
```

Run the playbook again to verify idempotence.

## Reapplying Linux Client Configuration

```bash
./scripts/run-ansible.sh \
  playbooks/dns-clients.yml \
  --syntax-check
```

```bash
./scripts/run-ansible.sh \
  playbooks/dns-clients.yml \
  --ask-become-pass
```

Run it a second time and confirm:

```text
changed=0
unreachable=0
failed=0
```

## Troubleshooting

### The DNS service is not running

```bash
sudo systemctl status named --no-pager
sudo journalctl -u named -n 100 --no-pager
sudo named-checkconf -z
```

### An authoritative record does not resolve

```bash
sudo named-checkzone \
  medusalab.test \
  /var/named/medusalab.test.zone
```

```bash
sudo named-checkzone \
  141.168.192.in-addr.arpa \
  /var/named/141.168.192.in-addr.arpa.zone
```

Confirm that the zone serial was incremented and rerun the DNS server playbook.

### External names do not resolve

Test the configured forwarders directly:

```bash
dig @1.1.1.1 www.redhat.com A +short
dig @1.0.0.1 www.redhat.com A +short
```

Check BIND logs:

```bash
sudo journalctl -u named -n 100 --no-pager
```

### A Linux client cannot reach `dns01`

```bash
ping -c 3 192.168.141.10
dig @192.168.141.10 dns01.medusalab.test A +short
```

Confirm that VMnet1 has no default route and VMnet8 remains the default path.

### Windows cannot resolve the internal namespace

```powershell
Get-DnsClientNrptRule |
Where-Object DisplayName -eq "MedusaLab Internal DNS"

Clear-DnsClientCache

Resolve-DnsName dns01.medusalab.test -Type A
```

### WSL cannot resolve the internal namespace

Confirm that Windows resolution works first.

Then:

```powershell
wsl --shutdown
```

Reopen WSL and retry.

## Recovery

If the BIND configuration is damaged:

1. Do not edit the managed server files manually.
2. Validate the repository versions.
3. Confirm SSH and Ansible connectivity to `dns01`.
4. Reapply the DNS server playbook.
5. Validate the service and zones.
6. Reapply the DNS-client playbook if required.

```bash
./scripts/run-ansible.sh \
  playbooks/dns-server.yml \
  --ask-become-pass
```

```bash
./scripts/run-ansible.sh \
  playbooks/dns-clients.yml \
  --ask-become-pass
```

## Current Limitation

`dns01` is the only internal DNS server.

Until a secondary server is deployed, an outage of `dns01` will interrupt authoritative resolution for `medusalab.test`.

