# loki
__Tags - `loki`__

Deploys loki (default version - `3.5`)

### Usage
```yaml
    - alesharik.baseinfra.loki
```

### Vars
```yaml
loki:
  image: grafana/loki
  version: 3.5
  networks: [] # external docker networks to attach to
  disable_default_network: false # point compose's default network at `none`
  env: [] # environment lines for the container, e.g. "JAEGER_AGENT_HOST=jaeger"
  allow_structured_metadata: true
  log_format: json
  retention:
    retention_period: 30d # required, max retention
    retention_stream: # configure retention for specific log sets
      - selector: '{container_name="nginx-proxy"}'
        priority: 1
        period: 24h
  migrate_from_v11: false # migrate from old v11 schema
  migration_dates: # used to migrate old loki from v11 to v13
    v11: "2020-10-24"
    v13: "2024-07-06"
  directories:
    ansible: "{{ dir.ansible }}/loki" # compose project on the host
    data: "{{ dir.data }}/loki" # mounted at /var/lib/loki
```
`loki` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

These are the only two roots. `<ansible>/config` is the only path compose
bind-mounts off `ansible`, at `/etc/loki`, so `config.yaml` moves with it. That
is not a var of its own — the container is started with
`-config.file=/etc/loki/config.yaml`, a path fixed on its side of the mount.

`directories.data` is mounted at `/var/lib/loki`, which the rendered config uses
as `common.path_prefix`: chunks, the tsdb index and cache, compaction working
files and rules all hang off it. It is created owned by uid `10001`, the user the
image runs as.

`retention` is written into `limits_config` verbatim, so anything loki accepts
there works — `retention_period` is the global maximum and each `retention_stream`
entry overrides it for the streams its selector matches. `retention_period` is
also what `table_manager.retention_period` is set from.

`migrate_from_v11` prepends the old `boltdb-shipper`/`v11` period to
`schema_config`, for an installation that predates the `tsdb`/`v13` switch.
Leave it off on a new deployment: an empty store with two schema periods makes
loki read the older one for anything timestamped before `migration_dates.v13`.

`disable_default_network` points compose's default network at docker's built-in
`none`, so no project bridge network is created — one less network, and one less
set of iptables rules, on machines short of memory.

It only works alongside a non-empty `networks`. Compose puts a network-scoped
alias on every attachment and `none` rejects aliases, so a container left on the
default network does not start at all — compose fails the whole project with
`network-scoped aliases are only supported for user-defined networks`. The
networks listed are external: they must already exist, the role does not create
them.

```yaml
loki:
  networks:
    - proxy
  disable_default_network: true
```

Loki publishes no ports, so with either setting it is only reachable from the
networks it is attached to — which is what `vmagent` and `grafana` need.

### Effects
- creates and manages `{{ loki.directories.ansible }}`
- creates `{{ loki.directories.data }}`, owned by uid `10001`
- creates and manages `{{ loki.directories.ansible }}/config` - `config.yaml`
- deploys docker compose project `loki` with container `loki`

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- exposes 3100 port to the networks it is attached to, not to the host
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart loki` - restarts loki

### Dependencies
- `bootstrap`
- `docker`
