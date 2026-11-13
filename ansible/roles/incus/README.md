# Incus on the PostmarketOS Dragon Q6a nodes

The role installs \`incus\` and \`incus-client\` from the APK repositories already
configured on the nodes. It does not add or change repositories.

It uses an existing \`incus.service\` when one is installed. If no systemd unit
is present, it installs a small fallback unit; the Alpine package exposes an
OpenRC subpackage, but the configured package list does not show a separate
Incus systemd subpackage.

The existing \`incus\` inventory group contains both Dragon Q6a nodes.
\`group_vars/incus.yml\` selects \`bigdergboi\` (10.1.0.8) as the bootstrap
member; \`smoldergboi\` (10.1.0.9) joins it. Cluster traffic uses TCP 8443.

The role bootstraps the seed, issues join tokens for members not already in the
cluster, and joins them. Joining a cluster discards local Incus state, so use
this role only on freshly installed/uninitialized Incus nodes. It does not
create storage pools, networks, or profiles; configure those after the cluster
has formed.

Run from \`ansible/\`:

\`\`\`sh
ansible-playbook -i inventory.yml site.yml --syntax-check
ansible-playbook -i inventory.yml site.yml --limit incus --tags incus
\`\`\`

Cluster formation is skipped in Ansible check mode because token exchange and
joining are live operations. Two nodes can form a cluster, but this is not
highly available: a three-member cluster is needed to retain database quorum
after losing one member.
