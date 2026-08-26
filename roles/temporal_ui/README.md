# temporal_ui
__Tags - `temporal_ui`__

Deploys the [Temporal Web UI](https://github.com/temporalio/ui-server) as a
docker compose project — one container, and nothing else. The server it talks to
is the [`temporal`](../temporal) role's, or any other Temporal frontend.

Uses the official [`temporalio/ui`](https://hub.docker.com/r/temporalio/ui) image
and runs as uid `1000`, gid `1000` — the `temporal` user inside it.

### Usage
```yaml
    - alesharik.baseinfra.temporal
    - alesharik.baseinfra.temporal_ui
```
```yaml
temporal_ui:
  listen_ips:
    - "127.0.0.1:8080:8080"
  cors_origins:
    - "https://temporal.example.com"
```

### Vars
```yaml
temporal_ui:
  image: temporalio/ui
  version: "2.53.3"
  networks:
    - "{{ temporal.network | default('temporal') }}" # joined; the role creates none
  address: "temporal:{{ temporal.grpc_port | default(7233) }}"
  port: 8080
  listen_ips: [] # e.g. "127.0.0.1:8080:8080"; empty publishes nothing
  default_namespace: default
  cors_origins: [] # empty keeps the image's own default
  env: [] # any other TEMPORAL_* setting, as KEY=value lines
  directories:
    ansible: "{{ dir.ansible }}/temporal-ui"
```
`temporal_ui` is a plain dict override — setting it replaces the defaults
wholesale, so list every key above, not just the ones you are changing.

### CORS

`cors_origins` is the list of browser origins allowed to call the UI's API. Left
empty the variable is **not set at all**, so the image's own default
(`http://localhost:8080`) stands. Behind a reverse proxy, name the origin users
actually reach it on:

```yaml
temporal_ui:
  cors_origins:
    - "https://temporal.example.com"
```

### Effects
- creates and manages `{{ temporal_ui.directories.ansible }}` — the compose project
- deploys a docker compose project named after `directories.ansible`, with a
  single container `ui`

#### Docker networks
- **creates none.** Every entry of `networks` is joined as an external network
  and has to exist already

### Networking
- `ui:{{ temporal_ui.port }}` on each of `networks`
- publishes every entry of `listen_ips`; nothing if that is empty

### Handlers
- `restart temporal ui` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`
- a running Temporal frontend, which `temporal` provides
