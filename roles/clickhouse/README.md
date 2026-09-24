# clickhouse
__Tags - `clickhouse`__

Deploys [ClickHouse](https://clickhouse.com/) as a docker compose project. It
runs as a single server by default, and as a sharded, replicated cluster when
`cluster.name` is set.

Uses the official `clickhouse/clickhouse-server` image and runs as uid `1002`,
gid `1002`, as earlier versions of this role did. The image's own `clickhouse`
user is `101`, but existing data directories belong to `1002`.

### Usage
```yaml
    - alesharik.baseinfra.clickhouse
```
```yaml
clickhouse:
  root:
    user: root
    password: pwd
```
The `clickhouse` dict is a wholesale override, so a real config lists every key
in [Vars](#vars).

### Vars
```yaml
clickhouse:
  image: clickhouse/clickhouse-server
  version: "26.8.10.6"
  network: clickhouse # the docker network the role creates
  listen_ips: [] # host IPs the HTTP (8123) and native (9000) ports are published on
  root: # admin login; the entrypoint creates it and removes `default`
    user: root
    password: "" # required
  users: {} # name: {password, grants: [...]}
  databases: [] # created with CREATE DATABASE IF NOT EXISTS
  config: {} # extra top-level server settings, setting: value
  metrics:
    enabled: true
    port: 9363
  cluster:
    name: "" # empty = single server
    hosts: [] # inventory hostnames of every server, this host included
    shard: 1 # this server's shard; hosts with the same shard are replicas
    peer_ip: "" # address the other servers dial
    secret: "" # shared by all servers
    keeper: [] # inventory hostnames of the clickhouse_keeper ensemble
  directories:
    ansible: "{{ dir.ansible }}/clickhouse" # compose project on the host
    data: "{{ dir.data }}/clickhouse" # mounted at /var/lib/clickhouse
```
`clickhouse` is a **wholesale override** — setting it replaces the defaults,
there is no deep merge. List every key above, not only the ones you change.

Example users and databases:
```yaml
clickhouse:
  databases:
    - events
  users:
    app:
      password: pass
      grants:
        - GRANT ALL ON events.*
```

User passwords are stored as `password_sha256_hex`. The root password goes into
a file that the entrypoint reads through `CLICKHOUSE_PASSWORD_FILE`.

`config` adds top-level settings with scalar values, for example
`max_concurrent_queries: 200`. It does not take nested sections.

### Cluster mode

Set `cluster.name` on every server. Each server builds `remote_servers` from the
`cluster` dict of every host in `cluster.hosts`, read from `hostvars`. Hosts
with the same `shard` are replicas of that shard:

```yaml
# group_vars - the same on every server
clickhouse:
  cluster:
    name: main
    hosts: [ch-1, ch-2, ch-3, ch-4]
    secret: "{{ vault_clickhouse_cluster_secret }}"
    keeper: [keeper-1, keeper-2, keeper-3]
    peer_ip: "{{ ansible_default_ipv4.address }}"
    shard: "{{ clickhouse_shard }}" # 1 on ch-1 and ch-2, 2 on ch-3 and ch-4
```

The role then sets:
- the macros `{cluster}`, `{shard}` and `{replica}`. `{replica}` is the
  inventory hostname.
- `internal_replication` on each shard, so a `Distributed` table writes to one
  replica and `ReplicatedMergeTree` copies the data.
- `secret` on the cluster, for distributed queries between servers.
- `interserver_http_credentials` from the same secret, for replica fetches on 9009.
- `<zookeeper>` with the `peer_ip` and `client_port` of every `cluster.keeper`
  host, read from their `clickhouse_keeper` dict. Deploy the keeper with the
  [`clickhouse_keeper`](../clickhouse_keeper/README.md) role, and put its
  `peer_ip` into its `listen_ips`, so the client port is published there.

A replicated table and a distributed table over it:
```sql
CREATE TABLE events.hits ON CLUSTER '{cluster}' (id UInt64)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events/hits', '{replica}')
ORDER BY id;

CREATE TABLE events.hits_all ON CLUSTER '{cluster}' AS events.hits
ENGINE = Distributed('{cluster}', events, hits, rand());
```

`remote_servers` names servers by **inventory hostname**, not by `peer_ip`. A
server runs an `ON CLUSTER` query only when it finds a local address among the
cluster hosts, and the host `peer_ip` is not local inside a container. So the
container gets `hostname: <inventory_hostname>`, which docker resolves to the
container, and `extra_hosts` entries that map the other names to their `peer_ip`.
For this reason inventory hostnames must be plain DNS names.

A remote server runs a distributed query as the user that started it. So
`root.user` must be the same on every server, and the role checks it. Give the
`users` the same names and passwords on every server too.

`databases` are created on each server, not `ON CLUSTER`. Every server runs the
role, so each one gets its own copy.

### Effects
- creates and manages `{{ clickhouse.directories.ansible }}` — the compose project
- creates `{{ clickhouse.directories.data }}`, owned by `1002:1002`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `clickhouse`
- removes `.env`, `init-defaults.sh` and `users/` in the compose dir. The
  earlier version of this role wrote them.

#### Docker networks
- creates `{{ clickhouse.network }}`

### Networking
- `clickhouse:8123` (HTTP) and `clickhouse:9000` (native) on `{{ clickhouse.network }}`
- publishes 8123 and 9000 on each of `listen_ips`
- in cluster mode, publishes 9000 and 9009 (interserver) on `cluster.peer_ip`

### Handlers
- `restart clickhouse` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- in cluster mode, a running [`clickhouse_keeper`](../clickhouse_keeper/README.md)

### Metrics
With `metrics.enabled`, the server serves `/metrics` on `metrics.port`, with
labels for the collection's prometheus autodiscovery. The port is not published.
