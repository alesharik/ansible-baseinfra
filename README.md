# Ansible Collection - alesharik.baseinfra

## Base roles
- [`bootstrap`](./roles/bootstrap/README.md) installs base utils, configures hostname, swap, users, sudo
- [`chrony`](./roles/chrony/README.md) - setup chrony NTP server
- [`docker`](./roles/docker/README.md) - install docker

### Roles
- [`clickhouse`](./roles/clickhouse/README.md) - deploy clickhouse, a single server or a sharded, replicated cluster
- [`clickhouse_keeper`](./roles/clickhouse_keeper/README.md) - deploy clickhouse keeper, a single server or an ensemble
- [`docker_registry_server`](./roles/docker_registry_server/README.md) - deploy a docker registry with htpasswd auth
- [`garage`](./roles/garage/README.md) - deploy garage S3 object store, a single node or a cluster, with keys and buckets
- [`grafana`](./roles/grafana/README.md) - deploy grafana
- [`loki`](./roles/loki/README.md) - deploy loki log store
- [`mimir`](./roles/mimir/README.md) - deploy mimir metrics store
- [`node_exporter`](./roles/node_exporter/README.md) - deploy node exporter
- [`postgres`](./roles/postgres/README.md) - deploy postgresql: a single server, a primary or a streaming standby
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
- [`pulsar`](./roles/pulsar/README.md) - deploy an apache pulsar broker, a single one or a cluster
- [`temporal`](./roles/temporal/README.md) - deploy a temporal server against an external postgres
- [`temporal_ui`](./roles/temporal_ui/README.md) - deploy the temporal web ui

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
| `clickhouse`             | `26.8.10.6`                                                             | 2026-09-24   | 2026-09-24   |
| `clickhouse_keeper`      | `26.8.10.6`                                                             | 2026-09-24   | 2026-09-24   |
| `docker_registry_server` | `2`                                                                     | 2026-08-02   |              |
| `garage`                 | `v2.4.1`                                                                | 2026-09-24   | 2026-09-24   |
| `grafana`                | `13.0.2`                                                                | 2026-08-01   | 2026-06-14   |
| `harbor`                 | `2.15.2`                                                                | 2026-09-17   | 2026-09-17   |
| `loki`                   | `3.5`                                                                   | 2026-08-01   | 2025-06-22   |
| `mimir`                  | `2.16.0`                                                                | 2026-08-01   | 2025-06-22   |
| `minio`                  | `RELEASE.2024-07-04T14-25-45Z`                                          |              |              |
| `nginx_proxy`            | nginx - `1.7-alpine`, le - `2.5`                                        |              |              |
| `node_exporter`          | `v1.8.1`                                                                | 2026-08-02   |              |
| `postgres`               | `18.6`, exporter - `v0.20.1`                                            | 2026-09-22   | 2026-09-22   |
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
| `pulsar`                 | `4.2.1`                                                                 |              |              |
| `temporal`               | `1.31.2`, admin-tools - `1.31.2`                                        | 2026-08-26   | 2026-08-26   |
| `temporal_ui`            | `2.53.3`                                                                | 2026-08-26   | 2026-08-26   |