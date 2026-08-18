# vmagent
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
  remoteWrite: {} # each key becomes a -remoteWrite.<key>=<value> flag
  node_label: true # adds -remoteWrite.label=node=<ansible_hostname> to every shipped series
  directories:
    ansible: "{{ dir.ansible }}/vmagent" # compose project on the host
    data: "{{ dir.data }}/vmagent" # mounted at /vmagent
```
`vmagent` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing. Omitting
`node_label` from an override still leaves the label on (the template defaults
it to `true`); set it to `false` to ship series without the `node` label.

These are the only two roots. `<ansible>/config` is the only path compose
bind-mounts, at `/etc/vmagent`, so everything vmagent reads hangs off `ansible`
and moves with it: `config.yml`, `password`, and the `conf.d` other roles drop
extra scrape configs into. None of those are vars of their own — the container
globs `/etc/vmagent/conf.d/*.yml`, a path fixed on its side of the mount.

`<ansible>/config/conf.d` is the drop point other roles write into rather than a
path they hardcode — see `watchtower.directories.vmagent`, which builds it off
`directories.ansible`. Reading that from another role only works when both sit in
the same play's `roles:` list, which is where another role's defaults come into
scope.

### Effects
- creates and manages `{{ vmagent.directories.ansible }}`
- creates `{{ vmagent.directories.data }}`, owned by uid `10001`
- creates and manages `{{ vmagent.directories.ansible }}/config` - `config.yml` and `password`
- creates `{{ vmagent.directories.ansible }}/config/conf.d` for other roles to drop scrape configs into
- deploys docker compose project `vmagent` with container `vmagent`
- **container has root user, docker access and host network**
- sets up debug server on `localhost:8429` with username `vmagent-auth` and password `{{ vmagent.directories.ansible }}/config/password`

### Networking
- **uses host network**
- hosts server on `localhost:8429` with username `vmagent-auth` and password `{{ vmagent.directories.ansible }}/config/password`

### Handlers
- `restart vmagent` - restarts vmagent

### Dependencies
- `bootstrap`
- `docker`

### Prometheus autodiscovery
The shipped `config.yml` scrapes vmagent itself and every docker container
carrying `prometheus.io.*` labels — see the collection README for the label set.
