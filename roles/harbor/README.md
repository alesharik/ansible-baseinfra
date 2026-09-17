# harbor
__Tags - `harbor`__

Deploys [harbor](https://goharbor.io/) as a docker compose project, with an
external postgres and an external redis.

Harbor is nine containers behind an nginx of its own, and they talk to each
other over TLS signed by a CA the role generates. The role writes `harbor.yml`,
runs the `goharbor/prepare` image from harbor to turn that into the component configs,
then replaces the `docker-compose.yml` prepare wrote with its own.

### Usage
```yaml
    - alesharik.baseinfra.harbor
```
```yaml
harbor:
  hostname: harbor.org
  admin_password: "admin_pass"
  networks:
    - traefik
  db:
    host: postgres-harbor-postgres-1
    password: "db_password"
    network: postgres-harbor_main
  redis:
    host: redis-harbor-redis-1
    password: "redis_password"
    network: redis-harbor_redis
```

### Vars
```yaml
harbor:
  version: "2.15.2"
  hostname: "" # the name the reverse proxy serves, and what clients push to
  external_url: "" # empty means https://<hostname>
  admin_password: ""
  network: harbor # the docker network the role creates
  listen_ips: [] # host publications for the proxy container, compose syntax
  networks: [] # extra external networks the proxy joins
  syslog: # harbor's bundled rsyslog container
    enabled: true
    port: 1514 # published on 127.0.0.1, every container logs into it
  db:
    host: ""
    port: 5432
    name: harbor
    username: harbor
    password: ""
    network: "" # the docker network the server answers on
  redis:
    host: ""
    port: 6379
    password: ""
    network: ""
  trivy:
    enabled: true
    skip_update: false
    security_check: "vuln,config,secret"
    github_token: ""
  metrics:
    enabled: true
  config: {} # extra harbor.yml keys, merged over the ones the role writes
  directories:
    ansible: "{{ dir.ansible }}/harbor"
    data: "{{ dir.data }}/harbor"
    logs: /var/log/harbor
```
`harbor` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

### Publishing harbor

The role attaches no reverse proxy of its own. The `proxy` container serves
HTTP on port **8080**, and there are two ways to reach it:

- `networks` — extra external docker networks the proxy joins. Put your traefik
  (or nginx-proxy, or caddy) on one of them and route to **`<network>:8080`**,
  where `<network>` is `harbor.network`. The role writes no proxy labels and no
  proxy environment, so the routing rule, the certificate and the hostname are
  all yours.

  The compose service behind it is called `proxy`, which is too generic a
  name for a shared network, so the role gives it a network alias equal to
  `harbor.network` on every network in `networks`. That alias is also what tells
  two harbors on one host apart.
- `listen_ips` — host publications in compose `ports:` syntax, for a proxy that
  is not in docker at all:
  ```yaml
  harbor:
    listen_ips:
      - "127.0.0.1:8080:8080"
  ```

Empty for both publishes nothing, and harbor is then reachable only from its own
network.

`hostname` still has to be the name the proxy serves. Harbor writes it into the
token service audience and into the `docker push` target, so a harbor that
answers on a name it was not told about rejects pushes.

Uploading a large image needs the proxy to allow a large body. On nginx that is
`client_max_body_size`. Traefik has no limit of its own.

### Logging

With `syslog.enabled`, harbor runs its own rsyslog container. Every other
container logs into it through the docker syslog driver, and it writes
`{{ directories.logs }}/*.log` with logrotate. That is harbor's own default, and
what harbor's documentation describes.

Turn it off to leave every container on the daemon's own logging driver, which
is where the rest of this collection puts container output:

```yaml
harbor:
  syslog:
    enabled: false
```

Off also drops the `log` container, the host publication, and
`{{ directories.logs }}`, which the role then does not create.

Harbor starts rsyslog with `sudo -u #10000`. That call fails inside a nested
docker daemon, where pam_unix reports "Authentication service cannot retrieve
authentication info", so the container restarts forever and every other
container then fails to be created. An ordinary docker host is fine. The
molecule scenario runs with `syslog.enabled: false` for this reason.

### Database and redis

Harbor keeps no database and no cache of its own — `db` and `redis` name servers
that are already running. `network` is the docker network each server answers
on, and `host` is its name on that network. Both may name the same network, and
the role then attaches it once.

The `db.name` database has to exist before the role runs. Harbor creates its own
schema in it, but not the database.

The two roles in this collection that fit are [`postgres`](../postgres/README.md)
and [`redis`](../redis/README.md), either of which can run a second instance
under its own name for harbor alone.

### `config`

The `harbor.yml` file has about forty keys, and the role writes only the ones
harbor requires. Everything else goes in `config`, in the syntax harbor reads,
merged over what the role wrote:

```yaml
harbor:
  config:
    log:
      level: debug
    jobservice:
      max_job_workers: 4
    cache:
      enabled: true
      expire_hours: 24
    upload_purging:
      enabled: true
      age: 168h
```

A key here wins over the value the role set for it, `hostname` and `data_volume`
included. See [harbor.yml.tmpl](https://github.com/goharbor/harbor/blob/main/make/harbor.yml.tmpl)
for what harbor reads.

### Internal TLS

The harbor components verify each other, so the role generates a CA
and one certificate per component with `goharbor/prepare gencert`, into
`{{ directories.ansible }}/tls`. `prepare` then copies the set into
`{{ directories.data }}/secret/tls` with the ownership each container needs, and
that copy is what the containers read.

The certificates are good for a year and nothing renews them on its own, so the
role regenerates the whole set when the CA is inside 30 days of expiry, or when
fewer than 28 files are there. Regenerating restarts harbor.

The expiry check runs `openssl x509 -checkend` out of the same
`goharbor/prepare` image, rather than `community.crypto`, so the role needs no
python packages on the target beyond what ansible itself uses.

The role also copies the CA into
`common/config/shared/trust-certificates/harbor_internal_ca.crt` by hand.
`prepare` means to do this itself, but it looks for the file at `/hostfs/data/…`
— harbor's *container* path for the data volume — so it only finds it when
`dir.data` happens to be `/data`. Everywhere else it logs `ca file … is not
exist`, carries on, and every component then rejects its neighbours'
certificates.

### Effects
- creates and manages `{{ harbor.directories.ansible }}` — `harbor.yml`, the
  compose project, `tls/`, and the `common/config` tree that `prepare` generates
- creates `{{ harbor.directories.data }}`. Everything under it is created and
  owned by `prepare`: `registry`, `job_logs`, `ca_download`, `secret`,
  `trivy-adapter`
- creates `{{ harbor.directories.logs }}`, with syslog on
- deploys a docker compose project named after `directories.ansible`, with
  containers `registry`, `registryctl`, `core`, `portal`, `jobservice`,
  `proxy`, and — behind their flags — `log`, `trivy-adapter` and `exporter`

#### Docker networks
- creates `{{ harbor.network }}`
- connects to `{{ harbor.db.network }}` and `{{ harbor.redis.network }}`
- connects the `proxy` container to every network in `{{ harbor.networks }}`

### Networking
- publishes `{{ harbor.syslog.port }}` on `127.0.0.1`, with syslog on. Every
  container logs through the syslog driver, which the docker daemon opens on
  the host rather than on a docker network, so this is what makes their logging
  work
- publishes whatever `listen_ips` names, and nothing else
- `{{ harbor.network }}:8080` on `{{ harbor.network }}` and on every network in
  `{{ harbor.networks }}`

### Handlers
- `restart harbor` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `metrics.enabled`, a `harbor-exporter` sidecar answers on port `8080` at
`/metrics`, labelled for the prometheus autodiscovery in this collection. It already
aggregates core, jobservice and registry metrics, so it is the one target worth
scraping. The port is not published: the scrape comes from vmagent, which runs
on the host network and reaches the container over the bridge.

### Version bumps
The compose template tracks the `docker-compose.yml` that `goharbor/prepare`
generates, so regenerate that file and diff it against the template when you
change `version`. The container names, the config paths and the internal ports
in it belong to harbor, not to us:

```bash
docker run --rm --privileged \
  -v "$PWD/input:/input" -v "$PWD/data:/data" \
  -v "$PWD:/compose_location" -v "$PWD/common/config:/config" \
  -v /:/hostfs \
  goharbor/prepare:v<version> prepare --with-trivy
```

`_version` in `harbor.yml` is derived from `version`, so it needs no separate
bump.
