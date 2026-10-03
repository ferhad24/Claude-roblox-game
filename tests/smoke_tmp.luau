local H = require("./harness")
local Catalog = H.require("src/shared/Core/Catalog")
local Locales = H.require("src/shared/Locales")
local errs = Catalog.validate(Locales.maps)
for _, e in errs do
	print("ERR", e)
end
print("errors:", #errs)
