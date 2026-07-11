# OpenShift Local Runbook

## Purpose

This runbook documents the installation, configuration, operation, verification, and recovery procedures for the MedusaLab OpenShift Local environment.

OpenShift Local runs on the Windows host through Hyper-V. Ubuntu WSL serves as the primary Platform Engineering workstation for `oc`, `kubectl`, Helm, Ansible, and k9s.

## Environment

| Component               | Value                                                |
| ----------------------- | ---------------------------------------------------- |
| Windows host            | MEDUSA                                               |
| Host operating system   | Windows 11 Pro                                       |
| Virtualization platform | Hyper-V                                              |
| CRC version             | 2.57.0                                               |
| OpenShift version       | 4.20.5                                               |
| CRC preset              | OpenShift                                            |
| WSL distribution        | Ubuntu 24.04 LTS                                     |
| OpenShift API           | `https://api.crc.testing:6443`                       |
| Web console             | `https://console-openshift-console.apps-crc.testing` |
| Pull-secret location    | `D:\MedusaLab\OpenShift\secrets\pull-secret.txt`     |
| Linux kubeconfig        | `~/.kube/config`                                     |

## Architecture

```text
Ubuntu WSL
  |
  | oc / kubectl / Helm / k9s
  | ~/.kube/config
  |
  v
https://api.crc.testing:6443
  |
  v
Windows 11 host
  |
  v
Hyper-V
  |
  v
OpenShift Local
OpenShift Container Platform 4.20.5
```

Windows hosts and operates the CRC virtual machine. Ubuntu WSL provides the command-line engineering environment used to administer the OpenShift cluster.

## Security Requirements

* Never commit the Red Hat pull secret to Git.
* Never store the `kubeadmin` password in this runbook.
* Do not include credentials directly in shell commands when an interactive prompt is available.
* Use the `developer` account for ordinary application labs.
* Use `kubeadmin` only for cluster-wide administration.
* Do not commit `~/.kube/config`.
* Treat the kubeconfig as sensitive because it can contain authentication tokens.

## Initial CRC Configuration

Run the following commands from Windows PowerShell:

```powershell
crc config set preset openshift
crc config set cpus 12
crc config set memory 32768
crc config set disk-size 150
crc config view
```

Prepare the Windows host:

```powershell
crc setup
```

Expected result:

```text
Your system is correctly setup for using CRC.
Use 'crc start' to start the instance.
```

## First Cluster Start

The first start requires the Red Hat pull secret:

```powershell
crc start `
  -p "D:\MedusaLab\OpenShift\secrets\pull-secret.txt"
```

The command creates the Hyper-V virtual machine, configures networking, and starts OpenShift.

At completion, CRC displays:

* Web-console address
* OpenShift API address
* `developer` credentials
* `kubeadmin` credentials
* `oc` environment instructions

Do not copy the displayed credentials into documentation.

## Daily Windows Operations

### Start the cluster

After the cluster has been created, the pull-secret option is normally not required:

```powershell
crc start
```

### Check cluster status

```powershell
crc status
```

Expected components should report `Running`:

```text
CRC VM:          Running
OpenShift:       Running
RAM Usage:       ...
Disk Usage:      ...
Cache Usage:     ...
Cache Directory: ...
```

### Stop the cluster

```powershell
crc stop
```

Stopping preserves the virtual machine, cluster configuration, projects, and workloads.

### Open the web console

```powershell
crc console
```

### Display current credentials

```powershell
crc console --credentials
```

Do not store the output in Git or documentation.

### Display the CRC version

```powershell
crc version
```

### Display CRC configuration

```powershell
crc config view
```

## Windows API Verification

Before troubleshooting WSL connectivity, verify that Windows can reach the OpenShift API:

```powershell
curl.exe -k https://api.crc.testing:6443/version
```

Check whether the API listener exists:

```powershell
Get-NetTCPConnection `
  -LocalPort 6443 `
  -State Listen
```

If Windows cannot connect, repair or restart CRC before troubleshooting Ubuntu WSL.

## Windows `oc` Environment

CRC includes a Windows OpenShift client. Load it into the current PowerShell session with:

```powershell
& crc oc-env | Invoke-Expression
```

Verify:

```powershell
oc version --client
```

Log in interactively:

```powershell
oc login `
  -u developer `
  https://api.crc.testing:6443
```

Administrative login:

```powershell
oc login `
  -u kubeadmin `
  https://api.crc.testing:6443
```

## Ubuntu WSL Client Installation

The Windows `oc.exe` binary cannot run as a native Linux executable. Ubuntu requires the Linux OpenShift client.

The client version should match the OpenShift minor version used by CRC whenever practical.

### Install OpenShift CLI 4.20.5

```bash
cd /tmp

curl -fLO \
  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.20.5/openshift-client-linux.tar.gz

rm -rf openshift-client
mkdir -p openshift-client

tar -xzf openshift-client-linux.tar.gz \
  -C openshift-client

sudo install -m 0755 \
  openshift-client/oc \
  /usr/local/bin/oc
```

Verify the client installation:

```bash
command -v oc
oc version --client
```

Expected binary:

```text
/usr/local/bin/oc
```

## WSL Network Verification

Run these commands inside Ubuntu WSL:

```bash
getent hosts api.crc.testing
```

Expected resolution:

```text
127.0.0.1 api.crc.testing
```

Check the active WSL networking mode:

```bash
wslinfo --networking-mode
```

Expected result:

```text
mirrored
```

Test direct API access:

```bash
curl -k --connect-timeout 5 \
  https://api.crc.testing:6443/version
```

Do not continue to `oc login` until this command returns API-version JSON.

### WSL configuration

The Windows file `%USERPROFILE%\.wslconfig` should include:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
```

Preserve any existing processor, memory, swap, firewall, or debugging settings.

After modifying `.wslconfig`, run from Windows PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu and repeat the connectivity test.

## Log In from Ubuntu WSL

Log in as the standard developer user:

```bash
oc login \
  -u developer \
  https://api.crc.testing:6443
```

Enter the password interactively.

Verify the active identity:

```bash
oc whoami
```

Expected result:

```text
developer
```

The login creates or updates:

```text
~/.kube/config
```

Confirm it exists:

```bash
ls -l ~/.kube/config
```

## Kubeconfig Verification

Display the current context:

```bash
kubectl config current-context
```

Display all configured contexts:

```bash
kubectl config get-contexts
```

Confirm that `oc` and `kubectl` use the same cluster:

```bash
oc whoami --show-server
kubectl cluster-info
```

Unless `KUBECONFIG` is explicitly set, the following tools use `~/.kube/config`:

* `oc`
* `kubectl`
* Helm
* k9s

## Developer Verification

The `developer` account should be used for namespace-scoped operations.

Create or select the training project:

```bash
oc project do180-lab 2>/dev/null ||
  oc new-project do180-lab
```

Verify:

```bash
oc whoami
oc project
oc get pods
kubectl get pods
helm list -A
```

Launch k9s:

```bash
k9s
```

The `developer` account is not expected to list cluster-scoped resources.

The following commands can return `Forbidden` when run as `developer`:

```bash
oc get nodes
oc get clusteroperators
oc get pods -A
```

This is expected role-based access-control behavior and does not indicate a cluster failure.

## Administrator Verification

Display the current CRC credentials from Windows PowerShell:

```powershell
crc console --credentials
```

Then log in from Ubuntu WSL:

```bash
oc login \
  -u kubeadmin \
  https://api.crc.testing:6443
```

Enter the password interactively.

Verify:

```bash
oc whoami
oc get nodes
oc get clusteroperators
```

Expected identity:

```text
kubeadmin
```

Expected node state:

```text
Ready
```

For healthy cluster operators, the normal target state is:

```text
AVAILABLE     True
PROGRESSING   False
DEGRADED      False
```

Return to the developer account after completing administrative work:

```bash
oc login \
  -u developer \
  https://api.crc.testing:6443
```

## Workstation Verification Role

The MedusaLab Ansible verification role is located at:

```text
ansible/roles/verification/tasks/main.yml
```

The role verifies installation of the local client binaries without requiring CRC to be running.

### kubectl verification

```yaml
- name: Verify kubectl
  ansible.builtin.command:
    cmd: kubectl version --client --output=yaml
  changed_when: false
```

### OpenShift CLI verification

```yaml
- name: Verify OpenShift CLI
  ansible.builtin.command: oc version --client
  changed_when: false
```

Run the workstation verification through the repository wrapper:

```bash
cd ~/lab/medusalab

./scripts/run-ansible.sh \
  playbooks/bootstrap.yml
```

Client verification must remain separate from cluster-health verification. Commands such as `kubectl cluster-info` depend on CRC being active and a valid kubeconfig being present.

## Training Project

Create the standard DO180 workspace as `developer`:

```bash
oc new-project do180-lab
```

Select it later with:

```bash
oc project do180-lab
```

List accessible projects:

```bash
oc projects
```

Delete the training project only when its resources are no longer needed:

```bash
oc delete project do180-lab
```

## Troubleshooting

### `oc: command not found`

Cause:

* The native Linux OpenShift client is not installed or is not on the WSL `PATH`.

Check:

```bash
command -v oc
```

Install or reinstall `/usr/local/bin/oc`.

### `cannot execute binary file: Exec format error`

Cause:

* A ZIP archive was executed directly, or
* The Windows `oc.exe` binary was treated as a native Linux executable.

Ubuntu WSL requires the Linux `oc` binary.

### Connection attempted against `localhost:8080`

Example:

```text
The connection to the server localhost:8080 was refused
```

Cause:

* No usable Kubernetes kubeconfig is configured.

Resolution:

```bash
oc login \
  -u developer \
  https://api.crc.testing:6443
```

Then confirm:

```bash
kubectl config current-context
```

### `Forbidden` when listing nodes or operators

Example:

```text
User "developer" cannot list resource "nodes"
```

Cause:

* The `developer` account does not have cluster-wide administrative permissions.

Resolution:

* Use namespace-scoped commands as `developer`.
* Log in as `kubeadmin` only when cluster-wide access is required.

### API connection refused from Windows

Check CRC:

```powershell
crc status
```

Restart without deleting the cluster:

```powershell
crc stop
crc setup
crc start
```

Retest:

```powershell
curl.exe -k https://api.crc.testing:6443/version
```

### API works in Windows but not WSL

Inside WSL:

```bash
wslinfo --networking-mode
getent hosts api.crc.testing

curl -k --connect-timeout 5 \
  https://api.crc.testing:6443/version
```

Confirm mirrored networking and restart WSL from PowerShell:

```powershell
wsl --shutdown
```

### CRC machine-state error

Example:

```text
Error getting the machine state: no results found
```

Attempt a normal cleanup sequence:

```powershell
crc stop
crc delete -f
crc cleanup
crc setup
```

Then recreate the instance:

```powershell
crc start `
  -p "D:\MedusaLab\OpenShift\secrets\pull-secret.txt"
```

This procedure is destructive. It deletes the CRC cluster and all workloads stored inside it.

### View CRC logs

```powershell
Get-Content "$env:USERPROFILE\.crc\crc.log" -Tail 200
```

### Inspect the Hyper-V virtual machine

```powershell
Get-VM |
  Where-Object Name -Like "*crc*" |
  Format-Table Name, State, Status, Uptime -AutoSize
```

## Cluster Reset

Use this only when the cluster must be rebuilt:

```powershell
crc stop
crc delete -f
crc cleanup
crc setup
```

Reapply the configuration:

```powershell
crc config set preset openshift
crc config set cpus 12
crc config set memory 32768
crc config set disk-size 150
```

Recreate the cluster:

```powershell
crc start `
  -p "D:\MedusaLab\OpenShift\secrets\pull-secret.txt"
```

A reset deletes all projects, workloads, cluster configuration, and generated credentials inside the CRC instance.

## Daily Workflow

### Windows

```powershell
crc start
crc status
```

### Ubuntu WSL

```bash
oc login \
  -u developer \
  https://api.crc.testing:6443

oc project do180-lab
oc get pods
```

Use the environment through:

```bash
oc
kubectl
helm
k9s
```

### End of session

Exit k9s and stop CRC from Windows PowerShell:

```powershell
crc stop
```

## Validation Record

| Item                        | Status             |
| --------------------------- | ------------------ |
| CRC installation            | Complete           |
| Hyper-V prerequisite setup  | Complete           |
| OpenShift cluster creation  | Complete           |
| Windows web-console access  | Complete           |
| Windows `oc` access         | Complete           |
| Linux `oc` installation     | Complete           |
| kubectl client verification | Complete           |
| WSL API connectivity        | Verify after login |
| WSL kubeconfig creation     | Verify after login |
| Helm connectivity           | Verify after login |
| k9s connectivity            | Verify after login |

Update the final four entries to `Complete` only after their corresponding verification commands succeed.

