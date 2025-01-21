local constSerialize
function constSerialize(what)
  if type(what) == "table" then
    local numIndices = {}
    local strIndices = {}
    local hasTrue = false
    local hasFalse = false
    for i in pairs(what) do
      if type(i) == "number" then
	table.insert(numIndices, i)
      elseif type(i) == "string" then
	table.insert(strIndices, i)
      elseif i == true then
	hasTrue = true
      elseif i == false then
	hasFalse = true
      end
    end
    table.sort(numIndices)
    table.sort(strIndices)

    local out = ""
    for i in ipairs(numIndices) do
      local j = what[i]
      out = out..("[%s]=%s,"):format(ser.serialize(i), ser.serialize(j))
    end
    for i in ipairs(strIndices) do
      local j = what[i]
      out = out..("[%s]=%s,"):format(ser.serialize(i), ser.serialize(j))
    end
    if hasFalse then
      out = out..("[false]=%s,"):format(ser.serialize(what[false]))
    end
    if hasTrue then
      out = out..("[true]=%s,"):format(ser.serialize(what[true]))
    end
    return "{"..out.."}"
  else
    return ser.serialize(what)
  end
end
return constSerialize
