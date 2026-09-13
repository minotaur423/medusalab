# Engineering Workstation

## Overview

This document defines the standard software configuration for the primary
MedusaLab engineering workstation.

The MedusaLab workstation is designed for OpenShift administration,
Platform Engineering, infrastructure automation, source control, and Red Hat
certification lab work.

The primary workstation platform is Red Hat Enterprise Linux.

---

# Primary Workstation

| Component | Value |
| --- | --- |
| Hostname | `ex180-client.medusalab.test` |
| Operating System | Red Hat Enterprise Linux 10.2 |
| Architecture | x86_64 |
| Role | OpenShift and Platform Engineering administrative workstation |

The authoritative MedusaLab repository is located at:

    ~/projects/medusalab

GitHub is the authoritative remote source of truth.

---

# Networking

The workstation is connected to both MedusaLab VMware networks.

| Interface Role | Network |
| --- | --- |
| Management | `192.168.141.0/24` |
| Lab / NAT | `192.168.197.0/24` |

The workstation uses the MedusaLab DNS infrastructure and can resolve both
internal lab names and external Internet names.

---

# Source Control

| Tool | Version / Configuration | Verify |
| --- | --- | --- |
| Git | 2.52.0 | `git --version` |
| OpenSSH | System OpenSSH client | `ssh -V` |

### Git Identity

The workstation uses the global Git identity configured for the MedusaLab
administrator.

### GitHub Access

GitHub repository access uses SSH.

The workstation SSH configuration selects the workstation GitHub key for
`github.com`.

Verify:

    ssh -T git@github.com

---

# Editors and Terminal

| Tool | Version | Verify |
| --- | --- | --- |
| Vim | 9.1 | `vim --version` |
| tmux | 3.4 | `tmux -V` |
| Bash | RHEL system Bash | `echo $BASH_VERSION` |

The MedusaLab standard uses:

- Vim as the default editor
- tmux for terminal multiplexing
- Version-controlled dotfiles

Managed dotfiles:

    dotfiles/vimrc
    dotfiles/tmux.conf

User configuration is linked to the repository:

    ~/.vimrc
    ~/.tmux.conf

---

# OpenShift and Kubernetes

## OpenShift CLI

| Tool | Version | Verify |
| --- | --- | --- |
| `oc` | 4.22.10 | `oc version --client` |

The OpenShift CLI is the primary administrative interface for the MedusaLab
OpenShift environment.

The workstation administers the full MedusaLab OpenShift cluster rather than
using OpenShift Local as its primary environment.

Primary cluster:

- OpenShift Container Platform 4.22
- Three-node compact cluster
- Nodes: `ocp-cp01`, `ocp-cp02`, `ocp-cp03`

---

## kubectl

| Tool | Version | Verify |
| --- | --- | --- |
| `kubectl` | 1.35.2 | `kubectl version --client` |

`kubectl` is retained for Kubernetes-compatible workflows, but `oc` is the
preferred OpenShift administration interface.

---

## Helm

| Tool | Version | Install Method | Verify |
| --- | --- | --- | --- |
| Helm | 3.22.0 | Official Helm project installer | `helm version --short` |

Installer:

    scripts/installers/install-helm.sh

The installer detects the operating system and treats the RHEL family as the
primary platform while preserving Debian/Ubuntu support where practical.

---

# Automation

## Ansible

| Tool | Version | Verify |
| --- | --- | --- |
| Ansible Core | 2.16.16 | `ansible --version` |

Purpose:

- Configuration management
- Lab automation
- Linux host configuration
- OpenShift supporting infrastructure

Configuration:

    ansible/ansible.cfg

Inventories:

    ansible/inventories/

Playbooks:

    ansible/playbooks/

---

## Terraform

| Tool | Version | Install Method | Verify |
| --- | --- | --- | --- |
| Terraform | 1.16.2 | Official HashiCorp RHEL repository | `terraform version` |

Installer:

    scripts/installers/install-terraform.sh

The installer uses the HashiCorp RHEL repository on RHEL-family systems and
retains Debian/Ubuntu support where practical.

---

# Container Tooling

## Podman

| Tool | Version | Verify |
| --- | --- | --- |
| Podman | 5.8.2 | `podman --version` |

Podman is the preferred local container engine on the RHEL workstation.

---

# Scripting and Data Utilities

| Tool | Version | Verify |
| --- | --- | --- |
| Python | 3.12.14 | `python3 --version` |
| jq | 1.7.1 | `jq --version` |
| yq | 4.53.6 | `yq --version` |

The RHEL jq package reports version 1.7.1 through RPM metadata. Its embedded `jq --version`
output currently returns `jq-`, but functional JSON processing has been verified.

---

# Workstation Configuration Strategy

MedusaLab workstation configuration follows these standards:

- Git is the source of truth.
- RHEL is the primary workstation platform.
- Dotfiles are version controlled.
- Installer scripts should be idempotent.
- Installer scripts must detect the operating-system family where needed.
- Official vendor repositories or upstream installation methods are preferred.
- Debian/Ubuntu compatibility may be retained where practical.
- Major tools must provide an installation method and verification command.

Shared operating-system detection is implemented in:

    scripts/lib/common.sh

---

# Secondary Environments

Windows 11 and Ubuntu WSL remain useful secondary environments for
administration, testing, and compatibility work.

OpenShift Local may still be used for isolated testing, but it is not the
primary MedusaLab OpenShift platform.

The primary OpenShift environment is the full MedusaLab cluster.

---

# Future Work

Future workstation improvements may include:

- Dedicated daily-use OpenShift kubeconfig separated from installation assets
- Workstation DNS registration
- Additional shell and CLI quality-of-life configuration
- Workstation health-check automation
- RHEL-first installer support for additional tools
- Documentation of workstation rebuild procedures
