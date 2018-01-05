local afr = require "afr"
local cjson = require "cjson"

local host = ngx.var.host
local lookupKey = afr.makeHostKey(host)

ngx.log(ngx.DEBUG, "[lookup] looking up key: ", lookupKey)

local result = afr.cacheLookupKey(lookupKey)
local rawResult = nil

----------------
-- No cached value, need to look it up in redis
----------------

if result == nil then
    ngx.log(ngx.DEBUG, "[lookup] cache miss for key: ", lookupKey)

    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeout(1000) -- 1 sec

    local ok, err = red:connect(AFR_REDIS_HOST, AFR_REDIS_PORT)
    if not ok then
        ngx.log(ngx.ERR, "[lookup] failed to connect: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local lookupRes, err = red:get(lookupKey)
    if not res and err then
        ngx.log(ngx.ERR, "[lookup] lookup failed: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if not lookupRes or lookupRes == ngx.null then
        ngx.log(ngx.INFO, "[lookup] empty lookup result: ", lookupKey)
        return ngx.redirect("https://www.deskpro.com/cloud-site-not-found?account=" .. ngx.escape_uri(host))
    end

    local success, decodeResult = pcall(cjson.decode, lookupRes)
    if not success then
        ngx.log(ngx.ERR, "[lookup] lookup decode failure: ", lookupRes)
        afr.cacheClearKey(lookupKey, lookupRes)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if not decodeResult or not decodeResult[AFR_PROXY_URL_VALUE_KEY] or decodeResult[AFR_PROXY_URL_VALUE_KEY] == "" then
        ngx.log(ngx.ERR, "[lookup] unexpected lookup result, missing key " .. AFR_PROXY_URL_VALUE_KEY ..": ", lookupRes)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    afr.cacheUpdateKey(lookupKey, decodeResult)
    result = decodeResult
    rawResult = lookupRes

----------------
-- Have a cached value, need to encode the stored table as json so we can pass it on
----------------

else
    ngx.log(ngx.DEBUG, "[lookup] cache hit for key: ", lookupKey)
    rawResult = cjson.encode(result)
end

-- Sets the var used in nginx.conf to proxy_pass
ngx.var.proxyPassUrl = result[AFR_PROXY_URL_VALUE_KEY]
ngx.log(ngx.DEBUG, "[lookup] proxy pass url: ", ngx.var.proxyPassUrl)

-- Passes on the JSON from the lookup as the X-Lookup header
if AFR_PASS_LOOKUP_HEADER and AFR_PASS_LOOKUP_HEADER ~= "" and AFR_PASS_LOOKUP_HEADER ~= "0" then
    ngx.req.set_header(AFR_PASS_LOOKUP_HEADER, rawResult)
end

-- Sets X-Forwarded-* headers if we want them
if AFR_SET_X_FWD_HEADERS and AFR_SET_X_FWD_HEADERS ~= "" and AFR_SET_X_FWD_HEADERS ~= "0" then
    ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    ngx.req.set_header("X-Forwarded-Host", host)

    if ngx.var.server_port == "8080" then
        ngx.req.set_header("X-Forwarded-Port", "80")
        ngx.req.set_header("X-Forwarded-Proto", "http")
    elseif ngx.var.server_port == "8433" then
        ngx.req.set_header("X-Forwarded-Port", "443")
        ngx.req.set_header("X-Forwarded-Proto", "https")
    end
end