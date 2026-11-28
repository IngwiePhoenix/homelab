# FileX

FileX is intentionally staged but not yet registered in the cluster root
`kubernetes/kustomization.yaml`. Add it there only when the deployment is ready
to reconcile.

## Namespace ownership

The `filex` Namespace is declared in `namespace.yaml` and included by this
component's Kustomization. Application resources, including the ESO Password
generator, ExternalSecret and generated `filex-env` Secret, live in `filex`.
Flux management resources (the Flux Kustomization, HelmRepository and
HelmRelease) remain in `flux-system`.

The HelmRelease uses a Flux Kustomize post-renderer to add
`FILEX_SECRET_KEY` as a Secret-backed environment variable to the rendered
FileX Deployment. This avoids moving or mirroring the application Secret into
`flux-system`, because HelmRelease `valuesFrom` references are namespace-local.

## Endpoints

- Web UI: `https://files.birb.it`
- WebDAV: `https://files.birb.it/dav`
- S3-compatible API: `https://files.birb.it/s3` (path-style)
- SFTP: `10.10.10.11:2022`
- NFSv3: `10.10.10.11:2049`

SFTP and NFSv3 are exposed by the Calico LoadBalancer service at
`10.10.10.11`. No FTP or FTPS listener is enabled. If a legacy device later
needs plain FTP, FileX can allow it on its FTPS listener with
`FILEX_FTPS_ALLOW_PLAIN`; that would also require enabling the listener and
exposing its control and passive data ports. Plain FTP sends credentials and
file contents without encryption, so only consider it for a specific device
on a trusted home LAN, never as an internet-facing service.

NFSv3 is unencrypted and unauthenticated on the wire; because this subnet is
routed, restrict it to trusted LAN/VPN clients and do not forward it to the
public internet. FileX does not run a portmapper, so NFS clients must specify
both `port=2049` and `mountport=2049`. The NFS export path itself is a bearer
credential; keep it private.

The `FILEX_SECRET_KEY` is generated once by External Secrets Operator and
stored as an immutable, orphaned Secret in `filex`. Back it up with the FileX
database; losing it makes previously stored S3 credentials unusable. The
application data PVC also holds the local file store and SFTP host keys.

OIDC is deliberately not configured. Local authentication remains enabled so
OIDC credentials can be added before the component is registered in the root
Kustomization.

With no admin credentials configured, FileX creates `admin@local` and prints a
random initial password once in the application logs.
