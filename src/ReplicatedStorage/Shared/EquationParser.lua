--[[
	EquationParser
	Shared parser for the Graphing Easel: turns a typed equation string
	into a table the graph renderer can draw. Used client-side by GraphUI
	(purely cosmetic rendering) and server-side by AlgebraManager to
	validate the first-graph Coin bonus - same code, same answers.

	Supported forms (case/space-insensitive):
	  y = mx + b      -> { kind = "linear", m, b }   (m optional: y=x, y=2x)
	  y = b           -> { kind = "horizontal", y }
	  x = c           -> { kind = "vertical", x }
	  y = ax^2 + bx + c -> { kind = "quadratic", a, b, c }
	Coefficients may be integers, decimals, simple fractions (3/4x),
	negative, or implicit 1 (y=x). Returns (nil, friendlyError) for
	anything else.
]]

local EquationParser = {}

local MAX_COEFF = 1000 -- Keep silly inputs (y=99999999x) off the easel
local FRIENDLY_ERROR = "Try something like y=2x+1 or y=x^2-4"

-- Parse a signed coefficient string: "", "+", "-", "2", "0.5", "3/4"
local function parseCoeff(text)
	if text == "" or text == "+" then
		return 1
	end
	if text == "-" then
		return -1
	end
	local num, den = string.match(text, "^([%d%.]+)/([%d%.]+)$")
	if num then
		local n, d = tonumber(num), tonumber(den)
		if n and d and d ~= 0 then
			return n / d
		end
		return nil
	end
	return tonumber(text)
end

-- Accumulate an expression into a*x^2 + b*x + c.
-- Returns a, b, c or nil if any term is unparseable.
local function parsePolynomial(expr)
	-- Turn "8x-2" into "8x+-2" so every term splits cleanly on "+"
	expr = string.gsub(expr, "%-", "+-")
	-- Reject empty terms ("y=x+", "y=2x++1")
	if string.sub(expr, -1) == "+" or string.find(expr, "%+%+") then
		return nil
	end

	local a, b, c = 0, 0, 0
	for term in string.gmatch(expr, "[^%+]+") do
		local coeffText, varPart = string.match(term, "^([%-%d%.%/]*)(.*)$")
		local coeff = parseCoeff(coeffText)
		if not coeff then
			return nil
		end
		if varPart == "x^2" then
			a = a + coeff
		elseif varPart == "x" then
			b = b + coeff
		elseif varPart == "" then
			c = c + coeff
		else
			return nil -- "x^3", "xy", "2*x", stray letters, ...
		end
	end
	return a, b, c
end

-- EquationParser.Parse(raw) -> resultTable or (nil, errorMessage)
function EquationParser.Parse(raw)
	if type(raw) ~= "string" then
		return nil, FRIENDLY_ERROR
	end

	local input = string.lower(raw)
	input = string.gsub(input, "%s+", "")
	if #input == 0 or #input > 40 then
		return nil, FRIENDLY_ERROR
	end

	local lhs, rhs = string.match(input, "^([a-z]+)=([^=]+)$")
	if not lhs or not rhs then
		return nil, FRIENDLY_ERROR
	end

	local a, b, c = parsePolynomial(rhs)
	if not a then
		return nil, FRIENDLY_ERROR
	end

	if math.abs(a) > MAX_COEFF or math.abs(b) > MAX_COEFF or math.abs(c) > MAX_COEFF then
		return nil, "Those numbers are too big for our easel!"
	end

	if lhs == "y" then
		if a ~= 0 then
			return { kind = "quadratic", a = a, b = b, c = c }
		elseif b ~= 0 then
			return { kind = "linear", m = b, b = c }
		else
			return { kind = "horizontal", y = c }
		end
	elseif lhs == "x" then
		if a ~= 0 or b ~= 0 then
			return nil, "x= needs just a number, like x=3"
		end
		return { kind = "vertical", x = c }
	end

	return nil, FRIENDLY_ERROR
end

return EquationParser
