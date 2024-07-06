# Ansible Collection - alesharik.baseinfra

### Roles
- `bootstrap` installs base utils
- `chrony` - setup chrony NTP server

### `procusers` user group
This group exists for users assigned to processes (like nginx, postgres, etc).
`sudo` group is allowed to log in as users in this group without password.