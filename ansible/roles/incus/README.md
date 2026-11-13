# Incus on the PostmarketOS Dragon Q6a nodes

This role installs Incus from Alpine's edge repositories and runs incusd under
systemd. The Alpine package provides the daemon and client, but its documented
service integration is OpenRC-specific, so this role supplies a systemd unit
for the PostmarketOS systemd image.

The inventory already has an incus group containing the two Dragon Q6a nodes.
group_vars/incus.yml selects bigdergboi (10.1.0.8) as the bootstrap member;
smoldergboi (10.1.0.9) joins it. Incus listens on each member's inventory
ansible_host address at TCP port 8443.

The role creates the cluster but deliberately does not create storage pools,
networks, or profiles. Those choices depend on the desired local/shared storage
and bridge-network design and should be configured separately after the cluster
forms. The seed and joining nodes must be fresh Incus installations without
pre-existing storage pools, networks, or profiles. The role checks this and
fails rather than wiping existing standalone configuration.

## Requirements and caveats

- The hosts must use the PostmarketOS systemd variant.
- Alpine edge main and community repositories are added with APK tags so
  edge packages are opt-in rather than the default source for unrelated
  upgrades. Incus is not being installed from a PostmarketOS-specific package
  repository here; test package compatibility on the installed PostmarketOS
  release before rolling it out to both nodes.
- Permit TCP port 8443 between the two nodes and ensure their clocks are
  synchronized. Incus requires cluster-member latency below 10 ms.
- This is a two-member cluster, not a highly available cluster. Incus requires
  at least three members for a cluster to retain database quorum after losing
  one member.
- The role only bootstraps and joins members that are listed in the incus
  inventory group. Add future nodes to that group before applying the playbook.
- VM support is disabled by default. Set incus_install_vm_support: true if
  the host's kernel and firmware are suitable for Incus VMs.
- The role does not alter the earlier postmarketos_baseline tasks; keep that
  role in its own play if you also use it for the Q6a hosts.

Run from ansible/:

  ansible-playbook -i inventory.yml site.yml --syntax-check
  ansible-playbook -i inventory.yml site.yml --limit incus --tags incus

Ansible check mode can validate package/service changes but cannot simulate the
Incus bootstrap and join token exchange. Do not treat --check as validation of
cluster formation.
