# minio
__Tags - `minio`__

Deploys MinIO

### Usage
```yaml
    - alesharik.baseinfra.minio
```
```yaml
minio:
  admin:
    username: adm # TODO admin username
    password: pass # TODO admin password
  hosts: # todo setup hosts
    storage.test:
      buckets:
        - test-prod
```

### Vars
```yaml
minio:
  version: RELEASE.2023-07-11T21-29-34Z # container tag
  image: quay.io/minio/minio # container image
```

### Effects
- creates and manages `{{ dir.ansible }}/minio`
- creates `{{ dir.data }}/minio`
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ minio.host }}` and `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ minio.host }}_location` - to set proxy to `{{ minio.bucket }}`
- deploys docker compose project `minio`

#### Docker networks
- connect to `nginx-proxy`
- creates `minio_minio` network

### Networking
- exposes 9000 port through `nginx-proxy` with host specified in config 
- connects to network `nginx-proxy`

### Handlers
- `restart minio` - restarts minio

### Dependencies
- `bootstrap`
- `docker`
- `nginx_proxy_base`