# Nginx Reverse proxy

Environment variables:

* `ORIGIN_HOST` main server hostname or ip address
* `ORIGIN_PORT` main server port (optional, defaults to 80)
* `DOMAIN` domain name (optional, when supplied it wil get a valid certificate)

```
docker run -t -p 80:80 -p 443:443 -v $(pwd)/test/dhparam.pem:/etc/ssl/dhparam.pem:ro -e DOMAIN=docker.neufund.org -e ORIGIN_HOST=google.com front
```

# Caching

By default, succesfull `GET` responses are cached for one day. Error responses
(not `200`, `301` or `302`) are cached for five seconds. Methods other than
`GET` or `HEAD` are not cached at all. Specifically `POST` requests are not
cached.

The `X-Accel-Expires` header can be used to change the default cache time. The
value `0` disables caching of the result. Other numbers set the cache validity
in seconds. The normal cache affecting headers `Expires`, `Cache-Control`,
`Set-Cookie`, `Vary` are ignored, but they are passed to the 

The cache can be explicitely invalidated by the `ORIGIN_HOST`. To do this, the
origin sends the request to be invalidated with an additional header
`X-Accel-Purge: purge`. The `ORIGIN_HOST` will *imediately* be requested for the
updated content.

Cache entries can get aribitrarily removed, but this should not happen often.


# Rate limiting

The rate limiter is based on remote ip address. After an initial burst of ten
requests, the request rate is limited to one request per second. There is also
a hard limit of 100 open connections per ip address.

Connections are also required to send the headers and body within 5 seconds.
This prevents a class of attacks (‘slowloris’) where the attacker tries to keep
many connections open.
