variable "incus_address" {
  description = "HTTPS address of the standalone Incus daemon."
  type        = string
  default     = "https://10.1.1.3:8443"
}

variable "incus_oidc_enabled" {
  description = "Whether OpenTofu should configure Incus native OIDC authentication."
  type        = bool
  default     = false
}

variable "incus_oidc_issuer" {
  description = "VoidAuth OIDC discovery URL. Only used when incus_oidc_enabled is true."
  type        = string
  default     = "https://auth.birb.it"
}

variable "incus_oidc_client_id" {
  description = "Dedicated OIDC client ID registered in VoidAuth for Incus."
  type        = string
  default     = ""

  validation {
    condition     = !var.incus_oidc_enabled || length(trimspace(var.incus_oidc_client_id)) > 0
    error_message = "incus_oidc_client_id must be set when incus_oidc_enabled is true."
  }
}

variable "incus_oidc_scopes" {
  description = "OIDC scopes requested by Incus."
  type        = string
  default     = "openid profile email"
}

variable "incus_oidc_claim" {
  description = "Claim Incus uses as the authenticated username."
  type        = string
  default     = "sub"
}
