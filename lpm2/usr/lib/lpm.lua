local sha256 = require("lockbox.digest.sha2_256")()
local streamutil = require("lockbox.util.stream")
local ser = require("serialization")
local libinstaller = require("lpm.installer")
local constSer = require("constser")
local cache = require("cache")
local ser = require("serialization")

local lpm = {}


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

function pkg:hash()
  sha256.init()
  sha256.update(streamutil:fromStr(ser.serialize({self.lib, self.attr, self.args})))
  sha256.finish()
  return sha256.asHex()
end

function lpm.doPhase(pkg, from, to)
  local installer = libinstaller.mkInstaller()
  self:get():phase(from, to, setmetatable({}, {__index = error}), installer)
end

pkg.type = "package"

--[[ a package should have:
  - a compareVersion function; to compare versions
  - a dependencies function; to get dependencies (as hashables)
  - a phase function; to progress through: 1(fetch), 2(build), 3(install)
  this gets a range of phases: (from..to), a versatile cacher, and an installer that can install *both* a file in the cache and a string (in memory)
]]--
function lpm.mkPackage(lib, attr, args, ver)
  return setmetatable({
      lib = lib,
      attr = attr,
      args = args,
      ver = ver,
		      }, {__index=pkg})
end

local dirMT = {__index = {
		 dirEntry = function(self, path, ...)
		   local what = self
		   local dirs, name = path:match("(.-/?)([^/]*)$")
		   if dirs and #dirs > 0 then
		     for sub in dirs:gmatch("([^/]*)/") do
		       what = what.entries[sub]
		       if not what then return end
		     end
		   end
		   if name and #name > 0 then
		     local old = what.entries[name]
		     if select("#", ...) > 0 then
		       what.entries[name] = (...)
		     end
		     return old
		   else
		     return what
		   end
		 end,
		 type = "directory"
	      }}

function lpm.mkDirectory(entries)
  local t = setmetatable({entries = entries or {}}, dirMT)
  return t
end

do -- init config
  local conf = loadfile("/etc/lpm.conf.lua")
  setmetatable(lpm, {__index=function(self,i)
		       if i == "pkgs" and conf then
			 self[i] = conf(self)
			 setmetatable(self, nil)
			 return self[i]
  end})
end

return lpm
