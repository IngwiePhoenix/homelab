# Incus on the PostmarketOS Dragon Q6a nodes

PostmarketOS already provides Incus in the configured APK repositories. This
role installs the native \`incus\` and \`incus-client\` packages and uses the
systemd service provided by the package set; it does not add Alpine Edge
repositories or ship a custom unit file.

The existing \`incus\` inventory group contains both Dragon Q6a nodes.
\`group_vars/incus.yml\` selects \`bigdergboi\` (10.1.0.8) as the bootstrap
member; \`smoldergboi\` (10.1.0.9) joins it. Cluster traffic uses TCP 8443.

The role bootstraps the seed, issues join tokens for members not already in the
cluster, and joins them. Joining a cluster discards local Incus state, so use
this role only on freshly installed/uninitialized Incus nodes. The role does
not create storage pools, networks, or profiles; those should be configured
after the cluster has formed.

Run from \`ansible/\`:

\`\`\`sh
ansible-playbook -i inventory.yml site.yml --syntax-check
ansible-playbook -i inventory.yml site.yml --limit incus --tags incus
\`\`\`

Cluster formation is skipped in Ansible check mode because the token exchange
and join are live operations. Two nodes can form a cluster, but this is not
highly available: a three-member cluster is needed to retain database quorum
after losing one member.
