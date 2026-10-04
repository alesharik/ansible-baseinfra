# vault
__Tags - `vault`__

Deploys a HashiCorp Vault cluster with raft storage and mutual TLS

### Usage
```yaml
    - alesharik.baseinfra.vault
```
```yaml
vault:
  peer_ip: # IP for vault cluster to connect to
  listen_ips:
  - "{{ vault.peer_ip }}"
  quorum:
  - quorum-1
  - quorum-2
  - quorum-3
```

`quorum` lists the inventory hostnames of all members. Each of these hosts must
set `vault.peer_ip`. The role reads the addresses from `hostvars` and writes one
`retry_join` stanza for each other member.

The role does not initialize or unseal vault. Run `vault operator init` on one
member, then `vault operator unseal` on every member. The other members join
the raft cluster through `retry_join` when they are unsealed.

### Vars
```yaml
vault:
  peer_ip: # IP for vault cluster to connect to - no default, must be set
  version: 2.1.1 # Vault version
  listen_ips: [] # Listen IPs - which IPs to expose Vault on, must contain peer_ip
  quorum: [] # List of quorum nodes - inventory hostnames
  vmagent: true # Enable/disable vmagent metrics
  pki: # PKI Config
    organization: "Vault"
    organizational_unit: "Vault"
  directories: # Directories config
    ca: "{{ playbook_dir }}/certs/vault" # CA container - should be on playbook runner
    tls: /etc/vault/tls # CA, server certificate and key
    data: /var/vault # raft storage
    # conf.d of the vmagent role. That role owns it, this role never creates it
    vmagent_conf: "{{ vmagent.directories.ansible | default(dir.ansible ~ '/vmagent') }}/config/conf.d"
```

This dict is a **wholesale override**. A value in group_vars replaces the role
defaults entirely. There is no deep merge, so an override must list every key
the role reads.

### Effects
- installs `python3-cryptography`
- creates the `vault` system user and group, with home `/home/vault`
- needs `sudo` on the host for the sudoers rule. `bootstrap` installs it when `setup_sudo` is on
- creates and manages `{{ vault.directories.tls }}`
- installs Vault from `releases.hashicorp.com` with
  [ansible-community.ansible-vault](https://github.com/ansible-community/ansible-vault)
  and runs it as systemd service `vault`. That role creates `/etc/vault.d` and
  `{{ vault.directories.data }}`
- writes `/home/vault/vault.{cer,key}`, and exports `VAULT_ADDR`, `VAULT_CACERT`,
  `VAULT_CLIENT_CERT` and `VAULT_CLIENT_KEY` in `/home/vault/.bashrc`
- writes sudoers rule `vault-access`: group `sudo` can run any command as
  `vault` without a password
- writes `{{ vault.directories.vmagent_conf }}/vault.{yml,cer,key}` and
  `vault-ca.cer`, only when that directory exists. The vmagent role owns it.

### Networking
- exposes 8200 HTTPS (API) on every IP in `{{ vault.listen_ips }}`
- exposes 8201 HTTPS (cluster) on every IP in `{{ vault.listen_ips }}`
- advertises `https://{{ vault.peer_ip }}:8200` as `api_addr` and
  `https://{{ vault.peer_ip }}:8201` as `cluster_addr`

Every listener requires a client certificate signed by the CA of this role.

### PKI
Generate CA pair (key+pem) without password on `{{ vault.directories.ca }}`.
For each Vault node, it generates a server certificate for `listen_ips`. The
member also uses it as its client certificate in `retry_join`.

The role also generates a client certificate for the CLI of the `vault` user,
and one for vmagent if required.

Every leaf certificate has a subject. `CN` is the `ansible_hostname` of the
member, `vault-cli` or `vmagent`. `O` and `OU` come from `vault.pki`.

### Handlers
- `restart vault` - restarts vault. A restart seals the member, so unseal it again.

### Dependencies
- `bootstrap`
- `ansible-community.ansible-vault` role, installed from git. See
  `molecule/requirements.yml`.
- `community.crypto`, `community.general` collections

### Metrics
Vault serves `/v1/sys/metrics?format=prometheus` on `{{ vault.peer_ip }}:8200`
without a token. The listener still requires the client certificate. The role
writes a scrape config and a client certificate into the vmagent conf.d.
