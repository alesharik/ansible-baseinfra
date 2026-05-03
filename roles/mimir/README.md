# loki
__Tags - `mimir`__

Deploys mimir (default version - `2.16.0`)

### Usage
```yaml
    - alesharik.baseinfra.mimir
```
```yaml
mimir:
  host: 0.0.0.0 # external IP
```

### Vars
```yaml
mimir:
  image: grafana/mimir
  version: 2.13.0
  clients:  # generate TLS creds for:
    - grafana
  log_format: json
  compactor_blocks_retention_period: 4w
  listen_hosts: ["127.0.0.1", "192.168.0.1"] # overrides port exposure in docker. Default is `[mimir.host]`. Allows to expose container on multiple networks
```

### Effects
- creates and manages `{{ dir.ansible }}/mimir`
- creates `{{ dir.data }}/mimir`
- deploys docker compose project `mimir`

### Networking
- exposes 9009 port on `{{ loki.host }}`

### Handlers
- `restart mimir` - restarts mimir

### Dependencies
- `bootstrap`
- `docker`