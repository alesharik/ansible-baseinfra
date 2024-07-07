# node_exporter
__Tags - `node_exporter`__

Deploys node exporter. **Container read-only has access to root file system:**

- /proc:/host/proc:ro
- /sys:/host/sys:ro
- /:/rootfs:ro
- /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket

### Usage
```yaml
    - alesharik.baseinfra.node_exporter
```

### Vars
```yaml
node_exporter:
  image: prom/node-exporter
  version: v1.8.1
```

### Effects
- creates and manages `{{ dir.ansible }}/node-exporter`
- deploys docker compose project `node-exporter` with container `node-exporter`

### Handlers
- `restart node exporter` - restarts node exporter

### Dependencies
- `bootstrap`
- `docker`