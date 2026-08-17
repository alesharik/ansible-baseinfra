# etcd
__Tags - `etcd`__

Deploys Etcd cluster

### Usage
```yaml
    - alesharik.baseinfra.etcd
```
```yaml
etcd:
  peer_ip: # IP for etcd cluster to connect to
  listen_ips:
  - "{{ etcd.peer_ip }}"
  quorum:
  - quorum-1
  - quorum-2
  - quorum-3
```

`quorum` lists the `ansible_hostname` of every member, and each of those hosts
must have `etcd.peer_ip` set — the role reads them out of `hostvars` to build
`ETCD_INITIAL_CLUSTER`.

### Vars
```yaml
etcd:
  peer_ip: # IP for etcd cluster to connect to - no default, must be set
  version: v3.6.12 # ETCD version
  image: "quay.io/coreos/etcd" # ETCD image
  listen_ips: [] # Listen IPs - which IPs to expose ETCD on
  networks: [] # List of docker networks to connect to - must already exist
  env: [] # Extra container environment, one "KEY=value" string per entry
  quorum: [] # List of quorum nodes - ansible_hostname values
  vmagent: true # Enable/disable vmagent metrics
  directories: # Directories config
    ansible: "{{ dir.ansible }}/etcd"
    data: "{{ dir.data }}/etcd"
    ca: "{{ playbook_dir }}/certs/etcd" # CA container - should be on playbook runner
    # conf.d of the vmagent role; owned by that role and never created here
    vmagent_conf: "{{ vmagent.directories.ansible | default(dir.ansible ~ '/vmagent') }}/config/conf.d"
  pki: # PKI Config
    organization: "ETCD"
    organizational_unit: "Etcd"
```

This dict is a **wholesale override** — setting it in group_vars replaces the
role defaults entirely, there is no deep merge, so an override has to list every
key the role reads.

### Effects
- creates and manages `{{ etcd.directories.ansible }}`
- creates `{{ etcd.directories.data }}`
- writes `{{ etcd.directories.vmagent_conf }}/etcd-<basename>.{yml,cer,key}` and
  `etcd-<basename>-ca.cer` — only when that directory already exists, since the
  vmagent role owns it
- deploys docker compose project `etcd`

#### Docker networks
- connect to specified networks

### Networking
- exposes 2380 HTTPS (peer cert) port on `{{ etcd.peer_ip }}`
- exposes 2379 HTTPS (server cert) port on `{{ etcd.listen_ips }}`
- connects to specified networks

### PKI
Generate CA pair (key+pem) without password on `{{ etcd.directories.ca }}`.
For each ETCD node, it generates TLS server and peer cert.
Also, it generates client cert for vmagent if required.

Every leaf certificate carries a subject (`CN` is the member's `ansible_hostname`,
`vmagent` for the client cert; `O`/`OU` come from `etcd.pki`). A subject-less
certificate would only be valid with a critical SAN extension (RFC 5280 4.2.1.6),
and while Go's TLS accepts one anyway — so etcd would start — strict verifiers
reject it.

### Handlers
- `restart etcd` - restarts etcd

### Dependencies
- `bootstrap`
- `docker`

### Metrics
etcd serves `/metrics` on its **client** port, `2379`, with client certificate
authentication — no separate metrics listener is configured. The role drops a
scrape config and a client certificate into vmagent's conf.d for it.
