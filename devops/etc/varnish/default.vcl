# Varnish config for www.hebcal.com
vcl 4.0;

# Load Let's Encrypt config before other rules
include "/etc/varnish/letsencrypt.vcl";

import std;
import vsthrottle;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "www-internal.hebcal.com";
    .port = "8080";
}

acl purge {
    "localhost";
}

sub vcl_recv {
    set req.http.X-Client-IP = client.ip;

    if (std.port(server.ip) == 443) {
        set req.http.X-Forwarded-Proto = "https";
    }

    if (req.url ~ "^/ical/.*\.ics" || req.url ~ "^/export/") {
        return(synth(750, "Moved Temporarily"));
    }

    if (req.url ~ "^/yahrzeit/yahrzeit.cgi/.*\.(ics|vcs|csv|dba)"
        || req.url ~ "^/hebcal/index.cgi/.*\.(ics|vcs|csv|dba|pdf)") {
        return(synth(750, "Moved Temporarily"));
    }

    if (req.url ~ "^/yahrzeit/undefined") {
        return(synth(751, "Not Found"));
    }

    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    if (req.url ~ "^/i/"
        || req.url ~ "^/holidays/"
        || req.url ~ "^/sedrot/"
        || req.url ~ "^/home/wp-content/themes/wordpress-bootstrap-.*/"
        || req.url ~ "^/home/wp-content/plugins/syntaxhighlighter/"
        || req.url ~ "^/home/wp-content/uploads/"
        || req.url ~ "^/home/wp-includes/css/"
        || req.url ~ "^/home/wp-includes/js/") {
        unset req.http.cookie;
    }

    if (req.url ~ "^/shabbat/\?" || req.url ~ "\?.*cfg=") {
        unset req.http.cookie;
    }

    if (req.url ~ "^/favicon\.ico" || req.url ~ "^/etc/") {
        unset req.http.cookie;
        unset req.http.user-agent;
    }

    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate" && req.http.user-agent !~ "MSIE") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            unset req.http.Accept-Encoding;
        }
    }

    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405, "Not allowed."));
        }
        return (purge);
    }

    if (vsthrottle.is_denied(client.identity, 90, 10s)) {
        # Client has exceeded 90 reqs per 10s
        return (synth(429, "Too Many Requests"));
    }

    if (! (req.url ~ "\?.*cfg=") && std.port(server.ip) == 80) {
        return(synth(752, "HTTPS Required"));
    }
}

sub vcl_synth {
    # force redirect to dedicated download server
    if (resp.status == 750) {
        set resp.http.Location = "http://download.hebcal.com" + req.url;
        set resp.status = 301;
        set resp.http.Content-Type = "application/json";
        synthetic( {"{ "err": ""} + resp.reason + {"" } "} );
        return(deliver);
    }
    if (resp.status == 751) {
        set resp.status = 404;
        set resp.http.Content-Type = "application/json";
        synthetic( {"{ "err": ""} + resp.reason + {"" } "} );
        return(deliver);
    }
    # force https redirect
    if (resp.status == 752) {
        set resp.http.Location = "https://www.hebcal.com" + req.url;
        set resp.status = 301;
        set resp.http.Content-Type = "application/json";
        synthetic( {"{ "err": "HTTPS Required" } "} );
        return(deliver);
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    if (req.url ~ "\?.*cfg=") {
        set resp.http.Access-Control-Allow-Origin = "*";
    }
}
