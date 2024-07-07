# redis
__Tags - `redis`__

Deploys redis single-node instance. 

Uses user `10031` and group `10031`

### Usage
```yaml
    - alesharik.baseinfra.redis
```
```yaml
redis:
  password: pass # redis password
  name: main # instance name
```

### Vars
```yaml
redis:
  image: bitnami/redis
  version: 7.2.5
  exporter:
    enabled: true
    image: bitnami/redis-exporter
    version: 1.61.0
```

### Effects
- creates and manages `{{ dir.ansible }}/redis-{{ redis.name }}`
- creates `{{ dir.data }}/redis-{{ redis.name }}`
- deploys docker compose project `redis-{{ redis.name }}`
- creates `redis-{{ redis.name }}` docker network

#### Docker networks
- creates `redis-{{ redis.name }}` docker network

### Networking
- `redis-{{ redis.name }}` docker network
- exposes `redis:6379` on `redis-{{ redis.name }}`
- exposes `exporter:9121` on `redis-{{ redis.name }}`

### Handlers
- `restart redis` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service `exporter` exposes metrics on `0.0.0.0:9121/metrics`. Service has required prometheus tags