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

The cluster-scoped `DbInstance/mariadb` reads that Secret across namespaces. DB Operator uses it to connect to the server at:

`mariadb.mariadb.svc.cluster.local:3306`

Future application-level `Database` and `DbUser` resources should be created in their application's namespace. DB Operator creates the corresponding credential Secret and ConfigMap alongside those resources, so workloads can consume them without moving credentials into a central namespace.

The DB Operator controller intentionally watches all namespaces to support those app-local resources. Its `DbInstance` is cluster-scoped in the current API; only the application-specific `Database` and `DbUser` CRs are namespaced.

## MariaDB instance

The initial instance is a single MariaDB 11.8 LTS replica with a 10 GiB PVC on `local-bunker`. The PVC uses the official MariaDB image's `mysql` UID/GID (999), and is retained if the MariaDB CR is deleted. This is a single-instance deployment, not a Galera or replicated HA topology.

The MariaDB Operator and DB Operator Helm chart versions are pinned in their HelmReleases for Renovate to update.

DB Operator's optional logical-backup jobs are not enabled here. Its upstream documentation notes that its backup images are not published for ARM; database backup policy should instead be configured through MariaDB Operator.
