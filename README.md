This sets up an nginx server that acts as a front-router for host names to
proxy them back to app servers.

The use-case is to map host names (i.e. for different apps or even different kinds of customers)
to backends based on a redis lookup.

For example, `customer-a.example.com` might be using `v1.app.foo.example.com`, and
`customer-b.example.com` might be using `v2.app.foo.example.com`.

It may not be desirable (or even possible) to use DNS. In those cases, this front-router
can sit in front of your app clusters and proxy requests to the proper backends.


```
                                        +-----+
                                        |Redis|               +----------------+
                                        +----^+               | App Cluster v1 |
               +-------------------+         |                +-^--------------+
+---------+    | Node balancer     |    +------------------+    |
| Request +----> & SSL termination +----> App Front Router +----+
+---------+    +-------------------+    +------------------+    |
                                                              +-v--------------+
                                                              | App Cluster v2 |
                                                              +----------------+
```

# Example usage

```
docker run . \
  --ulimit nofile=10000 \
  -e "AFR_REDIS_HOST=192.168.99.100" \
  -e "AFR_REDIS_PORT=32784" \
  -e "AFR_REDIS_KEY_PREFIX=site" \
  -e "AFR_SET_X_FWD_HEADERS=1"
  -p 80:8080
```

**Note: ulimit**

nginx is set up with 10000 worker connections. This is a lot, but should be fine (and desirable) in most production environments. But the real
max is limited by the environments ulimit which is typically quite low (~1024). So the `--ulimit` flag should be specified to raise it for
nginx.

# Exposed Ports

+--------+--------------------------------------------------------------------------------------------------------------------------------------+
| Port   | Description                                                                                                                          |
+--------+--------------------------------------------------------------------------------------------------------------------------------------+
| `8080` | Main http target port. Any request here goes through the lookup process and is proxied to a backend.                                 |
+--------+--------------------------------------------------------------------------------------------------------------------------------------+
| `8433` | Same as 8080, except this can be used to hint that the upstream request from the user is a HTTPS request. This can make it easier to |
|        | use this proxy with the `AFR_SET_X_FWD_HEADERS` so the correct protocal is set in `X-Forwarded-Proto` and `X-Forwarded-Port`.        |
|        | Note that this proxy still only operates over http only; targetting this port simply is an indicator for the purposes of headers.    |
+--------+--------------------------------------------------------------------------------------------------------------------------------------+
| `8111` | This port serves nginx [`stub_status`](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html).                              |
+--------+--------------------------------------------------------------------------------------------------------------------------------------+

# Environmental Variables

The following environmental variables are available to change some small operational properties of the service:

+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| Variable                  | Description                                                                                                                                     |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_REDIS_HOST`          | (Required) The hostname or IP address of the redis server containing lookup information                                                         |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_REDIS_PORT`          | The redis port. Default: `6379`                                                                                                                 |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_REDIS_KEY_PREFIX`    | Prefix redis keys with this string. For example, `account:`. Default: `''` (none)                                                               |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_PROXY_URL_VALUE_KEY` | The key of the JSON map containing the value for the backend to pass the request to. Default: `backend`                                         |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_CACHE_SIZE`          | How many cached lookups to keep in memory. Default: `5000`                                                                                      |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_CACHE_SIZE`          | How many cached lookups to keep in memory. Default: `5000`                                                                                      |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_PASS_LOOKUP_HEADER`  | Specify a header name to pass the full lookup string to the backend server. For example, `X-Lookup-Data`. Leave blank to not send anything.     |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `AFR_SET_X_FWD_HEADERS`   | Set the value to `1` to pass `X-Forwarded-*` headers (e.g. such as the users real IP address).                                                  |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `NAMESERVER`              | Which DNS resolver nginx should use to resolve host names (if the lookup returns a hostname). Default: THe resolver in /etc/resolve.conf        |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+
| `LOG_LEVEL`               | nginx error log level. Default: _warn_                                                                                                          |
+---------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------+

You can specify these as `-e "VAR=VAL"` flags when running the image. Another way is to create your own Dockerfile and codify the [`ENV`](https://docs.docker.com/engine/reference/builder/#env)
vars within.