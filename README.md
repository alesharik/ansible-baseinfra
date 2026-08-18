# Ansible Collection - alesharik.baseinfra

## Base roles
- [`bootstrap`](./roles/bootstrap/README.md) installs base utils, configures hostname, swap, users, sudo
- [`chrony`](./roles/chrony/README.md) - setup chrony NTP server
- [`docker`](./roles/docker/README.md) - install docker

### Roles
- [`docker_registry_server`](./roles/docker_registry_server/README.md) - deploy a docker registry with htpasswd auth
- [`grafana`](./roles/grafana/README.md) - deploy grafana
- [`loki`](./roles/loki/README.md) - deploy loki log store
- [`mimir`](./roles/mimir/README.md) - deploy mimir metrics store
- [`node_exporter`](./roles/node_exporter/README.md) - deploy node exporter
- [`redis`](./roles/redis/README.md) - deploy a single-node redis
- [`traefik`](./roles/traefik/README.md) - deploy traefik reverse proxy
- [`valkey`](./roles/valkey/README.md) - deploy a single-node valkey
- [`vinyl`](./roles/vinyl/README.md) - deploy varnish cache with an haproxy outbound TLS connector
- [`vmagent`](./roles/vmagent/README.md) - deploy vmagent metrics scraper
- [`watchtower`](./roles/watchtower/README.md) - deploy watchtower container updater
- [`wg_exporter`](./roles/wg_exporter/README.md) - deploy wireguard exporter
- [`etcd`](./roles/etcd/README.md) - deploy wireguard exporter
- [`zookeeper`](./roles/zookeeper/README.md) - deploy apache zookeeper, standalone or as an ensemble
- [`bookkeeper`](./roles/bookkeeper/README.md) - deploy apache bookkeeper, a single bookie or a cluster

## Users and groups
This role creates and manages users specified in config. It also can create homes for users, and set up their groups.
If user is not in config list, and was created by ansible - it will be removed

For root access, `sudo` group should be used.

### `ansible-managed` user group
This group is assigned to all users who are created or managed by current ansible role

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

| Name                     | Version                                                                 | Last checked | Last updated |
|--------------------------|-------------------------------------------------------------------------|--------------|--------------|
| `clickhouse`             | `24.6.2.17-alpine`                                                      |              |              |
| `docker_registry_server` | `2`                                                                     | 2026-08-02   |              |
| `grafana`                | `13.0.2`                                                                | 2026-08-01   | 2026-06-14   |
| `harbor`                 | `2.11.0`                                                                |              |              |
| `loki`                   | `3.5`                                                                   | 2026-08-01   | 2025-06-22   |
| `mimir`                  | `2.16.0`                                                                | 2026-08-01   | 2025-06-22   |
| `minio`                  | `RELEASE.2024-07-04T14-25-45Z`                                          |              |              |
| `nginx_proxy`            | nginx - `1.7-alpine`, le - `2.5`                                        |              |              |
| `node_exporter`          | `v1.8.1`                                                                | 2026-08-02   |              |
| `postgres`               | `16.3`, exporter - `v0.15.0`                                            |              |              |
| `redis`                  | `8.10-alpine`, exporter - `v1.89.0`                                     | 2026-08-15   | 2026-08-15   |
| `valkey`                 | `9.1-alpine`, exporter - `v1.89.0`                                      | 2026-08-15   | 2026-08-15   |
| `vmagent`                | `v1.101.0`                                                              |              |              |
| `watchtower`             | `1.14.3`                                                                | 2026-07-30   | 2026-07-30   |
| `wg_exporter`            | `3.6.6`                                                                 | 2026-08-02   |              |
| `headscale`              | `v0.25.1`                                                               | 2025-07-12   | 2025-07-12   |
| `traefik`                | `v3.6.15`                                                               | 2026-07-30   | 2026-07-30   |
| `etcd`                   | `v3.6.12`                                                               | 2026-08-17   | 2026-08-17   |
| `vinyl`                  | varnish - `9`, haproxy - `3.2-alpine`, exporter - `1.8.3-varnish-9.0.0` | 2026-08-12   | 2026-08-12   |
| `zookeeper`              | `3.9.5`                                                                 | 2026-08-18   | 2026-08-18   |
| `bookkeeper`             | `4.18.0`                                                                | 2026-08-18   | 2026-08-18   |