# AFFiNE

AFFiNE is deployed as one application Pod with a one-shot pre-deploy migration
init container. PostgreSQL is provided by the shared CNPG cluster and managed
through the EasyMile database CRDs; the required `vector` (pgvector) extension
is enabled on the AFFiNE database. Redis-compatible storage is provided by
SAP's Valkey Operator.

The application image is pinned to `ghcr.io/toeverything/affine:0.27.4`.
The upstream self-hosted image stores its generated private key under
`/root/.affine/config` and uploaded files under `/root/.affine/storage`.
Both directories are persisted on separate PVCs.

## URL

The public URL is `https://affine.birb.it`. To change the hostname later,
update these three entries:

- `configmap.yaml`: `AFFINE_SERVER_HOST` and `AFFINE_SERVER_EXTERNAL_URL`
- `ingressroute.yaml`: the `Host(...)` matcher

`AFFINE_SERVER_HTTPS` remains `true` because TLS terminates at Traefik.

## Persistent data and backups

- `affine-config-pvc` stores AFFiNE's generated configuration and private
  key. Back up the entire directory; the private key is needed to preserve
  encrypted or signed data.
- `affine-storage-pvc` stores uploaded files and blobs.
- PostgreSQL stores the application data and is backed up through the
  existing CNPG setup.
- Valkey is persisted for cache/queue continuity, but it is not a substitute
  for backing up PostgreSQL or the two AFFiNE PVCs.

The official self-hosted start flow runs
`node ./scripts/self-host-predeploy.js` before starting the server. This
deployment keeps that migration step in an init container and waits for both
PostgreSQL and Valkey before running it.

The database URL is assembled from the EasyMile-generated
`affine-db-creds` Secret. If a generated password ever contains URI-reserved
characters, URL-encode its username/password portion before using it in the
`DATABASE_URL`.

The first visit to the URL completes the initial administrator setup. See the
[official self-hosting guide](https://docs.affine.pro/self-host-affine/) and
[backup and restore guide](https://docs.affine.pro/self-host-affine/install/backup-restore)
for operational guidance.

## Enabling the component

This component is intentionally not referenced from
`kubernetes/kustomization.yaml` yet. When it is ready to be reconciled, add
`- affine/flux.yaml` to that root Kustomization.
