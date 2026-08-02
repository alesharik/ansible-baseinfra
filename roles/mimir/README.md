# mimir
__Tags - `mimir`__

Deploys mimir (default version - `2.16.0`)

Runs the single-binary layout — one container with `-target=all`, every ring
backed by `memberlist` and a replication factor of 1, storing blocks on the local
filesystem. Multitenancy is off, so writers and readers need no tenant header.

### Usage
```yaml
    - alesharik.baseinfra.mimir
```

### Vars
```yaml
mimir:
  image: grafana/mimir
  version: 2.16.0
  networks: [] # external docker networks to attach to
  disable_default_network: false # point compose's default network at `none`
  env: [] # environment lines for the container, e.g. "JAEGER_AGENT_HOST=jaeger"
  log_format: json
  compactor_blocks_retention_period: 4w # delete blocks older than this
  max_ingestion_rate: 50000 # samples/sec; burst is twice this
  directories:
    ansible: "{{ dir.ansible }}/mimir" # compose project on the host
    data: "{{ dir.data }}/mimir" # mounted at /var/lib/mimir
```
`mimir` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

These are the only two roots. `<ansible>/config` is the only path compose
bind-mounts off `ansible`, at `/etc/mimir`, so `config.yaml` moves with it. That
is not a var of its own — the container is started with
`-config.file=/etc/mimir/config.yaml`, a path fixed on its side of the mount.

`directories.data` is mounted at `/var/lib/mimir`. The tsdb, its sync dir,
compaction working files and rule storage are all configured as subdirectories of
it, so moving this moves all of them. It is created owned by uid `10001`, the
user the image runs as.

`max_ingestion_rate` becomes `limits.ingestion_rate`, and
`limits.ingestion_burst_size` is set to twice it. A vmagent pushing more than
this gets 429s on the remote-write endpoint.

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
mimir:
  networks:
    - proxy
  disable_default_network: true
```

Mimir publishes no ports, so with either setting it is only reachable from the
networks it is attached to — which is what `vmagent` and `grafana` need.

### Effects
- creates and manages `{{ mimir.directories.ansible }}`
- creates `{{ mimir.directories.data }}`, owned by uid `10001`
- creates and manages `{{ mimir.directories.ansible }}/config` - `config.yaml`
- deploys docker compose project `mimir` with container `mimir`

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- exposes 9009 port to the networks it is attached to, not to the host
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart mimir` - restarts mimir

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes its own metrics on port 9009 at `/metrics`.
