# loki
__Tags - `loki`__

Deploys loki

### Usage
```yaml
    - alesharik.baseinfra.loko
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
  tls_hostname: loki.infra.local # server hostname for DNS SAN in TLS cert
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
- creates `{{ playbook_dir }}/certs/loki_ca.key`, `{{ playbook_dir }}/certs/loki_server.key`, `{{ playbook_dir }}/certs/loki_grafana.key` to manage keys
- deploys docker compose project `loki`

### Networking
- exposes 3100 port on `{{ loki.host }}`

### Handlers
- `restart loki` - restarts loki

### Dependencies
- `bootstrap`
- `docker`