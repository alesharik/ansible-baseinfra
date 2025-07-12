# heascale
__Tags - `headscale`__

Deploys headscale server. Runs as user `0`.

### Usage
```yaml
    - headscale
```
```yaml
headscale:
  host: hs.example.com
  base: example.local # Internal domain base
```

### Vars
```yaml
headscale:
  host: tg.example.com # Host for headscale to work on
  
  image: "headscale/headscale" # docker image
  version: v0.25.1 # Docker tag
```

### Effects
- creates and manages `{{ dir.ansible }}/headscale`
- creates and manages `{{ dir.ansible }}/headscale/config/config.yaml` - config for Headscale
- creates and manages `{{ dir.data }}/headscale` - DB and private key storage
- deploys docker compose project `headscale`

#### Docker networks
- connect to `nginx-proxy`

### Networking
- exposes 8080 port through `nginx-proxy` with host specified in config 
- exposes 9090 port to all networks, with prometheus metrics at `/metrics`
- connects to network `nginx-proxy`

### Handlers
- `restart headscale` - restarts bot

### Dependencies
- `alesharik.baseinfra.bootstrap`
- `alesharik.baseinfra.docker`
- `alesharik.baseinfra.nginx_proxy_base`

### Metrics
Service exposes metrics on `http://0.0.0.0:9090/metrics`. Service has required prometheus tags