return function(lib)
  local ser = require("serialization")
  local constSer = require("constser")
  local fs = require("filesystem")
  local libsha256 = require("lockbox.digest.sha2_256")()
  local streamutils = require("lockbox.util.stream")
  lib.fsCacherDefaults = {
    interval = 3600,
    priority = 128,
  }

  

  --[[function percentEncode(str)
    return what:gsub("%W", function(ch) return ("%X"):format(ch:byte()) end)
    end]]--

  local function sha256(str)
    local stream = streamutils.fromString(str)
    libsha256.init()
    libsha256.update(stream)
    libsha256.finish()
    return libsha256.asHex()
  end
  
  local fsCache = {}
  function fsCache:getPath(args)
    local serialized = constSerialize(args)
    local hashed = sha256(serialized)
    return fs.concat(self.path, hashed)
  end

  function fsCache:has(args)
    local path = self:getPath(args)
    return fs.exists(path)
  end

  function fsCache:get(args)
    local path = self:getPath(args)
    local handle = io.open(path, "rb")
    local content = handle:read("*a")
    handle:close()
    return ser.unserialize(content)
  end

  function fsCache:set(args, what)
    local path = self:getPath(args)
    local dir = fs.concat(path, "..")
    fs.makeDirectory(dir)
    local handle = io.open(path, "wb")
    local content = ser.serialize(what)
    handle:write(content)
    handle:close()
  end

  function fsCache:evict(dt)
    self.timeLeft = self.timeLeft - dt
    -- this is so that a math.huge interval evicts with a math.huge dt
    if not (self.timeLeft > 0) then
      for sub in fs.list(self.path) do
	fs.remove(fs.concat(self.path, sub))
      end
      self.timeLeft = self.interval
    end
  end

  local fsCacherMT = {__index = fsCache}
  function lib.fsCacher(interval, priority, path)
    interval = interval or lib.fsCacherDefaults.interval
    priority = priority or lib.fsCacherDefaults.priority
    return setmetatable({
	interval = interval,
	priority = priority,
	timeLeft = interval,
	path = path
			}, fsCacherMT)
  end
  
end
