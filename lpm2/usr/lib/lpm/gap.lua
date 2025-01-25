local lpm = require("lpm")

local inet = require("internet")

local pkg = {}

function pkg:get()
  local lib = require(self.lib)
  return lib[self.attr](self.ver, table.unpack(self.args))
end

function pkg:dependencies()
  return self:get():dependencies()
end

function pkg:compareVersion(other)
  return self:get():compareVersion(other:get())
end

function pkg:phase(from, to, cache, installer)
  local this = self:get()
  local files = this:files()
  if from < to then
    if from < 1 and to == 3 then --direct install
      for url, target in pairs(files) do
	print(("%s -> %s"):format(url, target))
	local h = inet.request(url)
	assert(installer:installStream(h, target))
      end
      if this.postInstall then this:postInstall(installer) end
    elseif to < 3 then --put the files into the cache
      for url, target in pairs(files) do
	print(("%s -> cache"):format(url))
	local h = inet.request(url)
	assert(cache:writeStream(h, target))
      end
    elseif from >= 1 then --read the files from the cache
      for _, target in pairs(files) do
	print(("cache -> %s"):format(target))
	local h = cache:openRead(target)
	assert(installer:installStream(h, target))
	h:close()
      end
    end
  elseif from > to then
    if from == 3 and to < 1 then --direct uninstall
      for _, target in pairs(files) do

      end
    end
  end
end

local gap = {}
--[[ a package should have:
  - a compareVersion function; to compare versions
  - a dependencies function; to get dependencies (as hashables)
  - a files function; to get urls to download and where to put them
]]--
function gap.get(ver, lib, attr, args)
  return setmetatable({
      lib = lib,
      attr = attr,
      args = args,
      ver = ver,
		      }, {__index = pkg})
end

function gap.mkPackage(lib, attr, args, ver)
  return lpm.mkPackage("lpm.gap", "get", {lib, attr, args}, ver)
end

return gap
