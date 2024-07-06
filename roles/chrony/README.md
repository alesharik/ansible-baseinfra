# chrony
__Tags - `chrony`__

Deploys chrony

### Usage
```yaml
    - alesharik.baseinfra.chrony
```

### Effects
- installs `chrony` with apt
- stops and disables `systemd-timesyncd`
- starts and enables `chrony`

### Dependencies
- `bootstrap`