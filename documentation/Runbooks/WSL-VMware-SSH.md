# WSL-to-VMware SSH Runbook

## Purpose

This runbook documents how Ubuntu WSL connects to VMware guests on the private VMnet1 management network.

In the current MEDUSA networking configuration, WSL mirrored networking does not route VMnet1 traffic directly. Windows TCP port-proxy entries therefore forward loopback ports to SSH services on VMware guests.

The proxy is TCP-specific. ICMP ping from WSL to a VMware guest may still fail even when SSH and Ansible work correctly.

## Prerequisites

Before creating a proxy:

* The VMware guest must be running.
* The guest must have a static VMnet1 address.
* `sshd` must be active.
* The guest firewall must permit SSH.
* Windows must be able to connect directly to the guest on TCP port 22.
* The Windows IP Helper service must be running.
* The MedusaLab private key must be loaded into `ssh-agent`.

## Verify Windows-to-Guest Connectivity

Run from Windows PowerShell:

```powershell
Test-NetConnection `
  -ComputerName 192.168.141.20 `
  -Port 22
```

Expected:

```text
TcpTestSucceeded : True
```

Do not create the proxy until direct Windows connectivity succeeds.

## Configure the IP Helper Service

Run from an administrator PowerShell window:

```powershell
Set-Service iphlpsvc -StartupType Automatic
Start-Service iphlpsvc
```

## Create the rhel10-test01 Proxy

Remove any previous entry:

```powershell
netsh interface portproxy delete v4tov4 `
  listenaddress=127.0.0.1 `
  listenport=2211
```

It is harmless if the entry does not exist.

Create the proxy:

```powershell
netsh interface portproxy add v4tov4 `
  listenaddress=127.0.0.1 `
  listenport=2211 `
  connectaddress=192.168.141.20 `
  connectport=22
```

Verify:

```powershell
netsh interface portproxy show all

Test-NetConnection `
  -ComputerName 127.0.0.1 `
  -Port 2211
```

Expected:

```text
TcpTestSucceeded : True
```

## Ubuntu WSL SSH Configuration

The corresponding entry in `~/.ssh/config` is:

```sshconfig
Host rhel10-test01
    HostName 127.0.0.1
    Port 2211
    User minotaur423
    IdentityFile ~/.ssh/medusalab_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes
    HostKeyAlias rhel10-test01
```

The SSH configuration file must be protected:

```bash
chmod 600 ~/.ssh/config
```

## Verify ssh-agent

```bash
printf 'SSH_AUTH_SOCK=%s\n' "$SSH_AUTH_SOCK"
ssh-add -l
```

The MedusaLab ED25519 fingerprint should be listed.

## Verify SSH Access

```bash
nc -vz -w 5 127.0.0.1 2211

ssh rhel10-test01 \
  'hostnamectl --static && ip -4 -brief address'
```

Expected hostname:

```text
rhel10-test01
```

## Verify Ansible Access

From the MedusaLab repository:

```bash
cd ~/lab/medusalab

ANSIBLE_CONFIG="$PWD/ansible/ansible.cfg" \
ansible rhel_managed \
  -i ansible/inventory/hosts.yml \
  -m ansible.builtin.ping
```

Expected:

```text
rhel10-test01 | SUCCESS
```

## Troubleshooting

### Connection reset by peer

A connection reset on `127.0.0.1:<proxy-port>` usually means:

* The guest is powered off.
* The guest address changed.
* `sshd` is stopped.
* Windows cannot reach the guest.
* The proxy points to the wrong address.

Verify the guest state and then run:

```powershell
Test-NetConnection `
  -ComputerName 192.168.141.20 `
  -Port 22
```

### Connection timed out from WSL

Verify the proxy:

```powershell
netsh interface portproxy show all
```

Verify the IP Helper service:

```powershell
Get-Service iphlpsvc
```

Restart it when necessary:

```powershell
Restart-Service iphlpsvc
```

### SSH host-key warning

The SSH alias uses `HostKeyAlias` so each proxy-backed guest maintains an independent host-key identity.

Do not disable strict host-key checking globally.

If a VM was intentionally rebuilt, remove only its obsolete alias entry:

```bash
ssh-keygen -R rhel10-test01
```

Reconnect and verify the new fingerprint through the VMware console before accepting it.

## Security Requirements

* Never commit the MedusaLab private key.
* Never commit private-key passphrases.
* Never place passwords in the SSH configuration.
* Use a distinct loopback port and `HostKeyAlias` for each VMware guest.
* Remove obsolete port-proxy entries when systems are retired.
* Keep the sealed template powered off.

