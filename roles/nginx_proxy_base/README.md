# nginx-proxy-base

Creates config and vhost directory for nginx-proxy

### Usage
```yaml
    - alesharik.baseinfra.nginx_proxy_base
```

### Vars
_No local variables_

### Effects
- creates `{{ dir.ansible }}/nginx-proxy`
- creates `{{ dir.ansible }}/nginx-proxy/vhost.d`

### Dependencies
- `bootstrap`