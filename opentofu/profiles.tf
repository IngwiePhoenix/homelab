variable "incus_container_bridge" {
  description = "Host bridge attached to VLAN 30; created and maintained by Ansible."
  type        = string
  default     = "br30"
}

resource "incus_profile" "homelab" {
  name        = "homelab"
  description = "Homelab instances using the NAS-backed services storage pool and VLAN 30."

  device {
    name = "root"
    type = "disk"

    properties = {
      path = "/"
      pool = incus_storage_pool.services.name
    }
  }

  # The host bridge is bootstrap configuration owned by Ansible. It must
  # already exist and be connected/tagged for VLAN 30 before instances start.
  device {
    name = "eth0"
    type = "nic"

    properties = {
      nictype = "bridged"
      parent  = var.incus_container_bridge
    }
  }
}
