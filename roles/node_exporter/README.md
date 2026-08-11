# node_exporter
__Tags - `node_exporter`__

Deploys node exporter (default version - `v1.8.1`). **Container has read-only
access to the root file system:**

- /proc:/host/proc:ro
- /sys:/host/sys:ro
- /:/rootfs:ro
- /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket

### Usage
```yaml
    - alesharik.baseinfra.node_exporter
```

### Vars
```yaml
node_exporter:
  image: prom/node-exporter
  version: v1.8.1
  networks: [] # external docker networks to attach to
  disable_default_network: false # point compose's default network at `none`
  directories:
    ansible: "{{ dir.ansible }}/node-exporter" # compose project on the host
```
`node_exporter` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

`directories.ansible` is the only root. Everything else the container reads —
`/proc`, `/sys`, `/` and the dbus socket — is the machine itself and cannot
move, and the role keeps no state, so there is no `data` root to expose.

`--collector.systemd` is what the dbus socket is mounted for, and
`security_opt: apparmor:unconfined` is what lets the container read `/proc` and
`/sys` of the host rather than its own namespaced views.

#### `disable_default_network`

Points compose's default network at docker's built-in `none`, so no project
bridge network is created — one less network, and one less set of iptables
rules, on machines short of memory.

It only works alongside a non-empty `networks`. Compose puts a network-scoped
alias on every attachment and `none` rejects aliases, so a container left on the
default network does not start at all — compose fails the whole project with
`network-scoped aliases are only supported for user-defined networks`. The
networks listed are external: they must already exist, the role does not create
them.

There is a second reason to be careful with it here. The container publishes no
ports, so `vmagent` scrapes it at its address on a docker network; with no
network at all it has no address and nothing can reach 9100. Name a network
vmagent can route to before turning this on:

```yaml
node_exporter:
  networks:
    - monitoring
  disable_default_network: true
```

### Effects
- creates and manages `{{ node_exporter.directories.ansible }}`
- deploys docker compose project `node-exporter` with container `node-exporter`

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- exposes 9100 to the networks it is attached to, not to the host
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart node exporter` - restarts node exporter

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on port `9100` at `/metrics`, reachable from the docker
networks the container is attached to. Service has required prometheus tags.
