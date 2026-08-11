# wg_exporter
__Tags - `wg_exporter`__

Deploys the WireGuard exporter (default version - `3.6.6`). **This container runs
in the host network and holds the `NET_ADMIN` capability**

### Usage
```yaml
    - alesharik.baseinfra.wg_exporter
```

### Vars
```yaml
wg_exporter:
  image: mindflavor/prometheus-wireguard-exporter
  version: 3.6.6
  listen_address: 127.0.0.1 # host address the exporter binds
  port: 9586 # host port the exporter binds
  directories:
    ansible: "{{ dir.ansible }}/wg-exporter" # compose project on the host
```
`wg_exporter` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

`directories.ansible` is the only root. The exporter reads the WireGuard
interfaces through the host network namespace and keeps no state of its own, so
the compose file is the whole of what this role puts on disk — there is no
`data` root.

#### `listen_address` and `port`

The container is host-networked so it can see the WireGuard interfaces, which
means these are taken on the **host itself**, not inside a project network — a
second service already on `9586` collides with this one for real. The default
`127.0.0.1` keeps the metrics off every other interface; `vmagent` is
host-networked too and reaches it there.

They are two vars rather than one `address` string because the exporter wants
them as separate `-l`/`-p` flags while the `prometheus.io.address` label wants
them joined. Both come from the same pair, so moving the exporter moves the
scrape target with it.

#### Docker networks

Unlike the other roles here, this one exposes no `networks` or
`disable_default_network`. The service is host-networked, so it never attaches
to a project network and compose creates none to begin with.

### Effects
- creates and manages `{{ wg_exporter.directories.ansible }}`
- deploys docker compose project `wg-exporter` with container `wg-exporter`
- **container runs in the host network with the `NET_ADMIN` capability**

### Networking
- **uses the host network**
- binds `{{ wg_exporter.listen_address }}:{{ wg_exporter.port }}` on the host
- holds `NET_ADMIN`, which is what lets it read the WireGuard interfaces

### Handlers
- `restart wg exporter` - restarts the exporter

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `{{ wg_exporter.listen_address }}:{{ wg_exporter.port }}/metrics`.
Service has required prometheus tags — being host-networked it carries
`prometheus.io.address` rather than `prometheus.io.port`, since vmagent cannot
reach it at a container address.
