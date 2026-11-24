# Memos

Memos and Mortis are deployed in one Pod. The application listens on port
`5230`; Mortis listens on `5231` and reaches Memos over the Pod-local
loopback address. The Service exposes both ports, and the Traefik
`IngressRoute` sends the legacy Moe Memos API paths to Mortis:

- `/api/v1/` → Mortis
- `/o/r/` → Mortis
- everything else → Memos

Both images are pinned to `26.11.2`. Mortis `26.11.2` requires the Memos
`26.11.2` backend. Its published container image is built for `linux/arm64`.

## Moving the existing Docker data to this PVC

The PVC is mounted at the same path as the Compose deployment:
`/var/opt/memos`. Memos stores its default SQLite database there as
`memos_prod.db`, along with the local `assets/` directory.

1. Stop the Compose stack cleanly before copying the data, so SQLite can
   checkpoint its WAL and no process is writing to the database.
2. Copy the **contents** of the old `./data` directory into the root of
   `memos-pvc`. Preserve the database and the complete `assets/` directory.
3. Ensure the copied files are owned by UID/GID `10001:10001`. The Memos
   container runs as that non-root user; the PVC annotations set the initial
   directory ownership, but a copy performed as root can change ownership
   again.
4. Start the Kubernetes workload only after the copy is complete.

SQLite remains the active database backend in the Deployment. The
`MEMO_CONTENT_BYTES` variable from the old Compose file is not listed in
Memos 26.11.2's documented runtime environment variables, so it is
intentionally not carried over as a potentially ineffective setting.

## Later: migrate SQLite to PostgreSQL

This component intentionally starts with SQLite. It does not create PostgreSQL
resources or credentials yet. The Memos documentation describes configuring
PostgreSQL, but does not provide a built-in full-instance SQLite-to-PostgreSQL
migration command. The pgloader procedure below is a community-reported
workaround, not an officially supported Memos migration. Test it against a
separate copy and retain a restorable backup of the complete data directory.

### 1. Prepare PostgreSQL resources

Add these objects to this component when you are ready to migrate. They follow
the repository's EasyMile Postgres operator convention and generate the
`memos-db-creds` Secret:

```yaml
apiVersion: postgresql.easymile.com/v1alpha1
kind: PostgresqlDatabase
metadata:
  name: memos-db
  namespace: memos
spec:
  engineConfiguration:
    name: default-cluster-instance
    namespace: postgres
  database: memos
  masterRole: memos-role
  dropOnDelete: true
  waitLinkedResourcesDeletion: true
---
apiVersion: postgresql.easymile.com/v1alpha1
kind: PostgresqlUserRole
metadata:
  name: memos-db-user
  namespace: memos
spec:
  mode: MANAGED
  rolePrefix: memos
  privileges:
    - privilege: OWNER
      database:
        name: memos-db
      generatedSecretName: memos-db-creds
```

At that point, add the Postgres manifest to this directory's
`kustomization.yaml` and add `postgres-instance` to this component's Flux
`dependsOn` list. Wait for the generated Secret before changing the
application configuration.

### 2. Initialize the PostgreSQL schema

Use the **same Memos version** for schema initialization and the data import.
First, back up the SQLite database and assets. Upgrade the SQLite database to
the current Memos release before migrating; older databases may need the
intermediate upgrade path documented in the
[upgrade guide](https://usememos.com/docs/operations/upgrade).

Temporarily point Memos 26.11.2 at the empty PostgreSQL database and start it
once so Memos creates its PostgreSQL schema. Use the generated Secret values
(`HOST`, `PORT`, `DATABASE`, `LOGIN`, and `PASSWORD`) to construct the
DSN. For the eventual Deployment, the relevant environment is equivalent to:

```yaml
envFrom:
  - secretRef:
      name: memos-db-creds
env:
  - name: MEMOS_DRIVER
    value: postgres
  - name: MEMOS_DSN
    value: "postgres://$(LOGIN):$(PASSWORD)@$(HOST):$(PORT)/$(DATABASE)?sslmode=disable"
```

If the generated password contains URI-reserved characters, URL-encode the
username/password portion of the DSN. Use the SSL mode appropriate for the
cluster's PostgreSQL endpoint.

After schema initialization completes, stop Memos before importing data.

### 3. Import the SQLite rows

Connect to the PostgreSQL endpoint from a machine that can also read the
backed-up `memos_prod.db` file. For example, use a Kubernetes port-forward
for the database endpoint, then run pgloader with a data-only load:

```lisp
LOAD DATABASE
  FROM sqlite:///absolute/path/to/memos_prod.db
  INTO postgresql://LOGIN:PASSWORD@127.0.0.1:5432/memos?sslmode=disable
  WITH data only, disable triggers, preserve index names;
```

Before running pgloader, clear the initial instance-setting row(s) created
when Memos initialized the empty PostgreSQL database:

```sql
TRUNCATE system_setting;
```

The data-only pgloader procedure imports the rows into the schema already
created by Memos. Keep the same Memos version on both sides; pgloader resets
generated sequences by default. Do not run a newer Memos version against the
target database between schema initialization and import.

### 4. Switch the Deployment

Set `MEMOS_DRIVER=postgres` and `MEMOS_DSN` as shown above, then start the
Deployment. Keep `memos-pvc` mounted at `/var/opt/memos`: the PostgreSQL
database replaces the SQLite file, but local attachments and other data in
that directory still need persistent storage.

Verify users, memos, comments, attachments, and sharing before treating the
migration as complete. Keep the original SQLite database and backup until
those checks pass.

References:

- [Memos Docker deployment](https://usememos.com/docs/deploy/docker)
- [Memos database configuration](https://usememos.com/docs/configuration/database)
- [Memos upgrade guide](https://usememos.com/docs/operations/upgrade)
- [Community discussion of SQLite-to-PostgreSQL migration](https://github.com/orgs/usememos/discussions/6239)
- [pgloader SQLite reference](https://pgloader.readthedocs.io/en/latest/ref/sqlite.html)
