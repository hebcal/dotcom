# /etc/varnish/acmetool.vcl

# Forward challenge-requests to acmetool, which will listen to port 402
# when issuing lets encrypt requests

backend acmetool {
   .host = "127.0.0.1";
   .port = "402";
}

sub vcl_recv {
    if (req.url ~ "^/.well-known/acme-challenge/") {
        set req.backend_hint = acmetool;
        return(pass);
    }
}
