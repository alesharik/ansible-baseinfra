# loki
__Tags - `mimir`__

Deploys mimir (default version - `2.16.0`)

### Usage
```yaml
    - alesharik.baseinfra.mimir
```

### Vars
```yaml
mimir:
  image: grafana/mimir
  version: 2.13.0
  networks: # Join container to specified networks 
    - proxy
  log_format: json
  compactor_blocks_retention_period: 4w
```

### Effects
- creates and manages `{{ dir.ansible }}/mimir`
- creates `{{ dir.data }}/mimir`
- deploys docker compose project `mimir`

#### Docker networks
- connect to specified networks

### Networking
- exposes 9009 port
- connects to specified networks

### Handlers
- `restart mimir` - restarts mimir

### Dependencies
- `bootstrap`
- `docker`