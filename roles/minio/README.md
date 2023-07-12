# minio
__Tags - `minio`__

Deploys MinIO

### Usage
```yaml
    - alesharik.baseinfra.minio
```
```yaml
minio:
  host: host.com # TODO set host
  bucket: static # TODO which bucket to host
  admin:
    username: adm # TODO admin username
    password: pass # TODO admin password
```

### Vars
```yaml
minio:
  version: RELEASE.2023-07-11T21-29-34Z # container tag
  directory: "{{ dir.data }}/minio" # data directory
```

### Effects
- creates and manages `{{ dir.ansible }}/minio`
- creates `{{ dir.data }}/minio`
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ minio.host }}` - to set proxy to `{{ minio.bucket }}`
- deploys docker compose project `minio`
- logges in created docker registry with specified creds 

#### Docker networks
- connect to `nginx-proxy` if role `nginx_proxy_base` is deployed
- creates `minio_minio` network

### Networking
- exposes 9000 port through `nginx-proxy` with host specified in config 
- connects to network `nginx-proxy`

### Handlers
- `restart minio` - restarts minio

### Dependencies
- `bootstrap`
- `docker`