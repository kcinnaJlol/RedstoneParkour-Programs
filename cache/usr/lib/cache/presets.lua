local cachers = require("cache.cachers")
local fs = require("filesystem")

local lib = {}

local presetChainMT = {
  __call = function(self, cache)
    for _, preset in ipairs(self) do
      cache = preset(cache)
    end
    return cache
  end,
}
function lib.mkPresetChain(...)
  return setmetatable({...}, presetChainMT)
end

function lib.mkInsertPreset(f, ...)
  local args = table.pack(...)
  return function(cache)
    cache:add(f(table.unpack(args, 1, args.n)))
    return cache
  end
end

function lib.mkRamCacherPreset(interval, priority)
  return lib.mkInsertPreset(cachers.ramCacher, interval, priority)
end

function lib.mkFsCacherPreset(interval, priority, path)
  return function(cache)
    path = fs.concat(path, cache.name)
    cache:add(cachers.fsCacher(interval, priority, path))
    return cache
  end
end

return lib
