# zookeeper
__Tags - `zookeeper`__

Deploys [Apache ZooKeeper](https://zookeeper.apache.org/) as a docker compose
project, standalone by default and as an ensemble when `quorum` names more than
one host.

Uses the Docker Official [`zookeeper`](https://hub.docker.com/_/zookeeper) image
and runs as uid `1000`, gid `1000` — the `zookeeper` user inside it.

Metrics come from ZooKeeper's own built-in `PrometheusMetricsProvider`, so there
is no sidecar exporter.

### Usage
```yaml
    - alesharik.baseinfra.zookeeper
```
```yaml
zookeeper:
  listen_ips:
    - "{{ ansible_default_ipv4.address }}"
```

### Vars
```yaml
zookeeper:
  image: zookeeper
  version: "3.9.5"
  id: 1 # this server's myid, 1..255, unique across the ensemble
  peer_ip: "" # address the other members dial; required once quorum is set
  quorum: [] # inventory hostnames of every member; empty = standalone
  listen_ips: [] # host IPs the client port is published on
  network: zookeeper # the docker network the role creates
  client_port: 2181
  tick_time: 2000
  init_limit: 5
  sync_limit: 2
  max_client_cnxns: 60
  autopurge:
    purge_interval: 1 # hours; the image ships 0, meaning never
    snap_retain_count: 3
  four_lw_commands: "srvr,ruok,mntr" # must keep ruok - the healthcheck uses it
  admin_server: true # AdminServer on 8080, not published
  jvm_flags: "-XX:+UseShenandoahGC -Xmx512m"
  config: [] # extra zoo.cfg "key=value" entries, each free of whitespace
  metrics:
    enabled: true
    port: 7070
  directories:
    ansible: "{{ dir.ansible }}/zookeeper" # compose project on the host
    data: "{{ dir.data }}/zookeeper/data" # mounted at /data
    datalog: "{{ dir.data }}/zookeeper/datalog" # mounted at /datalog
    logs: "{{ dir.data }}/zookeeper/logs" # mounted at /logs
```
`zookeeper` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

### Standalone and ensemble

With `quorum: []` the role runs one server in ZooKeeper's standalone mode. It
needs no `peer_ip`, and the peer and election ports are never bound.

With `quorum` naming two or more hosts, each member renders the full server list
by reading every other member's `id`, `peer_ip` and `client_port` out of
`hostvars`, so all members must be in the same play:

```yaml
zookeeper:
  quorum:
    - zk-1
    - zk-2
    - zk-3
  peer_ip: "{{ ansible_default_ipv4.address }}"
```

with `id` set per host. Use an **odd** number of members: a quorum is a strict
majority, so three members tolerate one failure while two tolerate none — a
two-member ensemble is less available than a single server, not more.

Each member's own entry in the server list is written as `0.0.0.0` rather than
its `peer_ip`. That address is the one the server *binds*, and a container cannot
bind the host address its peer ports are published on; the other members still
dial the real `peer_ip` from their own copy of the list. ZooKeeper knows which
entry is its own from `myid`, not from the address, so nothing is lost.

### `id` and `myid`

`id` is written to `<directories.data>/myid` by the image's entrypoint — but only
when that file does not already exist. Changing `id` on a server that has run
before would therefore be silently ignored: the container would keep its old
identity while the rest of the ensemble addressed it by the new one. The role
fails instead, and renumbering a live member means removing its data directory
and letting it resynchronise from the others.

### Config

`config` takes extra `zoo.cfg` directives as `key=value` strings:

```yaml
zookeeper:
  config:
    - "maxSessionTimeout=60000"
    - "preAllocSize=131072"
```

It is a **list of whitespace-free entries**, not a free-form block. The image's
entrypoint expands it with `for entry in $ZOO_CFG_EXTRA`, so it word-splits and
writes one line per word — an entry containing a space would quietly become two
broken directives. The role rejects one that does.

There is no `clientPort` directive to set here. The entrypoint never writes one;
the client port comes from the `;<port>` suffix the role puts on the server
entry, and setting both forms would conflict. Use `client_port`.

Anything not named in the vars above keeps the image's default.

### Running two instances on one host

There is no `name` var. A second instance is a second `zookeeper` dict with its
own `network` and its own `directories`:

```yaml
zookeeper:
  network: zookeeper-kafka
  directories:
    ansible: "{{ dir.ansible }}/zookeeper-kafka"
    data: "{{ dir.data }}/zookeeper-kafka/data"
    datalog: "{{ dir.data }}/zookeeper-kafka/datalog"
    logs: "{{ dir.data }}/zookeeper-kafka/logs"
```

compose names the project after `directories.ansible`, so that also renames the
container to `zookeeper-kafka-zookeeper-1`, and `network` keeps the two instances
apart in docker and in the metrics `instance` label.

### Effects
- creates and manages `{{ zookeeper.directories.ansible }}` — the compose project
- creates `{{ zookeeper.directories.data }}`, `{{ zookeeper.directories.datalog }}`
  and `{{ zookeeper.directories.logs }}`, owned by `1000:1000`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `zookeeper`

#### Docker networks
- creates `{{ zookeeper.network }}`, which is what consumers attach to

### Networking
- `zookeeper:{{ zookeeper.client_port }}` on `{{ zookeeper.network }}`
- publishes the client port on each of `listen_ips`; nothing if that is empty
- with a quorum, publishes `2888` (peer) and `3888` (election) on `peer_ip`
- the AdminServer listens on `8080` inside the container and is never published

### Handlers
- `restart zookeeper` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `metrics.enabled`, ZooKeeper's built-in `PrometheusMetricsProvider` serves
`/metrics` on `metrics.port`, labelled for the collection's prometheus
autodiscovery. The port is not published: the scrape comes from vmagent, which
runs on the host network and reaches the container over the bridge.

The series carry **no `zk_` prefix** — that prefix belongs to the `mntr`
four-letter-word output, which is a different interface. `quorum_size` and
`znode_count` are the names to expect.

### Health

The container healthcheck sends `ruok` to the client port and expects `imok`.
That is a **liveness** check: ZooKeeper answers `ruok` as soon as the process is
up and the port is bound, including while it is still LOOKING for a quorum. For
whether a member is actually in quorum, ask `mntr` and read `zk_server_state` —
`leader` or `follower` in an ensemble, `standalone` on a single server:

```
echo mntr | nc -w 2 <host> 2181
```

Both commands have to stay in `four_lw_commands` to work; the default list has
them.
