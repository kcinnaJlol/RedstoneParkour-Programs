local lpm = require("lpm")
local shell = require("shell")
local argparse = shell.parse

local args, opts = argparse(...)
local cmd = table.remove(args, 1)

local function takeArgs(x)
  x = x or 1
  local ret = {}
  local argn = #args
  table.move(args, 1, x, 1, ret)
  table.move(args, x+1, argn, 1)
  return table.unpack(ret)
end

local function doPhases(ops)
  for _, op in ipairs(ops) do
    print(("[%u -> %u] %s"):format(op.from, op.to, op.path))
  end

  for _, op in ipairs(ops) do
    op.pkg:doPhase(op.from, op.to)
  end
end

local function mkOp(path, to)
  local op = {path=path, to=to}
  local pkg = lpm.pkgs:entry(path)
  local from, cacheSpec = lpm.getPhase(pkg)
  op.pkg = pkg
  op.from, op.cache = from, cacheSpec
  return op
end

local function setArgPkgsPhase(to)
  local ops = {}
  while #args > 0 do
    table.insert(ops, mkOp(takeArgs(1)))
  end
  return doPhases(ops)
end

local cmds = {}

function cmds.install()
  setArgsPkgsPhase(3)
end
