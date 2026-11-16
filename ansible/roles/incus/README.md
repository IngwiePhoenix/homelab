# Incus on smallsupportboi

This role installs and starts a **standalone** Incus server on
`smallsupportboi` (`10.1.1.3`). It does not configure or join an Incus
cluster.

The role installs `incus` and `incus-client` from the APK repositories already
configured on the host. It does not add or change repositories.

It uses an existing `incus.service` when one is installed. If no systemd unit
is present, it installs a small fallback unit. Once the daemon is ready, the
role configures its HTTPS API listener to the host's current Ansible inventory
address on TCP port `8443`. The address is derived from `ansible_host`, so
renaming or readdressing this host in `inventory.yml` updates the listener on
the next run.

Host packages, NFS mounts and host networking remain bootstrap responsibilities
of the existing PostmarketOS baseline. Incus storage pools, profiles, networks
and server-level application configuration are managed separately with
OpenTofu.

Run from `ansible/`:

```sh
ansible-playbook -i inventory.yml site.yml --syntax-check
ansible-playbook -i inventory.yml site.yml --limit smallsupportboi --tags incus
```

This role does not run `incus admin init`, initialize a cluster, or join any
cluster. It therefore does not discard existing local Incus state.
