local lib = {}

require("cache.ramcacher")(lib)
require("cache.fscacher")(lib)

return lib
