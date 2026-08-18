# pulsar
__Tags - `pulsar`__

Deploys an [Apache Pulsar](https://pulsar.apache.org/) broker as a docker compose
project — one broker per host, a single broker by default and a cluster as soon
as a second host points at the same ZooKeeper.

Uses the official [`apachepulsar/pulsar`](https://hub.docker.com/r/apachepulsar/pulsar)
image and runs as uid `10000`, gid `0` — the `pulsar` user inside it.

Needs a ZooKeeper and a BookKeeper. Use the [`zookeeper`](../zookeeper) and
[`bookkeeper`](../bookkeeper) roles: the defaults read their client port and
ledgers path straight out of their vars.

This role also initialises the cluster metadata, which used to be a separate
`pulsar_init` role.

### Usage
```yaml
    - alesharik.baseinfra.zookeeper
    - alesharik.baseinfra.bookkeeper
    - alesharik.baseinfra.pulsar
```
```yaml
pulsar:
  networks:
    - zookeeper
    - bookkeeper
  advertised_ip: "{{ ansible_default_ipv4.address }}" # only for a cluster
```

### Addresses and networks

The role **creates no docker network**. What it talks to is an address, and how
it can get there is `networks` — a list of networks that already exist, joined as
external and in the order given.

```yaml
pulsar:
  networks: [zookeeper, bookkeeper]     # joined, never created
  zookeeper:
    servers: "zookeeper:2181"           # a name, resolved on those networks
```

```yaml
pulsar:
  networks: []                          # nothing joined but the compose default
  zookeeper:
    servers: "10.0.0.11:2181,10.0.0.12:2181"   # routable addresses
```

Both work. A **name** in `zookeeper.servers` has to resolve on one of `networks`;
an **address** only has to be routable from the container, and then `networks` can
be empty.

Two consequences worth knowing:

- The broker is a BookKeeper **client**. It reads the bookie roster out of
  ZooKeeper and then dials each bookie *at the address that bookie registered
  itself under* — which this role never sees. So reaching ZooKeeper is not
  enough: whatever those registrations say has to be reachable too. With the
  `bookkeeper` role that is its `advertised_ip`, or its compose service name when
  that is empty, in which case its network has to be in `networks`.
- The metrics label names `networks[0]`, because a scraper has to be on the
  network it reaches the container through. Put the network vmagent is on first.
  With `networks` empty no such label is written.

The one-shot cluster-metadata init runs on the same networks, so it reaches
`zookeeper.servers` exactly as the broker will. Joining more than one network at
`docker run` needs Docker 25 or newer.

### Vars
```yaml
pulsar:
  image: apachepulsar/pulsar
  version: "4.2.1"
  cluster_name: cluster-a # the name in the metadata; see below before changing
  advertised_ip: "" # address other hosts reach this broker at; empty = one host
  networks: [] # existing docker networks to join; the role creates none
  broker_port: 6650 # where clients produce and consume
  web_port: 8080 # admin REST API, and /metrics/
  zookeeper:
    servers: "zookeeper:{{ zookeeper.client_port | default(2181) }}"
  bookkeeper:
    ledgers_path: "{{ bookkeeper.zookeeper.ledgers_path | default('/ledgers') }}"
    num_storage_containers: "{{ bookkeeper.stream_storage.num_storage_containers | default(8) }}"
  managed_ledger:
    ensemble_size: 1 # 1/1/1 is one bookie; 3/2/2 needs three
    write_quorum: 1
    ack_quorum: 1
  functions_worker:
    enabled: false # embedded in the broker process, not a container of its own
    state_storage_url: "bk://bookkeeper:{{ bookkeeper.stream_storage.grpc_port | default(4181) }}"
    num_package_replicas: 1
  metrics:
    enabled: true
  jvm:
    mem_opts: "-Xms512m -Xmx512m -XX:MaxDirectMemorySize=256m"
    gc_opts: "-XX:+UseShenandoahGC"
  config: {} # extra broker.conf settings, key: value
  directories:
    ansible: "{{ dir.ansible }}/pulsar" # compose project on the host
    functions: "{{ dir.data }}/pulsar/functions" # mounted at /pulsar/download
```
`pulsar` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

### Single broker and cluster

There is no member list in this role. A broker registers itself in ZooKeeper on
startup and clients read the roster from there, so a cluster is simply more hosts
running this role against the same ensemble. What separates the two cases is one
var:

```yaml
pulsar:
  advertised_ip: "{{ ansible_default_ipv4.address }}"
```

`advertised_ip` is the address the broker registers itself under — what every
client is then handed, **including a client that asked a different broker**. Each
topic is owned by exactly one broker at a time, and a lookup against any of them
answers with the owner's advertised address; so a cluster whose brokers advertise
names only they can resolve fails on the redirect rather than on the connection.
Empty, the broker advertises the compose service name `broker`, which resolves
only on the networks it joined and nowhere else: right for a single host, useless
to anything off it. Set, the role also publishes `broker_port` and `web_port` on
that address — both, because a client needs the topic and the admin API.

A cluster wants two things beyond that:

- **an ensemble**, not a standalone ZooKeeper — the metadata is the cluster
- **`managed_ledger` sizes** that fit the number of bookies. `1/1/1` puts every
  topic on a single bookie, which a cluster of brokers does not make redundant.

The broker keeps **no state on disk**. Everything is in ZooKeeper and BookKeeper,
which is why `directories` has no data root: losing a broker loses nothing, and
the topics it owned are picked up by the others.

### `cluster_name`

The cluster's name is a path segment in the metadata store, and it is written
there once — by the init this role runs, on first converge.

Changing it afterwards does **not** rename the cluster. It creates a second,
empty one beside the first, and the broker joins that: every existing topic,
tenant and namespace is still in the metadata and nothing can reach it. Unlike
zookeeper's `myid` or bookkeeper's cookie there is no file on this host to check
the var against — the state lives only in ZooKeeper — so the role cannot fail on
it, and this paragraph is the whole of the warning.

What is there is in the metadata store:

```
docker exec <container> bin/pulsar zookeeper-shell -server <zk>:2181 ls /admin/clusters
```

### The cluster metadata init, and BookKeeper

The init this role runs is `bin/pulsar initialize-cluster-metadata`, once per
converge — it is idempotent, and reports the same success whether it created the
metadata or found it.

It is passed `--existing-bk-metadata-service-uri`, which is what stops it
initialising BookKeeper's **ledger** metadata: that belongs to the `bookkeeper`
role, and without the flag this command would create its own at its own default
path.

It still initialises BookKeeper's **stream** metadata — the table service's —
whenever it finds none, whether or not this deployment runs a table service. That
is why `bookkeeper.num_storage_containers` is a var here and reads off the
`bookkeeper` role: left to its own default the command picks 16 where that role
picks 8, and the count is fixed by whichever ran first. Keeping them equal means
turning `bookkeeper`'s `stream_storage` on later still gets the count that role
asks for.

### Metrics

With `metrics.enabled`, the broker serves metrics on `web_port`, labelled for the
collection's prometheus autodiscovery. It binds no separate metrics port. The port
is not published: the scrape comes from vmagent, which runs on the host network
and reaches the container over the bridge.

The path is **`/metrics/`**, with the trailing slash — `/metrics` answers `301`
to it. That is what the `prometheus.io.path` label carries, so dropping the slash
costs a redirect on every scrape and breaks any collector that does not follow
one.

The same server answers the admin API, which is the readable account of a
broker's state:

```
curl http://<broker>:8080/admin/v2/brokers/health
curl http://<broker>:8080/admin/v2/clusters
curl http://<broker>:8080/admin/v2/brokers/cluster-a
```

`brokers/<cluster>` is the cluster's own roster — the answer to whether every
broker actually joined.

### Health

The container healthcheck is `/admin/v2/brokers/health`, which **produces and
consumes a message on a system topic**. That makes it an end-to-end check rather
than a liveness one: a broker whose bookies are unreachable fails it while still
holding its ports open, which a port check would call healthy. It is also why
`start_period` is 90s — a broker loads its metadata, claims its bundles and waits
for bookies before it answers this at all.

### The functions worker

`functions_worker` runs Pulsar Functions **inside the broker's own process**
rather than as a worker deployment of its own. It is off by default. On, it needs
BookKeeper's table service — that is where a function's state, what its context's
`putState` and `getState` reach, is kept:

```yaml
pulsar:
  functions_worker:
    enabled: true
```

The table service is `bookkeeper`'s `stream_storage`, which that role ships **on**.
A bookkeeper deployed with it off has nothing listening on `state_storage_url`
and functions that keep state fail at runtime. Note also that the table service is
local to its own host's docker network, so in a cluster only a broker co-located
with a bookie running it can reach the default URL.

`num_package_replicas` is a ledger count like the managed ledger sizes, and the
role rejects one larger than `managed_ledger.ensemble_size`.

The worker's config is the image's own `conf/functions_worker.yml`, **patched**
in place by `gen-yml-from-env.py` from the `PF_` variables the role sets — the
same arrangement `broker.conf` has with `apply-config-from-env.py`. The role sets
three keys: `numFunctionPackageReplicas`, `downloadDirectory` and
`stateStorageServiceUrl`. Everything else is the image's.

It is patched rather than replaced because **the worker's defaults live in that
YAML file, not in its Java class**. A config written from scratch keeps only the
keys it names: `topicCompactionFrequencySec` falls back to `0`, and the broker
then dies during startup scheduling a task at that period, with nothing in the
message naming the file. The same is true of `failureCheckFreqMs` and the other
intervals — do not hand this role a hand-written worker config.

The worker's id, hostname and service URLs are **not** set here. Running inside
the broker, Pulsar derives all four from the broker's own configuration and
ignores whatever the file says.

### Config

`config` takes extra `broker.conf` settings as `key: value`:

```yaml
pulsar:
  config:
    brokerDeduplicationEnabled: "true"
    subscriptionExpirationTimeMinutes: 1440
```

Each becomes a `PULSAR_PREFIX_<key>` variable. The image applies these with
`apply-config-from-env.py`, which rewrites the line a key already has in the
shipped `broker.conf` and **appends** one that is not there — the bare form only
does the first, which is why the role uses the prefix. So an arbitrary setting
does land, whether or not the shipped file mentions it. To read back what the
broker actually got:

```
docker exec <container> grep '^<key>=' /pulsar/conf/broker.conf
```

Settings the role owns are rejected rather than silently fighting the vars they
came from: the cluster name, the two metadata store URLs, the bookkeeper service
URI, the advertised address, both ports, the managed ledger sizes and the
functions worker switch. Use the var.

Anything not named in the vars above keeps the image's default.

### Running two instances on one host

There is no `name` var. A second instance is a second `pulsar` dict with its own
`directories`, and its own `networks` if it is to be reached separately:

```yaml
pulsar:
  networks: [zookeeper-second, bookkeeper-second]
  directories:
    ansible: "{{ dir.ansible }}/pulsar-second"
    functions: "{{ dir.data }}/pulsar-second/functions"
```

compose names the project after `directories.ansible`, so that also renames the
container to `pulsar-second-broker-1` and keeps the two apart in the metrics
`instance` label. Both would advertise the service name `broker` on whatever
networks they join, so give them distinct `advertised_ip` values
if they are to share one cluster.

### Effects
- creates and manages `{{ pulsar.directories.ansible }}` — the compose project
- creates `{{ pulsar.directories.functions }}`, owned by `10000:0`, with the
  functions worker on
- initialises the cluster metadata for `{{ pulsar.cluster_name }}` in ZooKeeper,
  recording BookKeeper's existing metadata rather than creating its own
- deploys a docker compose project named after `directories.ansible`, with a
  single container `broker`

#### Docker networks
- **creates none.** Every entry of `networks` is joined as an external network
  and has to exist already

### Networking
- `broker:{{ pulsar.broker_port }}` on each of `networks`; with none listed, on
  the compose project's own default network
- publishes `broker_port` and `web_port` on `advertised_ip`; nothing if that is
  empty

### Handlers
- `restart pulsar` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- a ZooKeeper, which `zookeeper` provides
- a BookKeeper, which `bookkeeper` provides
