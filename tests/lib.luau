--!nocheck
-- Minimal test kitabxanası (Lune üçün).
local Lib = {}

local results = { passed = 0, failed = 0, failures = {} }
Lib.results = results

local currentSuite = ""

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function Lib.describe(name: string, fn: () -> ())
	local prev = currentSuite
	currentSuite = (prev ~= "" and (prev .. " › ") or "") .. name
	fn()
	currentSuite = prev
end

function Lib.it(name: string, fn: () -> ())
	local full = (currentSuite ~= "" and (currentSuite .. " › ") or "") .. name
	local ok, err = xpcall(fn, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end)
	if ok then
		results.passed += 1
		print("  ✓ " .. full)
	else
		results.failed += 1
		table.insert(results.failures, { name = full, err = err })
		print("  ✗ " .. full)
		print("      " .. tostring(err):gsub("\n", "\n      "))
	end
end

function Lib.expect(actual: any)
	local e = {}
	function e.toBe(expected: any, msg: string?)
		if actual ~= expected then
			error(("gözlənilən %s, alınan %s %s"):format(fmt(expected), fmt(actual), msg or ""), 2)
		end
	end
	function e.toBeTruthy(msg: string?)
		if not actual then
			error(("doğru gözlənilirdi, alınan %s %s"):format(fmt(actual), msg or ""), 2)
		end
	end
	function e.toBeFalsy(msg: string?)
		if actual then
			error(("yanlış gözlənilirdi, alınan %s %s"):format(fmt(actual), msg or ""), 2)
		end
	end
	function e.toBeAtLeast(n: number, msg: string?)
		if not (actual >= n) then
			error(("≥ %s gözlənilirdi, alınan %s %s"):format(fmt(n), fmt(actual), msg or ""), 2)
		end
	end
	function e.toBeAtMost(n: number, msg: string?)
		if not (actual <= n) then
			error(("≤ %s gözlənilirdi, alınan %s %s"):format(fmt(n), fmt(actual), msg or ""), 2)
		end
	end
	function e.toBeNear(n: number, eps: number, msg: string?)
		if math.abs(actual - n) > eps then
			error(("%s ± %s gözlənilirdi, alınan %s %s"):format(fmt(n), fmt(eps), fmt(actual), msg or ""), 2)
		end
	end
	return e
end

-- Nəticə OK olmalıdır
function Lib.ok(result: any, msg: string?)
	if not result or not result.ok then
		error(("əməliyyat uğursuz: %s %s"):format(result and tostring(result.err) or "nil", msg or ""), 2)
	end
	return result
end

function Lib.fails(result: any, errKey: string?, msg: string?)
	if result and result.ok then
		error(("uğursuzluq gözlənilirdi %s"):format(msg or ""), 2)
	end
	if errKey and result.err ~= errKey then
		error(("xəta %s gözlənilirdi, alınan %s %s"):format(errKey, tostring(result.err), msg or ""), 2)
	end
	return result
end

return Lib
