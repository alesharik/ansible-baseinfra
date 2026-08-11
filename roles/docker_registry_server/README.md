# docker_registry_server
__Tags - `docker_registry_server`__

Deploys a docker registry (default version - `2`) with htpasswd authentication.

### Usage
```yaml
    - alesharik.baseinfra.docker_registry_server
```
```yaml
docker:
  registries: {} # owned by the `docker` role - see the warning below
  registry:
    server:
      users: # TODO add a user
        test:
          password: test # TODO set a password
          autologin: true
      autologin_registry: registry.example.com
      env:
        - "VIRTUAL_HOST=registry.example.com"
        - "VIRTUAL_PORT=80"
        - "LETSENCRYPT_HOST=registry.example.com"
```

### Vars
```yaml
docker:
  registries: {} # owned by the `docker` role, repeated here on purpose
  registry:
    server:
      image: registry
      version: "2"
      users: {} # username -> {password, autologin}
      autologin_registry: ~ # address `docker login` is pointed at; unset = no login
      networks: [] # external docker networks to attach to
      disable_default_network: false # point compose's default network at `none`
      env: [] # environment lines, e.g. "VIRTUAL_HOST=registry.example.com"
      directories:
        ansible: "{{ dir.ansible }}/docker-registry" # compose project on the host
        data: "{{ dir.data }}/docker-registry" # mounted at /var/lib/registry
```

> **`docker` is one dict shared with the `docker` role.** Ansible merges role
> defaults with replace semantics, not a deep merge, so the two files do not
> combine — whichever loads last wins outright. That is why this role's defaults
> repeat `registries: {}`, and why an override in `group_vars` has to list every
> key **both** roles read. Setting only `docker.registry.server` leaves
> `docker.registries` undefined and the `docker` role's login task fails.

Beyond that, `docker.registry.server` behaves like every other role dict here:
setting it replaces these defaults wholesale, so list every key above, not just
the ones you are changing.

`directories` names the only two roots. `htpasswd` sits next to the compose file
and is bind-mounted at `/htpasswd`, so it moves with `directories.ansible` — it
is not a var of its own, because the container is told
`REGISTRY_AUTH_HTPASSWD_PATH=/htpasswd`, a path fixed on its side of the mount.

#### `users`

Each key is an account in the registry's htpasswd file, hashed with bcrypt. The
file is mode `0600` owned by root; the registry image runs as root, so it reads
it through the bind mount.

Removing a user from this dict removes them from htpasswd on the next run — the
role reconciles the file against the config rather than only adding to it.

#### `autologin_registry`

> **Breaking change.** This replaces the behaviour where the role inferred the
> login address from a required `docker.registry.server.host` var and probed it
> over HTTPS when `nginx_proxy_base` was in the play. `host` is no longer read by
> anything, and the `nginx_proxy_base` integration is gone — that role is
> deprecated.

The address `docker login` is pointed at once the users are in place. Unset (the
default) means no login is attempted at all. Only accounts with
`autologin: true` are used — previously any account with the key merely
*defined* was logged in, including `autologin: false`.

The registry publishes no ports, so this has to be an address that resolves to
whatever fronts it, not the container:

```yaml
docker:
  registries: {}
  registry:
    server:
      autologin_registry: registry.example.com
      users:
        ci:
          password: secret
          autologin: true # logged in
        bot:
          password: secret # not logged in
```

Login runs `docker login --password-stdin` rather than
`community.docker.docker_login`, which needs the docker SDK for python — the
`docker` role installs only the CLI and the compose plugin. It is a no-op when
the credentials already stored in `/root/.docker/config.json` match.

#### `env`

> **Breaking change.** This replaces the `VIRTUAL_HOST`, `VIRTUAL_PORT` and
> `LETSENCRYPT_HOST` environment variables the role used to render from
> `docker.registry.server.host`. Nothing is emitted in their place, so a
> deployment fronted by `nginx_proxy` has to name them itself now:
> ```yaml
> docker:
>   registry:
>     server:
>       env:
>         - "VIRTUAL_HOST=registry.example.com"
>         - "VIRTUAL_PORT=80"
>         - "LETSENCRYPT_HOST=registry.example.com"
> ```

Everything the container is configured with beyond the auth settings the role
owns goes here, one `KEY=value` line each, so the role does not grow a var per
registry setting. `REGISTRY_AUTH`, `REGISTRY_AUTH_HTPASSWD_PATH`,
`REGISTRY_AUTH_HTPASSWD_REALM`, `REGISTRY_HTTP_ADDR` and
`REGISTRY_STORAGE_DELETE_ENABLED` are set by the role itself.

#### `disable_default_network`

> **Breaking change.** The compose template used to pin the default network to
> `none` unconditionally while attaching the service to an optional `network`
> var. With no `network` set that left the service on a `none` default network,
> which compose refuses to start at all. `network` is replaced by `networks`,
> and pointing the default at `none` is now opt-in.

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
docker:
  registry:
    server:
      networks:
        - proxy
      disable_default_network: true
```

### Effects
- installs `python3-passlib`, `python3-bcrypt` - what
  `community.general.htpasswd` imports on the target
- creates and manages `{{ docker.registry.server.directories.ansible }}`
- creates `{{ docker.registry.server.directories.data }}`
- creates and manages `{{ docker.registry.server.directories.ansible }}/htpasswd`,
  mode `0600` - the auth file for the server
- deploys docker compose project `docker-registry` with container `docker-registry`
- logs in to `autologin_registry` with each account marked `autologin: true`,
  when that var is set

#### Docker networks
- connect to specified networks
- with `disable_default_network`, creates no project default network

### Networking
- exposes 80 to the networks it is attached to, not to the host
- connects to specified networks
- with `disable_default_network`, the compose default network points at `none`,
  so the container is only ever on the networks named in `networks`

### Handlers
- `restart docker registry server` - restarts the registry

### Dependencies
- `bootstrap`
- `docker`
