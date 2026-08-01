# ADR-0003: OpenShift Dual-Network Architecture and Host-Routed Pod Egress

* **Status:** Accepted
* **Date:** 2026-07-24
* **Project:** MedusaLab
* **Cluster:** `ocp.medusalab.test`
* **OpenShift Version:** 4.22.4
* **Decision Owners:** MedusaLab Platform Engineering

## Context

The MedusaLab OpenShift cluster is a compact three-node cluster running on VMware Workstation.

Each OpenShift node has two virtual network interfaces:

1. VMware VMnet1 provides management and infrastructure connectivity.
2. VMware VMnet8 provides the node default route, application ingress, and internet access through VMware NAT.

The initial design used the VMnet1 address of `lb01` for both the OpenShift API and application ingress:

```text
api.ocp.medusalab.test       → 192.168.141.13
api-int.ocp.medusalab.test   → 192.168.141.13
*.apps.ocp.medusalab.test    → 192.168.141.13
```

The OpenShift nodes selected their VMnet8 addresses as their Kubernetes `InternalIP` values:

```text
ocp-cp01 → 192.168.197.135
ocp-cp02 → 192.168.197.136
ocp-cp03 → 192.168.197.137
```

This created two network problems.

First, application-route requests originating inside the cluster timed out when the wildcard applications domain resolved to the VMnet1 address of `lb01`. External requests from `lb01` succeeded, but requests from pods to Console, OAuth, and the Ingress canary route failed.

Second, pod traffic using direct OVN-Kubernetes egress could resolve DNS and establish outbound TCP connections, but TLS handshakes to internet services stalled. The same HTTPS requests succeeded when initiated directly from the RHCOS nodes or from `lb01`.

Affected external destinations included:

```text
console.redhat.com
api.openshift.com
quay.io
www.google.com
```

The failed pod egress caused the Insights Cluster Operator to report:

```text
Available=False
Progressing=False
Degraded=True
```

with repeated TLS handshake timeouts.

## Decision

MedusaLab will use a dual-network OpenShift architecture with separate infrastructure and application-ingress paths.

### VMnet1: Management and infrastructure network

```text
Network: 192.168.141.0/24
```

VMnet1 is used for:

* DNS
* Vault
* SSH management
* OpenShift API
* OpenShift internal API
* Machine Config Server
* Infrastructure administration

The following OpenShift records remain on the VMnet1 address of `lb01`:

```text
api.ocp.medusalab.test       → 192.168.141.13
api-int.ocp.medusalab.test   → 192.168.141.13
```

HAProxy exposes the following infrastructure services on VMnet1:

```text
192.168.141.13:6443
192.168.141.13:22623
```

### VMnet8: Primary node, NAT, and application-ingress network

```text
Network: 192.168.197.0/24
Gateway: 192.168.197.2
```

VMnet8 is used for:

* OpenShift node `InternalIP` addresses
* Node default routes
* VMware NAT internet access
* OpenShift application ingress
* Pod external egress through the node host network

The following addresses are reserved through VMware DHCP reservations:

```text
lb01      → 192.168.197.134
ocp-cp01  → 192.168.197.135
ocp-cp02  → 192.168.197.136
ocp-cp03  → 192.168.197.137
```

The OpenShift wildcard applications record points to the VMnet8 address of `lb01`:

```text
*.apps.ocp.medusalab.test → 192.168.197.134
```

HAProxy exposes application ingress on VMnet8:

```text
192.168.197.134:80
192.168.197.134:443
```

HAProxy may also retain its VMnet1 application listeners for administrative testing:

```text
192.168.141.13:80
192.168.141.13:443
```

### OVN-Kubernetes gateway configuration

Pod external traffic is routed through the node host networking stack.

The approved configuration is:

```yaml
spec:
  defaultNetwork:
    ovnKubernetesConfig:
      gatewayConfig:
        routingViaHost: true
        ipForwarding: Global
```

This configuration is applied through the Cluster Network Operator:

```bash
oc patch network.operator.openshift.io cluster \
  --type=merge \
  -p '{
    "spec": {
      "defaultNetwork": {
        "ovnKubernetesConfig": {
          "gatewayConfig": {
            "routingViaHost": true,
            "ipForwarding": "Global"
          }
        }
      }
    }
  }'
```

The configuration is verified with:

```bash
oc get network.operator.openshift.io cluster \
  -o jsonpath='routingViaHost={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.routingViaHost}{"\n"}ipForwarding={.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.ipForwarding}{"\n"}'
```

Expected output:

```text
routingViaHost=true
ipForwarding=Global
```

## Rationale

Using separate addresses for the API and application ingress prevents application-route traffic from crossing the wrong VMware network.

The API and Machine Config services remain on VMnet1 because that network provides stable connectivity to the external DNS, load-balancing, management, and installation infrastructure.

Application ingress uses VMnet8 because OpenShift pods and nodes use that network as their primary network and default route.

Setting `routingViaHost=true` sends pod external traffic through the RHCOS host networking stack. The host path was verified to support DNS, TCP, and TLS correctly through VMware NAT.

Setting `ipForwarding=Global` is required with host-routed pod egress in this environment. Enabling host routing without global forwarding caused pod DNS and service connectivity failures.

The OpenShift overlay MTU remains:

```text
1400
```

The VMware underlay MTU remains:

```text
1500
```

No MTU modification was required.

## Alternatives Considered

### Use VMnet1 for all OpenShift endpoints

Rejected because pod requests to application routes timed out when `*.apps.ocp.medusalab.test` resolved to `192.168.141.13`.

### Point API and application ingress entirely to VMnet8

Rejected because VMnet1 is the established management and infrastructure network for DNS, installation, API access, and Machine Config services.

### Keep `routingViaHost=false`

Rejected because pod traffic could establish TCP connections but TLS handshakes consistently timed out through direct OVN egress.

### Enable `routingViaHost=true` without global forwarding

Rejected because pods subsequently lost DNS and external connectivity.

### Change the OVN MTU

Rejected because the existing MTU values were already correct:

```text
Underlay MTU: 1500
OVN MTU:      1400
```

### Disable VMXNET3 checksum and segmentation offloads

Tested temporarily and rejected because disabling TSO, GSO, GRO, and transmit checksum offload did not resolve the TLS handshake failures.

## Consequences

### Positive consequences

* OpenShift Console routes work from inside and outside the cluster.
* OAuth routes work correctly.
* Ingress canary checks succeed.
* Authentication, Console, and Ingress Operators remain healthy.
* Pod DNS resolution works.
* Pod HTTPS egress works.
* The Insights Operator can communicate with Red Hat services.
* OpenShift node and pod traffic use predictable VMware network paths.
* The cluster survives graceful shutdown and startup without losing the configuration.

### Negative consequences

* The architecture depends on two VMware networks.
* The VMnet8 address of `lb01` must remain reserved.
* VM MAC addresses must remain stable.
* HAProxy must maintain listeners on multiple interfaces.
* DNS must preserve separate API and application-ingress targets.
* Pod egress depends on host routing and global forwarding.
* Replacing VMware network adapters can invalidate DHCP reservations.
* This configuration differs from the default OVN direct-egress behavior.

## Operational Requirements

The following settings must be preserved in automation and documentation.

### VMware reservations

```text
192.168.197.134 → lb01
192.168.197.135 → ocp-cp01
192.168.197.136 → ocp-cp02
192.168.197.137 → ocp-cp03
```

### DNS

```text
api.ocp.medusalab.test       → 192.168.141.13
api-int.ocp.medusalab.test   → 192.168.141.13
*.apps.ocp.medusalab.test    → 192.168.197.134
```

### HAProxy

```text
API:             192.168.141.13:6443
Machine Config:  192.168.141.13:22623
Ingress HTTP:    192.168.197.134:80
Ingress HTTPS:   192.168.197.134:443
```

### Firewall

The following ports must remain permitted on `lb01`:

```text
80/tcp
443/tcp
6443/tcp
22623/tcp
```

### OpenShift networking

```text
routingViaHost=true
ipForwarding=Global
clusterNetworkMTU=1400
```

## Validation

The decision was validated with the following checks.

### Node health

```bash
oc get nodes -o wide
```

Expected:

```text
ocp-cp01.ocp.medusalab.test   Ready
ocp-cp02.ocp.medusalab.test   Ready
ocp-cp03.ocp.medusalab.test   Ready
```

### Cluster Operator health

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

A healthy cluster displays only the header.

### Application ingress

```bash
curl \
  --insecure \
  --silent \
  --show-error \
  --output /dev/null \
  --write-out 'HTTP=%{http_code} TOTAL=%{time_total}s\n' \
  https://console-openshift-console.apps.ocp.medusalab.test/
```

Expected:

```text
HTTP=200
```

### Pod internet access

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

### Connected-cluster health

```bash
oc get clusteroperator insights
```

Expected:

```text
AVAILABLE=True
PROGRESSING=False
DEGRADED=False
```

## Rollback

The OpenShift gateway configuration can be restored to direct OVN routing with:

```bash
oc patch network.operator.openshift.io cluster \
  --type=merge \
  -p '{
    "spec": {
      "defaultNetwork": {
        "ovnKubernetesConfig": {
          "gatewayConfig": {
            "routingViaHost": false,
            "ipForwarding": "Restricted"
          }
        }
      }
    }
  }'
```

This rollback is not recommended in the current VMware Workstation environment because it restores the pod TLS failure.

A rollback should be performed only if the underlying VMware networking architecture is redesigned and pod DNS, route access, and outbound HTTPS are fully revalidated.

## Follow-up Actions

* Add VMware address reservations to infrastructure documentation.
* Manage `lb01` HAProxy and firewalld configuration through Ansible.
* Manage the `medusalab.test` DNS zone through Ansible.
* Add an automated validation for OpenShift gateway settings.
* Add pod DNS, application-route, and internet-TLS tests to the cluster verification playbook.
* Include the dual-network design in the MedusaLab architecture diagram.
* Preserve Network Operator configuration backups.
* Review this ADR if MedusaLab moves from VMware Workstation to another virtualization platform.

## References

* `docs/runbooks/OpenShift-4.22.4-Installation-and-Network-Resolution.md`
* OpenShift Network Operator resource:
  `network.operator.openshift.io/cluster`
* OpenShift applications domain:
  `apps.ocp.medusalab.test`
* MedusaLab DNS zone:
  `medusalab.test`

