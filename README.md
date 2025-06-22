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

## Versions

| Name                     | Version                          | Last checked | Last updated |
|--------------------------|----------------------------------|--------------|--------------|
| `clickhouse`             | `24.6.2.17-alpine`               |              |              |
| `docker_registry_server` | `2`                              |              |              |
| `grafana`                | `12.0.2`                         | 2025-06-22   | 2025-06-22   |
| `harbor`                 | `2.11.0`                         |              |              |
| `loki`                   | `3.5`                            | 2025-06-22   | 2025-06-22   |
| `mimir`                  | `2.16.0`                         | 2025-06-22   | 2025-06-22   |
| `minio`                  | `RELEASE.2024-07-04T14-25-45Z`   |              |              |
| `nexus`                  | `3.39.0`                         |              |              |
| `nginx_proxy`            | nginx - `1.7-alpine`, le - `2.5` |              |              |
| `nginx_static_git`       | `1.23.1-alpine`                  |              |              |
| `node_exporter`          | `v1.8.1`                         |              |              |
| `postgres`               | `16.3`, exporter - `v0.15.0`     |              |              |
| `promtail`               | `3.1.0`                          |              |              |
| `rabbitmq`               | `3.9.21`                         |              |              |
| `redis`                  | `7.2.5`                          |              |              |
| `vmagent`                | `v1.101.0`                       |              |              |
| `watchtower`             | `1.7.1`                          |              |              |
| `wg_exporter`            | `3.6.6`                          |              |              |