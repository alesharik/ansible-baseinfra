# nginx-proxy
__Tags - `docker_registry_server`__

Deploys docker registry

### Usage
```yaml
    - alesharik.baseinfra.docker_registry_server
```
```yaml
docker:
  registry:
    server:
      host: example.com # TODO specify host
      users: # TODO add user
        test: 
          password: test # TODO set password
          autologin: yes
```

### Vars
```yaml
docker:
  registry:
    server:
      version: 2 # container tag
      host: example.com # host for nginx-proxy
      users: # users to add to server
        test: 
          password: test
          autologin: yes # log in with this account into registry on deployment server
        ...
```

### Effects
- installs `passlib`, `bcrypt`
- creates and manages `{{ dir.ansible }}/docker-registry`
- creates `{{ dir.data }}/docker-registry`
- creates and manages `{{ dir.ansible }}/docker-registry/htpasswd` - auth file for server
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d/{{ docker.registry.server.host }}` - to set max file size
- deploys docker compose project `docker-registry`
- logges in created docker registry with specified creds 

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