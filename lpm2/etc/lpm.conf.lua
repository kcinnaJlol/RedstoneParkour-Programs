local lpmoppm = require("lpm.oppm")

lpmoppm.githubTimestamp = 1737397824

local regsets = {lpmoppm.getOfficialRegistrationSet()}

local pkgs = lpm.mkDirectory({})
pkgs:entry(lpmoppm.mkOppmDirectory(regsets))

return pkgs
