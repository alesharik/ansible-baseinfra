# postgres
__Tags - `postgres`__

Deploys [PostgreSQL](https://www.postgresql.org/) as a docker compose project,
with an optional prometheus exporter. The server runs in one of three modes: a
single server, a primary, or a streaming standby of a primary.

Uses the official [`postgres`](https://hub.docker.com/_/postgres) image. The
server runs as uid `999`, gid `999` — the `postgres` user inside the image.

When `version` names a newer major than the cluster on disk, the role runs
`pg_upgrade` by itself. See [Major upgrades](#major-upgrades).

### Usage
```yaml
    - alesharik.baseinfra.postgres
```
```yaml
postgres:
  password: "{{ vault_pg_root }}"
  exporter:
    password: "{{ vault_pg_exporter }}"
```

### Vars
```yaml
postgres:
  image: postgres
  version: "18.6" # must start with the major number
  username: postgres # the bootstrap superuser
  password: "" # required
  mode: single # single | primary | standby
  network: postgres # the docker network the role creates
  publish: [] # host bindings for port 5432: "5432", "10.0.0.5:5432"
  config: # server settings, one `-c key=value` flag each
    session_preload_libraries: auto_explain
    auto_explain.log_min_duration: 2s
  users: [] # {name, password, ip, privs: [{db, type, privs, objs}]}
  databases: [] # {name}
  replication:
    password: "" # the `replication` login; primary and standby
    source: "" # primary: pg_hba address of the standby, as CIDR
    host: "" # standby: address of the primary
    port: 5432 # standby: port of the primary
  upgrade_image: tianon/postgres-upgrade # tag is <old major>-to-<new major>
  exporter:
    enabled: true
    image: quay.io/prometheuscommunity/postgres-exporter
    version: v0.20.1
    password: "" # required when enabled; the `prom-exporter` login
  directories:
    ansible: "{{ dir.ansible }}/postgres" # compose project and config/pg_hba.conf
    data: "{{ dir.data }}/postgres" # mounted at /var/lib/postgresql
```
`postgres` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

`username` and `password` go to `initdb`, and `initdb` runs only on an empty
data directory. A new value on an existing cluster does not change the server.
It only breaks the login of the role. Change the password in the server first
(`ALTER ROLE`), then in the vars.

### Modes

| `mode` | What the role does |
|---|---|
| `single` | Creates the users, databases, grants and the `prom-exporter` login |
| `primary` | The same, plus the `replication` login, a `pg_hba` line for `replication.source`, and `wal_keep_size=512MB` |
| `standby` | Takes a base backup from `replication.host` when the data directory is empty, then runs as a hot standby. Creates nothing: every login and database comes over replication |

A `primary` without a standby behaves like a `single` server.

### Settings

The image keeps the `postgresql.conf` that `initdb` wrote, with the locale,
timezone and `listen_addresses` it picked. The role changes nothing in that
file. It starts the server with flags:

- `-c hba_file=/etc/postgresql/pg_hba.conf`, always
- `-c wal_keep_size=512MB`, on a primary
- one `-c key=value` for each `config` entry, in key order, last, so a `config` key wins

A change to `config` changes the compose file, and compose recreates the
container. So every `config` change is a restart, even for a setting that needs
only a reload.

`config` replaces the defaults like every other key. To keep `auto_explain`,
list its two keys in your own `config`.

### pg_hba.conf

The role writes `{{ postgres.directories.ansible }}/config/pg_hba.conf` and
nothing else decides who can log in. Every rule uses `scram-sha-256`.

```
local   all          <username>                     scram-sha-256
host    replication  replication    <source>        scram-sha-256   # primary
host    postgres     prom-exporter  samenet         scram-sha-256   # exporter enabled
host    <db>         <user>         <user.ip>       scram-sha-256   # each user, each db in its privs
```

**The superuser has no TCP rule.** It logs in over the socket only. Compose
mounts the socket directory at `{{ postgres.directories.ansible }}/run`, and the
role manages the server from the host through it. For a psql session as the
superuser, use `docker compose exec postgres psql -U <username>`, or point a
client on the host at that directory.

`samenet` inside the container is the docker network of the server. It is not
only the containers on that network. docker-proxy relays some connections to a
published port, and the server sees those with the gateway address of the
network, which is in `samenet`. That applies to connections from the host
loopback, and to IPv6 connections when the network has no IPv6. So with
`publish` set, an `ip: samenet` user can also log in through the published
port.

The role reloads the server (SIGHUP) when `pg_hba.conf` is newer than the last
configuration load of the server (`pg_conf_load_time()`). So a change also takes
effect when an earlier run failed before its reload. Before the reload, the role
reads `pg_hba_file_rules`, and it stops on a line with an error. On a SIGHUP the
server keeps its old rules when the file has an error, and the next restart
fails.

Compose mounts the whole `config` directory, not the file: ansible replaces the
file by rename, and a bind mount of a single file keeps the old one.

### Users, databases and grants

```yaml
postgres:
  users:
    - name: app
      password: "{{ vault_pg_app }}"
      ip: samenet # a pg_hba address: CIDR, samenet or all
      privs:
        - { db: appdb, type: database, privs: ALL, objs: appdb }
        - { db: appdb, type: schema, privs: ALL, objs: public }
  databases:
    - name: appdb
```

Each `privs` entry goes to
[`community.postgresql.postgresql_privs`](https://docs.ansible.com/ansible/latest/collections/community/postgresql/postgresql_privs_module.html),
connected to `db`. Each distinct `db` also gets one `pg_hba` line for the user,
from `ip`. A user can therefore log in only to the databases that its `privs`
name.

The role creates users and databases, and it never removes them. It does not
revoke a grant that you take out of `privs`.

`ip: samenet` lets in containers on the `postgres.network` network, and the
connections that docker-proxy relays (see [pg_hba.conf](#pg_hbaconf)). For a
client on another machine, use its address as CIDR, and add a `publish` entry.

### Replication

Streaming replication, over the published port of the primary. The standby
needs a `publish` entry on the primary and a `pg_hba` line for its own address.

```yaml
# primary
postgres:
  mode: primary
  publish: ["10.0.0.5:5432"]
  replication:
    password: "{{ vault_pg_replication }}"
    source: 10.0.0.6/32
    host: ""
    port: 5432
```
```yaml
# standby
postgres:
  mode: standby
  password: "{{ vault_pg_root }}" # the superuser of the primary
  replication:
    password: "{{ vault_pg_replication }}"
    source: ""
    host: 10.0.0.5
    port: 5432
  exporter:
    password: "{{ vault_pg_exporter }}" # the same as on the primary
```

Deploy the primary before the standby. On a standby with an empty data
directory, the role runs `pg_basebackup --write-recovery-conf` as uid `999`. That
writes `standby.signal` and `primary_conninfo` into the cluster. The role then
checks the major of the copy, and it stops when the primary runs another major
than `version`. After that, the
role does not touch the connection settings. A new primary address or a new
replication password needs a new base backup:

1. Stop the standby project: `docker compose --project-directory <ansible> down`.
2. Move `<data>/<major>` out of the data directory.
3. Run the role again.

The standby streams with no replication slot. `wal_keep_size=512MB` on the
primary is what lets a standby catch up after a short outage. For a longer
outage, set a bigger `wal_keep_size` in `config`, or take a new base backup.

The superuser, the `prom-exporter` login and every other login replicate from
the primary. So a standby needs the same `password` and `exporter.password` as
its primary.

### Major upgrades

Each cluster lives in `<data>/<major>/docker`. The compose file sets `PGDATA` to
that path for every version, and the data directory is one mount at
`/var/lib/postgresql`.

When the data directory holds a cluster of an older major, and none of the
major in `version`, the role upgrades it:

1. It stops the compose project. The image stops with SIGINT, a fast shutdown,
   and compose waits up to 2 minutes for it.
2. It runs `pg_upgrade --link` in `<upgrade_image>:<old>-to-<new>`, into
   `<data>/<new>/upgrading`. The new cluster gets the same bootstrap superuser
   and the same data checksum setting as the old one.
3. It renames `upgrading` to `docker`, starts the new server, and runs
   `vacuumdb --all --analyze-in-stages`. A marker file,
   `<data>/<new>/analyze_pending`, keeps this step for the next run when the
   current run fails before it.

`--link` makes hard links, so the upgrade is fast and needs almost no free
space. It also means that the old cluster must not start again.
`pg_upgrade` renames its `global/pg_control` to `pg_control.old` for that
reason. The role leaves `<data>/<old>` on disk. Remove it after you check the
new server. Do not run the `delete_old_cluster.sh` that `pg_upgrade` leaves in
the data directory: it holds the paths inside the container, not the host paths.

The role stops, and changes nothing, in these cases:

- **A standby with an older cluster.** `pg_upgrade` cannot upgrade a standby.
  Upgrade the primary first, then take a new base backup (see
  [Replication](#replication)).
- **A leftover `<data>/<new>/upgrading`.** An earlier upgrade did not finish.
  The old cluster is still usable while its `global/pg_control` exists. Read
  `upgrading/pg_upgrade_output.d`, remove `upgrading`, and run the role again.
- **A cluster newer than `version`.** A cluster cannot go to an older major.
- **`<data>/PG_VERSION`.** That is the layout of the old role. See the next
  section.

Before 18, the image also declares a `VOLUME` at `/var/lib/postgresql/data`. On
those versions docker creates an empty anonymous volume there. The role does
not use it.

### Moving from the old role

The old role kept its cluster at the top of `<dir.data>/postgres-<name>`, and
its compose project in `<dir.ansible>/postgres-<name>`. The new role refuses
that layout. Move the cluster once, by hand:

1. Stop the old project:
   `docker compose --project-directory <dir.ansible>/postgres-<name> down`.
2. Read the major of the cluster: `cat <dir.data>/postgres-<name>/PG_VERSION`.
3. Make the new directory: `mkdir -p <new data>/<major>`.
4. Move the cluster: `mv <dir.data>/postgres-<name> <new data>/<major>/docker`.
5. Make the new data directory owned by `999:999`, with mode `0700`.
6. Set the new vars. Keep `username` and `password` from the old vars.
7. Run the role. With `version` on a newer major, it upgrades the cluster.

The old role overwrote the `pg_hba.conf` and `postgresql.conf` in the data
directory. The new role mounts its own `pg_hba.conf`, so the old one has no
effect. The server still reads the old `postgresql.conf` from the cluster:

- **With an upgrade**, `pg_upgrade` makes a new cluster with a new
  `postgresql.conf` from `initdb`. Nothing else to do.
- **On the same major**, the old file stays in force. Its `listen_addresses`
  names the host address, which does not exist inside the container, so the
  server listens on `localhost` only and the role cannot reach it. Add
  `listen_addresses: "*"` to `config`.

After step 7, the role no longer needs `<dir.ansible>/postgres-<name>`. Remove it.

On a standby of the old role, do not move the data. Take a new base backup from
the upgraded primary instead.

### Effects
- installs `python3-psycopg2` on the host — the `community.postgresql` modules run there
- creates and manages `{{ postgres.directories.ansible }}` — the compose project
  and `config/pg_hba.conf`
- creates `{{ postgres.directories.ansible }}/run`, owned by `999:999`, mode
  `3775` — the socket directory of the server
- creates `{{ postgres.directories.data }}`, owned by `999:999`, mode `0700`
- deploys docker compose project named after `directories.ansible`, with
  containers `postgres` and, with the exporter on, `exporter`
- on an upgrade: runs a one-shot `upgrade_image` container
- on a new standby: runs a one-shot `pg_basebackup` container

#### Docker networks
- creates `{{ postgres.network }}`, which is what consumers attach to

### Networking
- publishes `5432` on each `publish` binding, and nothing when it is empty
- `postgres:5432` on `{{ postgres.network }}`
- `exporter:9187` on `{{ postgres.network }}`, with the exporter on

### Handlers
- `restart postgres` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `exporter.enabled`, a `postgres_exporter` sidecar answers on port `9187` at
`/metrics`, labelled for the collection's prometheus autodiscovery. It logs in as
`prom-exporter`, a member of `pg_monitor`. The port is not published: the scrape
comes from vmagent, which runs on the host network and reaches the container
over the bridge.

`pg_up` is the one to alert on. An exporter that reaches the server but cannot
log in reports `0` rather than failing to be scraped.
