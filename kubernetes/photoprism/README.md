# PhotoPrism

PhotoPrism is deployed at https://photos.birb.it, using the existing internal Traefik entry point. The route is home-only (websecure); it does not use a public edge entry point or create another TLS certificate.

## Existing photo data

The Deployment mounts the existing directories directly:

| Host path | Container path | Purpose |
| --- | --- | --- |
| /mnt/bunker/Photos/Photo Library | /photoprism/originals | Original photo and video library |
| /mnt/bunker/Photos/Photo Import | /photoprism/import | Files waiting to be imported |
| /mnt/bunker/Photos/Photoprism Cache | /photoprism/storage | PhotoPrism storage, index database, cache, and sidecars |

All three host paths use hostPath.type: Directory. Kubernetes will not create a missing directory, and the Pod cannot start on a node where one of the paths is absent. This relies on the Ansible-managed /mnt/bunker mount being in place on the node before the Pod is scheduled. A Directory check verifies that the directory exists; it does not independently verify that the directory is backed by the NFS mount rather than a local directory underneath the mount point.

The mounts are writable: PhotoPrism moves files from the import directory, updates metadata, and creates sidecar files. The container entrypoint starts with the permissions needed for initialization and then runs the application as UID/GID 1000:1000. Recursive ownership changes are disabled to avoid walking/changing the entire NFS library on startup. Make sure all three paths are writable by UID/GID 1000:1000, or adjust PHOTOPRISM_UID and PHOTOPRISM_GID in configmap.yaml to match the ownership already used on the share.

**Before the first start**, stop the old PhotoPrism instance and take a backup of all three directories, especially Photoprism Cache. The storage directory is mounted in place so the old SQLite index, configuration, cache, and sidecar data remain available to the new instance. The first run may perform database migrations; do not run two PhotoPrism versions against the same storage directory concurrently.

## Database choice

The Deployment uses SQLite in the existing storage directory. PhotoPrism's newly added PostgreSQL backend is explicitly experimental, and its maintainers warn against using it for a library you depend on. Keeping the old SQLite index also avoids an unnecessary database transfer during recovery. The cluster's PostgreSQL instance is therefore intentionally not used for this application.

## CPU-only processing

Video encoding is explicitly set to FFmpeg's software encoder. Face detection/recognition is not disabled. No GPU devices are mounted, and the Deployment deliberately has **no CPU or memory requests or limits** so the initial indexing and recovery are not constrained by Kubernetes resource settings.

## VoidAuth OpenID Connect

The Community Edition supports OpenID Connect. The issuer and callback configuration are already present, and the Deployment optionally loads credentials from the photoprism-oidc-creds Secret. OIDC becomes active when both client credentials are supplied.

Create a confidential OIDC client in VoidAuth with:

- Issuer: https://auth.birb.it/oidc
- Discovery URL: https://auth.birb.it/oidc/.well-known/openid-configuration
- Redirect URI: https://photos.birb.it/api/v1/oidc/redirect
- Scopes: openid email profile
- Authorization Code flow

Put the client ID and secret into a Secret manifest with these keys:

~~~yaml
apiVersion: v1
kind: Secret
metadata:
  name: photoprism-oidc-creds
  namespace: photoprism
type: Opaque
stringData:
  PHOTOPRISM_OIDC_CLIENT: "<voidauth-client-id>"
  PHOTOPRISM_OIDC_SECRET: "<voidauth-client-secret>"
~~~

Encrypt that manifest with the repository's SOPS age key, and only commit the encrypted file:

~~~sh
sops --encrypt /tmp/photoprism-oidc-creds.yaml \
  > kubernetes/photoprism/oidc-creds.sops.yaml
~~~

Add - oidc-creds.sops.yaml to the resources list in this directory's kustomization.yaml. The unencrypted counterpart oidc-creds.yaml is ignored by Git. Do not commit the plaintext manifest.

OIDC self-registration is enabled. In the Community Edition, newly registered OIDC accounts receive the Guest role by default; review/promote accounts from the existing administrator account as appropriate. Automatic redirection is left off so the local login option remains available.

The deployment intentionally does not set a new admin password: it expects the existing SQLite index from Photoprism Cache to contain the old account. Do not start it against an empty or incorrect storage directory as a substitute for restoring the old data.
