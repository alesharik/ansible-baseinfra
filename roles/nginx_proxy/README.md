# nginx-proxy
__Tags - `nginx_proxy`__

Deploys nginx-proxy

### Usage
```yaml
    - alesharik.baseinfra.nginx_proxy
```

### Vars
```yaml
nginx:
  proxy:
    versions:
      nginx: 1.0-alpine # nginx version
      le: 2.2 # LE-companion version
    vhosts: [] # deprecated
```

### Effects
- creates `{{ dir.ansible }}/nginx-proxy/docker-compose.yml`
- deploys docker compose project `nginx-proxy`

#### Docker networks
- connect to `nginx-proxy` - should be used to connect nginx-proxy to other containers

#### Volumes
- `certs` - volume with LE certificate
- `html` - volume to sync htmls for LE

### Networking
- host port 80 - for http services
- host port 443 - for https services 
- connects to network `nginx-proxy`

### Handlers
- `restart nginx-proxy` - restarts nginx-proxy

### Dependencies
- `bootstrap`
- `docker`
- `nginx_proxy_base`