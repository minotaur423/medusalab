# OpenShift Local (CRC) Runbook

## Purpose

This runbook documents the standard operating procedures for managing the MedusaLab OpenShift Local (CRC) environment.

---

# Environment

| Component                  | Value          |
| -------------------------- | -------------- |
| Platform                   | Windows 11 Pro |
| Virtualization             | Hyper-V        |
| CRC Version                | 2.57.0         |
| OpenShift Version          | 4.20.5         |
| Administration Workstation | Ubuntu WSL 2   |
| OpenShift CLI              | `oc`           |

---

# Start the Cluster

```powershell
crc start -p "D:\MedusaLab\OpenShift\secrets\pull-secret.txt"
```

---

# Verify Cluster Status

```powershell
crc status
```

Expected:

* CRC: Running
* OpenShift: Running
* Disk: Running

---

# Stop the Cluster

```powershell
crc stop
```

---

# Open the Web Console

```powershell
crc console
```

---

# Display Login Credentials

```powershell
crc console --credentials
```

**Do not store passwords in this document.**

---

# Configure oc Environment

```powershell
& crc oc-env | Invoke-Expression
```

---

# Login as Developer

```powershell
oc login -u developer https://api.crc.testing:6443
```

---

# Login as Cluster Administrator

```powershell
oc login -u kubeadmin https://api.crc.testing:6443
```

---

# Verify User

```powershell
oc whoami
```

---

# Verify Node Health

```powershell
oc get nodes
```

---

# Verify Cluster Operators

```powershell
oc get clusteroperators
```

---

# Create a Training Project

```powershell
oc new-project do180-lab
```

---

# Select Project

```powershell
oc project do180-lab
```

---

# List Projects

```powershell
oc projects
```

---

# Test Deployment

```powershell
oc create deployment hello-openshift \
  --image=quay.io/openshift/origin-hello-openshift

oc expose deployment hello-openshift --port=8080

oc expose service hello-openshift
```

---

# View Resources

```powershell
oc get pods
oc get svc
oc get routes
```

---

# Delete Training Project

```powershell
oc delete project do180-lab
```

---

# Reset the CRC Cluster

```powershell
crc stop
crc delete -f
crc cleanup
crc setup
```

Use only when rebuilding the OpenShift Local environment from scratch.

---

# Daily Workflow

1. Start CRC.
2. Configure the `oc` environment.
3. Log in.
4. Select or create a project.
5. Complete lab exercises.
6. Stop CRC when finished.

---

# Notes

* Use the `developer` account for application development.
* Use the `kubeadmin` account only for cluster administration.
* Never commit the pull secret or credentials to Git.
* Store the pull secret under `D:\MedusaLab\OpenShift\secrets`.

