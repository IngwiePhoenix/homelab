# Task

You will be asked to write Kubernetes manifests for a variety of applications.

## Structure

The cluster uses the k0s Kubernetes distribution and utilizes Flux as it's central CD to implement a clean GitOps style. You can always find the repository here: https://github.com/IngwiePhoenix/homelab

Updates are handled using Renovate - a cluster-local, selfhosted version is being used for that. Likewise, SOPS is used for encryption; secrets are always and only committed as `$(name).sops.yaml` and a matching `.gitignore` entry must be made for that same secret without the `.sops.` part to not accidentially commit the raw data.

The repository follows this schema:
```
(repo root)
- kubernetes/
  - $simpleComponent/
    - kustomization.yaml # Contains the list of files to apply.
    - flux.yaml # Contains the "metadata", like name, health checks and dependencies.
    - ...
  - $splitComponent/
    - install/... # Same as $simpleComponent; is used to install a service or operator, usually for CRDs
    - config/... # Configuration data for the previously installed component. May also be given a more apropriate term like "issuers" or "instance" to fit more into what is being deployed
    - flux.yaml # A combined document covering all the parts being installed. Each subfolder has it's own kustomization.yaml
```

The Git repository reference in Flux is:
```
  sourceRef:
    kind: GitRepository
    name: homelab-repo
```

Each component may contain any of:
- a Flux HelmRepo as `helm-repo.yaml`
- a Flux HelmRelease as `helm-release.yaml` - versions must ALWAYS be pinned for Renovate to bump them.
- a set of standard Kubernetes deployments

When writing plain Kubernetes objects, follow the following naming convention
- Deployment names end in `-app`
  * Use `wait4x/wait4x:latest` to wait for dependent services like databases.
  * The main container of a deployment with the "core logic" is either called "app" or "main".
- Service names end in `-svc`
  * A service may only use a LoadBalancer IP (Calico annotations; pool is `10.10.10.0/24`) when it has sufficiently complex requirements.
- Persistent Volume Claims end in `-pvc`
  * use `local-bunker` as the Storage Class (via local-path-provisioner).
  * use `local-path-provisioner/...` annotations for permission management. You might also want to set a pod/podTemplate's `securityContext` to equal values - or derive the values from the deployed container itself (i.e. by reading the source's Dockerfile)
    * `local-path-provisioner/uid: "<int>"`: Set UID
    * `local-path-provisioner/gid: "<int>"`: Set GID
    * `local-path-provisioner/perm: "<int>"`: Set permissions (i.e.: "0700")
- If you need to use a raw PV, ask back. This is a very unique and case-by-case situation. If you do get permission, they end in `-pv`
- Avoid using the plain Ingress object. Instead:
  * Depend on the Flux kustomization `traefik-ingress`
  * Use Traefik IngressRoute CRDs
    * Endpoint `websecure` is only usable at home, `edge` is also accessible from the public internet.
    * The `tls:` section defaults to `*.birb.it` SNIs. Only set it if you intend to derive or use sub-sub-domains.
  * Names end in `-ir`
- Secrets used to store environment variables end in `-env`
- Secrets used to store credentials end in `-creds`
- ConfigMaps end in `-cm`
- If a TLS certificate is needed, use Cert-Manager, and leave the used issuers blank, unless you want to explicitly use a self-signing one.
  * Certificate objects end in `-certm`
  * You DO NOT need to create a certificate for ingress; a default TLSStore is configured for Traefik. It uses `*.birb.it`.
- Namespaces have no suffix ever.
- When you need a PostgresQL database and account, use the EasyMile Postgres CRDs
  * `PostgresDatabase` object names end in `-db`. The database itself has no suffix.
  * `PostgresqlUserRole` end in `-db-user`
- When you need a Valkey or Redis-compatible database, use SAP's Valkey Operator CRD.
- When you need a MongoDB, use the MongoDBCommunity operator's CRDs for users and passwords and databases.
  * The default instance is in namespace `mongodb` and called `default-cluster`.
- Should you introduce additional or special stanzas that describe remote versions, you should integrate that with Renovate.
  * You can find the repository config in `(repo)/renovate.json5`
  * You can find the global config in `kubernetes/renovate-operator/config/renovate.config.js` (it is injected via the operator)
  * Try to re-use existing parsers and matchers wherever possible!
  * If you must make a new one, keep your RegEx as simple as possible. I do not want to review a kilometer long pattern-matching snake!

When using HelmRepo and HelmRelease:
- Helm Release names end in `-helmrelease`
  * Target namespace follows the name of the chart. I.e. Chart "Traefik" becomes target namespace "traefik"
  * The `releaseName` follows the same schema. This keeps naming equalized and simple. I do have to type those out by hand after all.
- Helm Repo names end in `-helmrepo`

When creating the component's `flux.yaml`:
- Use dependencies where possible - this creates neat chains of execution and installation.
- Use directed health checks rather than `wait: true` - they are often faster.
- Each component, even ones that split across folders, only has one `flux.yaml`. This means, that all Flux Kustomizations land in one, potentially multi-part, document.
  * An example is `kubernetes/traefik/flux.yaml`.

Example Postgres objects:
```
apiVersion: postgresql.easymile.com/v1alpha1
kind: PostgresqlDatabase
metadata:
  name: $(name)-db
  namespace: $(namespace)
spec:
  # There is only this one instance, ever.
  engineConfiguration:
    name: default-cluster-instance
    namespace: postgres
  database: $(name)
  masterRole: $(name)-role
  dropOnDelete: true
  waitLinkedResourcesDeletion: true
---
apiVersion: postgresql.easymile.com/v1alpha1
kind: PostgresqlUserRole
metadata:
  name: $(name)-db-user
  namespace: $(namespace)
spec:
  mode: MANAGED
  rolePrefix: $(name)
  privileges:
    - privilege: OWNER
      database:
        name: $(name)-db
      generatedSecretName: $(name)-db-creds
```

## When to pick Helm over plain objects

If the finished deployment would contain more than five individual Deployments, that is probably a sign you should use Helm, as a general rule of thumb. If there is only one container that needs deployment - minus the wait4x init containers - then you can easily write it as plain objects. The goal is to keep the repository maintainable - so a small set of containers that need to be minded is prefered over a full set. Helm is very convenient, but comes with it's own issues, too.

## Special note

My cluster runs exclusively on arm64/aarch64. Deployments must have images for that. Due to storage constraint, pick Alpine-based images when they get offered - they are usually easier on resources than Debian, Ubuntu, or alike. But this is only a preference, not a criteria.
