# MariaDB

This component mirrors the split used by `kubernetes/postgres/`:

- **MariaDB Operator** owns the MariaDB server lifecycle and maintenance.
- **DB Operator** registers that server and provisions application databases and users.

## Reconciliation stages

The Flux Kustomizations are deliberately ordered:

1. `mariadb-operator-crds` installs the MariaDB Operator CRDs.
2. `mariadb-operator` installs the controller and limits its watch scope to the `mariadb` namespace.
3. `mariadb-operator-instance` creates the MariaDB server in `mariadb`.
4. `db-operator` installs DB Operator.
5. `db-operator-instance` registers the server with DB Operator.

## Credential handoff

MariaDB Operator generates the root password in the `mariadb` namespace:

- Secret: `mariadb-root-creds`
- Key: `password`

The cluster-scoped `DbInstance/mariadb` reads that Secret across namespaces. DB Operator uses it to connect to the operator-managed primary Service at:

`mariadb-primary.mariadb.svc.cluster.local:3306`

Using the primary Service means DB Operator continues to connect to the active primary after an automatic promotion.

Future application-level `Database` and `DbUser` resources should be created in their application's namespace. DB Operator creates the corresponding credential Secret and ConfigMap alongside those resources, so workloads can consume them without moving credentials into a central namespace.

The DB Operator controller intentionally watches all namespaces to support those app-local resources. Its `DbInstance` is cluster-scoped in the current API; only the application-specific `Database` and `DbUser` CRs are namespaced.

## MariaDB high availability

The MariaDB instance has two pods: one primary and one replica, managed through the operator's replication topology.

- Semi-synchronous replication is enabled. The primary waits for an acknowledgement from the replica before committing a transaction to the client.
- Automatic primary failover is enabled. When the primary pod becomes unavailable, the operator promotes the ready replica and updates the primary Service.
- The DB Operator connection endpoint targets that primary Service.
- Required pod anti-affinity prevents the two MariaDB pods from sharing a Kubernetes node.
- A hard node selector restricts both pods to nodes labelled `homelab/location=internal`.

This requires at least two schedulable nodes with the internal label. If fewer than two are available, the second MariaDB pod remains Pending rather than being co-located with the primary or placed on an external node.

This is a two-member topology, matching the current CNPG instance count. It provides one replica/failover candidate; it is not the operator project's most redundant recommended production topology, which uses a primary plus at least two replicas (or a three-node Galera cluster). The operator also recommends MaxScale for more advanced production failover and switchover handling; it is not added here.

Each MariaDB pod receives its own 10 GiB PVC on `local-bunker`. The PVCs use the official MariaDB image's `mysql` UID/GID (999), and are retained if the MariaDB CR is deleted.

The MariaDB Operator and DB Operator Helm chart versions are pinned in their HelmReleases for Renovate to update.

DB Operator's optional logical-backup jobs are not enabled here. Its upstream documentation notes that its backup images are not published for ARM; database backup policy should instead be configured through MariaDB Operator.
