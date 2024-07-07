# nginx-proxy
__Tags - `TAG`__

Deploys ABCD

### Usage
```yaml
    - alesharik.baseinfra.
```
```yaml

```

### Vars
```yaml
```

### Effects
- installs `passlib`, `bcrypt`
- creates and manages `{{ dir.ansible }}/docker-registry`
- creates `{{ dir.data }}/docker-registry`
- creates and manages `{{ dir.ansible }}/docker-registry/htpasswd` - auth file for server
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ docker.registry.server.host }}` - to set max file size
- deploys docker compose project `docker-registry`
- logges in created docker registry with specified creds 

#### Docker networks
- connect to `nginx-proxy` if role `nginx_proxy_base` is deployed

### Networking
- exposes 80 port through `nginx-proxy` with host specified in config 
- connects to network `nginx-proxy`

### Handlers
- `restart docker registry server` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `0.0.0.0:9100/metrics`. Service has required prometheus tags