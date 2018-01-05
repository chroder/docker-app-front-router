#!/bin/sh
if [ "$NAMESERVER" == "" ]; then
	export NAMESERVER=`cat /etc/resolv.conf | grep "nameserver" | awk '{print $2}' | tr '\n' ' '`
fi
if [ "$LOG_LEVEL" == "" ]; then
    export LOG_LEVEL="warn"
fi

if [ "$AFR_REDIS_HOST" == "" ]; then
	echo "!!!"
    echo "Must provide AFR_REDIS_HOST env variable"
    echo "!!!"
    echo
    exit 1
fi

if [ "$AFR_REDIS_PORT" == "" ]; then
    export AFR_REDIS_PORT=6379
fi

if [ "$AFR_CACHE_SIZE" == "" ]; then
    export AFR_CACHE_SIZE="5000"
fi

if [ "AFR_CACHE_TIME" == "" ]; then
    export AFR_CACHE_TIME="5"
fi

if [ "$AFR_REDIS_KEY_PREFIX" == "" ]; then
    export AFR_REDIS_KEY_PREFIX=""
fi

if [ "$AFR_PROXY_URL_VALUE_KEY" == "" ]; then
    export AFR_PROXY_URL_VALUE_KEY="backend"
fi

VARNAMES='$NAMESERVER:$LOG_LEVEL:$AFR_REDIS_HOST:$AFR_REDIS_PORT:$AFR_CACHE_SIZE:$AFR_CACHE_TIME:$AFR_REDIS_KEY_PREFIX:$AFR_PROXY_URL_VALUE_KEY:$AFR_PASS_LOOKUP_HEADER:$AFR_SET_X_FWD_HEADERS'
if [ ! -f /usr/local/openresty/nginx/conf/nginx.conf.tpl ]; then
    cp /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf.tpl
fi
envsubst "$VARNAMES" < /usr/local/openresty/nginx/conf/nginx.conf.tpl > /usr/local/openresty/nginx/conf/nginx.conf

echo "Starting nginx"
exec /usr/local/openresty/bin/openresty -g "daemon off;"
