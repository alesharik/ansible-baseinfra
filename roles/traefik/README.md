# traefik
__Tags - `traefik`__

Deploys traefik as a docker compose service

### Usage
```yaml
    - alesharik.baseinfra.traefik
```

### Vars
```yaml
traefik:
  image: traefik
  version: "v3.6.15"
  entrypoints: # written into traefik.yml as `entryPoints` verbatim
    web:
      address: :80
      http:
        redirections:
          entryPoint:
            to: websecure
            scheme: https
            permanent: true
    websecure:
      address: ":443"
      http:
        tls: { }
  listen_ips: # compose port mappings, one line each
    - "0.0.0.0:443:443"
    - "0.0.0.0:80:80"
  networks: [] # external docker networks to attach to
  disable_default_network: false # point compose's default network at `none`
  env: [] # environment lines for the container, e.g. "CF_API_EMAIL=me@example.com"
  directories:
    configs: "{{ playbook_dir }}/traefik" # dynamic confs on the controller
    ansible: "{{ dir.ansible }}/traefik" # compose project on the host
    acme: "{{ dir.data }}/traefik-acme" # acme storage, mounted at /acme
```
`traefik` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

`entrypoints` is passed to traefik untouched, so anything traefik accepts under
`entryPoints` works. `listen_ips` is passed to compose untouched, so it takes the
full docker syntax — a bind address, a host port different from the container
port, or `/udp`. The two are independent: an entrypoint with no matching
`listen_ips` line still listens inside the container, reachable from other
containers but not from the host, which is what metrics scraping wants.

```yaml
traefik:
  entrypoints:
    websecure:
      address: ":443"
      http:
        tls: { }
      http3: { }
    metrics:
      address: ":9100"
  listen_ips:
    - "0.0.0.0:443:443"
    - "0.0.0.0:443:443/udp"
```

`disable_default_network` points compose's default network at docker's built-in
`none`, so no project bridge network is created — one less network, and one less
set of iptables rules, on machines short of memory.

It only works alongside a non-empty `networks`. Compose puts a network-scoped
alias on every attachment and `none` rejects aliases, so a container left on the
default network does not start at all — compose fails the whole project with
`network-scoped aliases are only supported for user-defined networks`. The
networks listed are external: they must already exist, the role does not create
them.

```yaml
traefik:
  networks:
    - proxy
  disable_default_network: true
```

`traefik.certificatesResolvers` is optional and, when set, is written into
`traefik.yml` verbatim too. `directories.acme` is mounted at `/acme`, so that is
where `storage` should point:
```yaml
traefik:
  certificatesResolvers:
    letsencrypt:
      acme:
        email: me@example.com
        storage: /acme/acme.json
        dnsChallenge:
          provider: cloudflare
```

Every file in `directories.configs` on the controller is run through the template
engine and copied into `confs/` next to the compose project, where traefik reads
it through its file provider. Files in `confs/` that are not in
`directories.configs` are removed, so that directory is fully managed by the role.

### Effects
- creates and manages `{{ traefik.directories.ansible }}`
- creates `{{ traefik.directories.acme }}`
- deploys docker compose project `traefik`

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- by default, exposes 80 HTTP port on `0.0.0.0.0`
- by default, exposes 443 HTTPS port on `0.0.0.0.0`
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart traefik` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `0.0.0.0:80808/metrics` 