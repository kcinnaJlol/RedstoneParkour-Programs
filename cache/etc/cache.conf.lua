local cache = ...
local libPresets = require("cache.presets")
cache.preset.default = libPresets.mkPresetChain(
  libPresets.mkRamCacherPreset(nil,nil),
  libPresets.mkFsCacherPreset(nil,nil,"/tmp/cache")
)

cache.preset.persist = libPresets.mkPresetChain(
  libPresets.mkRamCacherPreset(nil,nil),
  libPresets.mkFsCacherPreset(nil,nil,"/tmp/cache"),
  libPresets.mkFsCacherPreset(math.huge,64,"/var/cache")
)
