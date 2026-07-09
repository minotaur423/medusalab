# Engineering Workstation

## Overview

This document defines the standard software configuration for the MedusaLab engineering workstation.

The workstation is designed to provide a reproducible Platform Engineering environment across Ubuntu WSL, Windows 11, and future Linux systems.

---

# Operating System

| Component | Version     | Verify                |
| --------- | ----------- | --------------------- |
| Ubuntu    | 24.04.4 LTS | `cat /etc/os-release` |
| WSL       | Version 2   | `wsl --status`        |

---

# Source Control

| Tool    | Version | Install Method | Verify          |
| ------- | ------- | -------------- | --------------- |
| Git     | 2.43.0  | Ubuntu package | `git --version` |
| OpenSSH | System  | Ubuntu package | `ssh -V`        |

### Notes

* SSH authentication has been configured for both GitHub and Bitbucket.
* GitHub repository access uses SSH rather than HTTPS.

---

# Editors & Terminal

| Tool | Install Method | Verify               |
| ---- | -------------- | -------------------- |
| Vim  | Ubuntu package | `vim --version`      |
| tmux | Ubuntu package | `tmux -V`            |
| Bash | Ubuntu default | `echo $BASH_VERSION` |

### Notes

The MedusaLab workstation standard uses:

* Vim as the default editor
* tmux for terminal multiplexing
* Managed dotfiles stored in the repository

---

# Automation

## Ansible

* Purpose: Configuration management and workstation automation.
* Install Method: Official Ansible PPA.
* Installer: `scripts/installers/install-ansible.sh`
* Verify: `ansible --version`

### Configuration

* Inventory: `ansible/inventory/hosts.yml`
* Configuration: `ansible/ansible.cfg`
* Bootstrap Playbook: `ansible/playbooks/bootstrap.yml`
* Verification Role: `ansible/roles/verification`

### Notes

The engineering workstation is treated as the first managed infrastructure node (`localhost`). This establishes the automation framework that will later manage Linux virtual machines, Windows Server systems, Kubernetes nodes, and platform services.

---

## Terraform

* Purpose: Infrastructure as Code provisioning.
* Install Method: HashiCorp APT repository.
* Installer: `scripts/installers/install-terraform.sh`
* Verify: `terraform version`

---

# Kubernetes

## kubectl

* Purpose: Kubernetes command-line client.
* Install Method: Official Kubernetes APT repository.
* Installer: `scripts/installers/install-kubectl.sh`
* Verify: `kubectl version --client`

### Notes

kubectl is the primary administrative interface for Kubernetes clusters within MedusaLab.

## k9s

- Purpose: Terminal UI for managing Kubernetes clusters.
- Install Method: GitHub release tarball via `scripts/installers/install-k9s.sh`.
- Verify: `k9s version`

---

## Helm

* Purpose: Kubernetes package manager.
* Install Method: Official Helm APT repository.
* Installer: `scripts/installers/install-helm.sh`
* Verify: `helm version`

---

# Cross-Platform Tools

## PowerShell 7

* Purpose: Cross-platform automation shell.
* Install Method: Microsoft APT repository.
* Installer: `scripts/installers/install-powershell.sh`
* Verify: `pwsh --version`

# Utilities

## yq

- Purpose: YAML, JSON, XML, CSV, TOML, and properties processor.
- Install Method: GitHub release binary via `scripts/installers/install-yq.sh`.
- Verify: `yq --version`

---

# Workstation Standards

## Repository

* Git is the source of truth.
* Dotfiles are version controlled.
* Installer scripts are idempotent.
* Bootstrap provisions the engineering workstation.

## Automation

Every workstation component must provide:

* Installation script
* Verification command
* Documentation
* Ansible verification
* Git history

---

# Planned Tools

The following components will be added in future phases:

* k9s
* Docker CLI
* Node.js LTS
* yq
* Azure CLI
* AWS CLI
* RKE2
* Rancher
* Jenkins
* Artifactory
* Vault
* Grafana
* Prometheus

