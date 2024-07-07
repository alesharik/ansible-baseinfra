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
loki:
  image: grafana/loki
  version: 2.7.4
  tls_hostname: loki.infra.local # server hostname for DNS SAN in TLS cert
  clients: # generate TLS creds for:
    - grafana
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