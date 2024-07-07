# clickhouse
__Tags - `clickhouse`__

Deploys clickhouse

### Usage
```yaml
    - alesharik.baseinfra.clickhouse
```
```yaml
clickhouse:
  root:
    password: pwd # root user password
```

### Vars
```yaml
clickhouse:
  image: clickhouse/clickhouse-server
  version: 24.6.2.17-alpine
  databases: # database list 
    - test
  users: 
    admin: # create new user
      password: pass # set user password
      grants:
        - GRANT ALL ON test.* # set grants
  root:
    user: root # root username
```

### Effects
- creates and manages `{{ dir.ansible }}/clickhouse`
- creates `{{ dir.data }}/clickhouse`
- deploys docker compose project `clickhouse`
- creates network `clickhouse`

#### Docker networks
- creates network `clickhouse`

### Networking
- creates network `clickhouse`
- exposes clickhouse on `clickhouse:9000` and `clickhouse:8123` in network `clickhouse`
- exposes clickhouse metrics on `clickhouse:9363` in network `clickhouse`

### Handlers
- `restart clickhouse` - restarts clickhouse

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `0.0.0.0:9363/metrics`. Service has required prometheus tags