resource "incus_storage_pool" "services" {
  name   = "services"
  driver = "dir"

  # This path is an Ansible-managed NFS mount. The NFS mount itself and its
  # systemd automount lifecycle are deliberately outside OpenTofu's scope.
  config = {
    source = "/mnt/bunker/Services/incus"
  }

  lifecycle {
    prevent_destroy = true
  }
}
