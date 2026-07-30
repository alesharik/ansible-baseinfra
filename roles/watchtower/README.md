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
  disable_default_network: false # run the container on docker's `none` network
```

`disable_default_network` puts the container on docker's built-in `none` network
via `network_mode`, so compose creates no project bridge network — one less
network, and one less set of iptables rules, on machines short of memory.

Watchtower reaches docker over `/var/run/docker.sock`, so updates keep working
with no network. Nothing else does: notifications cannot be delivered and the
metrics API cannot be scraped, so leave this off when `vmagent: true` or
`notification_url` is set.

This is `network_mode`, not a `networks: {default: {external: true, name: none}}`
mapping. Compose puts a network-scoped alias on every attachment and `none`
rejects aliases, so a service that declares no networks of its own cannot be
moved onto it that way — compose fails the project outright.

### Effects
- creates and manages `{{ dir.ansible }}/watchtower`
- deploys docker compose project `watchtower`

### Handlers
- `restart watchtower` - restarts registry

### Dependencies
- `bootstrap`
- `docker`