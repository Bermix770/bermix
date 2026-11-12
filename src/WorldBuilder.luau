-- Mine Rush : WorldBuilder
-- Generates the whole 3D island: terrain, town, 6 zones, paths, props, lighting.
-- Runs automatically when the server starts. To bake the map into the place file
-- (so you can see and edit it in Studio), run in the Command Bar:
--   require(game.ServerScriptService.WorldBuilder).Build(true)

local WorldBuilder = {}

local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Config = require(RS:WaitForChild("Config"))
local ModelLibrary = require(RS:WaitForChild("ModelLibrary"))

local T = workspace.Terrain
local M = Enum.Material
local rgb = Color3.fromRGB
local rng = Random.new(1337)
local V3 = Vector3.new
local UP = Vector3.yAxis

local World, F
local pathSegments = {}

---------------------------------------------------------------- basic helpers
local function yield()
	if RunService:IsRunning() then task.wait() end
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(props, parent, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then p.Shape = props.Shape end
	if props.Size then p.Size = props.Size end
	for k, v in pairs(props) do
		if k ~= "Shape" and k ~= "Size" then p[k] = v end
	end
	p.Parent = parent or F.Decor
	return p
end

local function ball(pos, d, color, mat, parent, collide)
	return part({ Shape = Enum.PartType.Ball, Size = V3(d, d, d), Position = pos, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false }, parent)
end

local function vcyl(pos, height, d, color, mat, parent, collide)
	return part({ Shape = Enum.PartType.Cylinder, Size = V3(height, d, d), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false }, parent)
end

local function beam(a, b, w, h, color, mat, parent, collide)
	local len = (b - a).Magnitude
	return part({ Size = V3(w, h, len), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false }, parent)
end

local function light(p, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 16
	l.Brightness = brightness or 1
	l.Shadows = shadows or false
	l.Parent = p
	return l
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end

local function billboard(adornee, text, offset, w, h, maxDist, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, w or 240, 0, h or 50)
	gui.StudsOffset = offset or V3(0, 4, 0)
	gui.MaxDistance = maxDist or 150
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

-- SurfaceGui text on the +Z (Back) face of a part
local function surfaceText(p, text, color, bg, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	l.BackgroundColor3 = bg or Color3.new()
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = sg
	sg.Parent = p
	return sg
end

local function prompt(p, action, actionText, objectText, arg)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText or ""
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp:SetAttribute("Action", action)
	if arg ~= nil then pp:SetAttribute("Arg", arg) end
	pp.Parent = p
	return pp
end

-- +Z of the returned CFrame faces `target`
local function faceTo(pos, target)
	return CFrame.lookAt(pos, V3(target.X, pos.Y, target.Z)) * CFrame.Angles(0, math.pi, 0)
end

local function flatDir(c)
	local d = V3(c.X, 0, c.Z)
	if d.Magnitude < 0.01 then return V3(0, 0, 1) end
	return d.Unit
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(x, z, fromY, depth)
	terrainParams.FilterDescendantsInstances = { T }
	fromY = fromY or 400
	local r = workspace:Raycast(V3(x, fromY, z), V3(0, -(depth or (fromY + 150)), 0), terrainParams)
	if r then return r.Position.Y, r.Material, r.Normal end
	return nil
end

local function rayTerrain(origin, dir)
	terrainParams.FilterDescendantsInstances = { T }
	return workspace:Raycast(origin, dir, terrainParams)
end

local function distToSegment2D(p, a, b)
	local ap = V3(p.X - a.X, 0, p.Z - a.Z)
	local ab = V3(b.X - a.X, 0, b.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-3), 0, 1)
	return (ap - ab * t).Magnitude
end

---------------------------------------------------------------- props
local WOOD = rgb(110, 75, 45)
local DARKWOOD = rgb(75, 50, 30)
local METAL = rgb(55, 55, 62)

local function lamp(x, z, color)
	local y = groundAt(x, z) or 10
	local b = V3(x, y, z)
	part({ Name = "LampPost", Size = V3(0.8, 12, 0.8), Position = b + V3(0, 6, 0), Color = METAL, Material = M.Metal })
	part({ Size = V3(3, 0.5, 3), Position = b + V3(0, 12.4, 0), Color = METAL, Material = M.Metal })
	local bulb = part({ Size = V3(1.8, 1.8, 1.8), Position = b + V3(0, 11.3, 0), Color = color or rgb(255, 220, 150), Material = M.Neon, CanCollide = false })
	light(bulb, color or rgb(255, 210, 140), 24, 1.3)
end

local function torch(pos, color)
	local stick = part({ Name = "Torch", Size = V3(0.5, 3, 0.5), Position = pos, Color = DARKWOOD, Material = M.Wood, CanCollide = false })
	local head = part({ Size = V3(0.8, 0.8, 0.8), Position = pos + V3(0, 1.7, 0), Color = rgb(255, 150, 50), Material = M.Neon, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = color or rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 230, 120)
	fire.Parent = head
	light(head, color or rgb(255, 160, 70), 26, 1.6, true)
	return stick
end

local function tree(x, z, scale, leaf)
	local y = groundAt(x, z)
	if not y then return end
	scale = scale or 1
	local h = 10 * scale
	local base = V3(x, y - 0.5, z)
	part({ Name = "Trunk", Size = V3(2 * scale, h, 2 * scale), CFrame = CFrame.new(base + V3(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = WOOD, Material = M.Wood })
	local leafColor = leaf or rgb(70 + rng:NextInteger(-10, 15), 150 + rng:NextInteger(-20, 20), 55)
	for _ = 1, 4 do
		local off = V3(rng:NextNumber(-2.5, 2.5) * scale, h + rng:NextNumber(-1.5, 3) * scale, rng:NextNumber(-2.5, 2.5) * scale)
		ball(base + off, rng:NextNumber(6, 9) * scale, leafColor, M.Grass, nil, false)
	end
end

local function pine(x, z, scale, snowy)
	local y = groundAt(x, z)
	if not y then return end
	scale = scale or 1
	local base = V3(x, y - 0.5, z)
	part({ Name = "PineTrunk", Size = V3(1.6 * scale, 6 * scale, 1.6 * scale), Position = base + V3(0, 3 * scale, 0), Color = DARKWOOD, Material = M.Wood })
	for i = 1, 4 do
		local s = (5.5 - i) * 2.3 * scale
		local top = snowy and i >= 3
		part({
			Name = "PineLeaves", Size = V3(s, 2.6 * scale, s),
			CFrame = CFrame.new(base + V3(0, (4 + i * 2.4) * scale, 0)) * CFrame.Angles(0, math.rad(i * 23), 0),
			Color = top and rgb(240, 245, 255) or rgb(40, 95, 55), Material = top and M.Snow or M.Grass, CanCollide = false,
		})
	end
end

local function rock(x, z, s, color, mat)
	local y = groundAt(x, z)
	if not y then return end
	part({
		Name = "Rock", Size = V3(s * rng:NextNumber(0.8, 1.4), s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.8, 1.4)),
		CFrame = CFrame.new(x, y + s * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
		Color = color or rgb(120, 120, 115), Material = mat or M.Slate,
	})
end

local function crystalCluster(cf, scale, color, mat, parent, withLight)
	local n = rng:NextInteger(4, 7)
	for k = 1, n do
		local h = rng:NextNumber(3, 8) * scale
		local w = rng:NextNumber(0.8, 1.6) * scale
		local tilt = CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5))
		local c = cf * CFrame.new(rng:NextNumber(-1.5, 1.5) * scale, 0, rng:NextNumber(-1.5, 1.5) * scale) * tilt * CFrame.new(0, h / 2 - 0.5, 0)
		part({ Name = "Crystal", Size = V3(w, h, w), CFrame = c * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = mat or M.Neon, CanCollide = false, CastShadow = false }, parent)
	end
	if withLight ~= false then
		local anchor = part({ Name = "CrystalLight", Size = V3(0.2, 0.2, 0.2), CFrame = cf * CFrame.new(0, 3 * scale, 0), Transparency = 1, CanCollide = false, CanQuery = false }, parent)
		light(anchor, color, 18 * scale, 1.2)
	end
end

local function crate(pos, s)
	s = s or 3
	part({ Name = "Crate", Size = V3(s, s, s), CFrame = CFrame.new(pos + V3(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = rgb(160, 115, 65), Material = M.WoodPlanks })
end

local function barrel(pos)
	vcyl(pos + V3(0, 1.6, 0), 3.2, 2.4, rgb(120, 80, 45), M.WoodPlanks)
	vcyl(pos + V3(0, 2.6, 0), 0.25, 2.55, METAL, M.Metal, nil, false)
	vcyl(pos + V3(0, 0.6, 0), 0.25, 2.55, METAL, M.Metal, nil, false)
end

local function campfire(pos)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		part({ Size = V3(1, 0.8, 1), CFrame = CFrame.new(pos + V3(math.sin(a) * 2, 0.4, math.cos(a) * 2)), Color = rgb(100, 100, 100), Material = M.Slate })
	end
	local logs = part({ Size = V3(2.5, 0.6, 0.6), CFrame = CFrame.new(pos + V3(0, 0.4, 0)), Color = DARKWOOD, Material = M.Wood })
	part({ Size = V3(2.5, 0.6, 0.6), CFrame = CFrame.new(pos + V3(0, 0.6, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = DARKWOOD, Material = M.Wood })
	local f = Instance.new("Fire")
	f.Size = 5
	f.Heat = 9
	f.Parent = logs
	light(logs, rgb(255, 150, 60), 28, 2, true)
end

local function tent(cf, color)
	local a = math.rad(55)
	local w, d = 7, 8
	local L = (w / 2) / math.cos(a)
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Tent", Size = V3(L, 0.3, d), CFrame = cf * CFrame.new(s * w / 4, (w / 4) * math.tan(a), 0) * CFrame.Angles(0, 0, -s * a), Color = color, Material = M.Fabric })
	end
	part({ Size = V3(0.4, (w / 2) * math.tan(a) + 0.5, 0.4), CFrame = cf * CFrame.new(0, ((w / 2) * math.tan(a)) / 2, d / 2), Color = DARKWOOD, Material = M.Wood })
end

local function signpost(pos, facing, text, color)
	part({ Size = V3(0.6, 8, 0.6), Position = pos + V3(0, 4, 0), Color = DARKWOOD, Material = M.Wood })
	local board = part({ Name = "Sign", Size = V3(10, 2.4, 0.4), CFrame = faceTo(pos + V3(0, 7, 0), facing), Color = rgb(150, 105, 60), Material = M.WoodPlanks })
	surfaceText(board, text, color or rgb(255, 240, 200))
	return board
end

local function bigSign(pos, facing, text, color, w)
	local board = part({ Name = "ZoneSign", Size = V3(w or 26, 5, 0.6), CFrame = faceTo(pos, facing), Color = rgb(35, 30, 30), Material = M.WoodPlanks })
	surfaceText(board, text, color)
	return board
end

-- Simple blocky NPC. +Z of cf is the front.
local function npc(cf, name, shirt, pants, parent, hatColor)
	local m = Instance.new("Model")
	m.Name = name
	local skin = rgb(255, 205, 160)
	local function p(size, off, color, mat)
		return part({ Size = size, CFrame = cf * off, Color = color, Material = mat or M.SmoothPlastic }, m)
	end
	p(V3(1, 2, 1), CFrame.new(-0.5, 1, 0), pants)
	p(V3(1, 2, 1), CFrame.new(0.5, 1, 0), pants)
	p(V3(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	p(V3(1, 2, 1), CFrame.new(-1.5, 3, 0), skin)
	p(V3(1, 2, 1), CFrame.new(1.5, 3, 0), skin)
	local head = p(V3(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), skin)
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Back
	face.Parent = head
	p(V3(1.5, 0.5, 1.5), CFrame.new(0, 5.35, 0), hatColor or rgb(255, 200, 40))
	local lampP = p(V3(0.4, 0.4, 0.2), CFrame.new(0, 5.3, 0.8), rgb(255, 255, 200), M.Neon)
	lampP.CanCollide = false
	billboard(head, name, V3(0, 2.4, 0), 200, 40, 60, rgb(255, 230, 120))
	m.PrimaryPart = head
	m.Parent = parent or F.Town
	return m, head
end

-- Building with door on +Z side and slab roof
local function building(cf, w, d, h, wall, roof, signText, signColor, parent)
	local m = Instance.new("Model")
	m.Name = signText or "Building"
	local function p(size, off, color, mat)
		return part({ Size = size, CFrame = cf * off, Color = color, Material = mat }, m)
	end
	p(V3(w + 2, 1, d + 2), CFrame.new(0, 0.5, 0), rgb(130, 130, 130), M.Cobblestone)
	p(V3(w, 0.4, d), CFrame.new(0, 1.2, 0), rgb(140, 100, 65), M.WoodPlanks)
	p(V3(w, h, 1), CFrame.new(0, h / 2 + 1, -d / 2 + 0.5), wall, M.Brick)
	p(V3(1, h, d), CFrame.new(-w / 2 + 0.5, h / 2 + 1, 0), wall, M.Brick)
	p(V3(1, h, d), CFrame.new(w / 2 - 0.5, h / 2 + 1, 0), wall, M.Brick)
	local door = 9
	local side = (w - door) / 2
	p(V3(side, h, 1), CFrame.new(-w / 2 + side / 2, h / 2 + 1, d / 2 - 0.5), wall, M.Brick)
	p(V3(side, h, 1), CFrame.new(w / 2 - side / 2, h / 2 + 1, d / 2 - 0.5), wall, M.Brick)
	p(V3(door, h - 9, 1), CFrame.new(0, 10 + (h - 9) / 2, d / 2 - 0.5), wall, M.Brick)
	-- corner beams
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			p(V3(1.4, h + 0.5, 1.4), CFrame.new(sx * (w / 2), h / 2 + 1, sz * (d / 2)), DARKWOOD, M.Wood)
		end
	end
	-- windows
	for _, sx in ipairs({ -1, 1 }) do
		local win = p(V3(0.3, 4, 5), CFrame.new(sx * (w / 2 + 0.05), h / 2 + 2, 0), rgb(255, 230, 160), M.Neon)
		win.Transparency = 0.2
	end
	-- roof
	local a = math.rad(28)
	local L = (d / 2 + 1.5) / math.cos(a)
	p(V3(w + 3, 0.8, L), CFrame.new(0, h + 1 + (d / 4) * math.tan(a), d / 4) * CFrame.Angles(a, 0, 0), roof, M.Slate)
	p(V3(w + 3, 0.8, L), CFrame.new(0, h + 1 + (d / 4) * math.tan(a), -d / 4) * CFrame.Angles(-a, 0, 0), roof, M.Slate)
	p(V3(w + 3.4, 0.8, 0.8), CFrame.new(0, h + 1 + (d / 2) * math.tan(a), 0), DARKWOOD, M.Wood)
	-- gable fill (stacked steps)
	local steps = 4
	for k = 1, steps do
		local sh = (d / 2) * math.tan(a) / steps
		local sw = d * (1 - (k - 0.5) / steps)
		for _, sx in ipairs({ -1, 1 }) do
			p(V3(0.8, sh, sw), CFrame.new(sx * (w / 2 - 0.5), h + 1 + sh * (k - 0.5), 0), wall, M.Brick)
		end
	end
	-- interior light
	local lp = p(V3(1.5, 0.4, 1.5), CFrame.new(0, h + 0.6, 0), rgb(255, 230, 170), M.Neon)
	light(lp, rgb(255, 220, 160), 30, 1.2)
	-- sign
	if signText then
		local board = p(V3(w * 0.7, 3, 0.4), CFrame.new(0, h + 0.2, d / 2 + 0.4), rgb(40, 30, 25), M.WoodPlanks)
		surfaceText(board, signText, signColor or rgb(255, 220, 90))
	end
	m.Parent = parent or F.Town
	return m
end

local function sellPad(pos, facing)
	local y = groundAt(pos.X, pos.Z, pos.Y + 20, 60) or pos.Y
	local p0 = V3(pos.X, y, pos.Z)
	local pad = part({ Name = "SellPad", Shape = Enum.PartType.Cylinder, Size = V3(0.6, 14, 14), CFrame = CFrame.new(p0 + V3(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(60, 230, 90), Material = M.Neon }, F.SellPads)
	vcyl(p0 + V3(0, 0.25, 0), 0.5, 16, rgb(40, 40, 45), M.Metal)
	light(pad, rgb(80, 255, 120), 20, 1.5)
	billboard(pad, "💰 SELL", V3(0, 6, 0), 200, 60, 140, rgb(130, 255, 150))
	emitter(pad, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 6, Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Right,
		Color = ColorSequence.new(rgb(120, 255, 150)), Size = NumberSequence.new(0.6), LightEmission = 1,
	})
	if facing then
		local cf = faceTo(p0, facing)
		crate(p0 + cf.RightVector * 9 + cf.LookVector * -4, 3)
		crate(p0 + cf.RightVector * 9.5 + cf.LookVector * -1, 2.5)
		barrel(p0 + cf.RightVector * -9 + cf.LookVector * -3)
	end
	return pad
end

local function spawnMarker(index, pos)
	part({ Name = "Zone" .. index, Size = V3(2, 2, 2), Position = pos + V3(0, 3, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, F.Spawns)
end

local function gateWall(cf, size, tier, zone, color)
	local g = part({ Name = "Gate", Size = size, CFrame = cf, Color = color, Material = M.ForceField, Transparency = 0.1 }, F.Gates)
	g:SetAttribute("RequiredTier", tier)
	g:SetAttribute("Zone", zone)
	return g
end

local function gateSign(pos, zone)
	local z = Config.Zones[zone]
	local anchor = part({ Name = "GateSign", Size = V3(1, 1, 1), Position = pos, Transparency = 1, CanCollide = false, CanQuery = false }, F.Gates)
	anchor:SetAttribute("RequiredTier", z.RequiredTier)
	anchor:SetAttribute("Zone", zone)
	anchor:SetAttribute("Sign", true)
	billboard(anchor, "🔒 " .. z.Name .. "\nNeed: " .. Config.Tools[z.RequiredTier].Name, V3(0, 0, 0), 380, 90, 140, rgb(255, 130, 130))
end

local function gateRing(center, radius, height, baseY, zone, color)
	local tier = Config.Zones[zone].RequiredTier
	local n = math.ceil(2 * math.pi * radius / 14)
	local w = 2 * math.pi * radius / n + 0.8
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local pos = V3(center.X + math.sin(a) * radius, baseY + height / 2, center.Z + math.cos(a) * radius)
		gateWall(CFrame.new(pos) * CFrame.Angles(0, a, 0), V3(w, height, 1), tier, zone, color)
	end
end

local function spinner(inst, speedY, speedX, bob)
	inst:SetAttribute("SpinY", speedY or 0)
	inst:SetAttribute("SpinX", speedX or 0)
	inst:SetAttribute("Bob", bob or 0)
	inst.Parent = F.Spin
end

local function path(a, b, width, lamps, lampColor)
	local A = V3(a.X, 8, a.Z)
	local B = V3(b.X, 8, b.Z)
	local len = (B - A).Magnitude
	T:FillBlock(CFrame.lookAt((A + B) / 2, B), V3(width, 4, len), M.Cobblestone)
	table.insert(pathSegments, { A, B })
	if lamps then
		local dir = (B - A).Unit
		local side = dir:Cross(UP)
		local n = math.floor(len / 30)
		for i = 1, n do
			local p = A + dir * (i * 30) + side * (width / 2 + 2.5) * ((i % 2 == 0) and 1 or -1)
			lamp(p.X, p.Z, lampColor)
		end
	end
end

local function nearPath(p, margin)
	for _, s in ipairs(pathSegments) do
		if distToSegment2D(p, s[1], s[2]) < margin then return true end
	end
	return false
end

---------------------------------------------------------------- lighting & terrain look
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = rgb(125, 128, 140)
	Lighting.Ambient = rgb(55, 58, 70)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.2
	Lighting.ExposureCompensation = 0.1
	Lighting.GeographicLatitude = 35
	-- Technology is only writable from Studio (command bar / plugins); the place file already uses Future.
	pcall(function() Lighting.Technology = Enum.Technology.Future end)
	local function ensure(class, name)
		local x = Lighting:FindFirstChild(name)
		if not x then
			x = Instance.new(class)
			x.Name = name
			x.Parent = Lighting
		end
		return x
	end
	local atm = ensure("Atmosphere", "Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.15
	atm.Color = rgb(199, 222, 255)
	atm.Decay = rgb(106, 128, 172)
	atm.Glare = 0.5
	atm.Haze = 1.2
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.3
	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.1
	rays.Spread = 0.75
	ensure("ColorCorrectionEffect", "ZoneColor")
	local grade = ensure("ColorCorrectionEffect", "BaseGrade")
	grade.Contrast = 0.08
	grade.Saturation = 0.12
	grade.Brightness = 0.01
	grade.TintColor = rgb(255, 252, 246)
	local dof = ensure("DepthOfFieldEffect", "DepthOfField")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 40
	dof.InFocusRadius = 70
	dof.NearIntensity = 0
	local sky = ensure("Sky", "Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
end

local function setupTerrainLook()
	T.WaterColor = rgb(35, 120, 155)
	T.WaterTransparency = 0.55
	T.WaterReflectance = 0.4
	T.WaterWaveSize = 0.18
	T.WaterWaveSpeed = 8
	pcall(function() T.Decoration = true end)
	T:SetMaterialColor(M.Grass, rgb(95, 165, 70))
	T:SetMaterialColor(M.LeafyGrass, rgb(80, 140, 60))
	T:SetMaterialColor(M.Rock, rgb(105, 100, 95))
	T:SetMaterialColor(M.Ground, rgb(100, 80, 60))
	T:SetMaterialColor(M.Cobblestone, rgb(150, 140, 130))
	T:SetMaterialColor(M.Pavement, rgb(170, 165, 160))
	T:SetMaterialColor(M.Slate, rgb(70, 55, 105))
	T:SetMaterialColor(M.Basalt, rgb(40, 32, 32))
	T:SetMaterialColor(M.CrackedLava, rgb(255, 90, 20))
	T:SetMaterialColor(M.Snow, rgb(235, 245, 255))
	T:SetMaterialColor(M.Glacier, rgb(150, 210, 245))
	T:SetMaterialColor(M.Salt, rgb(45, 25, 70))
	T:SetMaterialColor(M.Sand, rgb(230, 210, 160))
end

local function buildBase()
	T:Clear()
	T:FillBlock(CFrame.new(0, -14, 0), V3(1800, 8, 1800), M.Sand)
	T:FillBlock(CFrame.new(0, -2, 0), V3(1800, 16, 1800), M.Water)
	T:FillCylinder(CFrame.new(0, 2, 0), 12, 505, M.Sand)
	T:FillCylinder(CFrame.new(0, -50, 0), 116, 478, M.Rock)
	T:FillCylinder(CFrame.new(0, 5, 0), 6, 478, M.Ground)
	T:FillCylinder(CFrame.new(0, 8, 0), 4, 476, M.Grass)
	-- mountain ring framing the island
	for i = 1, 28 do
		local a = (i / 28) * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local r = rng:NextNumber(458, 478)
		local rad = rng:NextNumber(30, 46)
		local c = V3(math.sin(a) * r, rng:NextNumber(-10, 4), math.cos(a) * r)
		T:FillBall(c, rad, M.Rock)
		T:FillBall(c + V3(0, rad * 0.8, 0), rad * 0.32, M.Snow)
	end
	yield()
end

---------------------------------------------------------------- hub (Miner's Town)
local function buildHub()
	T:FillCylinder(CFrame.new(0, 9, 0), 6, 72, M.Grass)
	T:FillCylinder(CFrame.new(0, 11, 0), 6, 67, M.Grass)
	T:FillCylinder(CFrame.new(0, 13, 0), 6, 62, M.Grass)
	T:FillCylinder(CFrame.new(0, 15, 0), 2, 55, M.Pavement)

	local Y = 16
	local C = V3(0, Y, 0)

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = V3(12, 1, 12)
	spawn.Position = V3(0, Y + 0.5, 22)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(255, 200, 60)
	spawn.Material = M.Neon
	spawn.Transparency = 0.3
	spawn.Parent = World
	spawnMarker(0, V3(0, Y, 22))

	-- fountain
	vcyl(V3(0, Y + 1, 0), 2, 20, rgb(170, 170, 175), M.Marble)
	local water = vcyl(V3(0, Y + 1.6, 0), 1.4, 18, rgb(60, 160, 230), M.Glass, nil, false)
	water.Transparency = 0.3
	vcyl(V3(0, Y + 4, 0), 6, 2.5, rgb(190, 190, 195), M.Marble)
	vcyl(V3(0, Y + 7.2, 0), 0.8, 7, rgb(190, 190, 195), M.Marble)
	local top = ball(V3(0, Y + 8.4, 0), 2.2, rgb(255, 210, 60), M.Neon, nil, false)
	light(top, rgb(255, 220, 120), 30, 1.5)
	emitter(top, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 40, Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(10, 14), SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, -25, 0),
		Color = ColorSequence.new(rgb(150, 210, 255)), Size = NumberSequence.new(0.5), Transparency = NumberSequence.new(0.2),
	})
	local title = part({ Name = "Title", Size = V3(1, 1, 1), Position = V3(0, Y + 18, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	billboard(title, "⛏ MINER'S TOWN ⛏", V3(0, 0, 0), 520, 90, 260, rgb(255, 220, 90))

	-- Tool shop (west)
	local shopPos = V3(-38, Y, 4)
	local shopCf = faceTo(shopPos, C)
	building(shopCf, 22, 16, 12, rgb(175, 120, 80), rgb(170, 50, 45), "⛏ TOOL SHOP")
	local _, smithHead = npc(shopCf * CFrame.new(0, 1.4, 4), "Blacksmith Bruno", rgb(90, 60, 40), rgb(50, 50, 60), nil, rgb(80, 80, 80))
	prompt(smithHead, "Shop", "Open Shop", "Blacksmith Bruno", "Tools")
	-- anvil + forge
	part({ Name = "Anvil", Size = V3(3, 1.2, 1.6), CFrame = shopCf * CFrame.new(-6, 3.2, -3), Color = METAL, Material = M.Metal })
	part({ Size = V3(1.2, 1.4, 1.2), CFrame = shopCf * CFrame.new(-6, 2, -3), Color = METAL, Material = M.Metal })
	local forge = part({ Name = "Forge", Size = V3(4, 3, 3), CFrame = shopCf * CFrame.new(6, 2.9, -5), Color = rgb(90, 80, 75), Material = M.Brick })
	local coals = part({ Size = V3(3, 0.4, 2), CFrame = shopCf * CFrame.new(6, 4.5, -5), Color = rgb(255, 100, 20), Material = M.Neon })
	local ff = Instance.new("Fire")
	ff.Size = 3
	ff.Parent = coals
	light(forge, rgb(255, 120, 40), 18, 2)

	-- Backpack shop (east)
	local packPos = V3(38, Y, 4)
	local packCf = faceTo(packPos, C)
	building(packCf, 22, 16, 12, rgb(110, 140, 190), rgb(40, 70, 140), "🎒 BACKPACKS")
	local _, tailorHead = npc(packCf * CFrame.new(0, 1.4, 4), "Tailor Tess", rgb(60, 120, 200), rgb(40, 40, 60), nil, rgb(200, 80, 120))
	prompt(tailorHead, "Shop", "Open Shop", "Tailor Tess", "Packs")
	for k = 1, 4 do
		part({ Name = "Bag", Size = V3(1.6, 2, 1), CFrame = packCf * CFrame.new(-8 + k * 3.2, 5, -7), Color = Config.Backpacks[k + 2].Color, Material = M.Fabric })
	end

	-- Sell station (north-west)
	local sellPos = V3(-30, Y, -30)
	local sellCf = faceTo(sellPos, C)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part({ Size = V3(1.2, 12, 1.2), CFrame = sellCf * CFrame.new(sx * 9, 6, sz * 9), Color = DARKWOOD, Material = M.Wood })
		end
	end
	local ra = math.rad(20)
	for _, s in ipairs({ -1, 1 }) do
		part({ Size = V3(21, 0.8, 11), CFrame = sellCf * CFrame.new(0, 12 + 2.5 * math.tan(ra) * 2, s * 5) * CFrame.Angles(s * ra, 0, 0), Color = rgb(60, 170, 80), Material = M.Fabric })
	end
	local sellBoard = part({ Size = V3(14, 3, 0.4), CFrame = sellCf * CFrame.new(0, 11, 9.5), Color = rgb(30, 60, 30), Material = M.WoodPlanks })
	surfaceText(sellBoard, "💰 SELL ORES 💰", rgb(150, 255, 150))
	sellPad(sellPos + V3(0, 2, 0), C)

	-- Rebirth temple (north-east)
	local tPos = V3(30, Y, -32)
	vcyl(tPos + V3(0, 0.5, 0), 1, 24, rgb(220, 220, 230), M.Marble)
	vcyl(tPos + V3(0, 1.5, 0), 1, 18, rgb(230, 230, 240), M.Marble)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local pp = tPos + V3(math.sin(a) * 10.5, 0, math.cos(a) * 10.5)
		vcyl(pp + V3(0, 7, 0), 14, 1.8, rgb(235, 235, 245), M.Marble)
		local cap = part({ Size = V3(2.6, 1, 2.6), Position = pp + V3(0, 14.5, 0), Color = rgb(200, 160, 255), Material = M.Neon })
		light(cap, rgb(180, 120, 255), 12, 1)
	end
	local ringTop = vcyl(tPos + V3(0, 15.4, 0), 1, 24, rgb(220, 220, 235), M.Marble)
	ringTop.Transparency = 0
	local altar = part({ Name = "Altar", Size = V3(5, 3, 5), Position = tPos + V3(0, 3.5, 0), Color = rgb(60, 30, 90), Material = M.Marble })
	prompt(altar, "Rebirth", "Rebirth", "Rebirth Altar")
	local orb = ball(tPos + V3(0, 9, 0), 4, rgb(190, 110, 255), M.Neon, nil, false)
	light(orb, rgb(190, 110, 255), 30, 2)
	emitter(orb, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 20, Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Color = ColorSequence.new(rgb(220, 170, 255)), Size = NumberSequence.new(0.7),
	})
	spinner(orb, 0.6, 0, 1.2)
	local templeTitle = part({ Size = V3(1, 1, 1), Position = tPos + V3(0, 20, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	billboard(templeTitle, "🌟 REBIRTH TEMPLE", V3(0, 0, 0), 320, 60, 160, rgb(220, 170, 255))

	-- Hatchery (north)
	local hPos = V3(0, Y, -44)
	local archCf = faceTo(hPos + V3(0, 0, 10), C)
	part({ Size = V3(1.5, 14, 1.5), CFrame = archCf * CFrame.new(-16, 7, 0), Color = rgb(255, 230, 180), Material = M.Marble })
	part({ Size = V3(1.5, 14, 1.5), CFrame = archCf * CFrame.new(16, 7, 0), Color = rgb(255, 230, 180), Material = M.Marble })
	local archTop = part({ Size = V3(34, 3, 1.5), CFrame = archCf * CFrame.new(0, 15, 0), Color = rgb(255, 200, 90), Material = M.Marble })
	surfaceText(archTop, "🥚 HATCHERY 🥚", rgb(120, 60, 20))
	for k, egg in ipairs(Config.Eggs) do
		local x = -15 + (k - 1) * 10
		local p0 = hPos + V3(x, 0, -2 - math.abs(x) * 0.15)
		-- pedestal: stepped marble base, gold trim, glowing ring and corner crystals
		vcyl(p0 + V3(0, 0.4, 0), 0.8, 7.2, rgb(185, 175, 160), M.Marble)
		vcyl(p0 + V3(0, 1.3, 0), 1.2, 6, rgb(215, 205, 190), M.Marble)
		vcyl(p0 + V3(0, 0.85, 0), 0.15, 7.3, rgb(255, 200, 70), M.Foil, nil, false)
		vcyl(p0 + V3(0, 2.0, 0), 0.25, 6.3, rgb(255, 200, 70), M.Foil, nil, false)
		local ring = vcyl(p0 + V3(0, 2.2, 0), 0.25, 5.4, egg.Color, M.Neon, nil, false)
		emitter(ring, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 6, Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Right, LightEmission = 1,
			Color = ColorSequence.new(egg.Color:Lerp(Color3.new(1, 1, 1), 0.5)), Size = NumberSequence.new(0.35, 0),
		})
		for c = 1, 4 do
			local a = c / 4 * math.pi * 2 + math.pi / 4
			local cp = p0 + V3(math.cos(a) * 3.1, 2.6, math.sin(a) * 3.1)
			part({ Size = V3(0.5, 1.4, 0.5), CFrame = CFrame.new(cp) * CFrame.Angles(0, a, math.rad(12)), Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.3), Material = M.Glass, Transparency = 0.15, CanCollide = false })
		end
		local model, e = ModelLibrary.BuildEgg(egg, 5.2, true)
		model.Name = "Egg" .. k
		model:PivotTo(CFrame.new(p0 + V3(0, 5.4, 0)))
		light(e, egg.Color, 14, 1.4)
		billboard(e, egg.Name .. "\n💰 " .. tostring(egg.Cost), V3(0, 5, 0), 200, 56, 60, egg.Color:Lerp(Color3.new(1, 1, 1), 0.4))
		prompt(e, "Hatch", "Hatch", egg.Name, k)
		spinner(model, 0.5, 0, 0.6)
	end

	-- Quest giver
	local _, joeHead = npc(faceTo(V3(14, Y, 26), V3(0, Y, 22)), "Old Miner Joe", rgb(160, 60, 40), rgb(60, 60, 110))
	prompt(joeHead, "Quest", "Talk", "Old Miner Joe")
	crate(V3(17, Y, 28), 2.5)
	barrel(V3(18, Y, 24))

	-- Void portal
	local portalPos = V3(-24, Y, 40)
	local pcf = faceTo(portalPos + V3(0, 9, 0), C)
	for k = 1, 20 do
		local a = k / 20 * math.pi * 2
		part({ Size = V3(2, 2, 2), CFrame = pcf * CFrame.new(math.cos(a) * 7, math.sin(a) * 7, 0) * CFrame.Angles(0, 0, a), Color = rgb(50, 0, 90), Material = M.Neon })
	end
	local disc = part({ Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V3(0.4, 13, 13), CFrame = pcf * CFrame.Angles(0, math.rad(90), 0), Color = rgb(120, 40, 220), Material = M.Glass, Transparency = 0.25, CanCollide = false })
	light(disc, rgb(150, 60, 255), 24, 2)
	emitter(disc, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 30, Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Color = ColorSequence.new(rgb(200, 120, 255)), Size = NumberSequence.new(0.6),
	})
	prompt(disc, "Portal", "Enter", "Portal to The Void", 6)
	billboard(disc, "🌌 THE VOID\nNeed: " .. Config.Tools[10].Name, V3(0, 10, 0), 300, 70, 100, rgb(210, 160, 255))
	vcyl(portalPos + V3(0, 0.5, 0), 1, 18, rgb(40, 20, 60), M.Marble)

	-- Leaderboards
	local function board(pos, name, title, color)
		local cf = faceTo(pos, C)
		part({ Size = V3(0.8, 18, 0.8), CFrame = cf * CFrame.new(-7.6, 9, 0), Color = METAL, Material = M.Metal })
		part({ Size = V3(0.8, 18, 0.8), CFrame = cf * CFrame.new(7.6, 9, 0), Color = METAL, Material = M.Metal })
		local b = part({ Name = name, Size = V3(14, 14, 0.6), CFrame = cf * CFrame.new(0, 10, 0), Color = rgb(25, 25, 35), Material = M.SmoothPlastic }, F.Leaderboards)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		sg.Parent = b
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0.14, 0)
		t.BackgroundColor3 = color
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = title
		t.Parent = sg
		for r = 1, 10 do
			local row = Instance.new("TextLabel")
			row.Name = "Row" .. r
			row.Position = UDim2.new(0.04, 0, 0.15 + (r - 1) * 0.085, 0)
			row.Size = UDim2.new(0.92, 0, 0.08, 0)
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.GothamBold
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = r == 1 and rgb(255, 215, 0) or (r == 2 and rgb(220, 220, 230) or (r == 3 and rgb(230, 150, 80) or Color3.new(1, 1, 1)))
			row.Text = r .. ". ..."
			row.Parent = sg
		end
	end
	board(V3(26, Y, 46), "TopEarned", "💰 TOP EARNERS", rgb(200, 150, 20))
	board(V3(42, Y, 34), "TopRebirths", "🌟 TOP REBIRTHS", rgb(130, 60, 200))

	-- lamps, planters, benches, flags
	for k = 1, 14 do
		local a = (k + 0.5) / 14 * math.pi * 2
		lamp(math.sin(a) * 51, math.cos(a) * 51, rgb(255, 215, 150))
	end
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2 + 0.15
		local p0 = V3(math.sin(a) * 58, Y, math.cos(a) * 58)
		vcyl(p0 + V3(0, 1, 0), 2, 5, rgb(150, 110, 80), M.Brick)
		tree(p0.X, p0.Z, 0.7)
	end
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + 0.5
		local p0 = V3(math.sin(a) * 20, Y, math.cos(a) * 20)
		local cf = faceTo(p0, C)
		part({ Name = "Bench", Size = V3(6, 0.5, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = rgb(140, 95, 55), Material = M.WoodPlanks })
		part({ Size = V3(6, 2, 0.4), CFrame = cf * CFrame.new(0, 2.8, -1), Color = rgb(140, 95, 55), Material = M.WoodPlanks })
		part({ Size = V3(0.5, 1.4, 1.8), CFrame = cf * CFrame.new(-2.6, 0.7, 0), Color = METAL, Material = M.Metal })
		part({ Size = V3(0.5, 1.4, 1.8), CFrame = cf * CFrame.new(2.6, 0.7, 0), Color = METAL, Material = M.Metal })
	end
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		local p0 = V3(math.sin(a) * 63, Y, math.cos(a) * 63)
		local yy = groundAt(p0.X, p0.Z) or Y
		part({ Size = V3(0.6, 20, 0.6), Position = V3(p0.X, yy + 10, p0.Z), Color = rgb(220, 220, 220), Material = M.Metal })
		part({ Name = "Flag", Size = V3(0.2, 3.5, 6), CFrame = CFrame.new(p0.X, yy + 18, p0.Z) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 3), Color = (k % 2 == 0) and rgb(255, 190, 40) or rgb(220, 60, 50), Material = M.Fabric, CanCollide = false })
	end
	yield()
end

---------------------------------------------------------------- Arena
local function buildArena()
	local C = Config.ArenaCenter
	T:FillCylinder(CFrame.new(C.X, 8, C.Z), 4, 36, M.Pavement)
	for k = 1, 14 do
		local a = k / 14 * math.pi * 2
		local p0 = V3(C.X + math.sin(a) * 38, 10, C.Z + math.cos(a) * 38)
		if math.cos(a) < 0.85 then
			part({ Size = V3(3, 18, 3), Position = p0 + V3(0, 9, 0), Color = rgb(130, 125, 120), Material = M.Cobblestone })
			torch(p0 + V3(0, 19.5, 0))
			local b = (k + 1) / 14 * math.pi * 2
			if math.cos(b) < 0.85 then
				local q = V3(C.X + math.sin(b) * 38, 10, C.Z + math.cos(b) * 38)
				beam(p0 + V3(0, 3, 0), q + V3(0, 3, 0), 2, 6, rgb(120, 115, 110), M.Cobblestone)
			end
		end
	end
	part({ Name = "BossSpawn", Size = V3(2, 2, 2), Position = V3(C.X, 10, C.Z - 4), Transparency = 1, CanCollide = false, CanQuery = false }, F.Markers)
	bigSign(V3(C.X, 24, C.Z + 40), V3(0, 24, 0), "⚔ GOLEM ARENA ⚔", rgb(255, 120, 80), 30)
	for k = 1, 3 do
		rock(C.X + rng:NextNumber(-25, 25), C.Z + rng:NextNumber(-25, 15), rng:NextNumber(2, 4), rgb(110, 110, 105))
	end
end

---------------------------------------------------------------- Zone 1: Sunny Meadow
local function buildMeadow(i)
	local z = Config.Zones[i]
	local C = z.Center
	local dir = flatDir(C)
	local side = dir:Cross(UP)

	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(20, 72)
		local rad = rng:NextNumber(14, 26)
		T:FillBall(V3(C.X + math.sin(a) * r, 10 - rad * rng:NextNumber(0.45, 0.75), C.Z + math.cos(a) * r), rad, M.Grass)
	end
	-- windmill hill
	local hill = C + dir * 48
	T:FillBall(V3(hill.X, -12, hill.Z), 34, M.Grass)
	-- pond
	local pond = C - side * 42 + dir * 5
	T:FillCylinder(CFrame.new(pond.X, 8, pond.Z), 4, 17, M.Sand)
	T:FillCylinder(CFrame.new(pond.X, 8, pond.Z), 8, 14, M.Air)
	T:FillCylinder(CFrame.new(pond.X, 6, pond.Z), 4, 14, M.Water)
	yield()

	-- windmill
	local hy = groundAt(hill.X, hill.Z) or 20
	local base = V3(hill.X, hy - 1, hill.Z)
	vcyl(base + V3(0, 12, 0), 24, 9, rgb(230, 220, 200), M.Brick)
	vcyl(base + V3(0, 24.5, 0), 1, 10, DARKWOOD, M.Wood)
	for k = 1, 4 do
		vcyl(base + V3(0, 25 + k * 1.2, 0), 1.2, 10 - k * 2.2, rgb(170, 60, 50), M.Slate)
	end
	local hubCf = faceTo(base + V3(0, 21, 0), V3(0, 0, 0)) * CFrame.new(0, 0, 5.2)
	local blades = Instance.new("Model")
	blades.Name = "WindmillBlades"
	local hubPart = part({ Name = "Hub", Size = V3(1.6, 1.6, 1.6), CFrame = hubCf, Color = DARKWOOD, Material = M.Wood }, blades)
	for k = 1, 4 do
		local a = k * math.pi / 2
		part({ Size = V3(2.6, 13, 0.3), CFrame = hubCf * CFrame.Angles(0, 0, a) * CFrame.new(0, 7.5, 0.3), Color = rgb(245, 240, 230), Material = M.Fabric }, blades)
		part({ Size = V3(0.4, 14, 0.4), CFrame = hubCf * CFrame.Angles(0, 0, a) * CFrame.new(0, 7.5, 0), Color = DARKWOOD, Material = M.Wood }, blades)
	end
	blades.PrimaryPart = hubPart
	blades:SetAttribute("SpinZ", 0.8)
	blades.Parent = F.Spin

	-- farm: house, fences, hay
	local farm = C + side * 45 - dir * 5
	local fy = groundAt(farm.X, farm.Z) or 10
	building(faceTo(V3(farm.X, fy - 0.5, farm.Z), C), 16, 12, 10, rgb(200, 70, 60), rgb(90, 60, 40), "FARM", nil, F.Decor)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local fp = farm + V3(math.sin(a) * 16, 0, math.cos(a) * 16)
		local yy = groundAt(fp.X, fp.Z)
		if yy and k ~= 12 then
			part({ Size = V3(0.6, 3.5, 0.6), Position = V3(fp.X, yy + 1.5, fp.Z), Color = WOOD, Material = M.Wood })
			local b = (k + 1) / 16 * math.pi * 2
			local q = farm + V3(math.sin(b) * 16, 0, math.cos(b) * 16)
			local qy = groundAt(q.X, q.Z) or yy
			beam(V3(fp.X, yy + 2.5, fp.Z), V3(q.X, qy + 2.5, q.Z), 0.3, 0.5, WOOD, M.Wood)
			beam(V3(fp.X, yy + 1.2, fp.Z), V3(q.X, qy + 1.2, q.Z), 0.3, 0.5, WOOD, M.Wood)
		end
	end
	for k = 1, 5 do
		local hp = farm + side * rng:NextNumber(-10, 10) + dir * rng:NextNumber(5, 12)
		local yy = groundAt(hp.X, hp.Z)
		if yy then
			part({ Name = "Hay", Shape = Enum.PartType.Cylinder, Size = V3(3, 3.5, 3.5), CFrame = CFrame.new(hp.X, yy + 1.6, hp.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(225, 190, 90), Material = M.Grass })
		end
	end

	-- trees, flowers, rocks
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(15, 82)
		local p = C + V3(math.sin(a) * r, 0, math.cos(a) * r)
		if (p - pond).Magnitude > 20 and (p - farm).Magnitude > 20 and (p - hill).Magnitude > 10 and not nearPath(p, 8) then
			tree(p.X, p.Z, rng:NextNumber(0.8, 1.3))
		end
	end
	local flowerColors = { rgb(255, 90, 120), rgb(255, 220, 60), rgb(160, 110, 255), rgb(255, 255, 255), rgb(255, 140, 40) }
	for _ = 1, 90 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, 82)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy, mat = groundAt(x, zz)
		if yy and mat == M.Grass then
			part({ Name = "Stem", Size = V3(0.15, 1, 0.15), Position = V3(x, yy + 0.5, zz), Color = rgb(60, 140, 50), CanCollide = false, CastShadow = false })
			ball(V3(x, yy + 1.1, zz), 0.6, flowerColors[rng:NextInteger(1, #flowerColors)], M.SmoothPlastic, nil, false)
		end
	end
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 80)
		rock(C.X + math.sin(a) * r, C.Z + math.cos(a) * r, rng:NextNumber(2, 5))
	end
	-- lily pads
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(2, 11)
		vcyl(pond + V3(math.sin(a) * r, 0, math.cos(a) * r) + V3(0, 0, 0) * 0 + V3(0, 8.05 - pond.Y, 0), 0.1, rng:NextNumber(2, 3), rgb(60, 160, 60), M.Grass, nil, false)
	end

	local entry = C - dir * 72
	bigSign(V3(entry.X, 22, entry.Z), V3(0, 22, 0), "🌼 SUNNY MEADOW", rgb(150, 255, 120))
	sellPad(C - dir * 64 + side * 14, V3(0, 10, 0))
	spawnMarker(i, V3((C - dir * 66).X, (groundAt((C - dir * 66).X, (C - dir * 66).Z) or 10), (C - dir * 66).Z))
	yield()
end

---------------------------------------------------------------- Zone 2: Dark Caves (hollow mountain)
local function buildCaves(i)
	local z = Config.Zones[i]
	local C = z.Center
	local dir = flatDir(C)
	local side = dir:Cross(UP)
	local Cg = V3(C.X, 0, C.Z)

	T:FillBall(V3(C.X, 5, C.Z), 75, M.Rock)
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + 0.3
		T:FillBall(V3(C.X + math.sin(a) * 58, rng:NextNumber(-4, 14), C.Z + math.cos(a) * 58), rng:NextNumber(24, 36), M.Rock)
	end
	T:FillBall(V3(C.X, 60, C.Z), 26, M.LeafyGrass)
	-- hollow cave + floor
	T:FillBall(V3(C.X, 30, C.Z), 45, M.Air)
	T:FillCylinder(CFrame.new(C.X, -3, C.Z), 30, 46, M.Ground)
	-- floor bumps
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, 34)
		T:FillBall(V3(C.X + math.sin(a) * r, 8, C.Z + math.cos(a) * r), rng:NextNumber(5, 8), M.Rock)
	end
	-- inner rock pillars (avoid the tunnel axis)
	local baseAngle = math.atan2(-dir.X, -dir.Z)
	for k = 1, 3 do
		local a = baseAngle + k * (math.pi * 2 / 4)
		T:FillCylinder(CFrame.new(C.X + math.sin(a) * 24, 40, C.Z + math.cos(a) * 24), 60, 4.5, M.Rock)
	end
	-- entrance tunnel
	local tMid = C - dir * 63
	tMid = V3(tMid.X, 19, tMid.Z)
	T:FillBlock(CFrame.lookAt(tMid, tMid + dir), V3(18, 18, 76), M.Air)
	T:FillBlock(CFrame.lookAt(tMid - V3(0, 10, 0), tMid - V3(0, 10, 0) + dir), V3(16, 4, 76), M.Ground)
	yield()

	-- tunnel supports
	for k = 0, 6 do
		local p = C - dir * (95 - k * 10)
		local fy = groundAt(p.X, p.Z, 26, 30) or 11
		local l = V3(p.X, fy, p.Z) + side * 7.5
		local r = V3(p.X, fy, p.Z) - side * 7.5
		part({ Name = "Support", Size = V3(1.4, 14, 1.4), Position = l + V3(0, 7, 0), Color = DARKWOOD, Material = M.Wood })
		part({ Name = "Support", Size = V3(1.4, 14, 1.4), Position = r + V3(0, 7, 0), Color = DARKWOOD, Material = M.Wood })
		beam(l + V3(0, 14, 0), r + V3(0, 14, 0), 1.6, 1.6, DARKWOOD, M.Wood)
		if k % 2 == 0 then torch(l + V3(0, 9, 0) - side * 1.2) end
	end
	local mouth = C - dir * 100
	bigSign(V3(mouth.X, 30, mouth.Z), V3(0, 30, 0), "🪨 DARK CAVES", rgb(255, 190, 120))
	gateWall(CFrame.lookAt(V3(mouth.X, 19, mouth.Z) + dir * 6, V3(mouth.X, 19, mouth.Z) + dir * 7), V3(20, 20, 1), z.RequiredTier, i, rgb(255, 150, 60))
	gateSign(V3(mouth.X, 22, mouth.Z) - dir * 2, i)

	-- rails + mine carts
	local railStart = C - dir * 98
	local railEnd = C - dir * 6
	for _, s in ipairs({ -1.6, 1.6 }) do
		local a = V3(railStart.X, 11.3, railStart.Z) + side * s
		local b = V3(railEnd.X, 12.3, railEnd.Z) + side * s
		beam(a, b, 0.3, 0.3, METAL, M.Metal, nil, false)
	end
	local railLen = (railEnd - railStart).Magnitude
	for k = 0, math.floor(railLen / 3) do
		local p = railStart + (railEnd - railStart).Unit * (k * 3)
		part({ Name = "Sleeper", Size = V3(4.6, 0.3, 0.8), CFrame = CFrame.lookAt(V3(p.X, 11.1 + k * 3 / railLen, p.Z), V3(p.X, 11.1, p.Z) + dir), Color = DARKWOOD, Material = M.Wood, CanCollide = false })
	end
	for _, t in ipairs({ 0.35, 0.8 }) do
		local p = railStart:Lerp(railEnd, t)
		local cf = CFrame.lookAt(V3(p.X, 13, p.Z), V3(p.X, 13, p.Z) + dir)
		part({ Name = "MineCart", Size = V3(4, 2.4, 6), CFrame = cf, Color = rgb(90, 80, 75), Material = M.CorrodedMetal })
		part({ Size = V3(3.4, 0.6, 5.4), CFrame = cf * CFrame.new(0, 1.4, 0), Color = rgb(205, 115, 60), Material = M.Metal })
		for _, wx in ipairs({ -2, 2 }) do
			for _, wz in ipairs({ -2, 2 }) do
				part({ Shape = Enum.PartType.Cylinder, Size = V3(0.5, 1.4, 1.4), CFrame = cf * CFrame.new(wx, -1.2, wz), Color = METAL, Material = M.Metal })
			end
		end
	end

	-- scaffolding platforms (multi-level mining)
	local levels = { { y = 26, r = 36, a = baseAngle + math.rad(60) }, { y = 26, r = 36, a = baseAngle - math.rad(70) }, { y = 40, r = 35, a = baseAngle + math.rad(150) }, { y = 40, r = 35, a = baseAngle - math.rad(160) } }
	for _, L in ipairs(levels) do
		local pc = V3(C.X + math.sin(L.a) * L.r, L.y - 0.5, C.Z + math.cos(L.a) * L.r)
		local cf = faceTo(pc, Cg)
		part({ Name = "Scaffold", Size = V3(16, 1, 12), CFrame = cf, Color = rgb(130, 90, 55), Material = M.WoodPlanks }, F.Platforms)
		for _, sx in ipairs({ -7, 7 }) do
			for _, sz in ipairs({ -5, 5 }) do
				local post = cf * CFrame.new(sx, 0, sz)
				local h = L.y - 11
				part({ Size = V3(1, h, 1), CFrame = post * CFrame.new(0, -h / 2, 0), Color = DARKWOOD, Material = M.Wood })
			end
			part({ Size = V3(0.4, 3, 12), CFrame = cf * CFrame.new(sx * 1.1, 2, 0), Color = DARKWOOD, Material = M.Wood })
		end
		local truss = Instance.new("TrussPart")
		truss.Anchored = true
		truss.Size = V3(2, L.y - 11, 2)
		truss.CFrame = cf * CFrame.new(0, -(L.y - 11) / 2, 7)
		truss.Color = rgb(120, 85, 50)
		truss.Material = M.Wood
		truss.Parent = F.Platforms
		torch((cf * CFrame.new(6.5, 2, -5)).Position)
	end

	-- wall torches + emerald veins + stalactites
	for k = 1, 14 do
		local a = k / 14 * math.pi * 2
		local r = rayTerrain(V3(C.X, 18, C.Z), V3(math.sin(a), 0, math.cos(a)) * 60)
		if r then torch(r.Position - V3(math.sin(a), 0, math.cos(a)) * 1.2) end
	end
	for _ = 1, 16 do
		local d = V3(rng:NextNumber(-1, 1), rng:NextNumber(-0.1, 0.9), rng:NextNumber(-1, 1)).Unit
		local r = rayTerrain(V3(C.X, 28, C.Z), d * 70)
		if r then
			local cf = CFrame.lookAt(r.Position, r.Position + r.Normal) * CFrame.Angles(-math.pi / 2, 0, 0)
			crystalCluster(cf, 0.6, rgb(40, 220, 110), M.Neon, nil, rng:NextNumber() < 0.5)
		end
	end
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(0, 40)
		local o = V3(C.X + math.sin(a) * rr, 20, C.Z + math.cos(a) * rr)
		local r = rayTerrain(o, V3(0, 80, 0))
		if r and r.Position.Y > 45 then
			local len = rng:NextNumber(4, 10)
			part({ Name = "Stalactite", Size = V3(1.6, len, 1.6), CFrame = CFrame.new(r.Position - V3(0, len / 2 - 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(85, 78, 72), Material = M.Slate, CanCollide = false })
			part({ Size = V3(0.8, len * 0.5, 0.8), CFrame = CFrame.new(r.Position - V3(0, len + len * 0.15, 0)), Color = rgb(85, 78, 72), Material = M.Slate, CanCollide = false })
		end
	end
	-- crates & barrels
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(10, 36)
		local x, zz = C.X + math.sin(a) * rr, C.Z + math.cos(a) * rr
		local yy = groundAt(x, zz, 22, 20)
		if yy then
			if rng:NextNumber() < 0.5 then crate(V3(x, yy, zz), 3) else barrel(V3(x, yy, zz)) end
		end
	end
	-- trees on the mountain top
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(0, 25)
		tree(C.X + math.sin(a) * rr, C.Z + math.cos(a) * rr, 1)
	end

	local inside = C - dir * 22
	sellPad(V3(inside.X, 14, inside.Z) + side * 14, Cg)
	sellPad(C - dir * 112 + side * 16, V3(0, 10, 0))
	spawnMarker(i, V3(inside.X, 12.5, inside.Z))
	yield()
end

---------------------------------------------------------------- Zone 3: Crystal Grotto (underground cavern)
local grottoTunnel
local function buildGrotto(i)
	local z = Config.Zones[i]
	local C = V3(z.Center.X, 0, z.Center.Z)
	local dir = flatDir(C)
	local side = dir:Cross(UP)

	T:FillBall(V3(C.X, -30, C.Z), 60, M.Rock)
	T:FillBall(V3(C.X, -40, C.Z), 45, M.Air)
	T:FillCylinder(CFrame.new(C.X, -80, C.Z), 40, 52, M.Slate)
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(6, 32)
		T:FillBall(V3(C.X + math.sin(a) * r, -64, C.Z + math.cos(a) * r), rng:NextNumber(5, 9), M.Slate)
	end
	-- glowing pool
	local poolP = C + side * 18 + dir * 10
	T:FillCylinder(CFrame.new(poolP.X, -61, poolP.Z), 6, 9, M.Air)
	T:FillCylinder(CFrame.new(poolP.X, -62, poolP.Z), 4, 9, M.Water)
	local glow = vcyl(V3(poolP.X, -63.5, poolP.Z), 0.4, 16, rgb(80, 220, 255), M.Neon, nil, false)
	light(glow, rgb(80, 220, 255), 26, 2)

	-- sloped tunnel from the surface down to the cavern
	local P0 = C - dir * 175 + V3(0, 10, 0)
	local P1 = C - dir * 30 + V3(0, -60, 0)
	local mid = (P0 + P1) / 2
	local len = (P1 - P0).Magnitude
	local tcf = CFrame.lookAt(mid, P1)
	T:FillBlock(tcf * CFrame.new(0, 8, 0), V3(16, 16, len + 8), M.Air)
	T:FillBlock(tcf * CFrame.new(0, -1.5, 0), V3(14, 3, len), M.Slate)
	grottoTunnel = P0
	yield()

	local lineDir = (P1 - P0).Unit
	local tSide = lineDir:Cross(UP).Unit
	local tUp = tSide:Cross(lineDir).Unit
	-- rails + lanterns down the tunnel
	for _, s in ipairs({ -1.6, 1.6 }) do
		beam(P0 + tSide * s + tUp * 0.3, P1 + tSide * s + tUp * 0.3, 0.3, 0.3, METAL, M.Metal, nil, false)
	end
	for k = 1, math.floor(len / 14) do
		local p = P0 + lineDir * (k * 14)
		local s = (k % 2 == 0) and 1 or -1
		local lp = part({ Name = "Lantern", Size = V3(1, 1.4, 1), Position = p + tSide * s * 6.8 + tUp * 6, Color = rgb(170, 110, 255), Material = M.Neon, CanCollide = false })
		light(lp, rgb(170, 120, 255), 22, 1.4)
	end
	-- gate deep in the tunnel
	local gp = P0 + lineDir * 55
	gateWall(CFrame.lookAt(gp, gp + lineDir) * CFrame.new(0, 8, 0), V3(16, 16, 1), z.RequiredTier, i, rgb(180, 90, 255))
	gateSign(gp + tUp * 10 - lineDir * 3, i)
	-- entrance arch
	local archCf = CFrame.lookAt(P0, P0 + V3(lineDir.X, 0, lineDir.Z))
	for _, s in ipairs({ -1, 1 }) do
		part({ Size = V3(2, 16, 2), CFrame = archCf * CFrame.new(s * 9, 8, 0), Color = rgb(80, 60, 120), Material = M.Slate })
		crystalCluster(archCf * CFrame.new(s * 11, 0, 2), 0.8, rgb(180, 100, 255), M.Neon, nil, false)
	end
	local top = part({ Size = V3(22, 3, 2), CFrame = archCf * CFrame.new(0, 17, 0), Color = rgb(80, 60, 120), Material = M.Slate })
	surfaceText(top, "💎 CRYSTAL GROTTO ↓", rgb(220, 180, 255))
	top.SurfaceGui.Face = Enum.NormalId.Front
	light(top, rgb(180, 100, 255), 30, 1.5)

	-- crystals on the hill above
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 38)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy = groundAt(x, zz, 80, 80)
		if yy then crystalCluster(CFrame.new(x, yy, zz), 1.2, rgb(170, 90, 255), M.Neon, nil, false) end
	end

	-- inside: crystals on floor and walls, giant mushrooms, central floating crystal
	local colors = { rgb(170, 90, 255), rgb(80, 220, 255), rgb(255, 120, 220) }
	for k = 1, 26 do
		local d = V3(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-1, 1)).Unit
		local r = rayTerrain(V3(C.X, -45, C.Z), d * 80)
		if r then
			local cf = CFrame.lookAt(r.Position, r.Position + r.Normal) * CFrame.Angles(-math.pi / 2, 0, 0)
			crystalCluster(cf, rng:NextNumber(0.7, 1.4), colors[(k % 3) + 1], M.Neon, nil, k % 2 == 0)
		end
	end
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(14, 34)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy = groundAt(x, zz, -30, 50)
		if yy then
			local h = rng:NextNumber(6, 12)
			vcyl(V3(x, yy + h / 2, zz), h, 1.6, rgb(220, 210, 240), M.SmoothPlastic)
			local cap = vcyl(V3(x, yy + h + 0.5, zz), 1.6, h * 0.9, rgb(60, 200, 255), M.Neon)
			light(cap, rgb(60, 200, 255), 20, 1)
		end
	end
	local heart = part({ Name = "GrottoHeart", Size = V3(4, 9, 4), CFrame = CFrame.new(C.X, -42, C.Z) * CFrame.Angles(0, 0, 0), Color = rgb(200, 140, 255), Material = M.Neon, CanCollide = false })
	light(heart, rgb(200, 140, 255), 50, 2.5)
	spinner(heart, 0.4, 0, 2)

	local floor = C - dir * 20
	sellPad(V3(floor.X, -55, floor.Z) + side * 12, C)
	sellPad(P0 - V3(lineDir.X, 0, lineDir.Z) * 8 + tSide * 14, V3(0, 10, 0))
	local sy = groundAt(floor.X, floor.Z, -30, 50) or -60
	spawnMarker(i, V3(floor.X, sy, floor.Z))
	yield()
end

---------------------------------------------------------------- Zone 4: Lava Volcano
local function buildVolcano(i)
	local z = Config.Zones[i]
	local C = z.Center
	local dir = flatDir(C)
	local side = dir:Cross(UP)

	for k = 0, 26 do
		T:FillCylinder(CFrame.new(C.X, 8 + k * 4, C.Z), 8, 110 - k * 3 + rng:NextNumber(-2, 2), M.Basalt)
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 100)
		local h = 12 + (110 - r) / 3 * 4
		T:FillBall(V3(C.X + math.sin(a) * r, h - 5, C.Z + math.cos(a) * r), rng:NextNumber(8, 14), M.Basalt)
	end
	T:FillCylinder(CFrame.new(C.X, 118, C.Z), 54, 24, M.Air)
	T:FillCylinder(CFrame.new(C.X, 93, C.Z), 4, 25, M.CrackedLava)
	-- scorched ground ring
	T:FillCylinder(CFrame.new(C.X, 8, C.Z), 4, 125, M.Basalt)
	for k = 0, 26 do
		if k < 2 then T:FillCylinder(CFrame.new(C.X, 8 + k * 4, C.Z), 8, 110 - k * 3, M.Basalt) end
	end
	yield()

	-- lava lake in the crater (touch = sent back to foot)
	local lava = vcyl(V3(C.X, 95.6, C.Z), 1, 48, rgb(255, 100, 20), M.Neon, F.Lava, true)
	lava.Name = "LavaLake"
	light(lava, rgb(255, 110, 30), 60, 3)
	local smoke = part({ Name = "Smoke", Size = V3(1, 1, 1), Position = V3(C.X, 100, C.Z), Transparency = 1, CanCollide = false, CanQuery = false })
	emitter(smoke, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 12, Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new(rgb(60, 50, 50), rgb(30, 30, 30)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 40) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
	})
	emitter(smoke, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 30, Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(15, 30), SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top,
		Acceleration = V3(0, -12, 0), LightEmission = 1,
		Color = ColorSequence.new(rgb(255, 160, 40), rgb(255, 60, 0)), Size = NumberSequence.new(0.8),
	})

	-- lava rivers down the slopes
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + 0.4
		local prev
		local wobble = 0
		for r = 30, 106, 6 do
			wobble += rng:NextNumber(-0.06, 0.06)
			local x, zz = C.X + math.sin(a + wobble) * r, C.Z + math.cos(a + wobble) * r
			local yy = groundAt(x, zz, 200, 220)
			if yy then
				local p = V3(x, yy + 0.2, zz)
				if prev then
					local seg = beam(prev, p, 4 + r * 0.02, 0.6, rgb(255, 110, 20), M.Neon, nil, false)
					seg.CanTouch = false
					seg.CanQuery = false
					if (r // 6) % 3 == 0 then light(seg, rgb(255, 110, 30), 18, 1.5) end
				end
				prev = p
			end
		end
	end

	-- basalt columns, dead trees, obsidian spikes
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, 108)
		local cx, cz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		for _ = 1, 5 do
			local x, zz = cx + rng:NextNumber(-3, 3), cz + rng:NextNumber(-3, 3)
			local yy = groundAt(x, zz, 200, 220)
			if yy then
				local h = rng:NextNumber(4, 12)
				part({ Name = "BasaltColumn", Size = V3(2.2, h, 2.2), CFrame = CFrame.new(x, yy + h / 2 - 1, zz) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = rgb(35, 30, 32), Material = M.Basalt })
			end
		end
	end
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(50, 110)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy = groundAt(x, zz, 200, 220)
		if yy then
			local b = V3(x, yy - 0.5, zz)
			part({ Name = "DeadTree", Size = V3(1.2, 9, 1.2), CFrame = CFrame.new(b + V3(0, 4.5, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color = rgb(30, 22, 20), Material = M.Wood })
			part({ Size = V3(0.6, 5, 0.6), CFrame = CFrame.new(b + V3(0, 7, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.9) * CFrame.new(0, 2, 0), Color = rgb(30, 22, 20), Material = M.Wood })
		end
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 34)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy = groundAt(x, zz, 200, 220)
		if yy then crystalCluster(CFrame.new(x, yy, zz), 1.3, rgb(40, 15, 60), M.Glass, nil, false) end
	end

	-- mining camp outside the gate
	local camp = C - dir * 132
	local campCf = faceTo(V3(camp.X, 10, camp.Z), C)
	tent(campCf * CFrame.new(-10, 0, 0), rgb(200, 120, 60))
	tent(campCf * CFrame.new(10, 0, -2), rgb(160, 60, 50))
	campfire((campCf * CFrame.new(0, 0, 4)).Position)
	crate((campCf * CFrame.new(-4, 0, -6)).Position, 3)
	barrel((campCf * CFrame.new(4, 0, -7)).Position)
	bigSign(V3(camp.X, 26, camp.Z) + dir * 6, V3(0, 26, 0), "🌋 LAVA VOLCANO", rgb(255, 150, 60))

	gateRing(C, 118, 60, 4, i, rgb(255, 90, 30))
	gateSign(C - dir * 120 + V3(0, 14, 0), i)
	sellPad(C - dir * 108 + side * 14, C)
	sellPad(camp + side * 16, C)
	local sp = C - dir * 112
	spawnMarker(i, V3(sp.X, groundAt(sp.X, sp.Z) or 12, sp.Z))
	yield()
end

---------------------------------------------------------------- Zone 5: Frozen Peaks
local function buildFrozen(i)
	local z = Config.Zones[i]
	local C = z.Center
	local dir = flatDir(C)
	local side = dir:Cross(UP)

	T:FillCylinder(CFrame.new(C.X, 8, C.Z), 6, 110, M.Snow)
	local peaks = {
		{ C + dir * 55, 44 }, { C + dir * 30 + side * 58, 34 }, { C + dir * 25 - side * 60, 36 },
		{ C + dir * 85 + side * 25, 26 }, { C + dir * 80 - side * 30, 28 },
	}
	for _, pk in ipairs(peaks) do
		local p, r = pk[1], pk[2]
		T:FillBall(V3(p.X, 10 - r * 0.35, p.Z), r, M.Snow)
		T:FillBall(V3(p.X, 10 + r * 0.55, p.Z), r * 0.6, M.Snow)
		T:FillBall(V3(p.X, 10 + r * 0.95, p.Z), r * 0.3, M.Glacier)
	end
	-- ice cave through the main peak
	local mainPk = peaks[1][1]
	T:FillBlock(CFrame.lookAt(V3(mainPk.X, 18, mainPk.Z), V3(mainPk.X, 18, mainPk.Z) + side), V3(14, 14, 100), M.Air)
	T:FillBlock(CFrame.lookAt(V3(mainPk.X, 9, mainPk.Z), V3(mainPk.X, 9, mainPk.Z) + side), V3(12, 4, 100), M.Glacier)
	-- frozen lake
	local lake = C - side * 30 - dir * 18
	T:FillCylinder(CFrame.new(lake.X, 9, lake.Z), 4, 22, M.Glacier)
	yield()

	-- ice cave crystals & icicles
	for k = -4, 4 do
		local p = V3(mainPk.X, 25, mainPk.Z) + side * (k * 10)
		local r = rayTerrain(V3(p.X, 14, p.Z), V3(0, 30, 0))
		if r then
			for _ = 1, 3 do
				local off = V3(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
				local len = rng:NextNumber(2, 5)
				part({ Name = "Icicle", Size = V3(0.8, len, 0.8), Position = r.Position + off - V3(0, len / 2, 0), Color = rgb(190, 235, 255), Material = M.Ice, CanCollide = false })
			end
		end
		if k % 2 == 0 then
			local wp = V3(mainPk.X, 11, mainPk.Z) + side * (k * 10) + dir * 5.5
			crystalCluster(CFrame.new(wp), 0.7, rgb(120, 220, 255), M.Neon, nil, true)
		end
	end

	-- pines, ice spikes, igloos, snowmen
	for _ = 1, 34 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 105)
		local p = C + V3(math.sin(a) * r, 0, math.cos(a) * r)
		if (p - lake).Magnitude > 26 and not nearPath(p, 8) then pine(p.X, p.Z, rng:NextNumber(0.9, 1.5), true) end
	end
	for _ = 1, 18 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 100)
		local x, zz = C.X + math.sin(a) * r, C.Z + math.cos(a) * r
		local yy = groundAt(x, zz, 200, 220)
		if yy then
			local h = rng:NextNumber(6, 16)
			part({ Name = "IceSpike", Size = V3(2, h, 2), CFrame = CFrame.new(x, yy + h / 2 - 1, zz) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, math.rad(45), 0), Color = rgb(160, 220, 255), Material = M.Glass, Transparency = 0.2 })
		end
	end
	for _, off in ipairs({ side * 35 - dir * 50, -side * 50 - dir * 50 }) do
		local p = C + off
		local yy = groundAt(p.X, p.Z) or 11
		ball(V3(p.X, yy, p.Z), 12, rgb(245, 250, 255), M.Snow)
		local cf = faceTo(V3(p.X, yy, p.Z), C)
		part({ Size = V3(4, 4, 4), CFrame = cf * CFrame.new(0, 1.5, 6), Color = rgb(245, 250, 255), Material = M.Snow })
		part({ Size = V3(2.6, 3, 0.4), CFrame = cf * CFrame.new(0, 1.6, 8.1), Color = rgb(30, 40, 60), Material = M.SmoothPlastic, CanCollide = false })
	end
	for k = 1, 3 do
		local p = C - dir * 70 + side * ((k - 2) * 22)
		local yy = groundAt(p.X, p.Z) or 11
		ball(V3(p.X, yy + 1.6, p.Z), 4, rgb(250, 250, 255), M.Snow)
		ball(V3(p.X, yy + 4.6, p.Z), 3, rgb(250, 250, 255), M.Snow)
		ball(V3(p.X, yy + 6.8, p.Z), 2.2, rgb(250, 250, 255), M.Snow)
		local cf = faceTo(V3(p.X, yy + 6.8, p.Z), V3(0, 0, 0))
		part({ Size = V3(0.3, 0.3, 1.2), CFrame = cf * CFrame.new(0, 0, 1.4), Color = rgb(255, 140, 30), CanCollide = false })
	end
	-- aurora ribbons
	local auroraColors = { rgb(80, 255, 170), rgb(120, 180, 255), rgb(200, 120, 255) }
	for k = 1, 3 do
		local prev
		for s = -6, 6 do
			local p = C + dir * (40 + k * 20) + side * (s * 18) + V3(0, 130 + k * 12 + math.sin(s * 0.8 + k) * 8, 0)
			if prev then
				local seg = beam(prev, p, 0.4, 16, auroraColors[k], M.Neon, nil, false)
				seg.Transparency = 0.55
				seg.CastShadow = false
				seg.CanQuery = false
			end
			prev = p
		end
	end

	local entry = C - dir * 116
	bigSign(V3(entry.X, 28, entry.Z) - dir * 4, V3(0, 28, 0), "❄ FROZEN PEAKS", rgb(170, 230, 255))
	gateRing(C, 112, 60, 4, i, rgb(120, 200, 255))
	gateSign(C - dir * 114 + V3(0, 16, 0), i)
	sellPad(C - dir * 96 + side * 14, C)
	local sp = C - dir * 100
	spawnMarker(i, V3(sp.X, groundAt(sp.X, sp.Z) or 12, sp.Z))
	yield()
end

---------------------------------------------------------------- Zone 6: The Void (floating islands)
local function buildVoid(i)
	for _, isl in ipairs(Config.VoidIslands) do
		local top = isl.Y
		T:FillBall(V3(isl.X, top - isl.R * 0.45, isl.Z), isl.R * 1.05, M.Salt)
		T:FillBall(V3(isl.X, top - isl.R * 1.0, isl.Z), isl.R * 0.62, M.Basalt)
		T:FillBall(V3(isl.X, top - isl.R * 1.55, isl.Z), isl.R * 0.3, M.Basalt)
		T:FillBlock(CFrame.new(isl.X, top + 30, isl.Z), V3(isl.R * 3, 60, isl.R * 3), M.Air)
		-- dangling crystals under the island
		crystalCluster(CFrame.new(isl.X, top - isl.R * 1.5, isl.Z) * CFrame.Angles(math.pi, 0, 0), 1.6, rgb(150, 50, 255), M.Neon, nil, true)
		-- obelisks on top
		for k = 1, 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = isl.R * 0.7
			local x, zz = isl.X + math.sin(a) * r, isl.Z + math.cos(a) * r
			local yy = groundAt(x, zz, top + 20, 40) or top
			part({ Name = "Obelisk", Size = V3(2.4, 12, 2.4), CFrame = CFrame.new(x, yy + 5.5, zz) * CFrame.Angles(0, a, 0), Color = rgb(20, 10, 30), Material = M.Glass })
			local rune = part({ Size = V3(2.5, 1, 2.5), CFrame = CFrame.new(x, yy + 9, zz) * CFrame.Angles(0, a, 0), Color = rgb(180, 80, 255), Material = M.Neon, CanCollide = false })
			light(rune, rgb(180, 80, 255), 16, 1.5)
		end
	end
	yield()
	local center = Config.VoidIslands[1]
	local cpos = V3(center.X, center.Y, center.Z)
	local function bridge(a, b)
		local deck = beam(a, b, 8, 1, rgb(30, 15, 50), M.Glass, F.Platforms)
		deck.Name = "VoidBridge"
		local d = (b - a).Unit
		local s = d:Cross(UP).Unit
		for _, k in ipairs({ -1, 1 }) do
			local rail = beam(a + s * k * 3.8 + V3(0, 2, 0), b + s * k * 3.8 + V3(0, 2, 0), 0.4, 0.4, rgb(190, 90, 255), M.Neon, nil, true)
			rail.CastShadow = false
		end
	end
	for k = 2, #Config.VoidIslands do
		local o = Config.VoidIslands[k]
		local opos = V3(o.X, o.Y, o.Z)
		local d = V3(opos.X - cpos.X, 0, opos.Z - cpos.Z).Unit
		bridge(cpos + d * (center.R * 0.85) + V3(0, -0.4, 0), opos - d * (o.R * 0.8) + V3(0, -0.4, 0))
		local n = Config.VoidIslands[(k - 1) % (#Config.VoidIslands - 1) + 2]
		local npos = V3(n.X, n.Y, n.Z)
		local d2 = V3(npos.X - opos.X, 0, npos.Z - opos.Z).Unit
		bridge(opos + d2 * (o.R * 0.8) + V3(0, -0.4, 0), npos - d2 * (n.R * 0.8) + V3(0, -0.4, 0))
	end
	-- floating rings
	for k = 1, 4 do
		local ring = Instance.new("Model")
		ring.Name = "VoidRing"
		local rc = CFrame.new(math.sin(k * 1.6) * 60, 335 + k * 6, math.cos(k * 1.6) * 60)
		local hubP = part({ Name = "Hub", Size = V3(1, 1, 1), CFrame = rc, Transparency = 1, CanCollide = false, CanQuery = false }, ring)
		for s = 1, 16 do
			local a = s / 16 * math.pi * 2
			part({ Size = V3(3.2, 0.8, 0.8), CFrame = rc * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 8), Color = rgb(200, 120, 255), Material = M.Neon, CanCollide = false }, ring)
		end
		ring.PrimaryPart = hubP
		ring:SetAttribute("SpinX", 0.5 + k * 0.1)
		ring:SetAttribute("SpinY", 0.3)
		ring.Parent = F.Spin
	end
	-- black hole in the sky
	local hole = ball(V3(0, 420, -260), 60, rgb(0, 0, 0), M.SmoothPlastic, nil, false)
	hole.CastShadow = false
	local halo = part({ Shape = Enum.PartType.Cylinder, Size = V3(1, 130, 130), CFrame = CFrame.new(0, 420, -260) * CFrame.Angles(0.3, 0, math.rad(90)), Color = rgb(170, 80, 255), Material = M.Neon, Transparency = 0.6, CanCollide = false, CastShadow = false })
	spinner(halo, 0.2, 0, 0)

	-- portal home + sell pad + spawn
	local pc = faceTo(cpos + V3(0, 9, -16), cpos)
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		part({ Size = V3(1.8, 1.8, 1.8), CFrame = pc * CFrame.new(math.cos(a) * 6, math.sin(a) * 6, 0) * CFrame.Angles(0, 0, a), Color = rgb(255, 210, 90), Material = M.Neon })
	end
	local disc = part({ Name = "PortalHome", Shape = Enum.PartType.Cylinder, Size = V3(0.4, 11, 11), CFrame = pc * CFrame.Angles(0, math.rad(90), 0), Color = rgb(255, 220, 120), Material = M.Glass, Transparency = 0.3, CanCollide = false })
	light(disc, rgb(255, 220, 120), 24, 2)
	prompt(disc, "Portal", "Go Home", "Portal to Miner's Town", 0)
	sellPad(cpos + V3(14, 2, 6), cpos)
	spawnMarker(i, cpos + V3(0, 1, 14))
	local title = part({ Size = V3(1, 1, 1), Position = cpos + V3(0, 26, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	billboard(title, "🌌 THE VOID", V3(0, 0, 0), 400, 80, 250, rgb(210, 150, 255))
	yield()
end

---------------------------------------------------------------- paths & wilderness
local pathTargets

local function computePaths()
	pathTargets = {}
	local Z = Config.Zones
	local function add(c, back, name, color)
		local d = flatDir(c)
		local target = V3(c.X, 10, c.Z) - d * back
		table.insert(pathTargets, { From = d * 66, To = target, Name = name, Color = color })
	end
	add(Z[1].Center, 60, "🌼 Sunny Meadow", rgb(150, 255, 120))
	add(Z[2].Center, 100, "🪨 Dark Caves", rgb(255, 190, 120))
	add(Z[3].Center, 175, "💎 Crystal Grotto", rgb(220, 170, 255))
	add(Z[4].Center, 132, "🌋 Lava Volcano", rgb(255, 150, 60))
	add(Z[5].Center, 118, "❄ Frozen Peaks", rgb(170, 230, 255))
	table.insert(pathTargets, { From = V3(0, 0, -66), To = V3(0, 10, -112), Name = "⚔ Golem Arena", Color = rgb(255, 120, 80) })
	for _, p in ipairs(pathTargets) do
		path(p.From, p.To, 11, false)
	end
end

local function decoratePaths()
	for _, p in ipairs(pathTargets) do
		local A = V3(p.From.X, 8, p.From.Z)
		local B = V3(p.To.X, 8, p.To.Z)
		local dir = (B - A).Unit
		local side = dir:Cross(UP)
		local len = (B - A).Magnitude
		for k = 1, math.floor(len / 30) do
			local q = A + dir * (k * 30) + side * 8 * ((k % 2 == 0) and 1 or -1)
			lamp(q.X, q.Z)
		end
		local sp = A + dir * 6 + side * 8
		signpost(V3(sp.X, groundAt(sp.X, sp.Z) or 10, sp.Z), sp - dir * 10, p.Name, p.Color)
	end
end

local function insideAnyZone(p, margin)
	for i, z in ipairs(Config.Zones) do
		if i ~= 6 then
			local r = z.Kind == "Grotto" and 62 or z.Radius
			if V3(p.X - z.Center.X, 0, p.Z - z.Center.Z).Magnitude < r + margin then return true end
		end
	end
	if V3(p.X - Config.ArenaCenter.X, 0, p.Z - Config.ArenaCenter.Z).Magnitude < 48 then return true end
	return V3(p.X, 0, p.Z).Magnitude < 76
end

local function buildWilderness()
	-- gentle hills between zones
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(90, 430)
		local p = V3(math.sin(a) * r, 0, math.cos(a) * r)
		local rad = rng:NextNumber(12, 24)
		if not insideAnyZone(p, rad + 6) and not nearPath(p, rad + 6) then
			T:FillBall(V3(p.X, 10 - rad * rng:NextNumber(0.45, 0.7), p.Z), rad, M.Grass)
		end
	end
	-- two small lakes
	for _ = 1, 2 do
		for _ = 1, 20 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(120, 400)
			local p = V3(math.sin(a) * r, 0, math.cos(a) * r)
			if not insideAnyZone(p, 30) and not nearPath(p, 25) then
				T:FillCylinder(CFrame.new(p.X, 8, p.Z), 4, 19, M.Sand)
				T:FillCylinder(CFrame.new(p.X, 8, p.Z), 8, 16, M.Air)
				T:FillCylinder(CFrame.new(p.X, 6, p.Z), 4, 16, M.Water)
				break
			end
		end
	end
	yield()
	local placed = 0
	for _ = 1, 600 do
		if placed > 170 then break end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(78, 445)
		local p = V3(math.sin(a) * r, 0, math.cos(a) * r)
		if not insideAnyZone(p, 8) and not nearPath(p, 9) then
			local _, mat = groundAt(p.X, p.Z)
			if mat == M.Grass then
				local roll = rng:NextNumber()
				if roll < 0.55 then
					tree(p.X, p.Z, rng:NextNumber(0.8, 1.5))
				elseif roll < 0.75 then
					pine(p.X, p.Z, rng:NextNumber(0.9, 1.4), false)
				elseif roll < 0.9 then
					rock(p.X, p.Z, rng:NextNumber(2, 6))
				else
					local yy = groundAt(p.X, p.Z)
					if yy then ball(V3(p.X, yy + 0.8, p.Z), rng:NextNumber(3, 5), rgb(70, 140, 55), M.Grass, nil, false) end
				end
				placed += 1
			end
		end
	end
	-- invisible world border
	for k = 1, 40 do
		local a = k / 40 * math.pi * 2
		part({ Name = "Border", Size = V3(80, 600, 4), CFrame = CFrame.new(math.sin(a) * 500, 200, math.cos(a) * 500) * CFrame.Angles(0, a, 0), Transparency = 1, CanQuery = false })
	end
	yield()
end

---------------------------------------------------------------- entry point
function WorldBuilder.Build(force)
	local existing = workspace:FindFirstChild("World")
	if existing and existing:GetAttribute("Built") and not force then
		return existing
	end
	if existing then existing:Destroy() end
	pathSegments = {}
	World = Instance.new("Folder")
	World.Name = "World"
	F = {}
	for _, n in ipairs({ "Decor", "Town", "Platforms", "Gates", "SellPads", "Spawns", "Lava", "Leaderboards", "Spin", "Markers" }) do
		F[n] = folder(n, World)
	end
	World.Parent = workspace

	setupLighting()
	setupTerrainLook()
	buildBase()
	buildHub()
	computePaths()
	buildArena()
	buildMeadow(1)
	buildCaves(2)
	buildGrotto(3)
	buildVolcano(4)
	buildFrozen(5)
	buildVoid(6)
	decoratePaths()
	buildWilderness()

	World:SetAttribute("Built", true)
	return World
end

return WorldBuilder
