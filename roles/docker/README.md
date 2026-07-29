# docker
__Tags - `docker`__

Install docker

### Usage
```yaml
- alesharik.baseinfra.docker
```

### Vars
```yaml
docker:
  registries: # autoconfigure registries
    "https://registry.com":
      username: username
      password: pass
```

### Effects
- installs `docker`, `docker-compose`