#jinja2: trim_blocks: True, lstrip_blocks: True
vcl {{ vinyl.vcl_version }};
{% if vinyl.connector.enabled %}

# Outbound TLS connector, rendered by the vinyl role. Point a backend hint here
# to fetch an origin that only speaks HTTPS - haproxy works out the target from
# the request and originates the TLS itself:
#
#   set req.backend_hint = vinyl_connector;
#
# The Host header is the target by default, so the common case sets nothing.
# To override, set any of these on the request:
#
#   X-Vinyl-Target  hostname or literal IP to connect to   (default: Host)
#   X-Vinyl-Port    origin TLS port                        (default: {{ vinyl.connector.origin_port }})
#   X-Vinyl-Sni     SNI presented to the origin            (default: Host)
#
# There is deliberately no .probe: a probe would hit the forwarding frontend and
# try to resolve its own Host header, so std.healthy() on this backend is always
# true.
backend vinyl_connector {
    .path = "/run/vinyl/connector.sock";
    .connect_timeout = {{ vinyl.connector.timeout.connect }};
    .first_byte_timeout = {{ vinyl.connector.timeout.server }};
}
{% endif %}

# --- vinyl.config below -----------------------------------------------------
{{ vinyl.config }}
