# wg_exporter
__Tags - `wg_exporter`__

Deploys WireGuard exporter. **This container runs in host network and uses `NET_ADMIN` privilege**

### Usage
```yaml
    - alesharik.baseinfra.wg_exporter
```

### Vars
```yaml
wg_exporter:
  image: mindflavor/prometheus-wireguard-exporter
  version: 3.6.6
```

### Effects
- creates and manages `{{ dir.ansible }}/wg-exporter`
- deploys docker compose project `wg-exporter` with container name `wg-exporter`

### Networking
- container `wg-exporter` runs in host network and uses `NET_ADMIN` privilege

### Handlers
- `restart wg exporter` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `127.0.0.1:9586/metrics`. Service has required prometheus tags