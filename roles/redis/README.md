# redis
__Tags - `redis`__

Deploys a single-node [redis](https://redis.io/) as a docker compose project,
with an optional prometheus exporter.

Runs as uid `999`, gid `1000` — the `redis` user inside the official image.

For [valkey](https://valkey.io/), use the [`valkey`](../valkey/README.md) role.
It is the same role with valkey's names and image; the two can run side by side.

### Usage
```yaml
    - alesharik.baseinfra.redis
```
```yaml
redis:
  password: pass
```

### Vars
```yaml
redis:
  image: redis
  version: 8.10-alpine
  password: "" # empty means no requirepass at all
  network: redis # the docker network the role creates
  config: "" # extra redis.conf directives, appended verbatim
  overcommit_memory: true # set vm.overcommit_memory=1 on the host
  exporter:
    enabled: true
    image: oliver006/redis_exporter
    version: v1.89.0
  directories:
    ansible: "{{ dir.ansible }}/redis" # compose project on the host
    data: "{{ dir.data }}/redis" # mounted at /data
```
`redis` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

### Password

`password` is optional. Empty writes no `requirepass` line at all, which is how
the upstream image ships: the role publishes no host port, so the server is only
reachable from its own docker network. Anything on that network can then read
and write the whole keyspace, so set a password whenever that network is shared
with something you do not control.

It is written into `redis.conf`, which is `0400` and owned by uid `999` — the
container's own user reads it, and other users on the host cannot. redis takes
no password from the environment, which is why there is a config file at all.
A newline in the password would start a new `redis.conf` directive rather than
being part of the password, so the role rejects one with a message saying so.

With the exporter on, the password is also templated into `docker-compose.yml`
(`0700`, root) as the exporter's `REDIS_PASSWORD`.

### Config

`config` is appended verbatim below the two directives the role writes, so it
takes any `redis.conf` syntax:

```yaml
redis:
  config: |
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    appendonly yes
```

Everything the role does not write keeps redis's compiled-in default — the same
set the image runs with when it is given no config file at all — so persistence
stays on redis's default RDB snapshots until `config` says otherwise.

`dir` is not yours to set: it is `/data`, the image's working directory and the
container side of `directories.data`.

### Running two instances on one host

There is no `name` var. A second instance is a second `redis` dict with its own
`network` and its own `directories`:

```yaml
redis:
  network: redis-harbor
  directories:
    ansible: "{{ dir.ansible }}/redis-harbor"
    data: "{{ dir.data }}/redis-harbor"
```

compose names the project after `directories.ansible`, so that also renames the
containers to `redis-harbor-redis-1` and `redis-harbor-exporter-1`, and `network`
keeps the two instances apart in docker and in the metrics `instance` label.

### `overcommit_memory`

Redis forks to write RDB and AOF, and the child briefly shares the parent's page
tables, so a save can fail on a host that refuses to overcommit. `vm.overcommit_memory`
is **not namespaced** — inside a container it reaches the host kernel — which is
why this is a flag rather than something the role always does. Turn it off when
the host's sysctls are managed elsewhere.

### Effects
- creates and manages `{{ redis.directories.ansible }}` — `redis.conf` and the
  compose project
- creates `{{ redis.directories.data }}`, owned by `999:1000`
- sets `vm.overcommit_memory=1` unless `overcommit_memory: false`
- deploys docker compose project named after `directories.ansible`, with
  containers `redis` and, with the exporter on, `exporter`

#### Docker networks
- creates `{{ redis.network }}`, which is what consumers attach to

### Networking
- publishes nothing to the host
- `redis:6379` on `{{ redis.network }}`
- `exporter:9121` on `{{ redis.network }}`, with the exporter on

### Handlers
- `restart redis` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `exporter.enabled`, a `redis_exporter` sidecar answers on port `9121` at
`/metrics`, labelled for the collection's prometheus autodiscovery. The port is
not published: the scrape comes from vmagent, which runs on the host network and
reaches the container over the bridge.

`redis_up` is the one to alert on — an exporter that reaches redis but cannot
authenticate reports `0` rather than failing to be scraped.
