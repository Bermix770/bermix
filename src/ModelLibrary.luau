-- Mine Rush : ModelLibrary
-- Detailed procedural models for tools, eggs and pets (shared by server and client).
--
-- Custom models: put a Model named exactly like the item into
--   ReplicatedStorage.Assets.Tools / .Eggs / .Pets
-- (e.g. a Creator Store model you inserted in Studio) and it replaces the generated one.
-- Tools must contain a part named "Handle"; eggs/pets should have a PrimaryPart.

local RS = game:GetService("ReplicatedStorage")

local Lib = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local M = Enum.Material
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local AY = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y
local AZ = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis X -> Z
local UP = CFrame.Angles(rad(90), 0, 0) -- spike pointing -Z -> +Y

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function shade(c, k)
	if k < 0 then return c:Lerp(BLACK, -k) end
	return c:Lerp(WHITE, k)
end
Lib.Shade = shade

local function custom(kind, name)
	local assets = RS:FindFirstChild("Assets")
	local f = assets and assets:FindFirstChild(kind)
	local m = f and f:FindFirstChild(name)
	if m then return m:Clone() end
	return nil
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end

local function sparkles(parent, color, rate, size)
	return emitter(parent, {
		Texture = SPARKLE, Rate = rate or 6, Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Color = ColorSequence.new(color, WHITE), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.35), NumberSequenceKeypoint.new(1, 0) }),
	})
end

local function flames(parent, color, size)
	size = size or 0.6
	return emitter(parent, {
		Texture = FIRE, Rate = 22, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(1, 2.2),
		SpreadAngle = Vector2.new(12, 12), LightEmission = 0.9, EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(shade(color, 0.3), rgb(255, 60, 0)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- Part factory: everything is built relative to `root` and parented to `model`.
local function newKit(model, root, anchored)
	local kit = {}
	function kit.part(size, cf, color, mat, shape, class)
		local p = Instance.new(class or "Part")
		if shape then p.Shape = shape end
		p.Size = size
		p.CFrame = root * cf
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.Anchored = anchored
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	function kit.ball(d, cf, color, mat)
		return kit.part(V3(d, d, d), cf, color, mat, Enum.PartType.Ball)
	end
	-- ellipsoid
	function kit.ell(size, cf, color, mat)
		local p = kit.part(size, cf, color, mat)
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = p
		return p
	end
	-- cylinder, axis along local X of cf
	function kit.cyl(len, d, cf, color, mat)
		return kit.part(V3(len, d, d), cf, color, mat, Enum.PartType.Cylinder)
	end
	function kit.wedge(size, cf, color, mat)
		return kit.part(size, cf, color, mat, nil, "WedgePart")
	end
	-- symmetric point made of two wedges; tip at cf * (0, 0, -len/2)
	function kit.spike(w, h, len, cf, color, mat)
		local a = kit.wedge(V3(w, h / 2, len), cf * CFrame.new(0, h / 4, 0), color, mat)
		local b = kit.wedge(V3(w, h / 2, len), cf * CFrame.new(0, -h / 4, 0) * CFrame.Angles(0, 0, math.pi), color, mat)
		return a, b
	end
	return kit
end

---------------------------------------------------------------- tools
local METAL_DARK = rgb(55, 57, 64)
local METAL = rgb(150, 152, 160)
local LEATHER = rgb(70, 42, 28)

local function addTrail(handle, color, a, b)
	local a0 = Instance.new("Attachment")
	a0.Position = a
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Position = b
	a1.Parent = handle
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.22
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(color, WHITE)
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	tr.FaceCamera = true
	tr.Parent = handle
end

-- Builds the visual parts of a mining tool around `handle` (a 0.4 x 4 x 0.4 part, head at +Y).
local function buildToolParts(tool, handle, def, level)
	local kit = newKit(tool, handle.CFrame, false)
	local c, mat = def.Color, def.Material
	local hi = shade(c, 0.35)
	local fancy = level >= 4

	-- handle dressing
	if fancy then
		handle.Color = rgb(40, 40, 46)
		handle.Material = M.Metal
	end
	for i = 0, 4 do
		kit.part(V3(0.5, 0.17, 0.5), CFrame.new(0, -1.75 + i * 0.27, 0) * CFrame.Angles(0, rad(i * 18), 0), fancy and rgb(25, 25, 30) or LEATHER, M.Fabric)
	end
	kit.ball(0.62, CFrame.new(0, -2.05, 0), fancy and c or METAL_DARK, fancy and mat or M.Metal)
	kit.part(V3(0.52, 0.12, 0.52), CFrame.new(0, -0.35, 0), METAL, M.Metal)
	kit.part(V3(0.56, 0.16, 0.56), CFrame.new(0, 1.1, 0), METAL, M.Metal)
	kit.part(V3(0.5, 0.12, 0.5), CFrame.new(0, 0.85, 0), METAL_DARK, M.Metal)

	local glowParent = handle
	if def.Kind == "Pickaxe" then
		kit.part(V3(0.8, 0.95, 0.95), CFrame.new(0, 1.8, 0), METAL_DARK, M.Metal)
		kit.part(V3(0.86, 0.14, 1.0), CFrame.new(0, 2.2, 0), METAL, M.Metal)
		for _, s in ipairs({ 1, -1 }) do
			local cur = CFrame.new(0, 1.85, 0.4 * s)
			local segs = { { 1.0, 5, 0.62 }, { 0.95, 11, 0.52 }, { 0.85, 15, 0.42 } }
			for _, sg in ipairs(segs) do
				local len, bend, w = sg[1], sg[2], sg[3]
				cur = cur * CFrame.Angles(rad(bend) * s, 0, 0)
				kit.part(V3(w * 0.85, w, len + 0.04), cur * CFrame.new(0, 0, len / 2 * s), c, mat)
				kit.part(V3(w * 0.45, 0.06, len), cur * CFrame.new(0, w / 2 + 0.02, len / 2 * s), hi, mat)
				cur = cur * CFrame.new(0, 0, len * s)
			end
			local tipCf = cur * CFrame.new(0, 0, 0.42 * s) * (s > 0 and CFrame.Angles(0, math.pi, 0) or CFrame.identity)
			kit.spike(0.36, 0.42, 0.85, tipCf, hi, mat)
			-- rivets
			for _, x in ipairs({ -0.41, 0.41 }) do
				kit.ball(0.16, CFrame.new(x, 1.8, 0.28 * s), METAL, M.Metal)
			end
		end
		if def.Glow then
			for _, x in ipairs({ -0.42, 0.42 }) do
				local g = kit.ball(0.42, CFrame.new(x, 1.8, 0), c, M.Neon)
				glowParent = g
			end
		end
		if def.Glow or fancy then addTrail(handle, c, V3(0, 1.8, 2.6), V3(0, 1.8, -2.6)) end
	elseif def.Kind == "Drill" then
		kit.cyl(1.7, 1.25, CFrame.new(0, 1.8, 0.15) * AZ, METAL_DARK, M.Metal)
		kit.cyl(0.28, 1.33, CFrame.new(0, 1.8, 0.55) * AZ, c, mat)
		kit.cyl(0.28, 1.33, CFrame.new(0, 1.8, -0.25) * AZ, c, mat)
		kit.ball(1.15, CFrame.new(0, 1.8, 0.95), METAL_DARK, M.Metal)
		for i = -1, 1 do
			kit.part(V3(0.12, 0.08, 0.8), CFrame.new(i * 0.28, 2.42, 0.15), rgb(20, 20, 24), M.Metal)
		end
		kit.part(V3(0.3, 0.28, 0.45), CFrame.new(0, 1.12, -0.3), rgb(200, 40, 40), M.SmoothPlastic)
		kit.cyl(0.45, 0.95, CFrame.new(0, 1.8, -0.9) * AZ, METAL, M.Metal)
		kit.cyl(0.12, 1.02, CFrame.new(0, 1.8, -1.1) * AZ, METAL_DARK, M.Metal)
		for k = 0, 5 do
			local d = 0.82 * (1 - k / 6.5)
			kit.cyl(0.34, d, CFrame.new(0, 1.8, -1.32 - k * 0.3) * AZ, c, mat)
		end
		for k = 0, 11 do
			local r = 0.42 * (1 - k / 12.5)
			kit.wedge(V3(0.1, 0.22, 0.3), CFrame.new(0, 1.8, -1.25 - k * 0.15) * CFrame.Angles(0, 0, rad(k * 55)) * CFrame.new(0, r, 0), hi, mat)
		end
		local tip = kit.spike(0.22, 0.22, 0.5, CFrame.new(0, 1.8, -3.25), def.Glow and c or hi, def.Glow and M.Neon or mat)
		if def.Glow then glowParent = tip end
		if def.Glow then addTrail(handle, c, V3(0, 1.8, -3.4), V3(0, 1.8, -1.2)) end
	else -- Hammer
		kit.part(V3(1.4, 1.4, 2.4), CFrame.new(0, 1.9, 0), c, mat)
		for _, s in ipairs({ 1, -1 }) do
			kit.part(V3(1.62, 1.62, 0.32), CFrame.new(0, 1.9, 1.22 * s), METAL_DARK, M.Metal)
			kit.part(V3(1.25, 1.25, 0.14), CFrame.new(0, 1.9, 1.44 * s), hi, mat)
			kit.part(V3(1.5, 1.5, 0.16), CFrame.new(0, 1.9, 0.55 * s), METAL, M.Metal)
			for _, x in ipairs({ -0.81, 0.81 }) do
				for _, y in ipairs({ -0.55, 0.55 }) do
					kit.ball(0.16, CFrame.new(x, 1.9 + y, 1.22 * s), METAL, M.Metal)
				end
			end
		end
		if def.Glow then
			for _, x in ipairs({ -0.71, 0.71 }) do
				kit.part(V3(0.06, 0.9, 0.12), CFrame.new(x, 1.9, 0), c, M.Neon)
				kit.part(V3(0.06, 0.12, 0.7), CFrame.new(x, 1.9, 0), c, M.Neon)
			end
		end
		local isVoid = string.find(def.Name, "Void") ~= nil
		local spikes = isVoid and { { 0, 2.7, 0, UP }, { 0, 1.9, 1.9, CFrame.Angles(0, math.pi, 0) }, { 0, 1.9, -1.9, CFrame.identity } } or { { 0, 2.75, 0.5, UP }, { 0, 2.75, -0.5, UP }, { 0, 2.65, 0, UP } }
		for _, sp in ipairs(spikes) do
			kit.spike(0.35, 0.35, 0.9, CFrame.new(sp[1], sp[2], sp[3]) * sp[4], hi, isVoid and M.Neon or M.Ice)
		end
		if isVoid then
			for _, x in ipairs({ -0.72, 0.72 }) do
				glowParent = kit.ball(0.6, CFrame.new(x, 1.9, 0), shade(c, 0.5), M.Neon)
			end
		end
		if def.Glow then addTrail(handle, c, V3(0, 1.9, 1.5), V3(0, 1.9, -1.5)) end
	end

	if def.Glow then
		local l = Instance.new("PointLight")
		l.Color = c
		l.Range = 10
		l.Brightness = 1.8
		l.Parent = handle
		sparkles(glowParent, c, 8, 0.3)
	end
end

function Lib.BuildTool(level, Config)
	local def = Config.Tools[level]
	local c = custom("Tools", def.Name)
	if c and c:IsA("Tool") and c:FindFirstChild("Handle") then
		c.Name = def.Name
		c.CanBeDropped = false
		c:SetAttribute("MineTool", true)
		return c
	end
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool:SetAttribute("MineTool", true)
	tool.Grip = CFrame.new(0, -1.4, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = V3(0.4, 4, 0.4)
	handle.Color = rgb(110, 75, 45)
	handle.Material = M.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	buildToolParts(tool, handle, def, level)
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
	return tool
end

---------------------------------------------------------------- eggs
-- point and outward normal on an ellipsoid with horizontal semi-axis a, vertical b
local function eggSurface(a, b, theta, phi)
	local sp, cp = math.sin(phi), math.cos(phi)
	local pos = V3(a * sp * math.cos(theta), b * cp, a * sp * math.sin(theta))
	local n = V3(pos.X / (a * a), pos.Y / (b * b), pos.Z / (a * a)).Unit
	return CFrame.lookAt(pos, pos + n)
end

-- Returns (model, shell). The model's pivot is the egg centre.
function Lib.BuildEgg(def, height, anchored)
	local c = custom("Eggs", def.Name)
	if c and c:IsA("Model") then
		local pp = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart", true)
		c.PrimaryPart = pp
		return c, pp
	end
	local h = height or 5.2
	local w = h * 0.78
	local a, b = w / 2, h / 2
	local m = Instance.new("Model")
	m.Name = def.Name
	local kit = newKit(m, CFrame.identity, anchored ~= false)
	local col = def.Color
	local name = def.Name
	local theme = string.find(name, "Meadow") and "Meadow" or string.find(name, "Crystal") and "Crystal"
		or string.find(name, "Magma") and "Magma" or string.find(name, "Void") and "Void" or "Plain"

	local shellColor = col
	if theme == "Magma" then shellColor = shade(col, -0.6) end
	if theme == "Void" then shellColor = shade(col, -0.55) end
	local shell = kit.ell(V3(w, h, w), CFrame.identity, shellColor, theme == "Crystal" and M.Glass or M.SmoothPlastic)
	shell.Name = "Shell"
	shell.Reflectance = theme == "Crystal" and 0.15 or 0.04
	shell.CanQuery = true
	m.PrimaryPart = shell

	local rng = Random.new(#name * 97)
	local function onShell(theta, phi, inset)
		return eggSurface(a, b, theta, phi) * CFrame.new(0, 0, inset or 0.05)
	end

	-- decorative band
	local bandColor = theme == "Magma" and col or theme == "Void" and shade(col, 0.2) or shade(col, 0.45)
	kit.cyl(h * 0.07, w * 1.025, CFrame.new(0, -h * 0.04, 0) * AY, bandColor, (theme == "Magma" or theme == "Void") and M.Neon or M.SmoothPlastic)
	for k = 1, 8 do
		local t = k / 8 * math.pi * 2
		kit.ball(h * 0.075, onShell(t, math.pi / 2 + 0.02, -0.02), theme == "Plain" and WHITE or shade(col, 0.6), M.Neon)
	end

	if theme == "Meadow" or theme == "Plain" then
		for k = 1, 14 do
			local d = rng:NextNumber(0.35, 0.8) * h / 5.2
			local phi = rng:NextNumber(0.45, 2.55)
			if math.abs(phi - math.pi / 2) > 0.18 then
				kit.ell(V3(d, d, 0.22), onShell(rng:NextNumber(0, 6.28), phi, 0.06), k % 3 == 0 and WHITE or shade(col, 0.4), M.SmoothPlastic)
			end
		end
		if theme == "Meadow" then
			kit.cyl(0.6, 0.18, CFrame.new(0, b + 0.2, 0) * AY, rgb(70, 140, 50), M.Grass)
			for _, s in ipairs({ 1, -1 }) do
				kit.ell(V3(0.9, 0.12, 0.45), CFrame.new(0.35 * s, b + 0.45, 0) * CFrame.Angles(0, 0, rad(25) * s), rgb(90, 190, 70), M.Grass)
			end
			kit.ball(0.32, CFrame.new(0, b + 0.55, 0), rgb(255, 230, 90), M.Neon)
		end
	elseif theme == "Crystal" then
		local inner = kit.ell(V3(w * 0.55, h * 0.55, w * 0.55), CFrame.identity, shade(col, 0.5), M.Neon)
		inner.Transparency = 0.35
		for k = 1, 9 do
			local cf = onShell(rng:NextNumber(0, 6.28), rng:NextNumber(0.35, 2.4), 0.25)
			local len = rng:NextNumber(0.8, 1.5) * h / 5.2
			local shard = kit.part(V3(0.35, 0.35, len), cf * CFrame.new(0, 0, -len / 2 + 0.2) * CFrame.Angles(0, 0, rad(45)), k % 2 == 0 and WHITE or shade(col, 0.3), M.Glass)
			shard.Transparency = 0.15
			kit.spike(0.35, 0.35, 0.4, cf * CFrame.new(0, 0, -len + 0.01), WHITE, M.Glass)
		end
		sparkles(shell, shade(col, 0.4), 6, 0.4)
	elseif theme == "Magma" then
		for k = 1, 12 do
			local theta, phi = rng:NextNumber(0, 6.28), rng:NextNumber(0.4, 2.6)
			local len = rng:NextNumber(0.7, 1.4) * h / 5.2
			kit.part(V3(0.12, len, 0.1), onShell(theta, phi, 0.03) * CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8)), col, M.Neon)
		end
		for k = 1, 6 do
			local d = rng:NextNumber(0.4, 0.7)
			kit.ell(V3(d, d, 0.3), onShell(rng:NextNumber(0, 6.28), rng:NextNumber(0.5, 2.5), 0.08), rgb(35, 28, 28), M.Basalt)
		end
		local top = kit.part(V3(0.2, 0.2, 0.2), CFrame.new(0, b - 0.2, 0), col, M.Neon)
		top.Transparency = 1
		flames(top, col, 0.9)
	elseif theme == "Void" then
		for k = 1, 18 do
			kit.ball(rng:NextNumber(0.1, 0.22), onShell(rng:NextNumber(0, 6.28), rng:NextNumber(0.3, 2.8), -0.03), k % 4 == 0 and shade(col, 0.6) or WHITE, M.Neon)
		end
		for k = 1, 20 do
			local t = k / 20 * math.pi * 2
			kit.ball(0.18, CFrame.Angles(rad(18), 0, 0) * CFrame.new(math.cos(t) * w * 0.8, 0, math.sin(t) * w * 0.8), shade(col, 0.5), M.Neon)
		end
		sparkles(shell, shade(col, 0.5), 8, 0.4)
	end
	return m, shell
end

---------------------------------------------------------------- pets
-- Body plans and features per pet. Unknown pets fall back to DEFAULT.
local DEFAULT = { body = "Quad", ears = "Pointy", tail = "Thin", cheeks = true }
local SPECIES = {
	["Dirt Pup"] = { body = "Quad", ears = "Floppy", tail = "Stub", snout = true, cheeks = true, patches = true },
	["Pebble Cat"] = { body = "Quad", ears = "Pointy", tail = "Thin", whiskers = true, cheeks = true, patches = true },
	["Copper Bunny"] = { body = "Quad", ears = "Long", tail = "Puff", cheeks = true, teeth = true, mat = M.Metal },
	["Golden Mole"] = { body = "Quad", ears = "None", snout = true, helmet = true, claws = true, mat = M.Metal },
	["Rainbow Worm"] = { body = "Worm", rainbow = true, antennae = true, cheeks = true },
	["Quartz Fox"] = { body = "Quad", ears = "Pointy", tail = "Fluffy", snout = true, crystals = true },
	["Amethyst Owl"] = { body = "Bird", ears = "Tufts", beak = true, wings = "Feather", crystals = true },
	["Gem Golem"] = { body = "Golem", crystals = true, mat = M.Slate },
	["Prism Dragon"] = { body = "Quad", ears = "None", horns = true, wings = "Bat", tail = "Spiky", snout = true, spikes = true, rainbow = true },
	["Ember Lizard"] = { body = "Quad", ears = "None", tail = "Long", spikes = true, snout = true, flame = true },
	["Lava Hound"] = { body = "Quad", ears = "Pointy", tail = "Flame", snout = true, cracks = true, flame = true },
	["Phoenix"] = { body = "Bird", beak = true, wings = "Flame", crest = true, tail = "Feathers", flame = true },
	["Inferno Titan"] = { body = "Golem", horns = true, flame = true, cracks = true, mat = M.Basalt },
	["Shadow Cat"] = { body = "Quad", ears = "Pointy", tail = "Thin", whiskers = true, glowEyes = rgb(200, 90, 255), smoke = true },
	["Star Whale"] = { body = "Whale", stars = true },
	["Void Emperor"] = { body = "Orb", crown = true, horns = true, wings = "Bat", glowEyes = rgb(255, 120, 255), stars = true, orbiters = true },
}
Lib.PetSpecies = SPECIES

-- head geometry per body plan: centre, semi-axes, or flat face
local HEADS = {
	Quad = { c = V3(0, 0.38, -0.3), r = V3(0.92, 0.88, 0.88) },
	Bird = { c = V3(0, 0.1, 0), r = V3(0.88, 0.98, 0.82) },
	Worm = { c = V3(0, 0.15, -0.75), r = V3(0.78, 0.78, 0.78) },
	Whale = { c = V3(0, 0, 0.25), r = V3(1.05, 0.82, 1.45) },
	Orb = { c = V3(0, 0, 0), r = V3(0.98, 0.98, 0.98) },
}

-- CFrame on the front of an ellipsoidal head; its -Z (LookVector) points outward
local function headPoint(head, x, y)
	local c, r = head.c, head.r
	local q = 1 - (x * x) / (r.X * r.X) - (y * y) / (r.Y * r.Y)
	local z = -r.Z * math.sqrt(math.max(q, 0.02))
	local pos = c + V3(x, y, z)
	local n = V3(x / (r.X * r.X), y / (r.Y * r.Y), z / (r.Z * r.Z)).Unit
	return CFrame.lookAt(pos, pos + n)
end

local function rainbowColor(i, n)
	return Color3.fromHSV((i - 1) / n, 0.55, 1)
end

function Lib.BuildPet(def, Config)
	local rarity = Config.Rarities[def.Rarity]
	local m = custom("Pets", def.Name)
	if m and m:IsA("Model") then
		local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		m.PrimaryPart = root
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		return m
	end

	local sp = SPECIES[def.Name] or DEFAULT
	m = Instance.new("Model")
	m.Name = def.Name
	local kit = newKit(m, CFrame.identity, true)
	local col = def.Color
	local mat = sp.mat or M.SmoothPlastic
	local dark = shade(col, -0.25)
	local light = shade(col, 0.4)
	local glow = sp.glowEyes

	local root = kit.part(V3(0.5, 0.5, 0.5), CFrame.identity, col)
	root.Name = "Body"
	root.Transparency = 1
	m.PrimaryPart = root

	local function anim(p, kind, hinge, rel, side)
		p:SetAttribute("Anim", kind)
		p:SetAttribute("Hinge", hinge)
		p:SetAttribute("Rel", rel)
		p:SetAttribute("Side", side or 1)
	end

	local head = HEADS[sp.body]
	local body = sp.body

	------------------------------------------------ bodies
	if body == "Quad" then
		kit.ell(V3(1.84, 1.76, 1.76), CFrame.new(head.c), col, mat)
		kit.ell(V3(1.5, 1.3, 1.75), CFrame.new(0, -0.38, 0.45), col, mat)
		kit.ell(V3(1.0, 0.9, 1.2), CFrame.new(0, -0.55, 0.3), light, mat)
		for _, x in ipairs({ -0.45, 0.45 }) do
			for _, z in ipairs({ -0.15, 0.85 }) do
				kit.ell(V3(0.46, 0.55, 0.5), CFrame.new(x, -0.95, z), col, mat)
				kit.ell(V3(0.42, 0.18, 0.46), CFrame.new(x, -1.18, z - 0.05), sp.claws and dark or light, mat)
				if sp.claws then
					for _, cx in ipairs({ -0.12, 0, 0.12 }) do
						kit.spike(0.08, 0.08, 0.2, CFrame.new(x + cx, -1.2, z - 0.32), rgb(240, 230, 210), M.SmoothPlastic)
					end
				end
			end
		end
		if sp.patches then
			kit.ell(V3(0.7, 0.6, 0.3), headPoint(head, 0.42, 0.35) * CFrame.new(0, 0, 0.08), dark, mat)
			kit.ell(V3(0.8, 0.5, 0.6), CFrame.new(0.35, -0.05, 0.75), dark, mat)
		end
	elseif body == "Bird" then
		kit.ell(head.r * 2, CFrame.new(head.c), col, mat)
		kit.ell(V3(1.2, 1.3, 0.5), CFrame.new(0, -0.3, -0.5), light, mat)
		for _, x in ipairs({ -0.35, 0.35 }) do
			kit.ell(V3(0.3, 0.2, 0.45), CFrame.new(x, -0.92, -0.2), rgb(255, 170, 40), M.SmoothPlastic)
		end
		-- chest feather scallops
		for i = 0, 2 do
			for j = -1, 1 do
				kit.ell(V3(0.28, 0.2, 0.08), headPoint(head, j * 0.3 + (i % 2) * 0.15, -0.35 - i * 0.18) * CFrame.new(0, 0, -0.03), shade(light, 0.2), mat)
			end
		end
	elseif body == "Worm" then
		local n = 6
		for i = 1, n do
			local z = -0.75 + (i - 1) * 0.62
			local d = (i == 1) and 1.56 or 1.3 - (i - 2) * 0.12
			local segColor = sp.rainbow and rainbowColor(i, n) or col
			local y = (i == 1) and head.c.Y or math.sin(i * 1.3) * 0.18 - 0.25
			kit.ell(V3(d, d, d * 0.9), CFrame.new(0, y, z), segColor, mat)
			if i > 1 then
				kit.cyl(0.08, d * 1.02, CFrame.new(0, y, z) * AZ, shade(segColor, -0.15), mat)
			end
		end
	elseif body == "Golem" then
		local stone = col
		kit.part(V3(1.7, 1.45, 1.25), CFrame.new(0, -0.35, 0.15), stone, mat)
		kit.part(V3(1.2, 1.0, 1.05), CFrame.new(0, 0.75, -0.1), stone, mat)
		kit.part(V3(1.25, 0.2, 1.1), CFrame.new(0, 1.2, -0.1), dark, mat)
		for _, s in ipairs({ -1, 1 }) do
			kit.part(V3(0.6, 0.5, 0.65), CFrame.new(1.05 * s, 0.2, 0.1), dark, mat)
			kit.part(V3(0.48, 1.0, 0.5), CFrame.new(1.1 * s, -0.45, 0.05) * CFrame.Angles(rad(-10), 0, rad(6) * s), stone, mat)
			kit.part(V3(0.62, 0.55, 0.62), CFrame.new(1.15 * s, -1.1, -0.05), dark, mat)
			kit.part(V3(0.55, 0.55, 0.6), CFrame.new(0.45 * s, -1.25, 0.15), dark, mat)
		end
		head = nil
		local eyeCol = glow or (sp.flame and rgb(255, 170, 40)) or shade(col, 0.6)
		for _, s in ipairs({ -1, 1 }) do
			kit.part(V3(0.28, 0.2, 0.06), CFrame.new(0.27 * s, 0.82, -0.64), eyeCol, M.Neon)
		end
		kit.part(V3(0.5, 0.08, 0.06), CFrame.new(0, 0.48, -0.64), shade(col, -0.6), M.SmoothPlastic)
		if sp.cracks then
			for k = 1, 6 do
				kit.part(V3(0.06, 0.5, 0.06), CFrame.new(-0.6 + k * 0.18, -0.3 + (k % 2) * 0.3, -0.48) * CFrame.Angles(0, 0, rad(k * 37)), rgb(255, 120, 20), M.Neon)
			end
		end
	elseif body == "Whale" then
		kit.ell(head.r * 2, CFrame.new(head.c), col, mat)
		kit.ell(V3(1.5, 0.8, 2.4), CFrame.new(0, -0.38, 0.1), light, mat)
		for i = -2, 2 do
			kit.part(V3(0.05, 0.05, 1.8), CFrame.new(i * 0.2, -0.8, 0.1), shade(light, -0.15), mat)
		end
		for _, s in ipairs({ -1, 1 }) do
			local fin = kit.ell(V3(0.9, 0.12, 0.5), CFrame.new(1.05 * s, -0.35, -0.1) * CFrame.Angles(0, rad(25) * s, rad(-30) * s), dark, mat)
			anim(fin, "Flap", CFrame.new(0.8 * s, -0.3, -0.1), CFrame.new(0.3 * s, 0, 0) * CFrame.Angles(0, rad(25) * s, rad(-30) * s), s)
		end
		for _, s in ipairs({ -1, 1 }) do
			kit.ell(V3(0.9, 0.12, 0.5), CFrame.new(0.4 * s, 0.1, 1.85) * CFrame.Angles(0, rad(-30) * s, 0), dark, mat)
		end
		kit.ell(V3(0.5, 0.45, 0.5), CFrame.new(0, 0.05, 1.55), col, mat)
		local spout = kit.part(V3(0.2, 0.2, 0.2), CFrame.new(0, 0.85, -0.2), WHITE)
		spout.Transparency = 1
		emitter(spout, {
			Texture = SPARKLE, Rate = 8, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top, LightEmission = 1,
			Color = ColorSequence.new(rgb(200, 230, 255)), Size = NumberSequence.new(0.3), Acceleration = V3(0, -4, 0),
		})
	elseif body == "Orb" then
		kit.ell(head.r * 2, CFrame.new(head.c), col, mat)
		local cape = kit.ell(V3(1.7, 1.5, 0.3), CFrame.new(0, -0.45, 0.75) * CFrame.Angles(rad(15), 0, 0), rgb(150, 20, 40), M.Fabric)
		cape.Reflectance = 0.05
		kit.ell(V3(1.4, 0.25, 0.6), CFrame.new(0, 0.3, 0.6), rgb(255, 210, 60), M.Foil)
	end

	------------------------------------------------ face
	if head then
		local eyeX, eyeY = 0.34, 0.12
		if body == "Whale" then eyeX, eyeY = 0.62, 0.05 end
		if body == "Bird" then eyeX, eyeY = 0.3, 0.3 end
		for _, s in ipairs({ -1, 1 }) do
			local cf = headPoint(head, eyeX * s, eyeY)
			if glow then
				kit.ell(V3(0.44, 0.34, 0.14), cf * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, 0, rad(-12) * s), glow, M.Neon)
				kit.ell(V3(0.08, 0.28, 0.08), cf * CFrame.new(0, 0, -0.08), BLACK, M.SmoothPlastic)
			else
				kit.ell(V3(0.42, 0.52, 0.16), cf * CFrame.new(0, 0, -0.02), WHITE, M.SmoothPlastic)
				kit.ell(V3(0.3, 0.4, 0.12), cf * CFrame.new(0, -0.03, -0.07), rgb(25, 22, 30), M.SmoothPlastic)
				kit.ball(0.12, cf * CFrame.new(0.06 * s, 0.09, -0.13), WHITE, M.Neon)
				kit.ball(0.06, cf * CFrame.new(-0.05 * s, -0.1, -0.12), WHITE, M.Neon)
			end
			if sp.cheeks then
				local ch = kit.ell(V3(0.3, 0.17, 0.06), headPoint(head, (eyeX + 0.24) * s, eyeY - 0.32) * CFrame.new(0, 0, -0.01), rgb(255, 140, 165), M.SmoothPlastic)
				ch.Transparency = 0.15
			end
			if sp.whiskers then
				for k = -1, 1 do
					local wcf = headPoint(head, 0.3 * s, -0.22) * CFrame.new(0.25 * s, k * 0.06, -0.02) * CFrame.Angles(0, 0, rad(k * 12) * s)
					kit.part(V3(0.5, 0.025, 0.025), wcf, glow and glow or rgb(40, 40, 40), glow and M.Neon or M.SmoothPlastic)
				end
			end
		end
		if sp.snout then
			local sn = headPoint(head, 0, -0.28)
			kit.ell(V3(0.72, 0.48, 0.5), sn * CFrame.new(0, 0, 0.02), light, mat)
			kit.ell(V3(0.26, 0.18, 0.16), sn * CFrame.new(0, 0.1, -0.22), rgb(30, 25, 30), M.SmoothPlastic)
			kit.ell(V3(0.18, 0.06, 0.06), sn * CFrame.new(0, -0.14, -0.2), rgb(70, 30, 40), M.SmoothPlastic)
		elseif sp.beak then
			local bk = headPoint(head, 0, 0.02)
			kit.spike(0.3, 0.28, 0.45, bk * CFrame.new(0, 0, -0.15) * CFrame.Angles(rad(-15), 0, 0), rgb(255, 175, 40), M.SmoothPlastic)
		elseif body ~= "Whale" then
			kit.ell(V3(0.22, 0.09, 0.06), headPoint(head, 0, -0.26), rgb(70, 30, 40), M.SmoothPlastic)
			kit.ball(0.08, headPoint(head, 0, -0.12) * CFrame.new(0, 0, -0.02), rgb(255, 120, 150), M.SmoothPlastic)
		else
			kit.part(V3(1.1, 0.05, 0.05), headPoint(head, 0, -0.32) * CFrame.new(0, 0, -0.01), shade(col, -0.5), M.SmoothPlastic)
		end
		if sp.teeth then
			for _, s in ipairs({ -1, 1 }) do
				kit.part(V3(0.1, 0.14, 0.04), headPoint(head, 0.06 * s, -0.36) * CFrame.new(0, 0, -0.01), WHITE, M.SmoothPlastic)
			end
		end

		------------------------------------------------ head features
		local hc, hr = head.c, head.r
		if sp.ears == "Pointy" then
			for _, s in ipairs({ -1, 1 }) do
				local cf = CFrame.new(hc + V3(0.5 * s, hr.Y * 0.78, 0.05)) * CFrame.Angles(0, 0, rad(-18) * s) * UP
				kit.spike(0.5, 0.26, 0.72, cf, col, mat)
				kit.spike(0.3, 0.1, 0.48, cf * CFrame.new(0, -0.13, 0.08), glow or rgb(255, 160, 175), glow and M.Neon or M.SmoothPlastic)
			end
		elseif sp.ears == "Floppy" then
			for _, s in ipairs({ -1, 1 }) do
				kit.ell(V3(0.36, 0.85, 0.22), CFrame.new(hc + V3(0.85 * s, 0.05, 0.05)) * CFrame.Angles(0, 0, rad(18) * s), dark, mat)
			end
		elseif sp.ears == "Long" then
			for _, s in ipairs({ -1, 1 }) do
				local cf = CFrame.new(hc + V3(0.32 * s, hr.Y + 0.45, 0.05)) * CFrame.Angles(rad(-8), 0, rad(-10) * s)
				kit.ell(V3(0.38, 1.25, 0.22), cf, col, mat)
				kit.ell(V3(0.22, 0.95, 0.06), cf * CFrame.new(0, 0, -0.09), rgb(255, 165, 180), M.SmoothPlastic)
			end
		elseif sp.ears == "Tufts" then
			for _, s in ipairs({ -1, 1 }) do
				kit.spike(0.3, 0.16, 0.55, CFrame.new(hc + V3(0.55 * s, hr.Y * 0.85, 0)) * CFrame.Angles(0, 0, rad(-35) * s) * UP, dark, mat)
			end
		end
		if sp.horns then
			for _, s in ipairs({ -1, 1 }) do
				local hcf = CFrame.new(hc + V3(0.42 * s, hr.Y * 0.8, 0.25)) * CFrame.Angles(rad(-30), 0, rad(-20) * s)
				kit.cyl(0.35, 0.22, hcf * CFrame.new(0, 0.1, 0) * AY, rgb(240, 225, 190), M.SmoothPlastic)
				kit.spike(0.22, 0.22, 0.45, hcf * CFrame.new(0, 0.45, 0) * UP, rgb(250, 240, 215), M.SmoothPlastic)
			end
		end
		if sp.helmet then
			kit.ell(V3(1.6, 0.8, 1.6), CFrame.new(hc + V3(0, hr.Y * 0.55, 0.05)), rgb(255, 205, 40), M.SmoothPlastic)
			kit.cyl(0.1, 1.85, CFrame.new(hc + V3(0, hr.Y * 0.35, 0.05)) * AY, rgb(230, 175, 30), M.SmoothPlastic)
			local lampCf = headPoint(head, 0, hr.Y * 0.62) * CFrame.new(0, 0, -0.05)
			kit.cyl(0.18, 0.4, lampCf * AZ, rgb(80, 80, 85), M.Metal)
			local bulb = kit.ball(0.3, lampCf * CFrame.new(0, 0, -0.1), rgb(255, 250, 200), M.Neon)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Front
			sl.Range = 14
			sl.Brightness = 2
			sl.Angle = 50
			sl.Color = rgb(255, 245, 200)
			sl.Parent = bulb
		end
		if sp.crest then
			for k = -1, 1 do
				kit.spike(0.12, 0.3, 0.7 - math.abs(k) * 0.15, CFrame.new(hc + V3(0, hr.Y * 0.9, 0.1 + k * 0.22)) * CFrame.Angles(rad(-25 + k * 20), 0, 0) * UP, k == 0 and rgb(255, 220, 60) or rgb(255, 120, 30), M.Neon)
			end
		end
		if sp.antennae then
			for _, s in ipairs({ -1, 1 }) do
				local base = hc + V3(0.3 * s, hr.Y * 0.85, 0)
				kit.part(V3(0.06, 0.6, 0.06), CFrame.new(base + V3(0.06 * s, 0.25, 0)) * CFrame.Angles(0, 0, rad(-15) * s), rgb(60, 50, 60), M.SmoothPlastic)
				kit.ball(0.22, CFrame.new(base + V3(0.14 * s, 0.58, 0)), rgb(255, 230, 90), M.Neon)
			end
		end
		if sp.crown then
			local top = hc + V3(0, hr.Y * 0.88, 0)
			kit.cyl(0.25, 1.0, CFrame.new(top) * AY, rgb(255, 205, 50), M.Foil)
			for k = 1, 6 do
				local t = k / 6 * math.pi * 2
				kit.spike(0.18, 0.12, 0.35, CFrame.new(top + V3(math.cos(t) * 0.44, 0.27, math.sin(t) * 0.44)) * CFrame.Angles(0, -t, 0) * UP, rgb(255, 215, 70), M.Foil)
			end
			kit.ball(0.22, CFrame.new(top + V3(0, 0.05, -0.5)), rgb(255, 40, 120), M.Neon)
		end
	end

	------------------------------------------------ tails
	local tailBase = (body == "Quad") and V3(0, -0.3, 1.3) or (body == "Bird") and V3(0, -0.4, 0.75) or V3(0, -0.3, 1.2)
	local tail = sp.tail
	if tail == "Stub" then
		kit.ball(0.42, CFrame.new(tailBase + V3(0, 0.15, 0)), dark, mat)
	elseif tail == "Puff" then
		kit.ball(0.6, CFrame.new(tailBase + V3(0, 0.1, 0)), WHITE, M.SmoothPlastic)
	elseif tail == "Thin" then
		for i = 0, 5 do
			kit.ball(0.26 - i * 0.015, CFrame.new(tailBase + V3(0, i * 0.2, i * 0.12 - (i * i) * 0.012)), i == 5 and (glow or dark) or col, i == 5 and glow and M.Neon or mat)
		end
	elseif tail == "Fluffy" then
		local cf = CFrame.new(tailBase + V3(0, 0.35, 0.35)) * CFrame.Angles(rad(-40), 0, 0)
		kit.ell(V3(0.65, 0.65, 1.3), cf, col, mat)
		kit.ell(V3(0.5, 0.5, 0.55), cf * CFrame.new(0, 0, 0.55), WHITE, mat)
	elseif tail == "Long" or tail == "Spiky" then
		for i = 0, 4 do
			local d = 0.55 - i * 0.09
			local pos = tailBase + V3(0, -0.1 - i * 0.05, i * 0.38)
			kit.ell(V3(d, d, 0.6), CFrame.new(pos), col, mat)
			if tail == "Spiky" and i < 4 then
				kit.spike(0.08, 0.2, 0.3, CFrame.new(pos + V3(0, d / 2 + 0.05, 0)) * UP, light, M.Glass)
			end
		end
		if sp.flame then
			local tip = kit.ball(0.3, CFrame.new(tailBase + V3(0, -0.3, 1.75)), rgb(255, 150, 40), M.Neon)
			flames(tip, rgb(255, 150, 40), 0.5)
		end
	elseif tail == "Flame" then
		local cf = CFrame.new(tailBase + V3(0, 0.3, 0.25)) * CFrame.Angles(rad(-35), 0, 0)
		kit.ell(V3(0.45, 0.45, 0.9), cf, col, mat)
		local tip = kit.ball(0.4, cf * CFrame.new(0, 0, 0.5), rgb(255, 160, 30), M.Neon)
		flames(tip, rgb(255, 140, 30), 0.7)
	elseif tail == "Feathers" then
		for k = -1, 1 do
			local cf = CFrame.new(tailBase) * CFrame.Angles(rad(15), rad(k * 25), 0) * CFrame.new(0, 0, 0.6)
			kit.ell(V3(0.3, 0.1, 1.3), cf, k == 0 and rgb(255, 210, 50) or rgb(255, 110, 30), M.SmoothPlastic)
			kit.ell(V3(0.28, 0.12, 0.35), cf * CFrame.new(0, 0, 0.6), rgb(255, 80, 20), M.Neon)
		end
	end

	------------------------------------------------ wings
	if sp.wings then
		local wy, wz = (body == "Bird") and 0.15 or 0.15, (body == "Bird") and 0.25 or 0.5
		local wx = (body == "Bird") and 0.8 or (body == "Orb") and 0.85 or 0.7
		for _, s in ipairs({ -1, 1 }) do
			local hinge = CFrame.new(wx * s, wy, wz)
			local parts = {}
			if sp.wings == "Bat" then
				local memb = sp.rainbow and rainbowColor(s > 0 and 2 or 5, 6) or shade(col, sp.body == "Orb" and -0.4 or 0.25)
				local rel = CFrame.Angles(0, rad(-15) * s, rad(25) * s) * CFrame.new(0.65 * s, 0, 0)
				table.insert(parts, { kit.ell(V3(1.4, 0.1, 0.9), hinge * rel, memb, sp.rainbow and M.Glass or mat), rel })
				local boneRel = rel * CFrame.new(0, 0.05, -0.38)
				table.insert(parts, { kit.part(V3(1.4, 0.1, 0.1), hinge * boneRel, dark, mat), boneRel })
				local clawRel = rel * CFrame.new(0.72 * s, 0.05, -0.38) * CFrame.Angles(0, (s > 0) and -math.pi / 2 or math.pi / 2, 0)
				local c1, c2 = kit.spike(0.08, 0.1, 0.25, hinge * clawRel, rgb(240, 230, 210), M.SmoothPlastic)
				-- spike halves are offset +-h/4 from clawRel
				table.insert(parts, { c1, clawRel * CFrame.new(0, 0.025, 0) })
				table.insert(parts, { c2, clawRel * CFrame.new(0, -0.025, 0) * CFrame.Angles(0, 0, math.pi) })
			else
				local fireWing = sp.wings == "Flame"
				for k = 0, 2 do
					local rel = CFrame.Angles(0, rad(-10 - k * 14) * s, rad(30) * s) * CFrame.new((0.45 + k * 0.08) * s, 0, k * 0.1)
					local size = V3(1.1 - k * 0.15, 0.1, 0.45)
					local fc = fireWing and (k == 0 and rgb(255, 220, 60) or k == 1 and rgb(255, 140, 30) or rgb(255, 70, 20)) or shade(col, -0.1 * k)
					local fp = kit.ell(size, hinge * rel, fc, fireWing and M.Neon or mat)
					table.insert(parts, { fp, rel })
				end
			end
			for _, pr in ipairs(parts) do
				anim(pr[1], "Flap", hinge, pr[2], s)
			end
			if sp.wings == "Flame" then
				flames(parts[1][1], rgb(255, 150, 40), 0.4)
			end
		end
	end

	------------------------------------------------ extras
	if sp.spikes then
		local zs = (body == "Quad") and { 0.1, 0.45, 0.8 } or { 0 }
		for _, z in ipairs(zs) do
			kit.spike(0.12, 0.25, 0.4, CFrame.new(0, 0.32 - z * 0.25, z) * UP, light, sp.rainbow and M.Glass or mat)
		end
	end
	if sp.crystals then
		local spots = (body == "Golem") and { V3(-0.6, 0.55, 0.4), V3(0.6, 0.55, 0.4), V3(0, 0.45, 0.65), V3(0.65, -0.5, -0.5) }
			or (body == "Bird") and { V3(0, 0.95, 0.3), V3(-0.4, 0.7, 0.55), V3(0.4, 0.7, 0.55) }
			or { V3(0, 0.25, 0.8), V3(-0.3, 0.15, 1.0), V3(0.3, 0.15, 1.0) }
		for k, p in ipairs(spots) do
			local len = 0.55 + (k % 2) * 0.25
			local cf = CFrame.new(p) * CFrame.Angles(rad(-25), 0, rad((k % 3 - 1) * 25)) * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, rad(45), 0)
			local cr = kit.part(V3(0.24, len, 0.24), cf, shade(col, 0.3), M.Glass)
			cr.Transparency = 0.1
			kit.spike(0.24, 0.24, 0.25, cf * CFrame.new(0, len / 2 + 0.12, 0) * UP, WHITE, M.Glass)
		end
	end
	if sp.cracks and body == "Quad" then
		for k = 1, 5 do
			kit.part(V3(0.05, 0.4, 0.05), CFrame.new(((k % 2) * 2 - 1) * 0.74, -0.4 + (k % 3) * 0.12, 0.1 + k * 0.17) * CFrame.Angles(rad(k * 31), 0, 0), rgb(255, 130, 20), M.Neon)
		end
	end
	if sp.stars then
		local rng = Random.new(#def.Name)
		for k = 1, 10 do
			local t, ph = rng:NextNumber(0, 6.28), rng:NextNumber(0.3, 1.5)
			local r = head and head.r or V3(0.9, 0.9, 0.9)
			local c = head and head.c or Vector3.zero
			local dir = V3(math.cos(t) * math.sin(ph), math.cos(ph), math.sin(t) * math.sin(ph))
			kit.ball(rng:NextNumber(0.08, 0.16), CFrame.new(c + V3(dir.X * r.X, dir.Y * r.Y, dir.Z * r.Z) * 0.98), k % 3 == 0 and rgb(255, 230, 120) or WHITE, M.Neon)
		end
	end
	if sp.flame and body == "Golem" then
		local top = kit.part(V3(0.8, 0.2, 0.8), CFrame.new(0, 1.3, -0.1), rgb(255, 120, 20), M.Neon)
		flames(top, rgb(255, 140, 30), 1.1)
	end
	if sp.smoke then
		emitter(root, {
			Texture = SMOKE, Rate = 6, Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(rgb(90, 40, 140)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	if sp.orbiters then
		for k = 1, 3 do
			local orb = kit.ball(0.35, CFrame.new(0, 0.2, 0), rgb(200, 120, 255), M.Neon)
			anim(orb, "Spin", CFrame.new(0, 0.2, 0) * CFrame.Angles(rad(20), 0, 0), CFrame.Angles(0, k / 3 * math.pi * 2, 0) * CFrame.new(1.6, 0, 0), 1)
		end
	end

	------------------------------------------------ rarity effects
	if rarity and rarity.Order >= 4 then
		local l = Instance.new("PointLight")
		l.Color = rarity.Color
		l.Range = 9
		l.Brightness = 1.4
		l.Parent = root
		sparkles(root, rarity.Color, 5, 0.3)
	end
	if rarity and rarity.Order >= 5 then
		local haloY = (body == "Golem") and 1.75 or (body == "Orb") and 1.75 or 1.65
		if sp.ears == "Long" then haloY += 0.6 end
		for k = 1, 14 do
			local bead = kit.ball(0.14, CFrame.new(0, haloY, 0), rarity.Color, M.Neon)
			anim(bead, "Spin", CFrame.new(0, haloY, 0), CFrame.Angles(0, k / 14 * math.pi * 2, 0) * CFrame.new(0.6, 0, 0), 1)
		end
	end
	if rarity and rarity.Order >= 6 then
		emitter(root, {
			Texture = SPARKLE, Rate = 14, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(180, 180), LightEmission = 1, Color = ColorSequence.new(rarity.Color, WHITE),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	return m
end

-- Animates hinged pet parts (wings, halos, orbiters) after the pet was pivoted to `cf`.
function Lib.AnimatePet(model, cf, t)
	for _, p in ipairs(model:GetChildren()) do
		local kind = p:GetAttribute("Anim")
		if kind then
			local hinge, rel, side = p:GetAttribute("Hinge"), p:GetAttribute("Rel"), p:GetAttribute("Side") or 1
			if kind == "Flap" then
				p.CFrame = cf * hinge * CFrame.Angles(0, 0, math.sin(t * 9) * 0.45 * side) * rel
			elseif kind == "Spin" then
				p.CFrame = cf * hinge * CFrame.Angles(0, t * 2.2, 0) * rel
			end
		end
	end
end

return Lib
