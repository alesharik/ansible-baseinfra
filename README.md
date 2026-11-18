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
- [`vault`](./roles/vault/README.md) - deploy a hashicorp vault cluster with raft storage and mutual TLS
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
| `clickhouse`             | `26.8.40.7`                                                             | 2026-11-18   | 2026-11-18   |
| `clickhouse_keeper`      | `26.8.40.7`                                                             | 2026-11-18   | 2026-11-18   |
| `docker_registry_server` | `3`                                                                     | 2026-11-18   | 2026-11-18   |
| `garage`                 | `v2.5.0`                                                                | 2026-11-18   | 2026-11-18   |
| `grafana`                | `13.0.2`                                                                | 2026-11-18   | 2026-06-14   |
| `harbor`                 | `2.16.0`                                                                | 2026-11-18   | 2026-11-18   |
| `loki`                   | `3.7`                                                                   | 2026-11-18   | 2026-11-18   |
| `mimir`                  | `3.2.6`                                                                 | 2026-11-18   | 2026-11-18   |
| `minio`                  | `RELEASE.2024-07-04T14-25-45Z`                                          |              |              |
| `nginx_proxy`            | nginx - `1.7-alpine`, le - `2.5`                                        |              |              |
| `node_exporter`          | `v1.12.1`                                                               | 2026-11-18   | 2026-11-18   |
| `postgres`               | `18.7`, exporter - `v0.21.1`                                            | 2026-11-18   | 2026-11-18   |
| `redis`                  | `8.10-alpine`, exporter - `v1.97.0`                                     | 2026-11-18   | 2026-11-18   |
| `valkey`                 | `9.1-alpine`, exporter - `v1.97.0`                                      | 2026-11-18   | 2026-11-18   |
| `vault`                  | `2.2.2`                                                                 | 2026-11-18   | 2026-11-18   |
| `vmagent`                | `v1.156.0`                                                              | 2026-11-18   | 2026-11-18   |
| `watchtower`             | `1.24.1`                                                                | 2026-11-18   | 2026-11-18   |
| `wg_exporter`            | `3.6.6`                                                                 | 2026-11-18   |              |
| `headscale`              | `v0.25.1`                                                               | 2025-07-12   | 2025-07-12   |
| `traefik`                | `v3.7.19`                                                               | 2026-11-18   | 2026-11-18   |
| `etcd`                   | `v3.7.3`                                                                | 2026-11-18   | 2026-11-18   |
| `vinyl`                  | varnish - `9`, haproxy - `3.2-alpine`, exporter - `1.8.3-varnish-9.0.0` | 2026-11-18   | 2026-08-12   |
| `zookeeper`              | `3.9.7`                                                                 | 2026-11-18   | 2026-11-18   |
| `bookkeeper`             | `4.18.1`                                                                | 2026-11-18   | 2026-11-18   |
| `pulsar`                 | `5.0.1`                                                                 | 2026-11-18   | 2026-11-18   |
| `temporal`               | `1.32.2`, admin-tools - `1.32.2`                                        | 2026-11-18   | 2026-11-18   |
| `temporal_ui`            | `2.58.1`                                                                | 2026-11-18   | 2026-11-18   |
| `keycloak`               | `26.8.2`                                                                | 2026-11-18   | 2026-11-18   |