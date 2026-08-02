# grafana
__Tags - `grafana`__

Deploys grafana (default version - `13.0.2`)

### Usage
```yaml
    - alesharik.baseinfra.grafana
```
```yaml
grafana:
  admin_password: password
```
`admin_password` is the only key with no default — the role has nothing sensible
to fall back to for it.

### Vars
```yaml
grafana:
  image: grafana/grafana-oss
  version: 13.0.2
  admin_password: password # required, no default
  networks: [] # external docker networks to attach to
  disable_default_network: false # point compose's default network at `none`
  env: [] # environment lines, e.g. "GF_SERVER_ROOT_URL=https://mon.example.com"
  directories:
    ansible: "{{ dir.ansible }}/grafana" # compose project on the host
    data: "{{ dir.data }}/grafana" # mounted at /var/lib/grafana
```
`grafana` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

These are the only two roots. `admin_password.txt` sits next to the compose file
and is referenced from it by relative path, the way compose resolves a
`secrets: file:` entry, so it is not a var of its own — it cannot live anywhere
but there.

`directories.data` is mounted at `/var/lib/grafana`: the sqlite database, plugins
and dashboards. It is created owned by uid `472`, the user the image runs as.

#### `admin_password`

Handed to the container as a docker secret rather than an env var: the role
writes `{{ grafana.directories.ansible }}/admin_password.txt`, compose mounts it
at `/run/secrets/admin_password`, and grafana is pointed at that path with
`GF_SECURITY_ADMIN_PASSWORD__FILE`. So it never shows up in `docker inspect`.

The file is mode `0400` owned by uid `472`, not by root. Compose bind-mounts a
`secrets: file:` entry, so the host ownership is what the container sees, and
grafana runs as `472` — a root-owned `0400` file is unreadable to it, and
grafana then falls back to its built-in default password without logging
anything, leaving the instance reachable with `admin`/`admin`.

Grafana only reads it when it initialises its database. Changing it later
restarts the container but does not change the password of an account that
already exists — use the UI, or `grafana-cli admin reset-admin-password`.

#### `env`

> **Breaking change.** This replaces the `VIRTUAL_HOST`, `VIRTUAL_PORT` and
> `LETSENCRYPT_HOST` environment variables the role used to render from a
> required `grafana.host` var. Nothing is emitted in their place, so a
> deployment fronted by `nginx_proxy` has to name them itself now:
> ```yaml
> grafana:
>   env:
>     - "VIRTUAL_HOST=mon.example.com"
>     - "VIRTUAL_PORT=3000"
>     - "LETSENCRYPT_HOST=mon.example.com"
> ```
> `grafana.host` is no longer read by anything.

Everything the container is configured with beyond the admin password goes here,
one `KEY=value` line each, so the role does not grow a var per grafana setting.
Behind `traefik` that is usually just the root URL:
```yaml
grafana:
  env:
    - "GF_SERVER_ROOT_URL=https://mon.example.com"
```

#### `disable_default_network`

Points compose's default network at docker's built-in `none`, so no project
bridge network is created — one less network, and one less set of iptables
rules, on machines short of memory.

It only works alongside a non-empty `networks`. Compose puts a network-scoped
alias on every attachment and `none` rejects aliases, so a container left on the
default network does not start at all — compose fails the whole project with
`network-scoped aliases are only supported for user-defined networks`. The
networks listed are external: they must already exist, the role does not create
them.

```yaml
grafana:
  networks:
    - proxy
  disable_default_network: true
```

Grafana publishes no ports, so with either setting it is reachable only from the
networks it is attached to — whatever proxies it has to be on one of them.

### Effects
- creates and manages `{{ grafana.directories.ansible }}`
- creates `{{ grafana.directories.data }}`, owned by uid `472`
- writes `{{ grafana.directories.ansible }}/admin_password.txt`, mode `0400`
  owned by uid `472` - the docker secret grafana reads its admin password from
- deploys docker compose project `grafana` with container `grafana`

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- exposes 3000 port to the networks it is attached to, not to the host
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart grafana` - restarts grafana

### Dependencies
- `bootstrap`
- `docker`
