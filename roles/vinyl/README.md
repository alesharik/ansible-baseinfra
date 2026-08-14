# vinyl
__Tags - `vinyl`__

Deploys [varnish](https://varnish-cache.org/) as a docker compose service, with
an haproxy sidecar that lets it fetch from origins that only speak HTTPS.

### Usage
```yaml
    - alesharik.baseinfra.vinyl
```
```yaml
vinyl:
  config: |
    import std;

    sub vcl_recv {
        set req.backend_hint = vinyl_connector;
    }
```

### Vars
```yaml
vinyl:
  image: varnish
  version: "9"
  config: "" # your VCL, without a `vcl 4.x;` line - the role writes that
  vcl_version: "4.1"
  listen_ips: [] # compose port mappings, one line each
  networks: [] # external docker networks to attach to
  storage: malloc # passed to varnishd as -s
  connector:
    enabled: true
    image: haproxy
    version: "3.2-alpine"
    origin_port: 443 # origin TLS port when a request carries no X-Vinyl-Port
    verify: required # or `none`, which trusts any certificate the origin sends
    ca_file: /etc/ssl/certs/ca-certificates.crt
    timeout:
      connect: 5s
      client: 300s
      server: 300s
  exporter:
    enabled: false
    image: ghcr.io/otto-de/prometheus-varnish-exporter
    version: 1.8.3-varnish-9.0.0
  directories:
    ansible: "{{ dir.ansible }}/vinyl" # compose project on the host
    data: "{{ dir.data }}/vinyl" # mounted at /data, only for file/persistent storage
```
`vinyl` is a plain dict override — setting it replaces the defaults wholesale,
so list every key above, not just the ones you are changing.

`listen_ips` is passed to compose untouched, so it takes the full docker syntax
— a bind address, a host port different from the container port, or `/udp`.
Nothing is published by default: the usual deployment puts a reverse proxy in
front on a shared docker network, where a host port would only widen the
surface.

`directories.data` is only created and only mounted when `storage` starts with
`file` or `persistent`. The default `malloc` cache lives in memory and needs no
directory at all.

### The VCL header is not yours

VCL requires `vcl 4.1;` to be the first line and every backend to be declared
before it is used, so the role owns the top of the file. It writes the version
line, then the connector backend, then your `vinyl.config`.

That means **`vinyl.config` must not contain a `vcl 4.x;` line**. A version line
left in it lands second in the rendered file and varnishd refuses to parse it,
which shows up as a container that will not start rather than as anything
pointing at the config — so the role asserts on it and fails the run with a
message naming the cause. Start your config at its first `import` or `backend`.

### Connector

Varnish cannot originate TLS. A backend declared in VCL speaks plain HTTP, so an
origin that only serves HTTPS — a sibling container behind its own certificate,
or any public site — is unreachable. The connector is an haproxy sidecar that
closes that gap:

```
        origin (any https host — container name, or public DNS)
          ↑ TLS, SNI from the Host header
        connector  (haproxy)
          ↑ plain HTTP over a unix domain socket
        vinyl      (varnish)
```

It is a **single dynamic forwarder**, not a set of per-origin proxies: it works
out where each request is going from the request itself, so one listener serves
every origin and there is nothing to keep in step as origins come and go.

Point a backend hint at it and the Host header becomes the target:

```vcl
sub vcl_recv {
    set req.backend_hint = vinyl_connector;
}
```

The `backend vinyl_connector` stanza is written by the role, so its socket path
and timeouts are never copied into your config. Override the defaults per
request with any of:

| header | default | meaning |
|---|---|---|
| `X-Vinyl-Target` | `Host` | hostname **or literal IP** to connect to |
| `X-Vinyl-Port` | `connector.origin_port` | origin TLS port |
| `X-Vinyl-Sni` | `Host` | SNI presented to the origin |

All three are stripped before the request leaves haproxy, so the origin never
sees them. Target and SNI are independent — a container reachable as `seomeow`
that serves a certificate for `seomeow.example.com` is fetched with:

```vcl
sub vcl_recv {
    set req.backend_hint = vinyl_connector;
    set req.http.X-Vinyl-Target = "seomeow";
    set req.http.X-Vinyl-Port = "8443";
}
```

A target that does not resolve gets an explicit `503` from the connector rather
than a hang against an unset destination. A target with no Host header to fall
back on gets a `400`.

The connector reaches origins by container name because it resolves through
docker's embedded DNS, which also forwards public names — so caching a public
site and caching a sibling container are the same code path. There is nothing to
configure for that: haproxy takes its nameservers from the container's
`/etc/resolv.conf`, which docker writes, so the connector follows whatever
networks the container is attached to. Names are resolved **per request**, so an
origin container that is recreated with a new IP is picked up without reloading
varnish.

`verify: required` is the default: the origin's chain is validated against
`ca_file`, and its name is checked against the SNI the connector sent — which is
the Host header unless `X-Vinyl-Sni` overrides it. An origin whose certificate is
self-signed, expired, or issued for a different name is refused, and the fetch
fails with a `503` rather than silently going through.

That refuses sibling containers behind self-signed certificates, which is the
usual private deployment. Turn verification off for those:

```yaml
vinyl:
  connector:
    verify: none
```

`verify: none` **trusts any certificate the origin presents**, so it is only
appropriate where the network path itself is trusted — a private docker network
between containers you run. `ca_file` is unused in that mode.

Since the SNI drives the name check, an origin reached by container name but
serving a public certificate needs the two split, or `required` will reject it:

```vcl
set req.http.X-Vinyl-Target = "seomeow";
set req.http.X-Vinyl-Sni = "seomeow.example.com";
```

There is deliberately **no `.probe`** on the connector backend — a probe would
hit the forwarding frontend and try to resolve its own Host header. So
`std.healthy(req.backend_hint)` on `vinyl_connector` is always true, and a
`set req.grace` guarded by it always applies.

Because it is declared first, `vinyl_connector` is also varnish's *default*
backend — with the role defaults and no `vinyl.config` at all, varnish starts and
proxies everything to the origin named in each request's Host header.

`connector.enabled: false` drops the sidecar, the socket volume and the injected
backend stanza. Do that when every origin you cache speaks plain HTTP — but note
that it also removes the only backend the role writes, so `vinyl.config` must
then declare at least one of its own. VCL with no backend does not compile
(`No backends or directors found in VCL program`) and varnish will not start.

### Effects
- creates and manages `{{ vinyl.directories.ansible }}` — `vinyl.vcl`,
  `haproxy.cfg`, `docker-varnish-entrypoint` and the compose project
- creates `{{ vinyl.directories.data }}`, only with `file`/`persistent` storage
- deploys docker compose project `vinyl` with containers `vinyl` and,
  with the connector on, `connector`
- the connector container starts as root, because the haproxy image's own uid
  cannot create a socket in the root-owned volume. Its config sets `user
  haproxy`, so the worker that handles traffic runs unprivileged once the socket
  is bound; the haproxy master stays root to respawn workers, as it always does

#### Docker networks
- connects both containers to the networks named in `networks`, which must
  already exist — the role does not create them

### Networking
- publishes nothing by default; `listen_ips` maps host ports onto the container
- varnish listens on `:80` HTTP and `:8443` PROXY inside the container
- the connector takes traffic only over `/run/vinyl/connector.sock`, on a tmpfs
  volume shared between the two containers. Its `8405` listener carries the
  healthcheck and `/metrics` and is reachable over the docker network, but
  nothing of the connector is published to the host

### Handlers
- `restart vinyl` - restarts the compose project
- `reload vinyl` - runs `varnishreload`, swapping the VCL without dropping the
  cache or open connections. A `vinyl.config` change notifies this rather than a
  restart

### Dependencies
- `bootstrap`
- `docker`

### Metrics

#### Varnish
With `exporter.enabled`, a `prometheus-varnish-exporter` sidecar reads varnish's
shared memory straight off the `varnish_tmpfs` volume — it needs no network path
to varnish — and answers on port `9131` at `/metrics`, labelled for the
collection's prometheus autodiscovery. The port is not published: the scrape
comes from vmagent over the docker network.

The image's root path serves an HTML landing page rather than metrics, so the
`prometheus.io.path` label is `/metrics`. Note the exporter tag pins a varnish
version too, and `1.8.1-varnish-9.0.1` is published **arm64 only** — pick a tag
that carries the architecture you deploy on.

#### Connector
The connector exports its own metrics whenever it runs. There is no sidecar and
no flag: haproxy's prometheus endpoint is compiled into the binary, so the
numbers come from the process actually serving the requests. It answers at
`/metrics` on port `8405` — the same unpublished listener as the healthcheck —
and the container carries the same autodiscovery labels as everything else.

Connector traffic appears under two proxies, `outbound` (the frontend varnish
talks to) and `origin` (the backend that re-originates over TLS):

| series | what it tells you |
|---|---|
| `haproxy_frontend_http_requests_total{proxy="outbound"}` | fetches varnish sent through the connector |
| `haproxy_backend_http_responses_total{proxy="origin",code="5xx"}` | origins that answered with an error |
| `haproxy_backend_connection_errors_total{proxy="origin"}` | origins that could not be connected to at all |
| `haproxy_backend_response_time_average_seconds{proxy="origin"}` | how slow the origins are |

`connection_errors_total` is the one to alert on: a certificate rejected by
`verify: required` lands there, and the request itself only ever shows up to
varnish as a `503`.
