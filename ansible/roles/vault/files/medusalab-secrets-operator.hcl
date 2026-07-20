# Human operator access to MedusaLab KV v2 secrets.
#
# This policy permits ordinary secret lifecycle operations but does not
# grant access to Vault system administration, authentication methods,
# audit configuration, or unrelated secrets engines.

path "secret/data/*" {
  capabilities = [
    "create",
    "read",
    "update",
    "patch",
    "delete"
  ]
}

path "secret/metadata/*" {
  capabilities = [
    "read",
    "list",
    "delete"
  ]
}

path "secret/delete/*" {
  capabilities = ["update"]
}

path "secret/undelete/*" {
  capabilities = ["update"]
}

path "secret/destroy/*" {
  capabilities = ["update"]
}

path "secret/config" {
  capabilities = ["read"]
}
