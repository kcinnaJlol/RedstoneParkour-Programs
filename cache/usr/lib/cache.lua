local lib = {}

local cache = {}

function cache:get(args)
  local ret, reti

  -- get the earliest cacher that has a value
  for i, cacher in ipairs(self.cachers) do
    if not cacher.has or cacher:has(args) then
      ret = cacher:get(args)
      if ret and ret[1] then reti = i break end
    end
  end

  -- update all earlier cachers with the value
  for i = 1, reti do
    local cacher = self.cachers[i]
    if cacher.set then
      cacher:set(args, ret)
    end
  end
  return ret
end

function cache:evict(dt)
  for _, cacher in ipairs(self.cachers) do
    if cacher.evict then
      cacher:evict(dt)
    end
  end
end

local function compareCachers(a,b)
  return (a.priority or 0) > (b.priority or 0)
end

function cache:add(cacher)
  --implement bsearch later
  table.insert(self.cachers, cacher)
  table.sort(self.cachers, compareCachers)
  return cacher
end

local cacheMT = {__index = cache}

lib.overrides = {}
local function onNewCache(caches, name, newCache)
  if lib.overrides[name] then
    for _, override in ipairs(lib.overrides[name]) do
      newCache = override(newCache)
    end
  end
  rawset(caches, name, newCache)
end

lib.caches = setmetatable({}, {__newindex = onNewCache})

function lib.mkCache(name)
  local newCache = setmetatable({name = name, cachers = {}}, cacheMT)
  lib.caches[name] = newCache
  return newCache
end

-- use as: cache.preset.aggressive(cache.mkCache("lpm.githubAPI"))
lib.preset = setmetatable({}, {__index = function() return function() end end})

local wrapPresetMT = {
  __index = {
    get = function(self, args)
      return table.pack(self[1](table.unpack(args, 1, args.n)))
    end,
    priority = -256
  }
}

function lib.preset.wrap(f)
  return function(cache)
    cache:add(setmetatable({f}, wrapPresetMT))
    return cache
  end
end

local wrapMT = {
  __call = function(self, ...)
    local cache = self[1]
    local args = table.pack(...)
    local ret = cache:get(args) or {}
    return table.unpack(ret, 1, ret.n)
  end
}

function lib.wrap(name, f, ...)
  local cache = lib.preset.wrap(f)(lib.mkCache(name))
  for _, preset in ipairs({...}) do
    cache = preset(cache)
  end
  return setmetatable({cache}, wrapMT)
end

do -- init config
  local conf = loadfile("/etc/cache.conf.lua")
  if conf then conf(lib) end
end

return lib
