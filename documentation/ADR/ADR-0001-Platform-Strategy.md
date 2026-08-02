\# ADR-0001: Platform Strategy



\## Status



Accepted



\## Date



2026-07-07



\## Decision



MedusaLab will use a hybrid platform model:



\* Windows 11 Pro as the primary desktop host.

\* Hyper-V and Windows virtualization features enabled for WSL2 support.

\* WSL2 Ubuntu as the primary engineering workstation.

\* VMware Workstation Pro for traditional virtual machines.

\* Kubernetes for platform services.



\## Context



The MEDUSA desktop has enough CPU, memory, storage, and GPU capacity to support a large enterprise-style lab. The goal is not to rely on one tool for every workload, but to assign each platform a clear role.



\## Rationale



WSL2 provides a strong Linux-based development environment inside Windows. VMware Workstation Pro provides mature VM management, snapshots, and isolated operating system labs. Kubernetes provides the long-running platform layer for services such as Jenkins, Artifactory, Vault, Grafana, Prometheus, and supporting applications.



\## Alternatives Considered



\* VMware only

\* Hyper-V only

\* WSL2 only

\* Docker Desktop only

\* Running all services directly on Windows



\## Consequences



This approach provides flexibility and closely resembles enterprise engineering environments where developers use workstations to manage centralized infrastructure. It also requires clear documentation so that responsibilities between Windows, WSL2, VMware, and Kubernetes remain well defined.



