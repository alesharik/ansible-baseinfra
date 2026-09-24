# garage
__Tags - `garage`__

Deploys [Garage](https://garagehq.deuxfleurs.fr/), an S3-compatible object
store, as a docker compose project. It runs as a single node by default, and as
a cluster when `peers` names hosts. The role also applies the cluster layout,
and manages S3 access keys and buckets.

Uses the official `dxflrs/garage` image. The image runs as root and has no
shell.

### Usage
```yaml
    - alesharik.baseinfra.garage
```
The defaults run a single node with no keys and no buckets. The `garage` dict is
a wholesale override, so a real config lists every key in [Vars](#vars).

### Vars
```yaml
garage:
  image: dxflrs/garage
  version: v2.4.1
  peers: [] # inventory hostnames of every member; empty = single node
  peer_ip: "" # address the other members dial; required once peers is set
  rpc_port: 3901 # host port for RPC, published on peer_ip in a cluster
  replication_factor: 1 # copies of each object; not more than the members
  zone: dc1 # this node's zone in the layout
  capacity: 100G # this node's weight in the layout, binary units
  tags: [] # this node's tags in the layout
  s3:
    region: garage
    root_domain: "" # e.g. ".s3.example.com" for vhost-style buckets
  network: garage # the docker network the role creates
  publish: [] # host bindings for the S3 port, "[address:]port"
  labels: {} # extra container labels, e.g. for traefik
  access_keys: [] # {name, id, secret}
  buckets: [] # {name, access: [{key, read, write, owner}]}
  metrics:
    enabled: true
  directories:
    ansible: "{{ dir.ansible }}/garage" # compose project and config on the host
    data: "{{ dir.data }}/garage" # mounted at /var/lib/garage
```
`garage` is a **wholesale override**. Setting it replaces the defaults, there is
no deep merge. List every key above, not only the ones you change.

### Single node and cluster

With `peers: []` the role runs one node. It needs no `peer_ip`, and the RPC port
is not published.

With `peers` set, every member must be in the same play. The first member in
`peers` is the leader. It connects the other members, applies the layout for all
of them, and manages the keys and the buckets. The other members read the layout
settings of each member from `hostvars`.

```yaml
garage:
  peers:
    - s3-1
    - s3-2
    - s3-3
  peer_ip: "{{ ansible_default_ipv4.address }}"
  replication_factor: 3
  zone: dc1 # per host
  capacity: 1T # per host
```

All members need the same `replication_factor`. The role checks this before it
starts. Garage cannot change `replication_factor` once the
cluster holds data.

### RPC secret

The members of a cluster use a shared secret to connect to each other. The role
makes it on the first run, on the leader, and stores it in
`{{ garage.directories.ansible }}/rpc_secret` (`0600`, root). On each later run,
the leader reads the secret from this file. The other members get it from the
leader, and have no copy of the file.

Keep this file. If you remove it, the role makes a new secret on the next run,
and all members restart with it. A node that did not get the new secret cannot
connect to the cluster.

To add a node to an existing cluster, add it to `peers` on every member, and
run the play on all of them. The new node gets the secret from the leader.

### Layout

The leader compares `zone`, `capacity` and `tags` of each member with the
applied layout. It stages only the members that differ, and then applies the
next layout version. A node that is in the layout but not in `peers` keeps its
role. Remove it by hand with `garage layout remove`.

`capacity` is a weight for the partition split, not a quota. It uses binary
units: `1G` is 1024^3 bytes.

### Access keys and buckets

```yaml
garage:
  access_keys:
    - name: app
      id: GK0123456789abcdef01234567 # "GK" and 24 hex characters
      secret: "<openssl rand -hex 32>"
  buckets:
    - name: media
      access:
        - key: app # read and write, not owner
        - key: backup
          write: false
          owner: false
```

The role imports each key with its `id` and `secret`, so the clients get the
same credentials on every deploy. Garage cannot change the secret of a key, and
never takes an id back. To rotate a secret, give the key a new id. The role
fails when a key exists with another secret.

In `access`, `read` and `write` default to `true`, and `owner` defaults to
`false`. The permissions of a listed bucket are exactly the ones in `access`. The
role takes away any other permission, also from keys that are not in `access`.

The role never deletes a key or a bucket. Keys and buckets that are not in the
lists stay as they are.

### Effects
- creates and manages `{{ garage.directories.ansible }}` — the compose project
  and `config/garage.toml`, and on the leader `rpc_secret`
- creates `{{ garage.directories.data }}` — the metadata db in `meta/`, the
  objects in `data/`
- deploys a docker compose project named after `directories.ansible`, with a
  single container `garage`
- applies the cluster layout, and imports keys and creates buckets

#### Docker networks
- creates `{{ garage.network }}`

### Networking
- `garage:3900` (S3) on `{{ garage.network }}`
- publishes the S3 port on each binding in `publish`, nothing if that is empty
- with `peers`, publishes `rpc_port` on `peer_ip`

The role runs the `garage` CLI inside the container over loopback. In a cluster
the CLI would otherwise dial `rpc_public_addr`, the host address, and a
container cannot always reach its own host address.

### Handlers
- `restart garage` - restarts the compose project

### Dependencies
- `bootstrap`
- `docker`

### Metrics
With `metrics.enabled`, the admin API serves `/metrics` on port `3903`, with
labels for the collection's prometheus autodiscovery. The port is not
published. The role sets no admin token, so the admin API serves only
`/health` and `/metrics`, and `/metrics` needs no token.

### Migrating from MinIO

This procedure moves the buckets of a MinIO container to garage on the same
host. It uses the layout of the removed `minio` role: the compose project in
`{{ dir.ansible }}/minio`, the service `minio` on the docker network `minio`,
and the data in `{{ dir.data }}/minio`. Change the names if your deployment is
different.

The copy uses [rclone](https://rclone.org/) in a temporary container. The
container attaches to both docker networks, so neither service needs a
published port. More than one `--network` flag needs docker 28 or later.

What moves: the objects, their `Content-Type` and their user metadata.

What does not move: object versions, bucket policies, lifecycle rules,
notifications and MinIO users. Garage does not use MinIO policies. Access is
set per key and per bucket in `access`.

#### Before you start

- Make sure the disk has space for a second copy of `{{ dir.data }}/minio`.
  Both copies exist until the last step.
- Make a list of the buckets. Run this command on the host:

  ```
  docker exec minio-minio-1 sh -c 'ls /data1'
  ```

  Each directory, except `.minio.sys`, is a bucket.
- Make a list of the clients and of the MinIO keys that they use. Garage cannot
  import MinIO keys, because a garage key id must be "GK" and 24 hex
  characters. Each client gets a new key.

#### Procedure

1. Make a new key for each client, and one `migration` key. Use
   `openssl rand -hex 12` for the id part and `openssl rand -hex 32` for the
   secret.

2. Add the keys and the buckets to `garage`. Give the `migration` key read and
   write access to each bucket:

   ```yaml
   garage:
     access_keys:
       - name: app
         id: GK<24 hex characters>
         secret: <64 hex characters>
       - name: migration
         id: GK<24 hex characters>
         secret: <64 hex characters>
     buckets:
       - name: media
         access:
           - key: app
           - key: migration
   ```

3. Run the playbook with the `garage` role. Do not remove the `minio`
   deployment yet.

4. Do a first copy while MinIO still serves the clients. Set the variables
   first:

   ```
   MINIO_USER=<MinIO root user>
   MINIO_PASSWORD=<MinIO root password>
   GARAGE_KEY_ID=<migration key id>
   GARAGE_SECRET=<migration key secret>
   ```

   Then run rclone for each bucket. Replace `media` with the bucket name:

   ```
   docker run --rm --network minio --network garage \
     -e RCLONE_CONFIG_MINIO_TYPE=s3 \
     -e RCLONE_CONFIG_MINIO_PROVIDER=Minio \
     -e RCLONE_CONFIG_MINIO_ENDPOINT=http://minio:9000 \
     -e RCLONE_CONFIG_MINIO_ACCESS_KEY_ID="$MINIO_USER" \
     -e RCLONE_CONFIG_MINIO_SECRET_ACCESS_KEY="$MINIO_PASSWORD" \
     -e RCLONE_CONFIG_GARAGE_TYPE=s3 \
     -e RCLONE_CONFIG_GARAGE_PROVIDER=Other \
     -e RCLONE_CONFIG_GARAGE_ENDPOINT=http://garage:3900 \
     -e RCLONE_CONFIG_GARAGE_REGION=garage \
     -e RCLONE_CONFIG_GARAGE_ACCESS_KEY_ID="$GARAGE_KEY_ID" \
     -e RCLONE_CONFIG_GARAGE_SECRET_ACCESS_KEY="$GARAGE_SECRET" \
     rclone/rclone sync minio:media garage:media --metadata --progress
   ```

   rclone does not create buckets on garage. The role creates them in step 3.

5. Stop the clients that write to MinIO.

6. Do step 4 again. This copy is short: `sync` copies only the objects that
   changed after the first copy, and deletes the objects that were deleted.

7. Compare the two sides. Use the same `docker run` command as in step 4,
   but replace `sync` and its flags with `check minio:media garage:media`.
   Make sure the output shows `0 differences found`.

8. Point the clients at garage, and start them. Each client needs these
   changes:
   - the endpoint: `http://garage:3900` on the `garage` network, or the
     address in `publish` or in your proxy
   - the new access key and secret from step 1
   - the region `garage`
   - path-style addressing, unless `s3.root_domain` is set

   Move the proxy host names from the old MinIO container to garage. With
   traefik, add the labels to `garage.labels`.

9. Remove the `migration` key from each bucket in `access`, and run the
   playbook again. The role takes away the access of the key. The key itself
   stays in garage, because the role never deletes a key.

10. Remove MinIO. Run this command in `{{ dir.ansible }}/minio`:

    ```
    docker compose down
    ```

    Keep `{{ dir.data }}/minio` until the clients work on garage. Then remove
    it by hand.

### Health
The container has no healthcheck: the image has no shell, and `garage health`
dials `rpc_public_addr`. The role waits for `GetClusterHealth` to report
`healthy` instead. To check a node by hand:

```
docker exec garage-garage-1 /garage -c /etc/garage/garage.toml \
  -h "$(docker exec garage-garage-1 /garage -c /etc/garage/garage.toml node id -q | cut -d@ -f1)@127.0.0.1:3901" \
  status
```
