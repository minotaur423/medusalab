# DO180 Training Baseline

Date: 2026-08-11

## Cluster

- OpenShift 4.22.4
- Three-node compact cluster
- 3/3 nodes Ready
- Master MCP healthy
- ClusterVersion healthy
- All ClusterOperators healthy
- No Pending pods
- No outstanding CSRs

## Administration

Preferred workstation:

    Athena

Named OpenShift administrator:

    minotaur423-admin

Developer training identity:

    developer

Break-glass identity:

    kubeadmin

## Training Identity Validation

Developer:

    oc auth can-i '*' '*' --all-namespaces
    no

Developer project self-provisioning:

    oc auth can-i create projectrequests.project.openshift.io
    yes

## Training Policy

During DO180/DO280 preparation:

- Do not upgrade OpenShift.
- Do not redesign networking.
- Do not remove kubeadmin.
- Do not disable SSH password authentication.
- Avoid unrelated infrastructure changes.
- Use the developer identity for application exercises.
- Use the named administrator only when an exercise requires elevated privileges.

MedusaLab is frozen as the DO180/DO280 training baseline.
