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

### Vars
```yaml
etcd:
  peer_ip: # IP for etcd cluster to connect to
  version: v3.6.12 # ETCD version
  image: "quay.io/coreos/etcd" # ETCD image
  listen_ips: [] # Listen IPs - which IPs to expose ETCD on
  networks: [] # List of docker networks to connect to
  env: [] # List of ENV for etcd
  quorum: [] # Lis tog quorum nodes - hostname names
  vmagent: true # Enable/disable vmagent metrics
  directories: # Directories config
    ansible: "{{ dir.ansible }}/etcd"
    data: "{{ dir.data }}/etcd"
    ca: "{{ playbook_dir }}/certs/etcd" # CA container - should be on playbook runner
    vmagent_conf: "{{ dir.ansible }}/vmagent/config/conf.d"
  pki: # PKI Config
    organization: "ETCD"
    organizational_unit: "Etcd"
```

### Effects
- creates and manages `{{ etcd.directories.ansible }}`
- creates `{{ etcd.directories.data }}`
- creates `{{ dir.ansible }}/vmagent/config/conf.d/etcd-*.{yaml, -ca.cer, .cer, .key}`
- deploys docker compose project `etcd`

#### Docker networks
- connect to specified networks

### Networking
- exposes 2380 HTTPS (server cert) port on `{{ etcd.peer_ip }}`
- exposes 2379 HTTPS (peer cert) port on `{{ etcd.listen_ips }}`
- connects to specified networks

### PKI
Generate CA pair (key+pem) without password on `{{ etcd.directories.ca }}`.
For each ETCD node, it generates TLS server and peer cert. 
Also, it generates client cert for vmagent if required.

### Handlers
- `restart etcd` - restarts registry

### Dependencies
- `bootstrap`
- `docker`

### Metrics
Service exposes metrics on `0.0.0.0:9379/metrics` with required HTTPS and client cert. Service configures vmagent by yourself. 