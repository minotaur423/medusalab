# MedusaLab human administrator policy.
#
# This is intentionally broad for the MedusaLab administrative account.
# Never assign this policy to applications or automated workloads.

path "*" {
  capabilities = [
    "create",
    "read",
    "update",
    "patch",
    "delete",
    "list",
    "sudo"
  ]
}
