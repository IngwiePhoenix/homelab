# PhotoPrism

PhotoPrism is deployed at https://photos.birb.it, using the existing internal Traefik entry point. The route is home-only (websecure); it does not use a public edge entry point or create another TLS certificate.

## Existing photo data

The Deployment mounts the existing directories directly:

| Host path | Container path | Purpose |
| --- | --- | --- |
| /mnt/bunker/Photos/Photo Library | /photoprism/originals | Original photo and video library |
| /mnt/bunker/Photos/Photo Import | /photoprism/import | Files waiting to be imported |
| /mnt/bunker/Photos/Photoprism Cache | /photoprism/storage | PhotoPrism storage, cache, sidecars, and backups |

The paths are on the existing /mnt/bunker NFS mount, which is synchronously and hard mounted on every Kubernetes node by Ansible. The local-bunker StorageClass also uses this backing tree; this Deployment intentionally mounts the established PhotoPrism directories directly.

All three host paths use hostPath.type: Directory. Kubernetes will not create a missing directory, and the Pod cannot start on a node where one of the paths is absent. The Ansible-managed NFS mount must therefore be in place before the Pod is scheduled. A Directory check verifies that the directory exists; it does not independently verify the mounted filesystem.

The mounts are writable: PhotoPrism moves files from the import directory, updates metadata, and creates sidecar files. The container runs the application as UID/GID 1000:1000. Recursive ownership changes are disabled to avoid walking/changing the entire NFS library on startup. Make sure all three paths are writable by UID/GID 1000:1000, or adjust PHOTOPRISM_UID and PHOTOPRISM_GID in configmap.yaml to match the ownership already used on the share.

**Before the first start**, stop the old PhotoPrism instance and take a backup of all three directories, especially Photoprism Cache. Do not run two PhotoPrism versions against the same storage directory concurrently.

## MariaDB database and one-time restore

The existing MariaDB Operator instance and DB Operator registration are reused. The namespaced DB Operator Database resource creates the database named photoprism and its primary user on the registered mariadb instance. The generated credentials Secret is photoprism-mariadb-creds in the photoprism namespace. The primary user receives full privileges on this database, which PhotoPrism needs for schema migrations.

The connection endpoint is generated from the DB Operator instance configuration, which points at mariadb-primary.mariadb.svc.cluster.local:3306. That Service follows the MariaDB Operator's current primary after failover.

### Selected backup

The first Pod startup restores this specific dump:

~~~text
/photoprism/storage/backups/mysql/2024-06-14.sql
~~~

The restore init container waits for the MariaDB primary Service, checks that the dump exists and is non-empty, then runs:

~~~sh
photoprism restore --albums --database --force --albums-path /photoprism/storage/backups/serial /photoprism/storage/backups/mysql/2024-06-14.sql
~~~

This restores the index database from the 2024-06-14 SQL dump and restores album metadata from the YAML backups in the configured serial-backup directory. PhotoPrism's restore command also runs the schema migrations shipped with the same PhotoPrism image. The application then runs any remaining schema migrations automatically during startup.

The init container writes this marker into the shared storage directory only after the restore command succeeds:

~~~text
/photoprism/storage/.photoprism-mariadb-restore-20240614-complete
~~~

Subsequent Pod starts skip the restore when the marker exists. If the restore command fails, the marker is not written and the init container fails instead of starting PhotoPrism against an empty or partially restored index. The force flag allows the restore command to replace an existing target index when it retries.

The restored database includes PhotoPrism user accounts, passwords, sessions, and settings. Existing local accounts may therefore require the passwords that were in use when the 2024-06-14 backup was made.

After the application is ready, inspect the migration history with:

~~~sh
kubectl exec -n photoprism deploy/photoprism-app -- photoprism migrations ls
~~~

Keep the original SQL and YAML backups, and retain an independent backup of the full storage and originals directories until the restored library has been checked.

## PhotoPrism version and processing

The Deployment uses the stable Community Edition image 261029-ce. The newer 261126 build is a development preview, so the stable build is retained for this recovery.

Video encoding is explicitly set to FFmpeg's software encoder. Face detection/recognition is not disabled. No GPU devices are mounted, and the Deployment deliberately has **no CPU or memory requests or limits** so initial indexing and recovery are not constrained by Kubernetes resource settings.

## VoidAuth OpenID Connect

The Community Edition supports OpenID Connect. The issuer and callback configuration are already present, and the Deployment optionally loads credentials from the photoprism-oidc-creds Secret.

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

The plaintext counterpart oidc-creds.yaml is gitignored. Do not commit the plaintext manifest.

OIDC self-registration is enabled. In the Community Edition, newly registered OIDC accounts receive the Guest role by default; review/promote accounts from the existing administrator account as appropriate. Automatic redirection is left off so the local login option remains available.
