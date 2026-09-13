# ADR-0002: Workstation Configuration Strategy

## Status

Accepted

## Date

2026-07-08

## Decision

MedusaLab workstations will be configured through version-controlled dotfiles, bootstrap scripts, and documented installation procedures.

## Context

The MedusaLab engineering workstation must be reproducible across WSL, future Linux systems, and eventually the MacBook Pro environment.

## Rationale

Manual configuration does not scale and is difficult to reproduce. Bootstrap scripts allow the workstation to be rebuilt consistently from Git.

## Standards

- Git is the source of truth.
- Dotfiles are managed in the MedusaLab repository.
- Bootstrap scripts must be idempotent when practical.
- Vendor repositories are preferred over outdated distribution packages.
- Every major tool must have:
  - Install script
  - Verification command
  - Documentation entry
  - Git commit

## Consequences

This increases upfront discipline but makes the workstation easier to rebuild, audit, and extend.

---

## Amendment — 2026-09-12

### Primary Workstation Platform

Red Hat Enterprise Linux is now the primary operating system for the
MedusaLab engineering workstation.

The primary engineering workstation is:

- Host: `ex180-client.medusalab.test`
- Operating System: Red Hat Enterprise Linux 10
- Architecture: x86_64
- Role: OpenShift and Platform Engineering administrative workstation

Ubuntu WSL and Windows remain supported as secondary administrative
environments where useful, but they are no longer the primary MedusaLab
engineering workstation platform.

### Rationale

MedusaLab is increasingly focused on OpenShift, Red Hat Enterprise Linux,
Ansible, Kubernetes, and enterprise Platform Engineering.

Using RHEL as the primary workstation provides closer alignment with:

- OpenShift administration
- Red Hat tooling and package management
- Enterprise Linux operational practices
- Ansible automation
- EX280 training and future Red Hat certification work

### Installer Standard

Installer scripts should:

1. Detect the operating system.
2. Treat the RHEL family as the primary supported platform.
3. Use `dnf` and official vendor repositories or upstream installation
   mechanisms where appropriate.
4. Preserve Debian/Ubuntu support when practical.
5. Remain idempotent.
6. Provide explicit verification after installation.

Shared operating-system detection is implemented in:

    scripts/lib/common.sh

### Source of Truth

The authoritative MedusaLab repository is cloned on the engineering
workstation at:

    ~/projects/medusalab

GitHub remains the authoritative remote source of truth.
