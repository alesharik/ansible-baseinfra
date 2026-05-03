# loki
__Tags - `loki`__

Deploys loki (default version - `3.5`)

### Usage
```yaml
    - alesharik.baseinfra.loki
```
```yaml
loki:
  host: 0.0.0.0 # external IP
```

### Vars
```yaml
---
loki:
  image: grafana/loki
  version: 3.1.0
  clients:  # generate TLS creds for:
    - grafana
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
  listen_hosts: ["127.0.0.1", "192.168.0.1"] # overrides port exposure in docker. Default is `[loki.host]`. Allows to expose container on multiple networks
```

### Effects
- creates and manages `{{ dir.ansible }}/loki`
- creates `{{ dir.data }}/loki`
- deploys docker compose project `loki`

### Networking
- exposes 3100 port on `{{ loki.host }}`

### Handlers
- `restart loki` - restarts loki

### Dependencies
- `bootstrap`
- `docker`