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
