# FileX

FileX is intentionally staged but not yet registered in the cluster root
`kubernetes/kustomization.yaml`. Add it there only when the deployment is ready
to reconcile.

## Endpoints

- Web UI: `https://files.birb.it`
- WebDAV: `https://files.birb.it/dav`
- S3-compatible API: `https://files.birb.it/s3` (path-style)
- SFTP: `10.10.10.11:2022`
- Explicit FTPS: `10.10.10.11:2121`, passive TCP ports `30000-30100`
- NFSv3: `10.10.10.11:2049`

SFTP, FTPS and NFSv3 are exposed by the Calico LoadBalancer service at
`10.10.10.11`. The FTPS passive range is also advertised using that address.
FTPS starts with a self-signed certificate; configure/trust a proper certificate
before relying on strict client certificate validation. NFSv3 is unencrypted and
unauthenticated on the wire; because this subnet is routed, restrict it to trusted
LAN/VPN clients and do not forward it to the public internet. FileX does not run
a portmapper, so NFS clients must specify both `port=2049` and `mountport=2049`.
The NFS export path itself is a bearer credential; keep it private.

The `FILEX_SECRET_KEY` is generated once by External Secrets Operator and
stored as an immutable, orphaned Kubernetes Secret in `flux-system`. Back it
up with the FileX database; losing it makes previously stored S3 credentials
unusable. The application data PVC also holds the local file store and SFTP
host keys.

OIDC is deliberately not configured. Local authentication remains enabled so
OIDC credentials can be added before the component is registered in the root
Kustomization.

With no admin credentials configured, FileX creates `admin@local` and prints a
random initial password once in the application logs.
