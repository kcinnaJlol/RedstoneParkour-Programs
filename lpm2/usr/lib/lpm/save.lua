return function(lpm)
  local constSer = require("constser")
  local tmpPhases = {}

  local function readSVD()
    local handle = io.open("/etc/lpm.svd", "rb")
    if not handle then return end
    local data = handle:read("*a")
    handle:close()
    return ser:unserialize(data)
  end
  readSVD = cache.wrap("lpm.readSVD", readSVD, cache.preset.lax)

  local function writeSVD(svd)
    local handle = io.open("/etc/lpm.svd", "wb")
    local data = ser.serialize(svd)
    handle:write(data)
    handle:close()
    readSVD[1]:flush(math.huge)
  end

  function lpm.getPhase(spec)
    local i = constSer(spec)
    local phase
    if tmpPhases[i] then
      local phase = tmpPhases[i][1]
      if phase and phase[3] > 0 then
	return table.unpack(phase)
      end
      
    end
    local svd = readSVD()
    return table.unpack(svd[i] or phase or {})
  end

  function lpm.setPhase(spec, phase, cacheSpec)
    local i = constSer(spec)
    local svd = readSVD()
    svd[i] = ser.serialize({phase, cacheSpec})
    writeSVD(svd)
  end

  function lpm.tmpSetPhase(spec, phase, cacheSpec, pri)
    local i = constSer(spec)
    if not tmpPhases[i] then
      tmpPhases[i] = {}
    end
    table.insert(tmpPhases[i], {phase, cacheSpec, pri})
    table.sort(tmpPhases[i], function(a,b) return a[3] > b[3] end)
  end

  function lpm.delTmpPhase(spec, phase, pri)
    local phases = tmpPhases[constSer(spec)]
    if not phases then return end
    local foundi
    for i,j in ipairs(phases) do
      if j[3] == pri then
	foundi = i
      end
    end
    table.remove(phases, foundi)
  end
end
