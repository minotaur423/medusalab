# MedusaLab OpenShift Cluster Shutdown and Startup Runbook

## Purpose

This runbook defines the supported procedure for gracefully shutting down and restarting the MedusaLab OpenShift cluster and its supporting infrastructure.

Use this procedure for planned maintenance or extended shutdowns, such as powering down the lab for several days.

The procedure is designed for the current MedusaLab architecture:

- OpenShift 4.22 compact three-node cluster
- All three OpenShift nodes serve as control-plane, master, and worker nodes
- External BIND DNS provided by `dns01` and `dns02`
- External HAProxy load balancing provided by `lb01`
- Vault provided by `vault01`
- VMware Workstation running on the Windows Medusa host
- OpenShift API endpoint: `api.ocp.medusalab.test`
- OpenShift application ingress: `*.apps.ocp.medusalab.test`

---

# Architecture Dependencies

The OpenShift cluster depends on infrastructure services outside the cluster.

## Infrastructure

| System | Management Address | Purpose |
|---|---:|---|
| `dns01` | `192.168.141.10` | Primary BIND DNS |
| `dns02` | `192.168.141.11` | Secondary BIND DNS |
| `vault01` | `192.168.141.12` | HashiCorp Vault |
| `lb01` | `192.168.141.13` | OpenShift API load balancer |
| `lb01` ingress | `192.168.197.134` | OpenShift application ingress |

## OpenShift Nodes

| Node | Internal IP |
|---|---:|
| `ocp-cp01.ocp.medusalab.test` | `192.168.197.135` |
| `ocp-cp02.ocp.medusalab.test` | `192.168.197.136` |
| `ocp-cp03.ocp.medusalab.test` | `192.168.197.137` |

The infrastructure VMs must remain available until all OpenShift nodes have completed their graceful shutdown.

---

# Important Operational Warning

> **Cordoning persists across reboot.**
>
> Starting an OpenShift VM does **not** automatically make the node schedulable again.
>
> If the cluster is shut down after the nodes have been cordoned, they must be explicitly uncordoned during startup.
>
> A node showing:
>
> ```text
> Ready,SchedulingDisabled
> ```
>
> is online but cannot accept normal workloads.
>
> **Do not declare MedusaLab operational until all three nodes show `Ready` without `SchedulingDisabled` and the post-startup validation checks in this runbook pass.**

---

# Part I — Graceful Shutdown

## 1. Establish OpenShift Administrative Access

Run the shutdown procedure from a system with working administrative access to the cluster.

When operating from `lb01`, use:

```bash
export KUBECONFIG="$HOME/.openshift/ocp-retry1/auth/kubeconfig"
```

Verify access:

```bash
oc whoami
oc whoami --show-server
```

The API server should be:

```text
https://api.ocp.medusalab.test:6443
```

---

## 2. Remove Temporary Test Pods

Remove any known temporary MedusaLab test workloads:

```bash
oc delete pod \
  route-test \
  egress-test-ocp-cp01 \
  egress-test-ocp-cp02 \
  egress-test-ocp-cp03 \
  -n default \
  --ignore-not-found
```

This step is safe if the pods no longer exist.

---

## 3. Verify Cluster Health Before Shutdown

### Check nodes

```bash
oc get nodes -o wide
```

All three nodes must be:

```text
Ready
```

Do not proceed if any node is:

```text
NotReady
Ready,SchedulingDisabled
```

unless the condition has been deliberately investigated and accepted.

### Check ClusterVersion

```bash
oc get clusterversion
```

Expected state:

```text
AVAILABLE=True
PROGRESSING=False
```

The status should indicate that the cluster is running the expected OpenShift version without an active reconciliation failure.

### Check ClusterOperators

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

A healthy cluster should print only the header.

### Check MachineConfigPools

```bash
oc get mcp
```

For the compact cluster, the `master` pool should show:

```text
UPDATED=True
UPDATING=False
DEGRADED=False
```

### Check Pending Pods

```bash
oc get pods -A --field-selector=status.phase=Pending
```

Expected:

```text
No resources found
```

Investigate unexpected Pending pods before continuing.

### Check CSRs

```bash
oc get csr
```

Review any outstanding certificate signing requests before shutdown.

---

## 4. Create an etcd Backup

Create one etcd backup before the planned cluster shutdown.

Run the backup on **one control-plane node only**.

Set a unique backup directory:

```bash
BACKUP_DIR="/home/core/assets/backup-$(date +%Y%m%d-%H%M%S)"
```

Create the backup on `ocp-cp01`:

```bash
oc debug --as-root \
  node/ocp-cp01.ocp.medusalab.test \
  -- chroot /host bash -lc \
  "mkdir -p '$BACKUP_DIR' &&
   /usr/local/bin/cluster-backup.sh '$BACKUP_DIR'"
```

The backup operation should report successful creation of the etcd snapshot and Kubernetes static resources.

Verify the backup:

```bash
oc debug --as-root \
  node/ocp-cp01.ocp.medusalab.test \
  -- chroot /host \
  ls -lh "$BACKUP_DIR"
```

The directory should contain files similar to:

```text
snapshot_<timestamp>.db
static_kuberesources_<timestamp>.tar.gz
```

Record the backup location:

```bash
echo "$BACKUP_DIR" |
tee "$HOME/last-etcd-backup-path.txt"
```

### Backup Limitation

The backup currently remains on the virtual disk of `ocp-cp01`.

This protects against many cluster-level failures associated with the planned power cycle, but it does **not** protect against loss or corruption of the `ocp-cp01` VM or its storage.

An off-node copy should be incorporated into the MedusaLab backup workflow.

---

## 5. Cordon All OpenShift Nodes

Mark all three nodes unschedulable:

```bash
for node in \
  ocp-cp01.ocp.medusalab.test \
  ocp-cp02.ocp.medusalab.test \
  ocp-cp03.ocp.medusalab.test
do
    echo "Cordoning $node"
    oc adm cordon "$node"
done
```

Verify:

```bash
oc get nodes
```

Expected:

```text
ocp-cp01.ocp.medusalab.test   Ready,SchedulingDisabled
ocp-cp02.ocp.medusalab.test   Ready,SchedulingDisabled
ocp-cp03.ocp.medusalab.test   Ready,SchedulingDisabled
```

### Do Not Drain the Compact Cluster

Do not perform a conventional drain of all three nodes as part of this procedure.

The current MedusaLab cluster consists of three nodes that simultaneously provide control-plane and worker functions.

For the current lab workload and planned full-cluster shutdown, the nodes are cordoned and then gracefully powered down rather than attempting to evacuate workloads among the same three nodes.

---

## 6. Schedule Graceful Shutdown of All OpenShift Nodes

The shutdown commands must be issued while the Kubernetes API remains available.

Run:

```bash
for node in \
  ocp-cp01.ocp.medusalab.test \
  ocp-cp02.ocp.medusalab.test \
  ocp-cp03.ocp.medusalab.test
do
    echo "Scheduling shutdown: $node"

    oc debug --as-root \
      "node/$node" \
      -- chroot /host \
      shutdown -h 1
done
```

Each command schedules a graceful operating-system shutdown approximately one minute later.

Scheduling all three before the first node stops helps preserve API and etcd availability long enough to submit all shutdown commands.

Wait approximately three minutes.

---

## 7. Verify OpenShift Nodes Are Powered Off

In VMware Workstation, verify:

```text
ocp-cp01 — Powered Off
ocp-cp02 — Powered Off
ocp-cp03 — Powered Off
```

The VMs must show:

```text
Powered Off
```

not:

```text
Suspended
```

Do not use VMware **Power Off** while a node is still running unless the graceful operating-system shutdown has failed and recovery procedures require it.

---

## 8. Shut Down Infrastructure VMs

Only after **all three OpenShift nodes are fully powered off**, shut down the supporting infrastructure VMs.

Use VMware Workstation:

```text
VM → Power → Shut Down Guest
```

Shutdown order:

1. `vault01`
2. `lb01`
3. `dns02`
4. `dns01`

Keep the DNS servers running until the end so hostname resolution remains available while the remaining infrastructure is being shut down.

Verify every infrastructure VM shows:

```text
Powered Off
```

---

## 9. Shut Down WSL and Windows

After all VMware guests are powered off, close VMware Workstation.

Open PowerShell and run:

```powershell
wsl --shutdown
```

Then shut down Windows normally:

```powershell
shutdown.exe /s /t 0
```

The MedusaLab environment is now fully shut down.

---

# Part II — Cluster Startup

## 10. Start Windows and VMware Workstation

Power on the Medusa Windows host normally.

Start VMware Workstation.

Do not immediately start all VMs simultaneously.

---

## 11. Start Infrastructure Services

Start the external dependencies before starting OpenShift.

Use this order:

1. `dns01`
2. `dns02`
3. `vault01`
4. `lb01`

Allow each VM sufficient time to boot before proceeding.

### Verify DNS

From an administrative workstation with access to VMnet1:

```bash
dig +short @192.168.141.10 api.ocp.medusalab.test
dig +short @192.168.141.11 api.ocp.medusalab.test
```

Both should return:

```text
192.168.141.13
```

Verify application ingress DNS:

```bash
dig +short @192.168.141.10 \
  oauth-openshift.apps.ocp.medusalab.test
```

Expected:

```text
192.168.197.134
```

### Verify API Load Balancer

```bash
nc -vz -w 3 192.168.141.13 6443
```

The TCP connection should succeed once `lb01` is operational and the OpenShift API backends become available.

### Verify Application Ingress Path

After the OpenShift nodes are running:

```bash
nc -vz -w 3 192.168.197.134 443
```

The TCP connection should succeed.

---

## 12. Start the OpenShift Nodes

Start:

1. `ocp-cp01`
2. `ocp-cp02`
3. `ocp-cp03`

All three nodes may take several minutes to restore control-plane services and etcd quorum.

Allow approximately ten minutes for initial reconciliation.

Do not assume that a running VM means the OpenShift cluster is operational.

---

## 13. Re-establish Administrative Access

Verify DNS resolution:

```bash
dscacheutil -q host \
  -a name api.ocp.medusalab.test
```

On macOS, MedusaLab DNS should resolve through:

```text
/etc/resolver/medusalab.test
```

using:

```text
nameserver 192.168.141.10
nameserver 192.168.141.11
```

Verify API connectivity:

```bash
nc -vz -w 3 192.168.141.13 6443
```

Then verify OpenShift access:

```bash
oc whoami
oc whoami --show-server
```

If authentication is no longer valid, log in again using the appropriate MedusaLab administrative credentials.

---

## 14. Uncordon All Three Nodes

> **MANDATORY STARTUP STEP**
>
> Cordoning survives reboot. Failure to perform this step can leave every node `Ready,SchedulingDisabled`, preventing normal workloads and OpenShift operators from scheduling.

First inspect the nodes:

```bash
oc get nodes
```

Then explicitly uncordon all three:

```bash
for node in \
  ocp-cp01.ocp.medusalab.test \
  ocp-cp02.ocp.medusalab.test \
  ocp-cp03.ocp.medusalab.test
do
    echo "Uncordoning $node"
    oc adm uncordon "$node"
done
```

Verify immediately:

```bash
oc get nodes
```

Required state:

```text
ocp-cp01.ocp.medusalab.test   Ready
ocp-cp02.ocp.medusalab.test   Ready
ocp-cp03.ocp.medusalab.test   Ready
```

None of the nodes may show:

```text
SchedulingDisabled
```

---

# Part III — Post-Startup Validation

## 15. Allow Cluster Reconciliation

After uncordoning, allow approximately five to ten minutes for OpenShift workloads and operators to reconcile.

Do not begin making unrelated configuration changes while the cluster is recovering.

---

## 16. Validate Nodes

```bash
oc get nodes -o wide
```

Required:

- All three nodes are `Ready`.
- No node is `SchedulingDisabled`.
- All three expected InternalIP addresses are present.

Expected InternalIP addresses:

```text
ocp-cp01   192.168.197.135
ocp-cp02   192.168.197.136
ocp-cp03   192.168.197.137
```

---

## 17. Validate MachineConfigPools

```bash
oc get mcp
```

Required for the `master` pool:

```text
UPDATED     True
UPDATING    False
DEGRADED    False
```

For the compact cluster:

```text
MACHINECOUNT          3
READYMACHINECOUNT     3
UPDATEDMACHINECOUNT   3
DEGRADEDMACHINECOUNT  0
```

Do not consider startup complete while the master MachineConfigPool is still updating or degraded.

---

## 18. Validate ClusterVersion

```bash
oc get clusterversion
```

Required:

```text
AVAILABLE     True
PROGRESSING   False
```

The status should report the expected OpenShift version without reconciliation errors.

---

## 19. Validate ClusterOperators

Run:

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

A fully healthy cluster should print only the header.

For every ClusterOperator:

```text
AVAILABLE     True
PROGRESSING   False
DEGRADED      False
```

If operators remain degraded or progressing, investigate before declaring startup complete.

---

## 20. Check Pending and Failed Pods

Check Pending workloads:

```bash
oc get pods -A --field-selector=status.phase=Pending
```

Expected:

```text
No resources found
```

Check failed workloads:

```bash
oc get pods -A --field-selector=status.phase=Failed
```

Review unexpected failures.

A Pending workload after startup may indicate that a node remains cordoned or that another scheduling dependency has not recovered.

---

## 21. Check CSRs

```bash
oc get csr
```

Review any outstanding certificate signing requests.

Do not automatically approve unknown CSRs without verifying their origin and purpose.

---

## 22. Validate OpenShift Ingress

Verify the OAuth route resolves:

```bash
dscacheutil -q host \
  -a name oauth-openshift.apps.ocp.medusalab.test
```

Expected:

```text
192.168.197.134
```

Verify TCP connectivity:

```bash
nc -vz -w 3 192.168.197.134 443
```

Optionally verify HTTPS:

```bash
curl -kIs \
  --connect-timeout 5 \
  https://oauth-openshift.apps.ocp.medusalab.test/ |
head
```

An HTTP response confirms that DNS, routing, HAProxy, ingress, and TLS negotiation are functioning.

---

# Final Operational Gate

MedusaLab OpenShift startup is complete **only when all of the following are true**:

- [ ] `dns01` is operational.
- [ ] `dns02` is operational.
- [ ] `vault01` is operational.
- [ ] `lb01` is operational.
- [ ] All three OpenShift VMs are powered on.
- [ ] All three OpenShift nodes report `Ready`.
- [ ] No OpenShift node reports `SchedulingDisabled`.
- [ ] All three nodes have been explicitly uncordoned.
- [ ] Master MachineConfigPool is `UPDATED=True`.
- [ ] Master MachineConfigPool is `UPDATING=False`.
- [ ] Master MachineConfigPool is `DEGRADED=False`.
- [ ] ClusterVersion is `AVAILABLE=True`.
- [ ] ClusterVersion is `PROGRESSING=False`.
- [ ] Every ClusterOperator is `AVAILABLE=True`.
- [ ] Every ClusterOperator is `PROGRESSING=False`.
- [ ] Every ClusterOperator is `DEGRADED=False`.
- [ ] No unexpected Pending pods remain.
- [ ] Outstanding CSRs have been reviewed.
- [ ] OpenShift API connectivity succeeds.
- [ ] OpenShift application ingress connectivity succeeds.

Only after these checks pass should MedusaLab be considered fully operational.

---

# Quick Post-Startup Health Check

The following commands provide a concise final validation:

```bash
echo "=== NODES ==="
oc get nodes

echo
echo "=== MACHINE CONFIG POOLS ==="
oc get mcp

echo
echo "=== CLUSTER VERSION ==="
oc get clusterversion

echo
echo "=== NON-HEALTHY CLUSTER OPERATORS ==="
oc get clusteroperators \
  -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="Available")].status,PROGRESSING:.status.conditions[?(@.type=="Progressing")].status,DEGRADED:.status.conditions[?(@.type=="Degraded")].status' |
awk '
  NR == 1 ||
  $2 != "True" ||
  $3 != "False" ||
  $4 != "False"
'

echo
echo "=== PENDING PODS ==="
oc get pods -A --field-selector=status.phase=Pending

echo
echo "=== CSRS ==="
oc get csr
```

Healthy results should show:

- three `Ready` nodes;
- no `SchedulingDisabled` nodes;
- healthy master MachineConfigPool;
- healthy ClusterVersion;
- only the ClusterOperator table header;
- no Pending pods;
- no unexpected CSRs.

---

# Troubleshooting: Nodes Are Ready but Operators Are Degraded

If all three nodes show:

```text
Ready,SchedulingDisabled
```

after startup, immediately check whether the shutdown procedure cordoned them.

Run:

```bash
for node in \
  ocp-cp01.ocp.medusalab.test \
  ocp-cp02.ocp.medusalab.test \
  ocp-cp03.ocp.medusalab.test
do
    oc adm uncordon "$node"
done
```

Then allow the cluster several minutes to reconcile and rerun the post-startup health checks.

A cluster in which all three compact nodes remain cordoned can produce symptoms including:

- Pending operator workloads
- MachineConfigPool reporting zero ready machines
- Monitoring operator degradation
- OpenShift Controller Manager progressing
- ClusterVersion reconciliation errors
- `0/3 nodes are available: 3 node(s) were unschedulable`

Do not troubleshoot these components independently until node schedulability has first been verified.

---

# Change Management

Changes to this shutdown/startup sequence should be committed to the MedusaLab repository before they become part of the normal operating procedure.

This runbook is the authoritative procedure for planned shutdown and startup of the MedusaLab OpenShift cluster.

