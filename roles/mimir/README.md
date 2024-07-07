# loki
__Tags - `mimir`__

Deploys mimir

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
  tls_hostname: loki.infra.local # server hostname for DNS SAN in TLS cert
  clients:  # generate TLS creds for:
    - grafana
  log_format: json
  compactor_blocks_retention_period: 4w
```

### Effects
- creates and manages `{{ dir.ansible }}/mimir`
- creates `{{ dir.data }}/mimir`
- creates `{{ playbook_dir }}/certs/mimir_ca.key`, `{{ playbook_dir }}/certs/mimir_server.key`, `{{ playbook_dir }}/certs/mimir_{{ client }}.key` to manage keys
- deploys docker compose project `mimir`

### Networking
- exposes 9009 port on `{{ loki.host }}`

### Handlers
- `restart mimir` - restarts mimir

### Dependencies
- `bootstrap`
- `docker`