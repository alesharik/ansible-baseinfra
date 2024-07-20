# nginx-proxy
__Tags - `watchtower`__

Deploys watchtower. [Documentation](https://containrrr.dev/watchtower/)

Requires `com.centurylinklabs.watchtower.enable: "true"` label to enable updates

### Usage
```yaml
    - alesharik.baseinfra.watchtower
```

### Vars
```yaml
watchtower:
  image: containrrr/watchtower
  version: 1.7.1
  vmagent: true # enable vmagent role integration
  interval: 30
  notification_url: # set notification url - https://containrrr.dev/watchtower/notifications/
```

### Effects
- creates and manages `{{ dir.ansible }}/watchtower`
- deploys docker compose project `watchtower`

### Handlers
- `restart watchtower` - restarts registry

### Dependencies
- `bootstrap`
- `docker`