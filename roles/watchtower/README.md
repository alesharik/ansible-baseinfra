# watchtower
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
  image: nickfedor/watchtower
  version: 1.14.3
  vmagent: true # enable vmagent role integration
  interval: 30
  notification_url: # set notification url - https://containrrr.dev/watchtower/notifications/
  disable_default_network: false # run the container on docker's `none` network
  directories:
    ansible: "{{ dir.ansible }}/watchtower" # compose project on the host
    # where the vmagent scrape config is dropped
    vmagent: "{{ vmagent.directories.ansible | default(dir.ansible ~ '/vmagent') }}/config/conf.d"
```
`watchtower` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

`directories.vmagent` follows the vmagent role's own `directories.ansible`, so
relocating vmagent moves this drop with it — `conf.d` hangs off that role's
compose dir and is not a var there. It only resolves when both roles are in the
same play's `roles:` list, that being the one case where another role's defaults
are in scope here. Under `include_role` they are not, and a wholesale `vmagent:`
override can drop the key entirely; both fall back to the path the vmagent role
uses by default, so neither case changes where the file lands.

The role does not create `directories.vmagent` — that directory belongs to the
vmagent role, which bind-mounts it into its own container, so creating it here
would leave a directory no vmagent ever reads. When it is missing the scrape
config is skipped rather than templated into thin air. Deploying vmagent later
and re-running this role fills it in.

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

`/root/.docker/config.json` is mounted at `/config.json` for registry
credentials, but only when that file already exists. Nothing here creates it, and
docker materialises a *directory* for a missing bind source — which watchtower
cannot parse as a docker config — so the mount is omitted instead.

### Effects
- creates and manages `{{ watchtower.directories.ansible }}`
- writes `{{ watchtower.directories.ansible }}/http_password` with `vmagent: true` -
  the bearer token for the metrics API
- writes `{{ watchtower.directories.vmagent }}/watchtower.yml` with `vmagent: true`,
  when that directory already exists
- mounts `/root/.docker/config.json` when it already exists
- deploys docker compose project `watchtower`

#### Docker networks
- with `disable_default_network`, creates no project default network and runs the
  container on docker's built-in `none` network

### Handlers
- `restart watchtower` - restarts watchtower

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `vmagent: true`, the container answers `/v1/metrics` on port 8080, guarded by
the bearer token in `{{ watchtower.directories.ansible }}/http_password`. The
scrape config dropped into vmagent's `conf.d` carries the same token.
