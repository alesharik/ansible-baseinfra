# bootstrap
__Tags - `bootstrap`__

Run initial machine setup: install base libraries, configures hostname

### Usage
```yaml
- alesharik.baseinfra.bootstrap
```
```yaml
users:
  test:
    groups: sudo
    create_home: true
```

### Vars
```yaml---
dir:
  data: /data
  ansible: /data/ansible
bootstrap:
  disable_algif_aead: true
  set_hostname: true
  setup_users: true
  limits:
    enabled: true
    nofile:
      soft: 8192
      hard: 1048576
users: {}
```

### Effects
- installs `ca-certificates`, `curl`, `gnupg`, `lsb-release`, `python3-pip`, `acl`
- creates and manages `{{ dir.data }}` and `{{ dir.ansible }}`
- disables `algif_aead` kernel module if `{{ bootstrap.disable_algif_aead }}` is `true`
- sets machine hostname to ansible host name if `{{ bootstrap.set_hostname }}` is `true`
- sets PAM limits if `{{ bootstrap.limits.enabled }}` is `true`
- creates and manages specified users if `{{ bootstrap.setup_users }}` is `true`
- installs sudo and sets up sudoers if `{{ bootstrap.setup_sudo }}` is `true`
- sets up swap file if `{{ bootstrap.swap.enabled }}` is `true`

### Handlers
- `restart machine` - restarts host