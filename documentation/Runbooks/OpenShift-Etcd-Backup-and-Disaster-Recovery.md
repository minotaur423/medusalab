# MedusaLab OpenShift — etcd Backup and Disaster Recovery

**Project:** MedusaLab  
**Cluster:** `ocp.medusalab.test`  
**Platform:** VMware Workstation on Windows 11  
**Topology:** Compact three-node OpenShift cluster  
**OpenShift version:** 4.22.4  
**Recovery date:** September 12, 2026  
**Status:** Recovery validated successfully

> This document intentionally omits passwords, private keys, pull secrets,
> kubeconfig contents, and other sensitive credentials.

---

## 1. Purpose

This runbook documents the successful recovery of the MedusaLab OpenShift
cluster after an unexpected power outage caused loss of etcd quorum.

The cluster was restored from a validated etcd backup and all three etcd
members were reconstructed under control of the OpenShift etcd Operator.

This procedure reflects the recovery performed on MedusaLab running
OpenShift 4.22.4.

---

## 2. Incident Summary

Following the power outage:

- `ocp-cp01` retained etcd state that could still be accessed.
- `ocp-cp02` and `ocp-cp03` could not safely participate in the old etcd cluster.
- etcd quorum was lost.
- The Kubernetes API was initially unavailable.
- Existing etcd data was preserved rather than manually repaired or deleted.

The validated backup used for recovery was:

    /home/core/assets/backup-20260830-235348/

Backup files:

    static_kuberesources_2026-08-30_235349.tar.gz
    snapshot_2026-08-30_235349.db

Pre-recovery data was preserved under:

    /home/core/assets/pre-recovery-20260907/

---

## 3. Recovery Safety Rules

During this recovery:

- Do not delete or manually modify `/var/lib/etcd`.
- Do not attempt low-level bbolt repair.
- Do not manually copy etcd static pod manifests between nodes.
- Do not manually add etcd members unless required by Red Hat documentation.
- Do not restart CRI-O, kubelet, or control-plane components blindly.
- Restore one authoritative etcd member first.
- Use `etcdctl` membership and endpoint health as authoritative evidence.
- Do not trust stale Kubernetes pod status for powered-off nodes.
- Do not remove the temporary quorum-guard override until all three members are healthy.

---

## 4. Cluster Addresses

| Node | VMnet1 Management | VMnet8 Internal / etcd |
|---|---:|---:|
| `ocp-cp01.ocp.medusalab.test` | `192.168.141.30` | `192.168.197.135` |
| `ocp-cp02.ocp.medusalab.test` | `192.168.141.31` | `192.168.197.136` |
| `ocp-cp03.ocp.medusalab.test` | `192.168.141.32` | `192.168.197.137` |

No node IP addresses or virtual NIC assignments were changed during recovery.

---

## 5. Restore the Initial etcd Member

The restore was performed on `ocp-cp01`:

    sudo -E /usr/local/bin/cluster-restore.sh \
      /home/core/assets/backup-20260830-235348

Successful completion reported:

    SNAPSHOT RESTORE COMPLETED

After the node stabilized, CRI-O and kubelet were verified.

Local API readiness:

    curl -k https://127.0.0.1:6443/readyz

Expected:

    ok

API readiness through the load balancer:

    curl -k https://api.ocp.medusalab.test:6443/readyz

Expected:

    ok

---

## 6. Verify the Restored Single-Member Cluster

Identify the current etcd container:

    sudo crictl ps --name etcd

Verify membership:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl member list -w table

Immediately following restore, the expected authoritative membership was only:

    ocp-cp01.ocp.medusalab.test
    peer:   https://192.168.197.135:2380
    client: https://192.168.197.135:2379

Verify endpoint health:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl endpoint health --cluster

The cp01 endpoint must successfully commit an etcd proposal.

---

## 7. Temporarily Disable the etcd Quorum Guard

With only one healthy restored member, the etcd Operator prevented normal
HA scale-up.

Following the OpenShift 4.22 documented multi-node recovery procedure,
temporarily disable the quorum guard:

    oc patch etcd/cluster --type=merge \
      -p '{"spec":{"unsupportedConfigOverrides":{"useUnsupportedUnsafeNonHANonProductionUnstableEtcd":true}}}'

Verify:

    oc get etcd cluster \
      -o jsonpath='{.spec.unsupportedConfigOverrides}{"\n"}'

Expected:

    {"useUnsupportedUnsafeNonHANonProductionUnstableEtcd":true}

This setting is temporary and must be removed after HA etcd has been restored.

---

## 8. Recover cp02

Power on `ocp-cp02` while leaving `ocp-cp03` powered off.

Verify services:

    sudo systemctl --no-pager -l status crio
    sudo systemctl --no-pager -l status kubelet

Inspect static pod manifests:

    sudo ls -l /etc/kubernetes/manifests/

During recovery, the important condition was that this file was initially absent:

    /etc/kubernetes/manifests/etcd-pod.yaml

This prevented stale pre-restore etcd state from immediately starting.

The etcd Operator subsequently created a new static pod and added cp02 to
the restored etcd cluster.

Verify authoritative membership from cp01:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl member list -w table

Expected members:

    ocp-cp01.ocp.medusalab.test
    ocp-cp02.ocp.medusalab.test

Verify both endpoints:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl endpoint health --cluster

Both endpoints must successfully commit proposals.

---

## 9. Recover cp03

After confirming healthy cp01 and cp02 etcd members, power on `ocp-cp03`.

Verify CRI-O and kubelet:

    sudo systemctl --no-pager -l status crio
    sudo systemctl --no-pager -l status kubelet

Inspect manifests:

    sudo ls -l /etc/kubernetes/manifests/

As with cp02, the old `etcd-pod.yaml` was initially absent.

The etcd Operator then created a new etcd static pod.

Confirm the new manifest:

    sudo ls -l /etc/kubernetes/manifests/etcd-pod.yaml

Confirm etcd is listening:

    sudo ss -lntp | grep -E '2379|2380'

Required ports:

    2379  etcd client traffic
    2380  etcd peer traffic

---

## 10. Verify Final Three-Member etcd Cluster

From cp01, identify the current etcd container:

    sudo crictl ps --name etcd

Verify membership:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl member list -w table

Final recovered members:

    ocp-cp01.ocp.medusalab.test  192.168.197.135
    ocp-cp02.ocp.medusalab.test  192.168.197.136
    ocp-cp03.ocp.medusalab.test  192.168.197.137

All three members must:

- Have status `started`.
- Be full voting members.
- Report `IS LEARNER=false`.

Verify endpoint health:

    sudo crictl exec <ETCD_CONTAINER_ID> \
      etcdctl endpoint health --cluster

Final result:

    https://192.168.197.135:2379 is healthy
    https://192.168.197.136:2379 is healthy
    https://192.168.197.137:2379 is healthy

Each endpoint successfully committed a proposal.

---

## 11. Verify the etcd ClusterOperator

Check:

    oc get co etcd

Required state before ending recovery:

    AVAILABLE     True
    PROGRESSING   False
    DEGRADED      False

---

## 12. Re-enable Normal Quorum Protection

Remove the temporary unsupported override:

    oc patch etcd/cluster --type=merge \
      -p '{"spec":{"unsupportedConfigOverrides":null}}'

Verify:

    oc get etcd cluster \
      -o jsonpath='{.spec.unsupportedConfigOverrides}{"\n"}'

No override should be returned.

Verify again:

    oc get co etcd

Required:

    AVAILABLE=True
    PROGRESSING=False
    DEGRADED=False

---

## 13. Final Cluster Validation

Verify nodes:

    oc get nodes

Final state:

    ocp-cp01.ocp.medusalab.test   Ready
    ocp-cp02.ocp.medusalab.test   Ready
    ocp-cp03.ocp.medusalab.test   Ready

Verify all ClusterOperators:

    oc get co

All operators must report:

    AVAILABLE=True
    PROGRESSING=False
    DEGRADED=False

Check for failed or incomplete pods:

    oc get pods -A \
      --field-selector=status.phase!=Running,status.phase!=Succeeded

Final result:

    No resources found

Check PVCs:

    oc get pvc -A

At the time of validation:

    No resources found

---

## 14. Ingress and Application Validation

Test the DO180 nginx application:

    curl -I \
      http://nginx-unprivileged-svc-do180-lab1.apps.ocp.medusalab.test

Expected:

    HTTP/1.1 200 OK

Test the OpenShift console:

    curl -kI \
      https://console-openshift-console.apps.ocp.medusalab.test

Expected:

    HTTP/1.1 200 OK

Test the ingress canary:

    curl -k \
      https://canary-openshift-ingress-canary.apps.ocp.medusalab.test

Expected:

    Healthcheck requested

This validates the path:

    DNS
      |
      v
    HAProxy
      |
      v
    OpenShift Ingress
      |
      v
    Route
      |
      v
    Service
      |
      v
    Application

---

## 15. Recovery Outcome

The MedusaLab OpenShift 4.22.4 cluster was successfully restored from the
August 30, 2026 etcd backup.

Final condition:

- Three nodes `Ready`.
- Three healthy etcd voting members.
- etcd quorum restored.
- Temporary non-HA recovery override removed.
- Normal quorum protection restored.
- All ClusterOperators healthy.
- No failed or incomplete pods.
- API functional through HAProxy.
- OpenShift console functional.
- Ingress canary functional.
- User application route functional.

The cluster was declared fully recovered on September 12, 2026.

---

## 16. Lessons Learned

- Maintain and regularly validate etcd backups.
- Preserve damaged etcd data until recovery decisions are complete.
- Do not attempt low-level database repair unless explicitly directed by Red Hat.
- Restore one authoritative etcd member before rebuilding additional members.
- Let the OpenShift etcd Operator reconstruct the remaining members.
- Powered-off nodes can leave stale pod status in the Kubernetes API.
- `etcdctl member list` and `etcdctl endpoint health` provide authoritative etcd state.
- The documented temporary non-HA override is necessary during this recovery workflow.
- Remove the override immediately after the three-member cluster is healthy.
- Recovery is not complete until nodes, ClusterOperators, ingress, and representative applications are validated.

---

## 17. Reference

Use the Red Hat OpenShift Container Platform 4.22 documentation:

    Backup and restore
      -> Control plane backup and restore

Always use recovery documentation matching the OpenShift version installed
on the cluster.
