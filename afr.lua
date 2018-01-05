local _M = {}

local lrucache = require "resty.lrucache"

local c, err = lrucache.new(AFR_CACHE_SIZE)
if not c then
    return error("failed to create the cache: " .. (err or "unknown"))
end

function _M.makeHostKey(host)
    return AFR_REDIS_KEY_PREFIX .. host
end

function _M.cacheLookupKey(key)
    return c:get(key)
end

function _M.cacheUpdateKey(key, value)
    return c:set(key, value, AFR_CACHE_TIME)
end

return _M