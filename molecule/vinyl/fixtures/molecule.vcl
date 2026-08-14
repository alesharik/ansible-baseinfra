# Fixture VCL for the vinyl-connector platform.
#
# Deliberately carries no `vcl 4.1;` line: the role writes that, and a config
# that still had one would fail the assert in tasks/main.yaml. The `import`
# below sits after the role's injected backend in the rendered file, which is
# what proves the injected header does not break a normal config.
import std;

# 127.0.0.1 only, so the two halves of the ACL are reachable from the test:
# a request through the published port arrives from the docker gateway and is
# refused, one sent from inside varnish's own netns is allowed.
acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
}

sub vcl_recv {
    set req.backend_hint = vinyl_connector;

    # Host and target are different things: this host name is never resolved,
    # only sent as Host, and the connector is told where to actually go.
    if (req.http.host == "alias.molecule.test") {
        set req.http.X-Vinyl-Target = "origin.molecule.test";
    }
    # nothing resolves this - the connector must say so rather than hang
    if (req.http.host == "broken.molecule.test") {
        set req.http.X-Vinyl-Target = "no-such-host.molecule.invalid";
    }
    # the origin's second listener, reached only by overriding the port
    if (req.url ~ "^/port8443") {
        set req.http.X-Vinyl-Target = "origin.molecule.test";
        set req.http.X-Vinyl-Port = "8443";
    }
    # a literal IP target takes haproxy's set-dst shortcut instead of DNS
    if (req.url ~ "^/byip") {
        set req.http.X-Vinyl-Target = req.http.X-Molecule-Ip;
        set req.http.X-Vinyl-Sni = "origin.molecule.test";
    }

    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "purge not allowed from " + client.ip));
        }
        return (purge);
    }

    set req.url = std.querysort(req.url);
    set req.url = regsuball(req.url, "(utm_[a-z]+|fbclid|gclid)=[^&]*&?", "");
    set req.url = regsub(req.url, "[?&]+$", "");

    if (req.url ~ "^[^?]*\.(css|js|png|woff2)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }
}

sub vcl_backend_response {
    if (bereq.url ~ "^[^?]*\.(css|js|png|woff2)(\?.*)?$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 1d;
    }
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Vinyl-Cache = "HIT";
    } else {
        set resp.http.X-Vinyl-Cache = "MISS";
    }
    set resp.http.X-Vinyl-Hits = obj.hits;
}
