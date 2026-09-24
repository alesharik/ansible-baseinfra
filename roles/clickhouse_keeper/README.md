# clickhouse_keeper
__Tags - `clickhouse_keeper`__

Deploys [ClickHouse Keeper](https://clickhouse.com/docs/guides/sre/keeper/clickhouse-keeper)
as a docker compose project. It runs as a single server by default, and as a raft
ensemble when `quorum` names hosts.

The [`clickhouse`](../clickhouse/README.md) role uses it in cluster mode, for
replicated tables and `ON CLUSTER` queries.

Uses the official `clickhouse/clickhouse-keeper` image and runs as uid `101`,
gid `101` — the `clickhouse` user inside it.

### Usage
```yaml
    - alesharik.baseinfra.clickhouse_keeper
```

### Vars
```yaml
clickhouse_keeper:
  image: clickhouse/clickhouse-keeper
  version: "26.8.10.6"
  id: 1 # raft server_id, unique across the ensemble
  peer_ip: "" # address the other members and clickhouse dial; required once quorum is set
  quorum: [] # inventory hostnames of every member; empty = single server
  listen_ips: [] # host IPs the client port is published on
  network: clickhouse-keeper # the docker network the role creates
  client_port: 9181
  raft_port: 9234
  four_lw_commands: "ruok,mntr,srvr,stat,conf" # must keep ruok - the healthcheck uses it
  coordination: {} # extra <coordination_settings>, setting: value
  metrics:
    enabled: true
    port: 9363
  directories:
    ansible: "{{ dir.ansible }}/clickhouse_keeper" # compose project on the host
    data: "{{ dir.data }}/clickhouse_keeper" # mounted at /var/lib/clickhouse
```
`clickhouse_keeper` is a **wholesale override** — setting it replaces the
defaults, there is no deep merge. List every key above, not only the ones you
change.

### Single server and ensemble

With `quorum: []` the role runs one keeper. It needs no `peer_ip`, and the raft
port is not published.

With `quorum` set, each member builds the raft configuration from every member's
`id`, `peer_ip` and `raft_port` in `hostvars`. So all members must be in the
inventory:

```yaml
clickhouse_keeper:
  quorum:
    - keeper-1
    - keeper-2
    - keeper-3
  peer_ip: "{{ ansible_default_ipv4.address }}"
```

Set `id` per host. Use an **odd** number of members. A quorum is a strict
majority, so three members tolerate one failure and two members tolerate none.

Each member writes its own entry with its real `peer_ip` too. This is different
from the `zookeeper` role, which writes `0.0.0.0` there. The leader's entry goes
into the raft log, and a follower forwards client sessions to that address. With
`0.0.0.0` a follower sends them to itself and rejects every client. The keeper
binds the raft port on every interface, so the container needs no host address.

### Config

The role writes `keeper_config.d/ansible.xml`, and the keeper merges it over the
image's `keeper_config.xml`. Anything not set there keeps the image default.
`coordination` adds settings to `<coordination_settings>`:

```yaml
clickhouse_keeper:
  coordination:
    session_timeout_ms: 30000
    raft_logs_level: warning
```

The keeper logs to the console at `information` level. The image default logs
to files inside the container at `trace` level.

### Effects
- creates and manages `{{ clickhouse_keeper.directories.ansible }}` — the compose project
- creates `{{ clickhouse_keeper.directories.data }}`, owned by `101:101`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `clickhouse_keeper`

#### Docker networks
- creates `{{ clickhouse_keeper.network }}`

### Networking
- `clickhouse_keeper:{{ clickhouse_keeper.client_port }}` on `{{ clickhouse_keeper.network }}`
- publishes the client port on each of `listen_ips`, nothing if that is empty
- with a quorum, publishes `raft_port` on `peer_ip`

A clickhouse server on another host reaches the keeper at
`peer_ip:client_port`. So in cluster mode, put `peer_ip` into `listen_ips`.

### Handlers
- `restart clickhouse_keeper` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `metrics.enabled`, the keeper serves `/metrics` on `metrics.port`, with
labels for the collection's prometheus autodiscovery. The port is not published.

### Health
The container healthcheck sends `ruok` to the client port and expects `imok`.
That is a **liveness** check: the keeper answers while it still looks for a
leader. To see whether a member joined the ensemble, ask `mntr` and read
`zk_server_state`:

```
echo mntr | nc -w 2 <host> 9181
```
