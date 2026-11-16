# IXUI configuration

IXUI is served at https://incus.birb.it through the internal Traefik instance.
The in-repository Helm chart downloads the pinned upstream static release and
verifies its SHA-256 checksum before serving it.

## Required Incus server certificate

The nginx reverse proxy verifies the TLS certificate presented by Incus. Before
activating this component from the root Kubernetes kustomization, create the
referenced Secret in the `ixui` namespace using the CA or server certificate
that issued the Incus HTTPS certificate:

```sh
kubectl -n ixui create secret generic incus-api-ca \
  --from-file=ca.crt=./incus-server-ca.crt
```

This is public trust material, not an Incus client credential. The proxy does
not hold an Incus client certificate and does not impersonate an administrator.
Browser authentication is handled by Incus itself.

The configured TLS server name defaults to `smallsupportboi`. If the Incus
server certificate uses a different DNS name, update
`chart/values.yaml` accordingly.

## VoidAuth OIDC

IXUI uses Incus's native OIDC login at the same origin (`/oidc/login`). Do not
put the Traefik VoidAuth forward-auth middleware in front of this route: it
would intercept the Incus login flow.

Configure Incus with its OIDC discovery URL, a dedicated client ID, scopes and
username claim. The corresponding optional OpenTofu variables are documented
in the repository's `opentofu/README.md`.

Incus requires the identity provider to support the OAuth Device Authorization
Grant. Verify that grant is enabled and works with VoidAuth before enabling
OIDC. Incus currently grants full Incus access to any successfully
OIDC-authenticated user unless OpenFGA authorization is also configured.
Do not expose this endpoint to untrusted users.

TLS certificates for the browser-facing hostname are issued by the existing
`letsencrypt-cloudflare` ClusterIssuer.
