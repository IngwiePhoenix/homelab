# Incus infrastructure

This OpenTofu root manages the standalone Incus daemon on `smallsupportboi`
(`10.1.1.3`). It does not create or manage the Incus daemon, operating-system
packages, systemd units, NFS mounts, or host bridge devices. Those are bootstrap
responsibilities for Ansible.

## Managed resources

- A directory storage pool named `services`, rooted at
  `/mnt/bunker/Services/incus`.
- A reusable `homelab` profile with its root disk on that pool and a NIC
  attached to the host bridge `br30`.
- Optional native Incus OIDC server configuration.

The storage path is on the NFS mount configured by Ansible. Ensure the mount is
available before the first apply. The directory storage driver does not provide
block-level snapshots or quotas. Do not unmount or remount the NFS export while
instances are running.

The `homelab` profile is not attached to Incus's `default` profile and does
not change existing instances. New instances must explicitly include it, for
example `profiles = ["default", "homelab"]` (or use it as their only profile
when they do not need the default profile).

## Host bootstrap prerequisites

On `smallsupportboi`, Ansible must:

1. Install and enable Incus.
2. Configure Incus's HTTPS listener on `10.1.1.3:8443`, for example with
   `incus config set core.https_address 10.1.1.3:8443`.
3. Mount the NFS export at `/mnt/bunker` before Incus starts workloads.
4. Create the host bridge `br30` and attach it to VLAN 30. This is intentionally
   not created by OpenTofu: the physical interface and VLAN trunk belong to
   host networking.

## Incus API credentials for Tofu Controller

The Tofu Controller runner mounts a Kubernetes Secret named
`incus-client-config` at `/etc/incus`. Create it in the `flux-system`
namespace before activating the Terraform custom resource.

On a trusted administrator workstation, create a dedicated Incus client
certificate, trust it on the server, and configure a remote with the server
certificate fingerprint verified out of band. The resulting Incus config
directory should contain `config.yml`, `client.crt` and `client.key`.

Create the Secret from that directory:

```sh
kubectl -n flux-system create secret generic incus-client-config \
  --from-file=config.yml="$HOME/.config/incus/config.yml" \
  --from-file=client.crt="$HOME/.config/incus/client.crt" \
  --from-file=client.key="$HOME/.config/incus/client.key"
```

The Incus remote name in `config.yml` must be `smallsupportboi` and point to
`https://10.1.1.3:8443`. Keep the private key out of Git. The runner uses the
Incus provider's `config_dir` setting to read this client configuration.

The controller's Terraform object defaults to manual plan approval. Review the
plan and explicitly approve it before any changes are applied. The Kubernetes
backend stores the OpenTofu state in Kubernetes Secrets.

## VoidAuth OIDC (optional)

OIDC is disabled by default. To enable it, set the following Terraform
variables in the `incus` Terraform object:

- `incus_oidc_enabled = true`
- `incus_oidc_issuer = "https://auth.birb.it"`
- `incus_oidc_client_id` to a dedicated client registered in VoidAuth.
- `incus_oidc_scopes` and `incus_oidc_claim` to claims actually emitted by
  your VoidAuth configuration.

Incus requires Device Authorization Grant support from the identity provider.
VoidAuth's OIDC implementation must be tested for this grant before enabling
OIDC; the presence of device-code-related implementation types alone does not
prove that the flow is enabled for your client.

Important: Incus currently grants full Incus access to users who authenticate
through OIDC unless a compatible authorization backend (OpenFGA) is configured.
Do not enable OIDC for untrusted users or expose the API publicly without
reviewing this limitation.

## Running locally

Install OpenTofu, then:

```sh
cd opentofu
tofu init
tofu plan
```

The local run requires an Incus client config under `~/.config/incus` (or set
`INCUS_CONF`). The controller uses the mounted Secret instead.
