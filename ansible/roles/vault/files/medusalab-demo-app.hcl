# Read-only policy for the MedusaLab demonstration application.
#
# The application can retrieve secrets only from its own subtree.
# It cannot list secret names, write data, read other applications,
# or administer Vault.

path "secret/data/apps/demo/*" {
  capabilities = ["read"]
}
