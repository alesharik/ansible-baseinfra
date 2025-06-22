# nginx-proxy
__Tags - `grafana`__

Deploys grafana (default version - `12.0.2`)

### Usage
```yaml
    - alesharik.baseinfra.grafana
```
```yaml
grafana:
  host: mon.example.com
  admin_password: password
```

### Vars
```yaml
grafana:
  image: grafana/grafana-oss
  version: 11.1.0
```

### Effects
- creates and manages `{{ dir.ansible }}/grafana`
- creates `{{ dir.data }}/grafana`
- deploys docker compose project `grafana`

#### Docker networks
- connect to `nginx-proxy`

### Networking
- exposes 80 port through `nginx-proxy` with host specified in config 
- connects to network `nginx-proxy`

### Handlers
- `restart grafana` - restarts registry

### Dependencies
- `bootstrap`
- `docker`