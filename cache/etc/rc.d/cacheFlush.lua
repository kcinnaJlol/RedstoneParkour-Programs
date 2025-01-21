local event = require("event")
local computer = require("computer")
local libCache = require("cache")

local timerID

local args = args or {}

local timerInterval = args.interval or 60

local messages = {
  alreadyActive = "timed cache evicter is already active",
  started = "timed cache evicter started: interval %us, id %u",
  alreadyStopped = "timed cache evicter is already stopped",
  stopped = "timed cache evicter stopped",
  interval = "eviction interval is currently %us",
}

local prevEvict
local function evict()
  for _, cache in pairs(libCache.caches) do
    cache:evict(timerInterval)
  end
  return true
end

function start()
  if timerID then
    print(messages.alreadyActive)
    return
  end
  prevEvict = computer.uptime()
  timerID = event.timer(timerInterval, evict, math.huge)
  print(messages.started:format(timerInterval, timerID))
end

function stop()
  if not timerID then
    print(messages.alreadyStopped)
    return
  end
  event.cancel(timerID)
  timerID = nil
  print(messages.stopped)
end

function interval(newInterval)
  newInterval = tonumber(newInterval or "")
  if not newInterval then
    print(messages.interval:format(timerInterval))
  else
    timerInterval = newInterval
    if timerID then
      stop()
      start()
    end
  end
end
