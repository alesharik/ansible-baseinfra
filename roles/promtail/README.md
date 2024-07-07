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
  version: 2.7.4
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
- creates `{{ playbook_dir }}/certs/promtail_{{ inventory_hostname }}.key` to manage node key
- deploys docker compose project `promtail` with container `promtail`

### Handlers
- `restart promtail` - restarts promtail

### Dependencies
- `bootstrap`
- `docker`