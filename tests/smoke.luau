-- Minimal Roblox API stubs to smoke-test ModelLibrary outside Studio.
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3mt)
end
Vector3mt = {}
Vector3mt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3mt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3mt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3mt.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
Vector3mt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
Vector3mt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2); assert(m > 0, "zero Unit"); return vec(t.X / m, t.Y / m, t.Z / m) end
	error("bad Vector3 field " .. tostring(k))
end
Vector3 = { new = vec, zero = vec(0, 0, 0), yAxis = vec(0, 1, 0) }

local CFmt = {}
local function cf(p) return setmetatable({ Position = p or vec() }, CFmt) end
CFmt.__mul = function(a, b)
	assert(getmetatable(a) == CFmt, "CFrame * : lhs not CFrame")
	if getmetatable(b) == CFmt then return cf(a.Position + b.Position) end
	assert(getmetatable(b) == Vector3mt, "CFrame * : rhs bad")
	return a.Position + b
end
CFmt.__index = function(t, k)
	if k == "Lerp" then return function(s, o) return o end end
	if k == "Rotation" then return cf() end
	error("bad CFrame field " .. tostring(k))
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then return cf(x) end
		return cf(vec(x, y, z))
	end,
	Angles = function(a, b, c) assert(type(a) == "number" and type(b) == "number" and type(c) == "number", "Angles args"); return cf() end,
	lookAt = function(p, t) assert((t - p).Magnitude > 0, "lookAt degenerate"); return cf(p) end,
	identity = cf(),
}

local C3mt = {}
C3mt.__index = { Lerp = function(a, b, t) assert(type(t) == "number"); return a end }
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
Color3 = { new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end, fromHSV = c3 }

local enumMt = { __index = function(t, k) local v = setmetatable({ Name = k }, getmetatable(t)); rawset(t, k, v); return v end }
Enum = setmetatable({}, { __index = function(t, k) local e = setmetatable({}, enumMt); rawset(t, k, e); return e end })
NumberRange = { new = function(...) return { ... } end }
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
ColorSequence = { new = function(...) return { ... } end }
Vector2 = { new = function(...) return { ... } end }
Random = { new = function() return { NextNumber = function(_, a, b) return (a + b) / 2 end, NextInteger = function(_, a, b) return a end } end }

local KNOWN = { Part = true, WedgePart = true, Model = true, Tool = true, SpecialMesh = true, ParticleEmitter = true, PointLight = true, SpotLight = true, Attachment = true, Trail = true, WeldConstraint = true }
local count = { parts = 0 }
local Inst = {}
Inst.__index = function(t, k)
	local m = rawget(Inst, k)
	if m then return m end
	return rawget(t, "_props")[k]
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_props").Parent
		if old then old._children[t] = nil end
		if v then v._children[t] = true end
	end
	assert(v ~= nil or k == "Parent", "setting nil " .. k)
	rawget(t, "_props")[k] = v
end
function Inst.SetAttribute(self, k, v) self._attrs[k] = v end
function Inst.GetAttribute(self, k) return self._attrs[k] end
function Inst.GetChildren(self) local r = {}; for c in pairs(self._children) do table.insert(r, c) end; return r end
function Inst.FindFirstChild() return nil end
function Inst.IsA(self, c) return self.ClassName == c or (c == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart")) end
Instance = {
	new = function(cls)
		assert(KNOWN[cls], "unexpected class " .. cls)
		if cls == "Part" or cls == "WedgePart" then count.parts += 1 end
		local o = setmetatable({ _props = { ClassName = cls, CFrame = (cls == "Part" or cls == "WedgePart") and CFrame.identity or nil }, _attrs = {}, _children = {} }, Inst)
		return o
	end,
}
local RSstub = setmetatable({ _props = {}, _attrs = {}, _children = {} }, Inst)
game = { GetService = function() return RSstub end }

local Lib = (function()
--@@LIB@@
end)()
local Config = (function()
--@@CONFIG@@
end)()
for i = 1, #Config.Tools do
	local before = count.parts
	local t = Lib.BuildTool(i, Config)
	assert(t.Name == Config.Tools[i].Name)
	print(("tool %-15s parts=%d"):format(Config.Tools[i].Name, count.parts - before))
end
for _, egg in ipairs(Config.Eggs) do
	local before = count.parts
	local m, shell = Lib.BuildEgg(egg, 5.2, true)
	assert(shell and m.PrimaryPart == shell)
	print(("egg  %-15s parts=%d"):format(egg.Name, count.parts - before))
	for _, p in ipairs(egg.Pets) do
		local b2 = count.parts
		local pm = Lib.BuildPet(p, Config)
		assert(pm.PrimaryPart, "no primary")
		Lib.AnimatePet(pm, CFrame.identity, 1.3)
		assert(Lib.PetSpecies[p.Name], "no species for " .. p.Name)
		print(("pet  %-15s parts=%d"):format(p.Name, count.parts - b2))
	end
end
print("ALL OK")
