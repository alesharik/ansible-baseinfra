# keycloak
__Tags - `keycloak`__

Deploys a single [Keycloak](https://www.keycloak.org/) node as a docker compose
project with one container. The database is PostgreSQL — the
[`postgres`](../postgres) role's, or any other.

Uses the official [`quay.io/keycloak/keycloak`](https://quay.io/repository/keycloak/keycloak)
image. It runs as uid `1000`.

### Usage
```yaml
    - alesharik.baseinfra.postgres
    - alesharik.baseinfra.keycloak
```
```yaml
postgres:
  # ...
  users:
    - name: keycloak
      password: "{{ vault_kc_db }}"
      ip: samenet
      privs:
        - { db: keycloak, type: database, privs: ALL, objs: keycloak }
        - { db: keycloak, type: schema, privs: ALL, objs: public }
  databases:
    - name: keycloak

keycloak:
  # ... every other key from Vars
  hostname: https://id.example.com
  admin:
    username: admin
    password: "{{ vault_kc_admin }}"
  database:
    host: postgres
    port: 5432
    name: keycloak
    user: keycloak
    password: "{{ vault_kc_db }}"
  networks:
    - postgres
    - proxy
```
The `schema` grant is necessary on PostgreSQL 15 and later. Without it the user
cannot create tables in `public`, and the first start fails.

### Vars
```yaml
keycloak:
  image: quay.io/keycloak/keycloak
  version: "26.8.0"
  hostname: "" # KC_HOSTNAME; empty turns strict hostname checks off
  proxy_headers: xforwarded # xforwarded | forwarded | "" (trust no proxy headers)
  admin:
    username: admin
    password: "" # required
  database:
    host: postgres
    port: 5432
    name: keycloak
    user: keycloak
    password: "" # required
  networks:
    - "{{ postgres.network | default('postgres') }}" # joined; the role creates none
  listen_ips: [] # e.g. "127.0.0.1:8080:8080"; empty publishes nothing
  features: [] # KC_FEATURES entries; empty keeps keycloak's defaults
  log_level: INFO
  console:
    output: json # default | json
    json_format: ecs # default | ecs
  java_opts_append: "" # JAVA_OPTS_APPEND
  env: [] # any other KC_* setting, as KEY=value lines
  directories:
    ansible: "{{ dir.ansible }}/keycloak"
```
`keycloak` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

#### `admin`

The temporary admin of the `master` realm (`KC_BOOTSTRAP_ADMIN_*`). Keycloak
reads it only while the `master` realm has no admin. A new value on an existing
database changes nothing. Change the password in the admin console.

#### `hostname` and `proxy_headers`

With `hostname` set, keycloak uses it for every URL it issues, and the
`Host` and `X-Forwarded-*` headers change nothing. With `hostname` empty, the
role sets `KC_HOSTNAME_STRICT=false`, and keycloak takes the host from each
request.

`proxy_headers: xforwarded` trusts `X-Forwarded-*`. Use it only when a proxy
is the sole way in. A client that reaches keycloak directly can then set its own
headers. With `listen_ips` set, think about `proxy_headers: ""`, or limit the
trusted proxies with `KC_PROXY_TRUSTED_ADDRESSES` in `env`.

#### `java_opts_append`

The image puts its own JVM flags in `JAVA_OPTS`: heap percentages, metaspace
size and the `--add-opens` flags. The role never sets `JAVA_OPTS`. It sets
`JAVA_OPTS_APPEND`, which keycloak adds after those flags. For a fixed heap,
use `-Xms512m -Xmx1g` here.

### Effects
- creates and manages `{{ keycloak.directories.ansible }}`
- writes `docker-compose.yml` there, mode `0600` — it holds the passwords
- deploys a docker compose project named after `directories.ansible`, with a
  single container `keycloak`

#### Docker networks
- **creates none.** Every entry of `networks` is joined as an external network
  and must exist

### Networking
- `keycloak:8080` (HTTP) on each of `networks`
- `keycloak:9000` (management: `/health`, `/metrics`) on each of `networks`
- publishes every entry of `listen_ips`; nothing if that is empty

### Handlers
- `restart keycloak` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- a PostgreSQL database and user, which `postgres` can provide

### Metrics
`/metrics` on port `9000`. The container carries the `prometheus.io.*` labels
that `vmagent` reads, with `prometheus.io.network` set to the first entry of
`networks`.

### Changes from the first version
- `java_opts` became `java_opts_append`. The old var replaced `JAVA_OPTS` and
  dropped the JVM flags of the image.
- `features` is a list, and the default is empty. The old default `preview`
  turned on every preview feature.
- The `keycloak-db-migration` container is gone. It ran `kc.sh build` in a
  separate container, which had no effect. `start` migrates the schema itself.
- The external `keycloak` network is gone. Use `networks`.
- `host` became `hostname`, and the role now sets `KC_HOSTNAME` from it.
- `admin` is new and required.
