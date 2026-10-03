--!nocheck
-- Kampaniya sonunda profilin JSON ölçüsü (DataStore limiti 4 MB)
local serde = require("@lune/serde")
local H = require("../harness")
local Bot = require("./Bot")
local Campaign = require("./Campaign")
local m = Campaign.run(H, Bot)
local json = serde.encode("json", m.profile)
print(("Profil JSON ölçüsü kampaniya sonunda: %d bayt (%.1f KB)"):format(#json, #json / 1024))
