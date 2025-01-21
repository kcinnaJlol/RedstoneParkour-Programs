return function(lib)
  lib.ramCacherDefaults = {
    interval = 120,
    priority = 256,
  }

  local ramCache = {}
  function ramCache:get(args)
    for _, item in ipairs(self.cache) do
      if item[1].n == args.n then
	for i = 1, item[1].n do
	  if not item[2][i] == args[i] then
	    item = nil
	    break
	  end
	end
      end
      
      if item then
	return item[2]
      end
    end
  end

  function ramCache:has(args)
    return self:get(args)
  end

  function ramCache:set(args, ret)
    table.insert(self.cache, 1, {args, ret})
  end

  function ramCache:evict(dt)
    self.timeLeft = self.timeLeft - dt
    -- this is so that a math.huge interval evicts with a math.huge dt
    if not (self.timeLeft > 0) then
      self.cache = {}
      self.timeLeft = self.interval
    end
  end

  local ramCacherMT = {__index = ramCache}
  function lib.ramCacher(interval, priority)
    interval = interval or lib.ramCacherDefaults.interval
    priority = priority or lib.ramCacherDefaults.priority
    return setmetatable({
	interval = interval,
	priority = priority,
	timeLeft = interval,
	cache = {}
			}, ramCacherMT)
  end
end
