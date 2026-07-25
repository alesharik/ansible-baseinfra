# nginx-proxy
__Tags - `TAG`__

Deploys ABCD

### Usage
```yaml
    - alesharik.baseinfra.
```
```yaml

```

### Vars
```yaml
```

### Effects
- installs `passlib`, `bcrypt`
- creates and manages `{{ dir.ansible }}/docker-registry`
- creates `{{ dir.data }}/docker-registry`
- creates and manages `{{ dir.ansible }}/docker-registry/htpasswd` - auth file for server
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ docker.registry.server.host }}` - to set max file size
- deploys docker compose project `docker-registry`
- logges in created docker registry with specified creds 

### SystemD services
- `disable-transparent-huge-pages.service` - disables transparent huge pages on system start

### Users and groups
This role creates and manages users specified in config. It also can create homes for users, and set up their groups.
If user is not in config list, and was created by ansible - it will be removed

For root access, `sudo` group should be used.

#### `ansible-managed` user group
This group is assigned to all users who are created or managed by current ansible role

#### `procusers` user group
This group exists for users assigned to processes (like nginx, postgres, etc).
`sudo` group is allowed to log in as users in this group without password.

#### Docker networks
- connect to `nginx-proxy` if role `nginx_proxy_base` is deployed

### Networking
- exposes 80 port through `nginx-proxy` with host specified in config 
- connects to network `nginx-proxy`

### Handlers
- `restart docker registry server` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `0.0.0.0:9100/metrics`. Service has required prometheus tags