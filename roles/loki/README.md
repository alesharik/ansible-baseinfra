# loki
__Tags - `loki`__

Deploys loki (default version - `3.5`)

### Usage
```yaml
    - alesharik.baseinfra.loki
```

### Vars
```yaml
---
loki:
  image: grafana/loki
  version: 3.1.0
  networks: # Join container to specified networks 
    - proxy
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
```

### Effects
- creates and manages `{{ dir.ansible }}/loki`
- creates `{{ dir.data }}/loki`
- deploys docker compose project `loki`

#### Docker networks
- connect to specified networks

### Networking
- exposes 3100 port
- connects to network specified networks

### Handlers
- `restart loki` - restarts loki

### Dependencies
- `bootstrap`
- `docker`