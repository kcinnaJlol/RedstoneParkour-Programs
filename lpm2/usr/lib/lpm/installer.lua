local fs = require("filesystem")

local function parent(path)
  return fs.concat(path, "..")
end

local function parseTarget(target)
  if type(target) == "string" then
    return target, {}
  elseif type(target) == "table" then
    return target[1], target
  end
end

local installer = {}

function installer:addOwned(path)
  table.insert(self.owned, path)
end

function installer:getOwned()
  return self.owned
end

function installer:ensureDirectory(dir)
  return fs.makeDirectory(dir)
end

function installer:installStream(stream, target)
  local path, opt = parseTarget(target)
  if opt.optional and fs.exists(path) then return end
  self:ensureDirectory(parent(path))
  local handle = io.open(path, "wb")
  local s,r = pcall(function()
      for chunk in stream do
	handle:write(chunk)
      end
  end)
  handle:close()
  self:addOwned(path)
  return s,r
end

local lib = {}

function lib.mkInstaller()
  return setmetatable({owned = {}}, {__index = installer})
end
return lib
