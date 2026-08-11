# OpenShift Authentication and Administrative Access

## Purpose

This runbook defines the administrative authentication model for the MedusaLab
OpenShift cluster.

Routine OpenShift administration must use a named identity rather than the
installation-generated `kubeadmin` account.

## Administrative Identity

The primary OpenShift administrative identity is:

    minotaur423-admin

Authentication is provided through the OpenShift OAuth server using an
HTPasswd identity provider.

The identity provider is:

    medusalab_htpasswd

The HTPasswd database is stored in the OpenShift Secret:

    Namespace: openshift-config
    Secret:    htpass-secret

The administrator has the OpenShift:

    cluster-admin

ClusterRole.

## Administrative Workstation

Athena is the preferred external OpenShift administration workstation.

OpenShift API:

    https://api.ocp.medusalab.test:6443

Athena resolves the private MedusaLab DNS namespace through the MedusaLab
DNS servers and reaches the API and application ingress through the routed
EnterpriseLab-to-MedusaLab management path.

## Routine Login

Authenticate using the named administrator:

    oc login \
      https://api.ocp.medusalab.test:6443 \
      -u minotaur423-admin

Enter the administrator password interactively.

Do not place the password in shell scripts, Git repositories, documentation,
shell aliases, or command-line arguments.

Verify the authenticated identity:

    oc whoami

Expected:

    minotaur423-admin

Verify the API endpoint:

    oc whoami --show-server

Expected:

    https://api.ocp.medusalab.test:6443

## Authorization Validation

Verify cluster-wide administrative authorization:

    oc auth can-i '*' '*' --all-namespaces

Expected:

    yes

Additional validation:

    oc get nodes
    oc get clusterversion
    oc get clusteroperators

## Identity Provider Validation

Display the configured identity providers:

    oc get oauth cluster \
      -o jsonpath='{range .spec.identityProviders[*]}{.name}{"\t"}{.type}{"\n"}{end}'

The MedusaLab HTPasswd provider should be present.

Verify authentication operator health:

    oc get co authentication

Expected state:

    AVAILABLE=True
    PROGRESSING=False
    DEGRADED=False

## Credential Storage

The cluster-side HTPasswd database is stored in:

    openshift-config/htpass-secret

Athena maintains a restricted local administrative copy under:

    ~/.openshift/medusalab-auth/htpasswd

Required permissions:

    ~/.openshift/medusalab-auth          0700
    ~/.openshift/medusalab-auth/htpasswd 0600

Authentication material must never be committed to Git.

## kubeadmin Policy

The installation-generated `kubeadmin` identity is retained as a
break-glass administrative credential.

It is not intended for routine administration.

Normal operations use:

    minotaur423-admin

The `kubeadmin` credential should be used only when the normal identity
provider or named administrator cannot be used.

Removal of `kubeadmin` is intentionally deferred until the authentication,
backup, and recovery procedures have been exercised and validated.

## Recovery Principle

Do not modify or remove the HTPasswd identity provider unless a separate
working cluster-admin session is available.

Before authentication changes:

1. Confirm current cluster health.
2. Maintain an active administrative session.
3. Verify break-glass credentials are available.
4. Apply the authentication change.
5. Wait for the authentication ClusterOperator to reconcile.
6. Test a new login.
7. Verify cluster-admin authorization.

This prevents an identity-provider configuration error from unnecessarily
locking administrators out of the cluster.

