#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

import vsthrottle;

# Default backend definition. Set this to point to your content server.
backend default {
#    .host = "w1.hebcal.com";
    .host = "10.128.109.86";
    .port = "8080";
}

acl purge {
    "localhost";
}

sub vcl_recv {
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
        || req.url ~ "^/torah/"
        || req.url ~ "^/home/wp-content/themes/wordpress-bootstrap-master/"
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

    if (vsthrottle.is_denied(client.identity, 60, 10s)) {
        # Client has exceeded 60 reqs per 10s
        return (synth(429, "Too Many Requests"));
    }

    set req.http.X-Client-IP = client.ip;
}

sub vcl_synth {
    if (resp.status == 750) {
        set resp.http.Location = "http://download.hebcal.com" + req.url;
        set resp.status = 301;
	synthetic("Moved.");
        return(deliver);
    }
    if (resp.status == 751) {
        set resp.status = 404;
	synthetic("Not Found.");
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
}
