# nginx-proxy
__Tags - `promtail`__

Deploys promtail. **Uses `loki` role certs and vars**

### Usage
```yaml
    - alesharik.baseinfra.promtail
```

Uses `loki` role vars:
```yaml
loki:
  host: 0.0.0.0 # external IP
  tls_hostname: loki.infra.local
```

### Vars
```yaml
promtail:
  image: grafana/promtail
  version: 3.1.0
  relabel_configs:
    docker: []
    systemd: []
  pipeline:
    common: []
    docker: []
    systemd: []
```

### Effects
- creates and manages `{{ dir.ansible }}/promtail`
- creates `{{ dir.data }}/promtail`
- deploys docker compose project `promtail` with container `promtail`
- **container has docker access**

### Handlers
- `restart promtail` - restarts promtail

### Dependencies
- `bootstrap`
- `docker`