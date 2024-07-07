# Ansible Collection - alesharik.baseinfra

## Basic setup
Create group_vars/all and fill it with:
```yaml
dir:
  data: /data # data directory for all roles
  ansible: /data/ansible # roles contents (dockerfiles, docker-compose, configs, etc)
```

### Roles
- `bootstrap` installs base utils
- `chrony` - setup chrony NTP server

### `procusers` user group
This group exists for users assigned to processes (like nginx, postgres, etc).
`sudo` group is allowed to log in as users in this group without password.

## Prometheus autodiscovery
Vmagent scans docker containers for config labels:
```yaml
prometheus.io.path: /metrics # metrics path
prometheus.io.port: 9100 # port
prometheus.io.instance: "{{ inventory_hostname }}" # additional labels
prometheus.io.address: 127.0.0.1:9586 # full address to server
```