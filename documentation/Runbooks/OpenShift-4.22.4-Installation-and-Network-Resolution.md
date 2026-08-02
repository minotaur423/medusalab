# MedusaLab OpenShift 4.22.4 — Installation and Network Resolution

**Project:** MedusaLab  
**Cluster:** `ocp.medusalab.test`  
**Platform:** VMware Workstation on Windows 11  
**Topology:** Compact three-node OpenShift cluster  
**OpenShift version:** 4.22.4  
**Status:** Operational  
**Session closeout date:** July 24, 2026

> This document intentionally omits passwords, private keys, pull secrets, kubeconfig contents, and other sensitive credentials.

---

## 1. Final Outcome

The OpenShift 4.22.4 compact cluster is operational with:

- Three control-plane nodes serving the `control-plane`, `master`, and `worker` roles.
- All nodes in `Ready` state.
- No pending certificate signing requests.
- Core Cluster Operators healthy.
- Ingress, Authentication, Console, Network, and Insights Operators healthy.
- Internal and external application routes functioning.
- Connected-cluster communication to Red Hat services functioning.
- VMware VMnet8 DHCP reservations protecting all cluster-facing addresses.

Final node addresses:

| Node | Management IP — VMnet1 | Primary/Internal IP — VMnet8 |
|---|---:|---:|
| `ocp-cp01.ocp.medusalab.test` | `192.168.141.30` | `192.168.197.135` |
| `ocp-cp02.ocp.medusalab.test` | `192.168.141.31` | `192.168.197.136` |
| `ocp-cp03.ocp.medusalab.test` | `192.168.141.32` | `192.168.197.137` |

Load balancer addresses:

| Host | Interface purpose | Address |
|---|---|---:|
| `lb01.medusalab.test` | VMnet1 infrastructure/API | `192.168.141.13` |
| `lb01.medusalab.test` | VMnet8 application ingress | `192.168.197.134` |

---

## 2. Final Network Architecture

### VMnet1 — Management and infrastructure services

```text
Network: 192.168.141.0/24
Windows host: 192.168.141.1
dns01: 192.168.141.10
dns02: 192.168.141.11
vault: 192.168.141.12
lb01: 192.168.141.13
cp01: 192.168.141.30
cp02: 192.168.141.31
cp03: 192.168.141.32
```

VMnet1 is used for DNS, Vault, SSH management, the OpenShift API, the internal API, the Machine Config Server, and infrastructure administration.

### VMnet8 — OpenShift primary and internet path

```text
Network: 192.168.197.0/24
VMware NAT gateway: 192.168.197.2
lb01: 192.168.197.134
cp01: 192.168.197.135
cp02: 192.168.197.136
cp03: 192.168.197.137
```

VMnet8 is used for node default routes, OpenShift node `InternalIP`, OVN-Kubernetes external traffic, application ingress, and internet access through VMware NAT.

### VMware DHCP reservations

```text
lb01      → 192.168.197.134
ocp-cp01  → 192.168.197.135
ocp-cp02  → 192.168.197.136
ocp-cp03  → 192.168.197.137
```

These reservations must be preserved. Replacing virtual NICs or allowing VMware to generate new MAC addresses will invalidate the reservations.

---

## 3. Final DNS Design

The authoritative zone is `medusalab.test`.

```text
dns01 — primary/master — 192.168.141.10
dns02 — secondary/slave — 192.168.141.11
```

Final OpenShift records:

```dns
api.ocp.medusalab.test.       A    192.168.141.13
api-int.ocp.medusalab.test.   A    192.168.141.13
*.apps.ocp.medusalab.test.    A    192.168.197.134
```

Design rationale:

- API and machine configuration traffic remain on VMnet1.
- Application routes use the VMnet8-facing HAProxy address.
- This avoids asymmetric traffic between the OpenShift pod/node network and the VMnet1 ingress listener.

---

## 4. Final HAProxy Design

HAProxy listens on VMnet1 for API and machine configuration traffic:

```text
192.168.141.13:6443
192.168.141.13:22623
```

HAProxy listens on both interfaces for application ingress:

```text
192.168.141.13:80
192.168.141.13:443
192.168.197.134:80
192.168.197.134:443
```

The VMnet8 listeners are required for application traffic originating from cluster pods and nodes.

The active router pods were observed on `cp02` and `cp03`. HAProxy ingress backends should use router-capable nodes with appropriate health checks.

---

## 5. Firewall Requirements on `lb01`

The following TCP ports must remain permitted:

```text
80/tcp
443/tcp
6443/tcp
22623/tcp
```

| Port | Purpose |
|---:|---|
| 80 | OpenShift application HTTP ingress |
| 443 | OpenShift application HTTPS ingress |
| 6443 | Kubernetes/OpenShift API |
| 22623 | Machine Config Server and Ignition |

The missing `22623/tcp` rule originally prevented `cp02` and `cp03` from retrieving Ignition data.

---

## 6. OVN-Kubernetes Gateway Configuration

The final working configuration is:

```yaml
spec:
  defaultNetwork:
    ovnKubernetesConfig:
      gatewayConfig:
        routingViaHost: true
        ipForwarding: Global
```

Verification:

```bash
oc get network.operator.openshift.io cluster \
  -o jsonpath='routingViaHost={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.routingViaHost}{"\n"}ipForwarding={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding}{"\n"}'
```

Expected:

```text
routingViaHost=true
ipForwarding=Global
```

### Why this was required

With `routingViaHost=false`:

- Pod DNS worked.
- Pod TCP connections to internet HTTPS endpoints completed quickly.
- TLS handshakes stalled before receiving response headers.
- The same destinations worked directly from the RHCOS node and from `lb01`.

A temporary `routingViaHost=true` change without global forwarding caused pod DNS failures.

The working combination was:

```text
routingViaHost=true
ipForwarding=Global
```

With both settings applied, pod DNS and HTTPS succeeded, TLS completed to Red Hat, Quay, and Google, and the Insights Operator recovered.

This should be documented as a VMware Workstation NAT integration requirement for this MedusaLab design, not as a universal OpenShift default.

---

## 7. MTU Configuration

Observed values:

```text
VMnet8 / ens192 / br-ex: 1500
OVN pod interface:       1400
ovn-k8s-mp0:             1400
```

OpenShift configuration:

```yaml
mtu: 1400
```

No MTU change was required.

---

## 8. Installation Problems and Resolutions

### 8.1 Incorrect root-device hint

Initial value:

```text
/dev/sda
```

Actual installation disk:

```text
/dev/nvme0n1
```

Resolution:

- Rebuilt the Agent-based installation ISO.
- Updated the root-device hint to `/dev/nvme0n1`.
- Reinstalled the control-plane nodes.

### 8.2 Ignition retrieval failure

Symptoms included `No route to host`.

Root cause:

- `lb01` firewalld did not allow Machine Config Server traffic on port `22623`.

Resolution:

- Opened `22623/tcp`.
- Confirmed `80`, `443`, `6443`, and `22623` were permanently permitted.
- `cp02` and `cp03` retrieved Ignition and joined the cluster.

### 8.3 Ingress, Authentication, and Console degradation

Symptoms included:

```text
CanaryChecksRepetitiveFailures
context deadline exceeded
Client.Timeout exceeded while awaiting headers
```

Findings:

- HAProxy worked externally through `192.168.141.13`.
- Cluster pods timed out when application wildcard DNS resolved to `192.168.141.13`.
- Direct tests through `192.168.197.134` succeeded after HAProxy was bound to that address.

Resolution:

- Reserved `192.168.197.134` for `lb01`.
- Added HAProxy listeners on `192.168.197.134:80` and `:443`.
- Changed only `*.apps.ocp.medusalab.test` to `192.168.197.134`.
- Left `api` and `api-int` on `192.168.141.13`.
- Ingress, Authentication, and Console recovered.

### 8.4 Insights Operator degradation

Symptoms:

```text
TLS handshake timeout
Failed to upload data
```

Affected destinations included:

```text
console.redhat.com
api.openshift.com
quay.io
www.google.com
```

Diagnostic result:

- Pod DNS succeeded.
- Pod TCP connections succeeded.
- Pod TLS stalled.
- RHCOS node HTTPS succeeded.
- `lb01` HTTPS succeeded.
- MTU was correct.
- VMXNET3 offload tests did not fix the condition.

Resolution:

```text
routingViaHost=true
ipForwarding=Global
```

Results:

- Pod DNS and HTTPS succeeded.
- Insights Operator restarted successfully.
- Insights became `Available=True`, `Progressing=False`, and `Degraded=False`.

---

## 9. Final Validation Commands

### Cluster Operators

```bash
oc get clusteroperators \
  -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="Available")].status,PROGRESSING:.status.conditions[?(@.type=="Progressing")].status,DEGRADED:.status.conditions[?(@.type=="Degraded")].status' |
awk '
  NR == 1 ||
  $2 != "True" ||
  $3 != "False" ||
  $4 != "False"
'
```

Healthy result:

```text
NAME   AVAILABLE   PROGRESSING   DEGRADED
```

### Nodes

```bash
oc get nodes -o wide
```

### Pending CSRs

```bash
oc get csr --no-headers |
awk '$NF == "Pending"'
```

### Failed pods

```bash
oc get pods -A \
  --field-selector=status.phase=Failed
```

An old failed kube-apiserver installer pod from revision 4 may remain as historical evidence. The active kube-apiserver revision was 13 and healthy.

### Insights

```bash
oc get clusteroperator insights
```

Expected:

```text
AVAILABLE=True
PROGRESSING=False
DEGRADED=False
```

### Pod internet test

```bash
oc run route-test \
  -n default \
  --image=registry.access.redhat.com/ubi9/ubi:latest \
  --restart=Never \
  --command -- \
  sleep infinity

oc wait \
  -n default \
  --for=condition=Ready \
  pod/route-test \
  --timeout=3m

oc exec \
  -n default \
  route-test \
  -- curl \
    --ipv4 \
    --insecure \
    --silent \
    --show-error \
    --output /dev/null \
    --connect-timeout 5 \
    --max-time 20 \
    --write-out \
    'HTTP=%{http_code} REMOTE=%{remote_ip} CONNECT=%{time_connect}s TLS=%{time_appconnect}s TOTAL=%{time_total}s\n' \
    https://console.redhat.com/

oc delete pod route-test \
  -n default
```

Expected:

```text
HTTP=200
TLS=<nonzero value>
```

---

## 10. Operational Notes

### Preserve these items

- VMware VMnet8 DHCP reservations.
- Existing VM MAC addresses.
- HAProxy dual-interface application listeners.
- DNS split between API and application ingress.
- `routingViaHost=true`.
- `ipForwarding=Global`.
- OVN MTU of 1400.
- `lb01` firewall rules.
- OpenShift installation directory and authentication files.
- Network Operator backup files.

### Avoid these actions without a maintenance plan

- Replacing VMnet8 virtual NICs.
- Allowing VMware to assign new MAC addresses.
- Changing the VMnet8 subnet or NAT gateway.
- Moving `*.apps` back to `192.168.141.13`.
- Removing the VMnet8 HAProxy listeners.
- Setting `routingViaHost=true` while leaving forwarding restricted.
- Changing the OpenShift MTU without a validated migration plan.
- Manually editing RHCOS network configuration outside supported OpenShift mechanisms.

---

## 11. Recommended Repository Placement

Suggested path:

```text
docs/runbooks/OpenShift-4.22.4-Installation-and-Network-Resolution.md
```

A separate architectural decision record can later be created at:

```text
docs/decisions/ADR-0003-OpenShift-Dual-Network-and-Host-Routed-Egress.md
```

Suggested ADR decision:

> MedusaLab OpenShift nodes use VMnet1 for management and infrastructure services, VMnet8 for the primary node network and NAT, VMnet8 application ingress through `lb01`, and OVN host-routed egress with global forwarding.

---

## 12. Next Session Checklist

Start the next session with:

```bash
export KUBECONFIG="$HOME/.openshift/ocp-retry1/auth/kubeconfig"

oc get nodes -o wide

oc get clusteroperators \
  -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="Available")].status,PROGRESSING:.status.conditions[?(@.type=="Progressing")].status,DEGRADED:.status.conditions[?(@.type=="Degraded")].status'

oc get clusteroperator insights

oc get network.operator.openshift.io cluster \
  -o jsonpath='routingViaHost={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.routingViaHost}{"\n"}ipForwarding={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding}{"\n"}'
```

Recommended next work:

1. Commit this runbook to the MedusaLab repository.
2. Create ADR-0003 for the dual-network and egress decision.
3. Add the DNS, HAProxy, firewalld, and gateway settings to Ansible.
4. Validate console login and administrator access.
5. Configure persistent storage.
6. Review image registry configuration.
7. Configure identity providers and reduce reliance on `kubeadmin`.
8. Establish backup procedures for etcd, DNS, Vault, HAProxy, and repository-managed configuration.
9. Add monitoring and alerting runbooks.
10. Begin application deployment and platform-engineering exercises.

---

## 13. Session Status

```text
OpenShift version:       4.22.4
Topology:                Compact 3-node
Nodes Ready:             3/3
Pending CSRs:            0
Ingress healthy:         Yes
Authentication healthy:  Yes
Console healthy:         Yes
Network healthy:         Yes
Insights healthy:        Yes
Pod internet access:     Yes
Cluster status:          Operational
```

