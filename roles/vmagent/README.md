# nginx-proxy
__Tags - `vmagent`__

Deploys vmagent. **Uses `mimir` role certs and vars**

### Usage
```yaml
    - alesharik.baseinfra.vmagent
```
```yaml
vmagent:
  remoteWrite:
    url: https://{{ mimir.host }}:9009/api/v1/push
```

### Vars
```yaml
vmagent:
  image: victoriametrics/vmagent
  version: v1.101.0
```

### Effects
- creates and manages `{{ dir.ansible }}/vmagent`
- creates `{{ dir.data }}/vmagent`
- deploys docker compose project `vmagent` with container `vmagent`
- **container has root user, docker access and host network**
- sets up debug server on `localhost:8429` with username `vmagent-auth` and password `{{ dir.ansible }}/vmagent/password`

### Networking
- **uses host network**
- hosts server on `localhost:8429` with username `vmagent-auth` and password `{{ dir.ansible }}/vmagent/password`

### Handlers
- `restart vmagent` - restarts registry

### Dependencies
- `bootstrap`
- `docker`