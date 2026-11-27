# Linkwarden

Linkwarden is available at [https://links.birb.it](https://links.birb.it). It uses the shared EasyMile PostgreSQL instance and stores captured pages and uploads in a `local-bunker` PVC.

The deployment uses the ARM64-capable upstream image, pinned to `v2.16.3`. Meilisearch is not deployed because Linkwarden's documentation describes it as optional.

## VoidAuth OIDC setup

Create a confidential OIDC application in VoidAuth with:

- Issuer: `https://auth.birb.it/oidc`
- Discovery URL: `https://auth.birb.it/oidc/.well-known/openid-configuration`
- Redirect URI: `https://links.birb.it/api/v1/auth/callback/oidc`
- Scopes: `openid email profile`
- Authorization Code flow

Put the generated client ID and client secret into `oidc-creds.sops.yaml`.

## Required secret values

Before activating this component, populate these values:

- `linkwarden-env.sops.yaml`: `NEXTAUTH_SECRET`. Generate at least 32 random bytes, for example with `openssl rand -base64 32`.
- `oidc-creds.sops.yaml`: `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET` from the VoidAuth application.

Then encrypt both manifests with the repository's SOPS age recipient:

```sh
sops --encrypt --in-place kubernetes/linkwarden/linkwarden-env.sops.yaml
sops --encrypt --in-place kubernetes/linkwarden/oidc-creds.sops.yaml
```

The raw, unencrypted counterpart paths are ignored by Git. Do not add `linkwarden/flux.yaml` to `kubernetes/kustomization.yaml` until the secret values have been populated and the manifests encrypted.

The first account created on a new Linkwarden instance becomes its administrator. Create that account before making the application publicly reachable. The current Traefik entry point is `websecure` (home access); switch it to `edge` only when public access is intended.
