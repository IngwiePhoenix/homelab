locals {
  incus_server_config = var.incus_oidc_enabled ? {
    "oidc.issuer"     = var.incus_oidc_issuer
    "oidc.client.id"  = var.incus_oidc_client_id
    "oidc.scopes"     = var.incus_oidc_scopes
    "oidc.claim"      = var.incus_oidc_claim
  } : {}
}

# The server exists independently; this resource only manages the explicitly
# declared server configuration keys. With OIDC disabled, it manages no keys.
resource "incus_server" "this" {
  config = local.incus_server_config
}
