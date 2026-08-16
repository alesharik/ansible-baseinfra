# valkey
__Tags - `valkey`__

Deploys a single-node [valkey](https://valkey.io/) as a docker compose project,
with an optional prometheus exporter.

Runs as uid `999`, gid `1000` — the `valkey` user inside the official image.

This is the [`redis`](../redis/README.md) role with valkey's names, image and
binaries. The two are separate roles with separate dicts, directories and
networks, so a host can run both.

### Usage
```yaml
    - alesharik.baseinfra.valkey
```
```yaml
valkey:
  password: pass
```

### Vars
```yaml
valkey:
  image: valkey/valkey
  version: 9.1-alpine
  password: "" # empty means no requirepass at all
  network: valkey # the docker network the role creates
  config: "" # extra valkey.conf directives, appended verbatim
  overcommit_memory: true # set vm.overcommit_memory=1 on the host
  exporter:
    enabled: true
    image: oliver006/redis_exporter
    version: v1.89.0
  directories:
    ansible: "{{ dir.ansible }}/valkey" # compose project on the host
    data: "{{ dir.data }}/valkey" # mounted at /data
```
`valkey` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

### Password

`password` is optional. Empty writes no `requirepass` line at all, which is how
the upstream image ships: the role publishes no host port, so the server is only
reachable from its own docker network. Anything on that network can then read
and write the whole keyspace, so set a password whenever that network is shared
with something you do not control.

It is written into `valkey.conf`, which is `0400` and owned by uid `999` — the
container's own user reads it, and other users on the host cannot. valkey takes
no password from the environment, which is why there is a config file at all.
A newline in the password would start a new `valkey.conf` directive rather than
being part of the password, so the role rejects one with a message saying so.

With the exporter on, the password is also templated into `docker-compose.yml`
(`0700`, root) as the exporter's `REDIS_PASSWORD`.

### Config

`config` is appended verbatim below the two directives the role writes, so it
takes any `valkey.conf` syntax:

```yaml
valkey:
  config: |
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    appendonly yes
```

Everything the role does not write keeps valkey's compiled-in default — the same
set the image runs with when it is given no config file at all — so persistence
stays on valkey's default RDB snapshots until `config` says otherwise.

`dir` is not yours to set: it is `/data`, the image's working directory and the
container side of `directories.data`.

### Running two instances on one host

There is no `name` var. A second instance is a second `valkey` dict with its own
`network` and its own `directories`:

```yaml
valkey:
  network: valkey-sessions
  directories:
    ansible: "{{ dir.ansible }}/valkey-sessions"
    data: "{{ dir.data }}/valkey-sessions"
```

compose names the project after `directories.ansible`, so that also renames the
containers to `valkey-sessions-valkey-1` and `valkey-sessions-exporter-1`, and
`network` keeps the two instances apart in docker and in the metrics `instance`
label.

### `overcommit_memory`

Valkey forks to write RDB and AOF, and the child briefly shares the parent's page
tables, so a save can fail on a host that refuses to overcommit. `vm.overcommit_memory`
is **not namespaced** — inside a container it reaches the host kernel — which is
why this is a flag rather than something the role always does. Turn it off when
the host's sysctls are managed elsewhere.

### Effects
- creates and manages `{{ valkey.directories.ansible }}` — `valkey.conf` and the
  compose project
- creates `{{ valkey.directories.data }}`, owned by `999:1000`
- sets `vm.overcommit_memory=1` unless `overcommit_memory: false`
- deploys docker compose project named after `directories.ansible`, with
  containers `valkey` and, with the exporter on, `exporter`

#### Docker networks
- creates `{{ valkey.network }}`, which is what consumers attach to

### Networking
- publishes nothing to the host
- `valkey:6379` on `{{ valkey.network }}`
- `exporter:9121` on `{{ valkey.network }}`, with the exporter on

### Handlers
- `restart valkey` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `exporter.enabled`, a `redis_exporter` sidecar answers on port `9121` at
`/metrics`, labelled for the collection's prometheus autodiscovery. The port is
not published: the scrape comes from vmagent, which runs on the host network and
reaches the container over the bridge.

It is `redis_exporter`, not a valkey build of it: valkey answers the same
protocol and the same `INFO`, the exporter supports it directly, and the series
it produces keep their `redis_` prefix. `REDIS_ADDR` is `redis://valkey:6379` for
the same reason — `redis://` is the protocol scheme, not the server.

`redis_up` is the one to alert on — an exporter that reaches valkey but cannot
authenticate reports `0` rather than failing to be scraped.

### Clients

Valkey is a fork of redis 7.2 and speaks the same protocol on the same port, so
redis clients connect unchanged. The image also ships `redis-server` and
`redis-cli` as symlinks to the valkey binaries; this role uses the valkey names.
