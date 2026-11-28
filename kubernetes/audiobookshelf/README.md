# Audiobookshelf

Audiobookshelf is deployed as one instance in the `audiobookshelf` namespace.
The deployment uses the official multi-architecture image pinned to `2.38.0`;
this release includes `linux/arm64` support.

## Storage

- `/audiobooks` is a read-only `hostPath` mount from `/mnt/bunker/Audiobooks`.
  The path is declared with `hostPath.type: Directory`, so the kubelet fails
  volume setup rather than creating a missing directory. Kubernetes does not
  check host paths during scheduling. The bunker mount is expected to exist on
  every node, as provisioned by Ansible.
- `/config` is backed by `audiobookshelf-config-pvc` and contains the SQLite
  database.
- `/metadata` is backed by `audiobookshelf-metadata-pvc` and contains metadata,
  covers, logs, and backups.

Both PVCs use the cluster's `local-bunker` StorageClass. In this cluster that
storage is backed by the shared NFS filesystem mounted on every node.

## SQLite on the shared filesystem

Audiobookshelf 2.38.0 does not expose a supported environment variable for
SQLite's journal mode. The deployment therefore runs an init container using
the same pinned image and SQLite library before the application starts. If
`/config/absdatabase.sqlite` already exists, it executes
`PRAGMA journal_mode=DELETE` and verifies the returned mode. If the database
does not yet exist, the init container leaves it alone; SQLite's default
journal mode for a new database is `DELETE`.

The Deployment has one replica and uses the `Recreate` strategy so two
Audiobookshelf server processes are not intentionally run against the same
SQLite database during an update. Do not scale this Deployment above one
replica.

**NFS caveat:** Audiobookshelf's official documentation recommends keeping
`/config` on local storage and warns that accessing SQLite over a network
filesystem can cause performance problems and database corruption. For this
homelab, the shared NFS-backed `local-bunker` storage is used as requested and
rollback-journal mode is enforced, but that does not remove SQLite's reliance
on correct filesystem locking and cache-coherency behavior. The NFS client/server
combination must provide those semantics. Keep independent backups of the
`/config` and `/metadata` data.

## Initial setup

Open `https://audiobooks.birb.it`, create the initial administrator account,
and add an Audiobooks library whose path is `/audiobooks`. The original
Audiobookshelf database and listening progress cannot be reconstructed from
the media files alone.
