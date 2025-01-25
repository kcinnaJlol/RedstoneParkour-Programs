local gap = require("lpm.gap")
local inet = require("internet")
local ser = require("serialization")
local fs = require("filesystem")
local json = require("json")
local cache = require("cache")
local lpm = require("lpm")

local lib = {}

lib.path = "/usr"

local pkg = {}

local function iso8601(timestamp)
  return os.date("%FT%TZ", timestamp)
end

local function request(url, data, headers)
  local s, handle = pcall(inet.request, url, data, headers)
  if not s then return s,handle end
  local s, ret = pcall(function()
      local ret = ""
      for chunk in handle do
	ret = ret..chunk
      end
      return ret
  end)
  if not s then return s, ret end
  return ret
end

lib.GH_API_HEADERS = {
  ["X-GitHub-Api-Version"] = "2022-11-28",
  ["user-agent"] = "lpm.oppm/OpenComputers",
}
local function ghApi(endpoint)
  local ret = request("https://api.github.com/"..endpoint, nil, lib.GH_API_HEADERS)
  ret = assert(json.decode(ret))
  return ret
end

lib.ghApi = ghApi

local function formatGithubPath(repo, ref, path)
  return string.format("https://raw.githubusercontent.com/%s/%s/path", repo, ref, path)
end

local function getPackages(repo, ref)
  local url = formatGithubPath(repo, ref, "programs.cfg")
  return ser.unserialize(request(url) or "{}")
end
getPackages = cache.wrap("lpm.oppm.getPackages", getPackages, cache.preset.persist)

local function findCommit(timestamp, repo)
  local commits = ghApi(("repos/%s/commits?until=%s&per_page=1"):format(repo, iso8601(timestamp)))
  return commits[1].sha
end
findCommit = cache.wrap("lpm.oppm.findCommit", findCommit, cache.preset.persist)

lib.regSets = {}

function lib.getRegSet(i)
  local set = lib.regSets[i]
  if type(set) == "table" then
    return set
  elseif type(set) == "function" then
    return set()
  end
end

function lib.findRegisteredPackageRepo(name)
  for i in pairs(lib.regSets) do
    local set = lib.getRegSet(i)
    local repo = set[name]
    if repo then return repo, set[1] end
  end
end

function lib.mkRegisteredSetFromInfo(info, timestamp)
  local set = {timestamp}
  for name, repoinfo in pairs(info) do
    if repoinfo.repo then
      local ref = findCommit(timestamp, repoinfo.repo)
      local pkgs = getPackages(repoinfo.repo, ref)
      for pkg in pkgs do
	set[pkg] = repoinfo.repo
      end
    end
    if repoinfo.programs then
      for name, info in pairs(repoinfo.programs) do
	local repo, path = info.repo:match("$([^/]+/[^/]+)/blob/master/(.+)")
	local pkg = {
	  files = {
	    -- i have no fucking clue how this should work
	    ["master/"..path] = "//home"
	  },
	  repo = repo,
	  name = name,
	}
      end
    end
  end
  return set
end

function lib.mkRegSetFromRepo(timestamp, repo, path)
  local ref = findCommit(timestamp, repo)
  local info = ser.unserialize(request(formatGithubPath(repo, ref, path)))
  return lib.mkRegisteredSetFromInfo(info)
end

function lib.mkOfficialRegSet(timestamp)
  return lib.mkRegSetFromRepo(timestamp, "OpenPrograms/openprograms.github.io", "repos.cfg")
end

function pkg:dependencies()
  local repoPkgs = getPackages(self.repo, self.ref)
  local deps = {}
  for name, path in pairs(self.info.dependencies or {}) do
    if not name:match("^%w+://") then
      if repoPkgs[name] then
	table.insert(deps, lib.mkPackage(self.repo, name, path, self.timestamp))
      else
	table.insert(deps, lib.mkRegisteredPackage(name, path, self.timestamp))
      end
    end
  end
  return {run = deps}
end

function pkg:compareVersion(other)
  return self.timestamp > other.timestamp
end

function pkg:files()
  local files = {}
  for from, to in pairs(self.info.files) do
    if to:sub(1,2) == "//" then
      to = to:sub(2)
    else
      to = fs.concat(lib.path, to)
    end
    local flag, source = from:match("([%?:]?)master/(.+)")
    if flag == "?" then to = {to, optional = true}
    elseif flag == ":" then error("no directory support (yet)") end
    local url = ("https://raw.githubusercontent.com/%s/%s/%s"):format(self.repo, self.ref, source)
    local name = source:match("[^/]+$")
    to = fs.concat(to, name)
    files[url] = to
  end
  for url, to in pairs(self.info.dependencies or {}) do
    if url:match("^%w+://") then
      if to:sub(1,2) == "//" then
	to = to:sub(2)
      else
	to = fs.concat(lib.path, to)
      end
      files[url] = to
    end
  end
  return files
end

function pkg:postInstall(installer)
  if self.info.postinstall then -- minitel uses this so support it i guess
    for _, cmd in ipairs(self.info.postinstall) do
      os.execute(cmd)
    end
  end
end

function lib.getInlinePackage(timestamp, info, path)
  return setmetatable({
      info = info,
      path = path,
      timestamp = timestamp,
      repo = info.repo,
      ref = findCommit(timestamp, info.repo),
      name = info.name
		      }, {__index=pkg})
end

function lib.get(timestamp, repo, name, path)
  local ref = findCommit(timestamp, repo)
  local packages = getPackages(repo, ref)
  if packages[name] then
    return setmetatable({
	info = packages[name],
	path = path,
	timestamp = timestamp,
	ref = ref,
	repo = repo,
	name = name,
			}, {__index=pkg})
  end
end

function lib.mkInlinePackage(info, path, timestamp)
  return gap.mkPackage("lpm.oppm", "getInline", {info, path}, timestamp)
end

function lib.mkPackage(repo, name, path, timestamp)
  return gap.mkPackage("lpm.oppm", "get", {repo, name, path}, timestamp)
end

function lib.mkRegisteredPackage(name, path)
  --assert(timestamp == lib.timestamp)
  local repo, timestamp = lib.findRegisteredPackageRepo(name)
  if type(repo) == "string" then
    return lib.mkPackage(repo, name, path, timestamp)
  elseif type(repo) == "table" then
    return lib.mkInlinePackage(info, path, timestamp)
  end
end

function lib.mkRegSetDirectory(set)
  local function index(self, i)
    return lib.mkRegisteredPackage(i, lib.path)
  end

  local function mkIter(self)
    return function inext(t, i)
      local newi = next(t, i)
      return self[newi]
    end
  end
  return setmetatable({}, {__index = index, __pairs = mkIter})
end

function lib.mkRegSetsDirectory()
  local function index(self, i)
    if i:sub(1,1) == "@" then
      local set = lib.regSets[i:sub(2)]
      return lib.mkRegSetDirectory(set)
    else
      return lib.mkRegisteredPackage(i, lib.path)
    end
  end

  local function mkIter(self)
    return function inext(t, i)
      local newi = next(t, i)
      return self[newi]
    end
  end
  return setmetatable({}, {__index = index, __pairs = mkIter})
end
return lib
