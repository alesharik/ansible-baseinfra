# harbor
__Tags - `harbor`__

Deploys harbor instance

### Usage
```yaml
    - alesharik.baseinfra.harbor
```
```yaml
harbor:
  hosts: 
    - harbor.org
  admin_password: "admin_pass"
  db:
    host: postgres-harbor-postgres-1
    port: 5432
    name: harbor
    username: harbor
    password: "password"
    network: postgres-harbor_main
  redis:
    host: redis-harbor-redis-1
    password: password
    network: redis-harbor_redis
```

### Vars
```yaml
harbor:
  version: 2.11.0 # harbor version
  cert_rotate: "false" # force rotate certificates
```

### Effects
- creates and manages `{{ dir.ansible }}/harbor`
- creates `{{ dir.data }}/harbor`
- sets up TLS components in `{{ dir.ansible }}/harbor/tls`
- deploys docker compose project `harbor`
- sets up nginx_proxy vhost to handle big files

#### Docker networks
- creates `harbor-harbor` network
- connects to `nginx-proxy`
- connects to `{{ harbor.redis.network }}`
- connects to `{{ harbor.db.network }}` 

### Networking
- exposes 80 port through `nginx-proxy` with host specified in config 
- exposes `log:1514` port on `127.0.0.1:10514`
- connects to network `{{ harbor.redis.network }}`
- connects to network  `{{ harbor.db.network }}` 
- connects to network `nginx-proxy`

### Handlers
- `restart harbor` - restarts harbor

### Dependencies
- `bootstrap`
- `docker`