# temporal
__Tags - `temporal`__

Deploys a [Temporal](https://temporal.io/) server as a docker compose project —
one container running the frontend, history, matching and worker services in a
single process, against an **external** PostgreSQL.

Uses the official [`temporalio/server`](https://hub.docker.com/r/temporalio/server)
image and runs as uid `1000`, gid `1000` — the `temporal` user inside it.

Needs a PostgreSQL with two databases already created. Use the
[`postgres`](../postgres) role — see [Reaching PostgreSQL](#reaching-postgresql),
which has the `pg_hba` details that decide whether this works at all.

### Usage
```yaml
    - alesharik.baseinfra.postgres
    - alesharik.baseinfra.temporal
```
```yaml
temporal:
  postgres:
    host: "{{ ansible_default_ipv4.address }}"
    password: "{{ vault_temporal_pg }}"
```

### Vars
```yaml
temporal:
  image: temporalio/server
  version: "1.31.2"
  admin_tools: # schema migrations and the namespace bootstrap
    image: temporalio/admin-tools
    version: "1.31.2" # keep in step with `version`
  network: temporal # the docker network this role creates
  advertised_ip: "" # address off-host clients reach the frontend at; empty = one host
  grpc_port: 7233 # where clients open workflows
  http_port: 7243 # the frontend's HTTP API
  membership:
    broadcast_address: "127.0.0.1" # a literal IP; see below before changing
    frontend_port: 6933
    history_port: 6934
    matching_port: 6935
    worker_port: 6939
  postgres:
    network: "" # existing network to join to reach it; empty joins none
    host: "{{ ansible_default_ipv4.address }}"
    port: 5432
    user: temporal
    password: "" # required
    database: temporal
    visibility_database: temporal_visibility
    max_conns: 20
    max_idle_conns: 20
    max_conn_lifetime: 1h
    visibility_max_conns: 10
    visibility_max_idle_conns: 10
    visibility_max_conn_lifetime: 1h
  num_history_shards: 4 # fixed on first start; see below
  cluster_name: active
  log_level: info
  namespaces:
    - name: default
      retention: 72h
  metrics:
    enabled: true
    port: 8000 # its own listener, not http_port
  dynamic_config: {}
  config: {} # extra temporal.yaml settings, deep-merged
  directories:
    ansible: "{{ dir.ansible }}/temporal"
```
`temporal` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

### Reaching PostgreSQL

This role **creates no database and no login role.** It migrates the schema into
two databases that have to exist already, and fails if they do not.

The default reaches the `postgres` role's primary on its published `5432`, over
this host's own address. The `postgres` role names its compose network after its
own project — `postgres-<name>_main` — and `postgres.name` has no default to fall
back to, so there is no network name here worth guessing at. To go over the
docker network instead:

```yaml
temporal:
  postgres:
    network: postgres-main_main   # whatever `postgres.name` makes it
    host: postgres                # the service name on that network
```

**The `postgres` role writes `pg_hba.conf` per user, per database, per source
address**, built from `postgres.users[].privs[].db` and `postgres.users[].ip`. So
the other half of this lives in that role's vars:

```yaml
postgres:
  users:
    - name: temporal
      password: "{{ vault_temporal_pg }}"
      ip: 172.0.0.0/8 # the container has to fall under this
      privs:
        - { db: temporal,            type: database, privs: ALL, objs: temporal }
        - { db: temporal_visibility, type: database, privs: ALL, objs: temporal_visibility }
  databases:
    - name: temporal
    - name: temporal_visibility
```

Both databases. A missing grant on `temporal_visibility` does not stop the server
starting and does not stop a workflow running — it surfaces the first time
anything lists workflows, which may be much later.

Whether those `pg_hba` rules are actually *in force* depends on the PostgreSQL
image. The `postgres` role delivers them by writing into its data directory
mount, which is `/var/lib/postgresql/data` — that is `PGDATA` up to PostgreSQL
17, but **PostgreSQL 18 moved `PGDATA` to `/var/lib/postgresql/18/docker`**. On
18 the file the role writes is not the one the server reads, and the image's own
default (`host all all all scram-sha-256`) applies instead — which happens to
let this role connect with nothing else configured. Check before relying on
either:

```
docker exec <postgres container> psql -U <user> -tAc 'show hba_file'
```

What this role needs is true regardless: the login role and **both** databases
have to exist, and the credentials have to work from the container.

### Namespaces

`namespaces` are **created, never reconciled.** Each is registered once with
`temporal operator namespace create`; on a namespace that already exists that
command exits 1 and says so, which the role treats as unchanged.

Changing `retention` on a namespace already registered therefore does nothing.
Change it by hand:

```
docker run --rm --network temporal temporalio/admin-tools:1.31.2 \
  temporal operator namespace update --address temporal:7233 -n default --retention 168h
```

### Config

`config` takes extra `temporal.yaml` settings and is deep-merged into the
rendered document:

```yaml
temporal:
  config:
    archival:
      history:
        state: enabled
        enableRead: true
```

Settings the role owns are **rejected** rather than silently fighting the vars
they came from: the shard count and both datastores, the membership block and
the metrics block, the four services' rpc ports and binds, the cluster names and
cluster information, the public client address and the dynamic config path. Each
of those also decides what is published, which network is joined, or what the
schema migration connects to. Use the var.

Anything not named in the vars above keeps Temporal's own default.

### Dynamic config

`dynamic_config` is written to a file the server polls every 60 seconds, in
Temporal's own format — each key maps to a list of constrained values:

```yaml
temporal:
  dynamic_config:
    limit.maxIDLength:
      - value: 255
    system.forceSearchAttributesCacheRefreshOnRead:
      - value: true
```

### Metrics

With `metrics.enabled`, the server binds a prometheus listener on `metrics.port`
— **its own listener**, separate from both `grpc_port` and `http_port`, and the
container carries the labels the collection's autodiscovery reads. The port is
not published: the scrape comes from vmagent, which runs on the host network and
reaches the container over the bridge.

`prometheus.io.network` names the network this role creates, never a joined
`postgres.network` — a scraper has to be on the network it reaches the container
through.

### Effects
- creates and manages `{{ temporal.directories.ansible }}` — the compose project,
  `temporal.yaml` (`0400`, owned by `1000`) and `dynamicconfig.yaml`
- migrates the schema in `postgres.database` and `postgres.visibility_database`
- registers every entry of `namespaces`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `temporal`

#### Docker networks
- **creates `{{ temporal.network }}`**
- joins `postgres.network` as external when it is set; that one has to exist

### Networking
- `temporal:{{ temporal.grpc_port }}` on `{{ temporal.network }}`
- publishes `grpc_port` and `http_port` on `advertised_ip`; nothing if it is empty

### Handlers
- `restart temporal` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- a PostgreSQL with both databases created, which `postgres` provides
