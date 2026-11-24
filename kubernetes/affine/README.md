# AFFiNE

AFFiNE is deployed as one application Pod with a one-shot pre-deploy migration
init container. PostgreSQL is provided by the shared CNPG cluster and managed
through the EasyMile database CRDs; the required `vector` and `pgcrypto`
extensions are enabled on the AFFiNE database. Redis-compatible storage is
provided by SAP's Valkey Operator.

The application image is pinned to `ghcr.io/toeverything/affine:0.27.4`.
The official self-hosted image runs as root and writes under
`/root/.affine`, so the two PVCs are provisioned with root ownership.

## URL

The public URL is `https://affine.birb.it`. To change the hostname later,
update both:

- `configmap.yaml`: `server.externalUrl`
- `ingressroute.yaml`: the `Host(...)` matcher

The ConfigMap is mounted into the persistent config directory as
`config.json`. The Reloader annotation rolls the Deployment when its
ConfigMap or generated credentials change.

## Persistent data and backups

- `affine-config-pvc` stores `config.json` and AFFiNE's generated
  `private.key`. Back up the entire directory; the private key is needed to
  preserve encrypted or signed data.
- `affine-storage-pvc` stores uploaded files and blobs.
- PostgreSQL stores the application data and is backed up through the
  existing CNPG setup.
- Valkey is persisted for cache/queue continuity, but it is not a substitute
  for backing up PostgreSQL or the two AFFiNE PVCs.

The first visit to the URL completes the initial administrator setup. See the
[official self-hosting guide](https://docs.affine.pro/self-host-affine/) and
[backup and restore guide](https://docs.affine.pro/self-host-affine/install/backup-restore)
for operational guidance.

## Enabling the component

This component is intentionally not referenced from
`kubernetes/kustomization.yaml` yet. When it is ready to be reconciled, add
`- affine/flux.yaml` to that root Kustomization.
