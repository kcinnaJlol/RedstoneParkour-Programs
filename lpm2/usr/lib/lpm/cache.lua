local fs = require("filesystem")

local lib = {}

local fscache = {}

function fscache:mount()
  return self.path
end

function fscache:openRead(sub)
  return io.open(fs.concat(self.path, sub), "rb")
end

function fscache:openWrite(sub)
  return io.open(fs.concat(self.path, sub), "wb")
end

function fscache:writeStream(stream, sub)
  local h = self:openWrire(sub)
  for chunk in stream do
    h:write(chunk)
  end
  return h:close()
end

local fscacheMT = {__index = fscache}

function lib.get(pkgspec)

end
