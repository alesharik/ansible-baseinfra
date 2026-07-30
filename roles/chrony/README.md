# chrony
__Tags - `chrony`__

Deploys chrony

### Usage
```yaml
    - alesharik.baseinfra.chrony
```

### Vars
```yaml
chrony:
  pools: # one `pool` line each; for single servers use extra_config
    - pool.ntp.org iburst burst
  makestep: # step rather than slew when off by more than threshold seconds
    threshold: 0.1
    limit: -1 # how many times, -1 for no limit
  minsources: 2 # sources that must agree before the clock is adjusted
  maxupdateskew: 5 # ppm; skew above this makes an update be ignored
  extra_config: "" # appended verbatim to the end of chrony.conf
```
`chrony` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

`extra_config` is written last, so it can add directives or narrow the ones
above. To serve NTP to a LAN, for instance, the role's `deny all` stays and the
`allow` follows it — note every other key is repeated, because the override is
wholesale:
```yaml
chrony:
  pools:
    - pool.ntp.org iburst burst
  makestep:
    threshold: 0.1
    limit: -1
  minsources: 2
  maxupdateskew: 5
  extra_config: |
    allow 10.0.0.0/8
    server ntp.corp.example iburst
```

The leap second directive is not configurable: the role picks `leapseclist` on
chrony >= 4.6 and `leapsectz right/UTC` below it, because `leapseclist` is a
fatal `Invalid directive` on Debian 12 (chrony 4.3) and Ubuntu 24.04 (4.5).

### Effects
- installs `chrony` with apt
- writes `/etc/chrony/chrony.conf`, replacing the packaged config, and removes
  the stale `/etc/chrony.conf` left by earlier versions of this role
- stops and disables `systemd-timesyncd`
- starts and enables `chrony`, restarting it when the config changes

### Handlers
- `restart chrony` - restarts chrony when the config changes

### Dependencies
- `bootstrap`