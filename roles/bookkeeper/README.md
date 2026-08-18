# bookkeeper
__Tags - `bookkeeper`__

Deploys [Apache BookKeeper](https://bookkeeper.apache.org/) as a docker compose
project — one bookie per host, a single bookie by default and a cluster as soon
as a second host points at the same ZooKeeper.

Uses the official [`apache/bookkeeper`](https://hub.docker.com/r/apache/bookkeeper)
image and runs as uid `10000`, gid `0` — the `bookkeeper` user inside it.

Needs a ZooKeeper. Use the [`zookeeper`](../zookeeper) role: the defaults read
its network and client port straight out of its vars.

### Usage
```yaml
    - alesharik.baseinfra.zookeeper
    - alesharik.baseinfra.bookkeeper
```
```yaml
bookkeeper:
  advertised_ip: "{{ ansible_default_ipv4.address }}" # only for a cluster
```

### Vars
```yaml
bookkeeper:
  image: apache/bookkeeper
  version: "4.18.0"
  advertised_ip: "" # address other hosts reach this bookie at; empty = one host
  network: bookkeeper # the docker network the role creates
  bookie_port: 3181
  zookeeper:
    network: "{{ zookeeper.network | default('zookeeper') }}" # "" attaches none
    servers: "zookeeper:{{ zookeeper.client_port | default(2181) }}"
    ledgers_path: /ledgers # znode the ledger metadata is rooted at
  http:
    enabled: true # admin server; /metrics comes from it
    port: 8080
  metrics:
    enabled: true # needs http.enabled
  auto_recovery: true # auditor and replication worker in the bookie's process
  disk_usage:
    threshold: 0.95 # bookie goes read-only past this
    warn_threshold: 0.9
  jvm:
    mem_opts: "-Xms512m -Xmx512m -XX:MaxDirectMemorySize=256m"
    gc_opts: "-XX:+UseShenandoahGC"
  stream_storage:
    enabled: true # the table service
    grpc_port: 4181
    num_storage_containers: 8 # fixed when the cluster is initialised
    ensemble_size: 1 # 1/1/1 is one bookie; upstream's 3/2/2 needs three
    write_quorum: 1
    ack_quorum: 1
  config: {} # extra bk_server.conf settings, key: value
  directories:
    ansible: "{{ dir.ansible }}/bookkeeper" # compose project on the host
    journal: "{{ dir.data }}/bookkeeper/journal" # mounted at /bookkeeper/journal
    ledgers: "{{ dir.data }}/bookkeeper/ledgers" # mounted at /bookkeeper/ledgers
    ranges: "{{ dir.data }}/bookkeeper/ranges" # mounted at /bookkeeper/ranges
```
`bookkeeper` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

### Single bookie and cluster

There is no member list in this role. A bookie registers itself in ZooKeeper on
startup and clients read the roster from there, so a cluster is simply more
hosts running this role against the same ensemble. What separates the two cases
is one var:

```yaml
bookkeeper:
  advertised_ip: "{{ ansible_default_ipv4.address }}"
```

`advertised_ip` is the address the bookie registers itself under — what every
client and every other bookie then dials. Empty, it advertises the compose
service name `bookkeeper`, which resolves on the role's own docker network and
nowhere else: right for a single host, useless to anything off it. Set, the role
also publishes `bookie_port` on that address.

A cluster wants three things beyond that:

- **an ensemble**, not a standalone ZooKeeper — the metadata is the cluster
- **`stream_storage` sizes** that fit, if the table service stays on (below)
- an **odd** number of bookies is *not* required. Ledger writes need
  `ackQuorum` bookies of the ensemble the client chose, and that is a client-side
  decision; there is no leader election among bookies, so three and four are both
  sensible.

`auto_recovery` is what makes a lost bookie a non-event: the auditor notices the
ledgers it held are now under-replicated and the replication worker copies them
back up to their write quorum from the remaining copies.

### `advertised_ip` and the cookie

On first start a bookie writes a **cookie** — beside its data in
`<directories.ledgers>/current/VERSION`, and in ZooKeeper under
`<ledgers_path>/cookies/`. It records the address the bookie claimed, and the
bookie refuses to start against a cookie that disagrees with its configuration:
it cannot tell having been renamed from having been handed another bookie's
disks.

The role checks this itself and fails with the two addresses named, rather than
leaving a container to restart-loop on an `InvalidCookieException`. Renaming a
bookie on purpose is a deliberate step:

```
docker exec <container> bookkeeper shell updatecookie -bookieId <new-ip>:3181
```

This is also why `advertised_ip` empty advertises the service name rather than
letting the bookie pick its own address: a container address changes on every
recreate, and each change would invalidate the cookie.

### Metrics

With `metrics.enabled`, BookKeeper's Prometheus provider serves `/metrics` **on
the admin server's port** (`http.port`, 8080), labelled for the collection's
prometheus autodiscovery. It does not bind a port of its own while that server
is enabled — `prometheusStatsHttpPort` in the shipped config is not the port to
scrape — so `metrics.enabled` requires `http.enabled`, and the role asserts it.

The same server answers the admin API, which is the readable account of a
bookie's state:

```
curl http://<bookie>:8080/api/v1/bookie/state
curl 'http://<bookie>:8080/api/v1/bookie/list_bookies?type=rw&print_hostnames=true'
```

`list_bookies` is the cluster's own roster — the answer to whether every bookie
actually joined. The container healthcheck uses `/api/v1/bookie/is_ready` from
the same server; with `http.enabled: false` it falls back to the image's
`bookiesanity` check, which starts a JVM per run and is slowed down accordingly.

### The table service

`stream_storage` is BookKeeper's table service — the key/value store layered on
the ledgers, and where Pulsar functions keep state. It is **on by default** and
**local to the host**: a range server registers itself in ZooKeeper under its own
address rather than `advertised_ip`, and the role pins that to the container
hostname `bookkeeper` — the same name this service answers to on both its
networks. Clients reach it there; nothing off the host can, because that name
only resolves inside docker. Turning it off in a cluster is reasonable:

```yaml
bookkeeper:
  stream_storage:
    enabled: false
```

Left on, `ensemble_size`, `write_quorum` and `ack_quorum` describe how the table
service replicates its own logs, and they have to fit the cluster — asking for
three bookies where there is one means it never creates a log. The role checks
the three sizes fall in that order; it cannot check them against a bookie count,
because nothing here counts bookies.

The metadata the table service needs is **not** created by the image's
entrypoint, which initialises the ledger metadata alone. A bookie that loads the
component against a cluster without it exits during startup. The role therefore
runs `bkctl cluster init` before starting the bookie, one host at a time; the
command is idempotent, so it runs on every converge. `num_storage_containers` is
written by that init and is fixed from then on — changing the var later does
nothing.

Pinning the registration takes one setting the image cannot apply from the
environment — `storageserver.grpc.useHostname` has no line in its shipped conf,
so the compose file appends it before the entrypoint runs, and sets the
container's `hostname` to match the service alias. Left alone, the range server
registers whichever of the container's addresses `/etc/hosts` lists first, and on
a bookie attached to both this role's network and ZooKeeper's that is as likely
to be the one its clients cannot reach.

Reaching it, from a container on the role's network:

```
bkctl -u bk://bookkeeper:4181 namespace create <ns>
bkctl -u bk://bookkeeper:4181 -n <ns> tables create <table>
bkctl -u bk://bookkeeper:4181 -n <ns> table put <table> <key> <value>
```

### Config

`config` takes extra `bk_server.conf` settings as `key: value`:

```yaml
bookkeeper:
  config:
    gcWaitTime: 900000
    journalMaxSizeMB: 2048
```

Each becomes a `BK_<key>` variable, which the image's entrypoint applies by
**rewriting the line that key already has in its shipped `bk_server.conf`**. A
key that is not in that file — commented or not — is dropped without a word. The
file covers some 224 settings, so most of what you would want is there, but
check it before assuming a setting took:

```
docker exec <container> grep '^<key>=' /opt/bookkeeper/conf/bk_server.conf
```

Settings the role owns are rejected rather than silently fighting the vars they
came from: paths, ports, the metadata URI, the advertised address, the stats and
table service settings. Use the var.

Anything not named in the vars above keeps the image's default.

### Running two instances on one host

There is no `name` var. A second instance is a second `bookkeeper` dict with its
own `network` and its own `directories`:

```yaml
bookkeeper:
  network: bookkeeper-second
  directories:
    ansible: "{{ dir.ansible }}/bookkeeper-second"
    journal: "{{ dir.data }}/bookkeeper-second/journal"
    ledgers: "{{ dir.data }}/bookkeeper-second/ledgers"
    ranges: "{{ dir.data }}/bookkeeper-second/ranges"
```

compose names the project after `directories.ansible`, so that also renames the
container to `bookkeeper-second-bookkeeper-1`, and `network` keeps the two apart
in docker and in the metrics `instance` label. Both would advertise the service
name `bookkeeper` on their own networks, so give them distinct `advertised_ip`
values if they are to share one cluster — and leave `stream_storage` on at most
one of them, because the table service registers itself under that same service
name and the second registration would overwrite the first.

### Effects
- creates and manages `{{ bookkeeper.directories.ansible }}` — the compose project
- creates `{{ bookkeeper.directories.journal }}` and
  `{{ bookkeeper.directories.ledgers }}`, owned by `10000:0`, and
  `{{ bookkeeper.directories.ranges }}` with the table service on
- initialises the cluster metadata in ZooKeeper, under
  `{{ bookkeeper.zookeeper.ledgers_path }}` and, with the table service on,
  `/stream`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `bookkeeper`

#### Docker networks
- creates `{{ bookkeeper.network }}`, which is what consumers attach to
- attaches to `{{ bookkeeper.zookeeper.network }}` as an external network, unless
  that is empty

### Networking
- `bookkeeper:{{ bookkeeper.bookie_port }}` on `{{ bookkeeper.network }}`
- publishes the bookie port on `advertised_ip`; nothing if that is empty
- the admin server listens on `{{ bookkeeper.http.port }}` inside the container
  and is never published
- the table service listens on `{{ bookkeeper.stream_storage.grpc_port }}` inside
  the container and is never published — see above for why publishing it would
  not help

### Handlers
- `restart bookkeeper` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- a ZooKeeper, which `zookeeper` provides
