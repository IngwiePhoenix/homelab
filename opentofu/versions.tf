terraform {
  required_version = ">= 1.8.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "= 1.2.1"
    }
  }
}

provider "incus" {
  config_dir = "/etc/incus"
  default_remote = "smallsupportboi"

  remote {
    name    = "smallsupportboi"
    address = var.incus_address
  }
}
