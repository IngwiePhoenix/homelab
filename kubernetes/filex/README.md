# FileX

FileX is intentionally staged but not yet registered in the cluster root
`kubernetes/kustomization.yaml`. Add it there only when the deployment is ready
to reconcile.

The `namespace.yaml` resource creates the dedicated `filex` namespace when
the component is registered. Application resources, including the External
Secrets Operator Password generator, ExternalSecret and generated `filex-env`
Secret, live there. Flux management resources (the HelmRepository,
HelmRelease and Flux Kustomization) remain in `flux-system`.

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
stored as an immutable, orphaned Kubernetes Secret named `filex-env` in the
`filex` namespace. The HelmRelease remains in `flux-system`; its Flux
post-renderer adds a `secretKeyRef` to the FileX Deployment, so the secret
value is never copied into Helm values or into the management namespace. Back
up `filex/filex-env` with the FileX database; losing `FILEX_SECRET_KEY` makes
previously stored S3 credentials unusable. The application data PVC also holds
the local file store and SFTP host keys.

OIDC is deliberately not configured. Local authentication remains enabled so
OIDC credentials can be added before the component is registered in the root
Kustomization.

With no admin credentials configured, FileX creates `admin@local` and prints a
random initial password once in the application logs.
