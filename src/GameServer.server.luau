-- Mine Rush Simulator : GameServer
-- Server-authoritative gameplay: data, ores, mining, selling, shop, quests,
-- pets/eggs, world boss, events, codes, game passes, leaderboards.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DSS = game:GetService("DataStoreService")
local MPS = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local ModelLibrary = require(RS:WaitForChild("ModelLibrary"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local World = WorldBuilder.Build(false)

local V3 = Vector3.new
local rgb = Color3.fromRGB
local rng = Random.new()

---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local MineRemote = remote("Mine")
local ActionRemote = remote("Action")
local SyncRemote = remote("Sync")
local NotifyRemote = remote("Notify")
local HitFxRemote = remote("HitFx")
local OpenUIRemote = remote("OpenUI")
local HatchRemote = remote("Hatch")
local BossRemote = remote("Boss")
Remotes.Parent = RS

---------------------------------------------------------------- data
local store
do
	local ok, s = pcall(function() return DSS:GetDataStore(Config.DataStoreName) end)
	if ok then store = s end
end
local topEarned, topRebirths
pcall(function()
	topEarned = DSS:GetOrderedDataStore(Config.DataStoreName .. "_TopEarned")
	topRebirths = DSS:GetOrderedDataStore(Config.DataStoreName .. "_TopRebirths")
end)

local function defaultData()
	return {
		Coins = 0, Rebirths = 0, Tool = 1, Backpack = 1, Bag = 0, BagValue = 0,
		QuestIndex = 1, QuestProgress = 0, TotalMined = 0, TotalEarned = 0,
		LastDaily = 0, Streak = 0, Pets = {}, NextPetId = 1, Codes = {},
		TotalHatched = 0, BossKills = 0, ShinyFound = 0, AutoMine = false,
	}
end

local Data = {}       -- [player] = table
local NoSave = {}     -- [player] = true if load failed (protects saves)
local Owns = {}       -- [player] = { PassName = true }
local lastHit = {}
local lastSell = {}

local function notify(player, text, kind)
	NotifyRemote:FireClient(player, text, kind or "info")
end
local function notifyAll(text, kind)
	NotifyRemote:FireAllClients(text, kind or "info")
end

local function hasPass(player, name)
	return Owns[player] ~= nil and Owns[player][name] == true
end

---------------------------------------------------------------- pets
local function slots(player)
	return Config.EquipSlots + (hasPass(player, "VIP") and Config.VIPExtraSlots or 0)
end

local function equippedPets(player, data)
	local list = {}
	for _, p in ipairs(data.Pets) do
		if Config.PetByName[p.Name] then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return Config.PetByName[a.Name].Bonus > Config.PetByName[b.Name].Bonus end)
	local out = {}
	for k = 1, math.min(slots(player), #list) do out[k] = list[k] end
	return out
end

local function petBonus(player, data)
	local b = 0
	for _, p in ipairs(equippedPets(player, data)) do b += Config.PetByName[p.Name].Bonus end
	return b
end

local function updatePetAttr(player, data)
	local names = {}
	for _, p in ipairs(equippedPets(player, data)) do table.insert(names, p.Name) end
	player:SetAttribute("Pets", HttpService:JSONEncode(names))
end

---------------------------------------------------------------- world events
local currentEvent, eventEnds = nil, 0

local function multiplier(player, data)
	local m = 1 + data.Rebirths * Config.RebirthBonus
	m *= 1 + petBonus(player, data)
	if hasPass(player, "DoubleCoins") then m *= 2 end
	if hasPass(player, "VIP") then m *= 1.25 end
	if currentEvent == "OreRush" then m *= 2 end
	return m
end

---------------------------------------------------------------- quests
local function currentQuest(data)
	local q = Config.Quests[data.QuestIndex]
	if q then return q end
	local n = data.QuestIndex - #Config.Quests
	local power = Config.Tools[data.Tool].Power
	return { Type = "mine", Amount = 100 + n * 25, Reward = math.floor(power * 1500 * (1 + n * 0.2)), Text = "Endless: mine " .. (100 + n * 25) .. " ores" }
end

local function refreshLevelQuest(data)
	local q = currentQuest(data)
	if q.Type == "tool" then data.QuestProgress = data.Tool
	elseif q.Type == "backpack" then data.QuestProgress = data.Backpack
	elseif q.Type == "rebirth" then data.QuestProgress = data.Rebirths end
end

local function questProgress(data, qtype, target, amount)
	local q = currentQuest(data)
	if q.Type ~= qtype then return end
	if qtype == "mine" and q.Target and q.Target ~= target then return end
	if qtype == "tool" or qtype == "backpack" or qtype == "rebirth" then
		refreshLevelQuest(data)
	else
		data.QuestProgress += amount or 1
	end
end

---------------------------------------------------------------- sync
local function sync(player)
	local data = Data[player]
	if not data then return end
	local q = currentQuest(data)
	local ids = {}
	for _, p in ipairs(equippedPets(player, data)) do ids[p.Id] = true end
	local passes = {}
	for name in pairs(Config.GamePasses) do passes[name] = hasPass(player, name) end
	SyncRemote:FireClient(player, {
		Coins = data.Coins, Rebirths = data.Rebirths, Tool = data.Tool, Backpack = data.Backpack,
		Bag = data.Bag, BagValue = data.BagValue, Capacity = Config.Backpacks[data.Backpack].Capacity,
		QuestIndex = data.QuestIndex, QuestProgress = data.QuestProgress,
		Quest = { Text = q.Text, Amount = q.Amount, Reward = q.Reward, Type = q.Type },
		Mult = multiplier(player, data), PetBonus = petBonus(player, data),
		Event = currentEvent, EventLeft = math.max(0, eventEnds - os.time()),
		RebirthCost = math.floor(Config.RebirthCost(data.Rebirths)),
		DailyIn = math.max(0, data.LastDaily + Config.DailyCooldown - os.time()), Streak = data.Streak,
		Pets = data.Pets, Equipped = ids, Slots = slots(player), Passes = passes,
		AutoMine = data.AutoMine, TotalMined = data.TotalMined, TotalHatched = data.TotalHatched,
		IsStudio = RunService:IsStudio(),
	})
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = math.floor(data.Coins)
		ls.Rebirths.Value = data.Rebirths
	end
	player:SetAttribute("Tool", data.Tool)
	player:SetAttribute("Rebirths", data.Rebirths)
end

local function syncAll()
	for p in pairs(Data) do sync(p) end
end

---------------------------------------------------------------- physical tools
local function makeTool(level)
	return ModelLibrary.BuildTool(level, Config)
end

local function giveTool(player)
	local data = Data[player]
	if not data then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	for _, c in ipairs({ backpack, char }) do
		if c then
			for _, t in ipairs(c:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("MineTool") then t:Destroy() end
			end
		end
	end
	if not backpack then return end
	local tool = makeTool(data.Tool)
	tool.Parent = backpack
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum:EquipTool(tool) end
end

local function overheadTag(player, char)
	local head = char:WaitForChild("Head", 10)
	if not head then return end
	local old = head:FindFirstChild("MinerTag")
	if old then old:Destroy() end
	local gui = Instance.new("BillboardGui")
	gui.Name = "MinerTag"
	gui.Size = UDim2.new(0, 200, 0, 26)
	gui.StudsOffset = V3(0, 2.6, 0)
	gui.MaxDistance = 60
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextStrokeTransparency = 0.2
	l.TextColor3 = rgb(255, 220, 120)
	local data = Data[player]
	local reb = data and data.Rebirths or 0
	l.Text = (hasPass(player, "VIP") and "👑 VIP  " or "") .. (reb > 0 and ("🌟" .. reb) or "")
	l.Parent = gui
	gui.Parent = head
end

---------------------------------------------------------------- ores
local OresFolder = Instance.new("Folder")
OresFolder.Name = "Ores"
OresFolder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain, World:WaitForChild("Platforms") }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { OresFolder }

local badMaterials = { [Enum.Material.Water] = true, [Enum.Material.CrackedLava] = true }

local function pickOre(zone)
	local total = 0
	for _, o in ipairs(zone.Ores) do total += o.Weight end
	local r = rng:NextNumber(0, total)
	for _, o in ipairs(zone.Ores) do
		r -= o.Weight
		if r <= 0 then return o end
	end
	return zone.Ores[1]
end

local function findSpot(zone)
	local sp = zone.Spawn
	for _ = 1, 20 do
		local origin
		if sp.Islands then
			local isl = sp.Islands[rng:NextInteger(1, #sp.Islands)]
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * isl.R * 0.8
			origin = V3(isl.X + math.sin(a) * r, sp.StartY, isl.Z + math.cos(a) * r)
		else
			local a = rng:NextNumber(0, math.pi * 2)
			local r = sp.MinR + math.sqrt(rng:NextNumber()) * (sp.MaxR - sp.MinR)
			origin = V3(zone.Center.X + math.sin(a) * r, sp.StartY, zone.Center.Z + math.cos(a) * r)
		end
		local res = workspace:Raycast(origin, V3(0, -(sp.StartY - sp.MinY) - 6, 0), rayParams)
		if res and not badMaterials[res.Material] and res.Position.Y >= sp.MinY and res.Position.Y <= sp.MaxY and res.Normal.Y > 0.45 then
			if #workspace:GetPartBoundsInRadius(res.Position, 6, overlap) == 0 then
				return res.Position, res.Normal
			end
		end
	end
	return nil
end

local function oreBillboard(core, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(0, 120, 0, 34)
	gui.StudsOffsetWorldSpace = V3(0, core.Size.Y + 2, 0)
	gui.MaxDistance = 40
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local name = Instance.new("TextLabel")
	name.Name = "OreName"
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = color
	name.TextStrokeTransparency = 0.2
	name.Text = text
	name.Parent = gui
	local bg = Instance.new("Frame")
	bg.Name = "Bar"
	bg.Position = UDim2.new(0.1, 0, 0.65, 0)
	bg.Size = UDim2.new(0.8, 0, 0.25, 0)
	bg.BackgroundColor3 = rgb(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = rgb(90, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local c2 = c:Clone()
	c2.Parent = fill
	gui.Parent = core
end

local spawnOre

local function buildOre(zoneIndex, def, shiny, pos, normal)
	local zone = Config.Zones[zoneIndex]
	local s = def.Size
	local up = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local m = Instance.new("Model")
	m.Name = def.Name
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.Size = V3(s, s * 0.6, s * 0.9)
	core.CFrame = up * CFrame.new(0, s * 0.2, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
	core.Color = zone.RockColor
	core.Material = Enum.Material.Rock
	core.Parent = m
	local chunkColor = shiny and def.Color:Lerp(Color3.new(1, 1, 1), 0.35) or def.Color
	local n = rng:NextInteger(4, 6)
	for k = 1, n do
		local c = Instance.new("Part")
		c.Name = "Chunk"
		c.Anchored = true
		c.CanCollide = false
		c.Color = chunkColor
		c.Material = def.Material
		local a = k / n * math.pi * 2
		if def.Style == "Crystal" then
			local h = s * rng:NextNumber(0.6, 1.1)
			c.Size = V3(s * 0.25, h, s * 0.25)
			c.CFrame = core.CFrame * CFrame.new(math.cos(a) * s * 0.22, s * 0.25, math.sin(a) * s * 0.22) * CFrame.Angles(math.sin(a) * 0.5, 0, math.cos(a) * 0.5) * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0)
		else
			local cs = s * rng:NextNumber(0.3, 0.45)
			c.Size = V3(cs, cs, cs)
			c.CFrame = core.CFrame * CFrame.new(math.cos(a) * s * 0.3, s * 0.3, math.sin(a) * s * 0.3) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3))
		end
		c.Parent = m
	end
	-- decorative detail: rubble around the base and small ore flecks in the rock
	local function deco(size, cf, color, mat, shape)
		local d = Instance.new("Part")
		d.Name = "Detail"
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		if shape then d.Shape = shape end
		d.Size = size
		d.CFrame = cf
		d.Color = color
		d.Material = mat
		d.Parent = m
	end
	for k = 1, rng:NextInteger(3, 5) do
		local a = rng:NextNumber(0, 6.28)
		local ps = s * rng:NextNumber(0.12, 0.22)
		deco(V3(ps, ps * 0.7, ps), up * CFrame.new(math.cos(a) * s * 0.65, ps * 0.2, math.sin(a) * s * 0.6) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), zone.RockColor:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)), Enum.Material.Rock)
	end
	for k = 1, 6 do
		local fs = s * 0.12
		local a = rng:NextNumber(0, 6.28)
		deco(V3(fs, fs, fs), core.CFrame * CFrame.new(math.cos(a) * s * 0.48, rng:NextNumber(-0.15, 0.2) * s, math.sin(a) * s * 0.42) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), chunkColor, def.Glow and Enum.Material.Neon or def.Material)
	end
	if def.Style == "Crystal" then
		deco(V3(0.3, s * 0.95, s * 0.95), core.CFrame * CFrame.new(0, -s * 0.28, 0) * CFrame.Angles(0, 0, math.pi / 2), chunkColor:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.Glass, Enum.PartType.Cylinder)
	end
	if def.Glow or shiny then
		local l = Instance.new("PointLight")
		l.Color = def.Color
		l.Range = shiny and 14 or 9
		l.Brightness = shiny and 2.5 or 1.2
		l.Parent = core
	end
	if shiny then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 12
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(2, 4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Color = ColorSequence.new(rgb(255, 255, 200))
		e.Size = NumberSequence.new(0.5)
		e.Parent = core
	end
	m.PrimaryPart = core
	local hp = def.HP * (shiny and 2 or 1)
	m:SetAttribute("Zone", zoneIndex)
	m:SetAttribute("OreName", def.Name)
	m:SetAttribute("HP", hp)
	m:SetAttribute("MaxHP", hp)
	m:SetAttribute("Value", def.Value * (shiny and Config.ShinyMultiplier or 1))
	m:SetAttribute("Shiny", shiny)
	m:SetAttribute("Tier", zone.RequiredTier)
	oreBillboard(core, (shiny and "✨ Shiny " or "") .. def.Name, shiny and rgb(255, 250, 170) or def.Color:Lerp(Color3.new(1, 1, 1), 0.3))
	m.Parent = OresFolder
	return m
end

spawnOre = function(zoneIndex)
	local zone = Config.Zones[zoneIndex]
	local pos, normal = findSpot(zone)
	if not pos then
		task.delay(3, spawnOre, zoneIndex)
		return
	end
	local chance = Config.ShinyChance * (currentEvent == "ShinyStorm" and 5 or 1)
	buildOre(zoneIndex, pickOre(zone), rng:NextNumber() < chance, pos, normal)
end

task.spawn(function()
	for i, z in ipairs(Config.Zones) do
		for _ = 1, z.OreCount do spawnOre(i) end
		task.wait()
	end
end)

---------------------------------------------------------------- selling
local function sell(player)
	local data = Data[player]
	if not data or data.Bag <= 0 then return end
	if os.clock() - (lastSell[player] or 0) < 0.8 then return end
	lastSell[player] = os.clock()
	local earned = math.floor(data.BagValue * multiplier(player, data))
	data.Coins += earned
	data.TotalEarned += earned
	local count = data.Bag
	data.Bag, data.BagValue = 0, 0
	questProgress(data, "earn", nil, earned)
	notify(player, "💰 Sold " .. count .. " ores for " .. earned .. " coins!", "sell")
	sync(player)
end

for _, pad in ipairs(World.SellPads:GetChildren()) do
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then sell(player) end
	end)
end

---------------------------------------------------------------- teleport
local function teleport(player, zoneIndex)
	local data = Data[player]
	local char = player.Character
	if not data or not char then return end
	zoneIndex = tonumber(zoneIndex) or 0
	if zoneIndex > 0 then
		local z = Config.Zones[zoneIndex]
		if not z then return end
		if data.Tool < z.RequiredTier then
			notify(player, "🔒 " .. z.Name .. " needs the " .. Config.Tools[z.RequiredTier].Name, "error")
			return
		end
	end
	local marker = World.Spawns:FindFirstChild("Zone" .. zoneIndex)
	if marker then char:PivotTo(CFrame.new(marker.Position + V3(0, 3, 0))) end
end

for _, lava in ipairs(World.Lava:GetChildren()) do
	lava.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and os.clock() - (lastSell[player] or 0) > 0.5 then
			teleport(player, 4)
			notify(player, "🔥 Too hot! The lava pushed you back down.", "error")
		end
	end)
end

---------------------------------------------------------------- eggs
local function hatch(player, eggIndex, free)
	local data = Data[player]
	local egg = Config.Eggs[tonumber(eggIndex) or 0]
	if not data or not egg then return end
	if data.Tool < egg.RequiredTier then
		notify(player, "🔒 " .. egg.Name .. " needs the " .. Config.Tools[egg.RequiredTier].Name, "error")
		return
	end
	if #data.Pets >= Config.MaxPets then
		notify(player, "🐾 Pet inventory full! Delete some pets.", "error")
		return
	end
	if not free then
		if data.Coins < egg.Cost then
			notify(player, "Not enough coins for " .. egg.Name, "error")
			return
		end
		data.Coins -= egg.Cost
	end
	local luck = hasPass(player, "LuckyPets") and 2 or 1
	local total = 0
	local weights = {}
	for k, pet in ipairs(egg.Pets) do
		local w = pet.Chance * ((Config.Rarities[pet.Rarity].Order >= 3) and luck or 1)
		weights[k] = w
		total += w
	end
	local r = rng:NextNumber(0, total)
	local chosen = egg.Pets[1]
	for k, pet in ipairs(egg.Pets) do
		r -= weights[k]
		if r <= 0 then chosen = pet break end
	end
	table.insert(data.Pets, { Id = data.NextPetId, Name = chosen.Name })
	data.NextPetId += 1
	data.TotalHatched += 1
	questProgress(data, "hatch", nil, 1)
	updatePetAttr(player, data)
	HatchRemote:FireClient(player, eggIndex, chosen.Name)
	if Config.Rarities[chosen.Rarity].Order >= 5 then
		notifyAll("🎉 " .. player.DisplayName .. " hatched a " .. chosen.Rarity .. " " .. chosen.Name .. "!", "rare")
	end
	sync(player)
end

---------------------------------------------------------------- world boss
local boss = nil

local function buildGolem(pos)
	local m = Instance.new("Model")
	m.Name = Config.Boss.Name
	local base = CFrame.new(pos)
	local stone, moss, eye = rgb(115, 110, 105), rgb(80, 140, 60), rgb(255, 60, 40)
	local function p(size, off, color, mat, name)
		local x = Instance.new("Part")
		x.Name = name or "Rock"
		x.Anchored = true
		x.Size = size
		x.CFrame = base * off
		x.Color = color
		x.Material = mat or Enum.Material.Slate
		x.Parent = m
		return x
	end
	p(V3(4, 7, 4), CFrame.new(-3, 3.5, 0), stone)
	p(V3(4, 7, 4), CFrame.new(3, 3.5, 0), stone)
	local body = p(V3(12, 9, 7), CFrame.new(0, 11.5, 0), stone, nil, "Body")
	p(V3(12.4, 1.5, 7.4), CFrame.new(0, 16, 0), moss, Enum.Material.Grass)
	p(V3(4, 10, 4), CFrame.new(-8.5, 10, 0) * CFrame.Angles(0, 0, 0.15), stone, nil, "ArmL")
	p(V3(4, 10, 4), CFrame.new(8.5, 10, 0) * CFrame.Angles(0, 0, -0.15), stone, nil, "ArmR")
	p(V3(5, 4, 5), CFrame.new(-9.2, 4.5, 0), stone)
	p(V3(5, 4, 5), CFrame.new(9.2, 4.5, 0), stone)
	local head = p(V3(6, 5, 5), CFrame.new(0, 18.5, -0.5), stone, nil, "Head")
	for _, sx in ipairs({ -1.4, 1.4 }) do
		local e = p(V3(1.2, 0.8, 0.3), CFrame.new(sx, 19, -3.05), eye, Enum.Material.Neon, "Eye")
		local l = Instance.new("PointLight")
		l.Color = eye
		l.Range = 12
		l.Parent = e
	end
	for k = 1, 5 do
		p(V3(1.2, 3 + k % 3, 1.2), CFrame.new(-4 + k * 1.6, 15, 3.4) * CFrame.Angles(0.5, 0, 0), rgb(170, 90, 255), Enum.Material.Neon, "Crystal")
	end
	m.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 300, 0, 40)
	gui.StudsOffset = V3(0, 9, 0)
	gui.MaxDistance = 200
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = rgb(255, 120, 90)
	l.TextStrokeTransparency = 0
	l.Text = "⚔ " .. Config.Boss.Name .. " ⚔"
	l.Parent = gui
	gui.Parent = head
	m:SetAttribute("Boss", true)
	m.Parent = workspace
	return m
end

local function bestEgg(data)
	local best = 1
	for k, egg in ipairs(Config.Eggs) do
		if data.Tool >= egg.RequiredTier then best = k end
	end
	return best
end

local function endBoss(defeated)
	if not boss then return end
	local b = boss
	boss = nil
	if defeated then
		for player, dmg in pairs(b.Damage) do
			local data = Data[player]
			if data and player.Parent then
				local reward = math.floor((dmg * Config.Boss.CoinsPerDamage + 100 * 2 ^ (data.Tool - 1)) * multiplier(player, data))
				data.Coins += reward
				data.BossKills += 1
				questProgress(data, "boss", nil, 1)
				notify(player, "⚔ Golem defeated! You dealt " .. dmg .. " damage and earned " .. reward .. " coins!", "rare")
				if rng:NextNumber() < Config.Boss.FreeEggChance then
					hatch(player, bestEgg(data), true)
					notify(player, "🥚 Bonus: a free egg from the Golem!", "rare")
				end
				sync(player)
			end
		end
		BossRemote:FireAllClients("dead", b.Model:GetPivot().Position)
	else
		notifyAll("💨 The Golem got bored and left the Arena...", "info")
		BossRemote:FireAllClients("gone")
	end
	for _, part in ipairs(b.Model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
			part.AssemblyLinearVelocity = V3(rng:NextNumber(-30, 30), rng:NextNumber(20, 50), rng:NextNumber(-30, 30))
		end
	end
	task.delay(4, function() b.Model:Destroy() end)
end

local function spawnBoss()
	if boss then return end
	local marker = World.Markers:FindFirstChild("BossSpawn")
	if not marker then return end
	local totalPower = 0
	for _, d in pairs(Data) do totalPower += Config.Tools[d.Tool].Power end
	local maxHP = math.floor(Config.Boss.BaseHP + totalPower * Config.Boss.HPPerPower)
	local model = buildGolem(marker.Position)
	boss = { Model = model, HP = maxHP, Max = maxHP, Damage = {}, Ends = os.clock() + Config.Boss.Lifetime, Pos = marker.Position, LastBroadcast = 0 }
	BossRemote:FireAllClients("spawn", maxHP, maxHP, marker.Position)
	notifyAll("⚔ The " .. Config.Boss.Name .. " has appeared in the Arena! Team up to defeat it!", "rare")
end

local function hitBoss(player, data, root)
	if (root.Position - boss.Model:GetPivot().Position).Magnitude > 30 then return end
	local tool = Config.Tools[data.Tool]
	local crit = rng:NextNumber() < Config.CritChance
	local dmg = tool.Power * (crit and Config.CritMultiplier or 1)
	boss.HP -= dmg
	boss.Damage[player] = (boss.Damage[player] or 0) + dmg
	HitFxRemote:FireClient(player, boss.Model:GetPivot().Position + V3(0, 8, 0), dmg, crit, false, nil)
	if os.clock() - boss.LastBroadcast > 0.15 or boss.HP <= 0 then
		boss.LastBroadcast = os.clock()
		BossRemote:FireAllClients("hp", math.max(0, boss.HP), boss.Max)
	end
	if boss.HP <= 0 then endBoss(true) end
end

task.spawn(function()
	task.wait(Config.Boss.FirstSpawn)
	while true do
		spawnBoss()
		local nextSlam = os.clock() + 7
		while boss do
			task.wait(0.1)
			if not boss then break end
			if os.clock() > boss.Ends then endBoss(false) break end
			-- face the nearest player
			local nearest, nd = nil, 120
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r then
					local d = (r.Position - boss.Pos).Magnitude
					if d < nd then nearest, nd = r, d end
				end
			end
			if nearest then
				local target = V3(nearest.Position.X, boss.Pos.Y, nearest.Position.Z)
				if (target - boss.Pos).Magnitude > 1 then
					local cur = boss.Model:GetPivot()
					local want = CFrame.lookAt(cur.Position, V3(target.X, cur.Position.Y, target.Z))
					boss.Model:PivotTo(cur:Lerp(want, 0.15))
				end
			end
			if os.clock() > nextSlam then
				nextSlam = os.clock() + 7
				BossRemote:FireAllClients("slam", boss.Pos)
			end
		end
		task.wait(Config.Boss.Interval)
	end
end)

---------------------------------------------------------------- mining
MineRemote.OnServerEvent:Connect(function(player, target)
	local data = Data[player]
	if not data or typeof(target) ~= "Instance" then return end
	local tool = Config.Tools[data.Tool]
	local now = os.clock()
	if now - (lastHit[player] or 0) < tool.Cooldown * 0.85 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local held = char:FindFirstChildOfClass("Tool")
	if not held or not held:GetAttribute("MineTool") then return end
	lastHit[player] = now

	if boss and target == boss.Model then
		hitBoss(player, data, root)
		return
	end
	if target.Parent ~= OresFolder or not target:IsA("Model") or not target.PrimaryPart then return end
	local core = target.PrimaryPart
	if (core.Position - root.Position).Magnitude > Config.MineRange + core.Size.X then return end
	local tier = target:GetAttribute("Tier") or 1
	if data.Tool < tier then
		notify(player, "🔒 You need the " .. Config.Tools[tier].Name .. " for this ore", "error")
		return
	end
	local capacity = Config.Backpacks[data.Backpack].Capacity
	if data.Bag >= capacity then
		notify(player, "🎒 Backpack full! Go to a 💰 SELL pad", "full")
		return
	end
	local crit = rng:NextNumber() < Config.CritChance
	local dmg = tool.Power * (crit and Config.CritMultiplier or 1)
	local hp = target:GetAttribute("HP") - dmg
	local maxHp = target:GetAttribute("MaxHP")
	local info = core:FindFirstChild("Info")
	if hp > 0 then
		target:SetAttribute("HP", hp)
		if info then
			local ratio = hp / maxHp
			info.Bar.Fill.Size = UDim2.fromScale(ratio, 1)
			info.Bar.Fill.BackgroundColor3 = rgb(255, 80, 60):Lerp(rgb(90, 230, 90), ratio)
		end
		HitFxRemote:FireClient(player, core.Position + V3(0, core.Size.Y, 0), dmg, crit, false, core.Color)
		return
	end

	-- ore broken
	local zoneIndex = target:GetAttribute("Zone")
	local oreName = target:GetAttribute("OreName")
	local shiny = target:GetAttribute("Shiny")
	local chunk = target:FindFirstChild("Chunk")
	local color = chunk and chunk.Color or core.Color
	data.Bag += 1
	data.BagValue += target:GetAttribute("Value")
	data.TotalMined += 1
	questProgress(data, "mine", oreName, 1)
	if shiny then
		data.ShinyFound += 1
		questProgress(data, "shiny", nil, 1)
		notifyAll("✨ " .. player.DisplayName .. " found a Shiny " .. oreName .. "!", "rare")
	end
	HitFxRemote:FireClient(player, core.Position + V3(0, core.Size.Y, 0), dmg, crit, true, color)
	target:Destroy()
	task.delay(Config.RespawnTime, spawnOre, zoneIndex)
	if data.Bag >= capacity then notify(player, "🎒 Backpack full! Go to a 💰 SELL pad", "full") end
	sync(player)
end)

---------------------------------------------------------------- actions
local function claimDaily(player, data)
	local now = os.time()
	if now < data.LastDaily + Config.DailyCooldown then
		notify(player, "🎁 Daily reward not ready yet", "error")
		return
	end
	if now - data.LastDaily <= Config.DailyStreakWindow then
		data.Streak = math.min(data.Streak + 1, 7)
	else
		data.Streak = 1
	end
	data.LastDaily = now
	local reward = math.floor((200 + 80 * 2 ^ (data.Tool - 1)) * data.Streak)
	data.Coins += reward
	notify(player, "🎁 Day " .. data.Streak .. " streak! +" .. reward .. " coins", "rare")
end

local function rebirth(player, data)
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Coins < cost then
		notify(player, "Need " .. math.floor(cost) .. " coins to rebirth", "error")
		return
	end
	data.Rebirths += 1
	data.Coins = 0
	data.Tool = 1
	data.Backpack = 1
	data.Bag, data.BagValue = 0, 0
	questProgress(data, "rebirth")
	giveTool(player)
	teleport(player, 0)
	if player.Character then overheadTag(player, player.Character) end
	notifyAll("🌟 " .. player.DisplayName .. " reached Rebirth " .. data.Rebirths .. "!", "rare")
end

ActionRemote.OnServerEvent:Connect(function(player, action, arg)
	local data = Data[player]
	if not data or type(action) ~= "string" then return end
	if action == "Ready" then
		-- just sync
	elseif action == "BuyTool" then
		local lvl = tonumber(arg)
		local def = lvl and Config.Tools[lvl]
		if not def or lvl <= data.Tool then return end
		if data.Coins < def.Cost then notify(player, "Not enough coins", "error") return end
		data.Coins -= def.Cost
		data.Tool = lvl
		questProgress(data, "tool")
		giveTool(player)
		notify(player, "⛏ You got the " .. def.Name .. "!", "buy")
	elseif action == "BuyPack" then
		local lvl = tonumber(arg)
		local def = lvl and Config.Backpacks[lvl]
		if not def or lvl <= data.Backpack then return end
		if data.Coins < def.Cost then notify(player, "Not enough coins", "error") return end
		data.Coins -= def.Cost
		data.Backpack = lvl
		questProgress(data, "backpack")
		notify(player, "🎒 You got the " .. def.Name .. "!", "buy")
	elseif action == "ClaimQuest" then
		local q = currentQuest(data)
		if data.QuestProgress >= q.Amount then
			data.Coins += q.Reward
			data.QuestIndex += 1
			data.QuestProgress = 0
			refreshLevelQuest(data)
			notify(player, "📜 Quest complete! +" .. q.Reward .. " coins", "rare")
		end
	elseif action == "Rebirth" then
		rebirth(player, data)
	elseif action == "Daily" then
		claimDaily(player, data)
	elseif action == "Hatch" then
		hatch(player, arg)
		return
	elseif action == "DeletePet" then
		local id = tonumber(arg)
		for k, p in ipairs(data.Pets) do
			if p.Id == id then table.remove(data.Pets, k) break end
		end
		updatePetAttr(player, data)
	elseif action == "Teleport" then
		teleport(player, arg)
		return
	elseif action == "Code" then
		local code = type(arg) == "string" and string.upper((arg:gsub("%s", ""))) or ""
		local c = Config.Codes[code]
		if not c then notify(player, "❌ Invalid code", "error") return end
		if data.Codes[code] then notify(player, "Code already used", "error") return end
		data.Codes[code] = true
		data.Coins += c.Coins or 0
		notify(player, "✅ Code redeemed! +" .. (c.Coins or 0) .. " coins", "rare")
	elseif action == "ToggleAuto" then
		if not hasPass(player, "AutoMine") then notify(player, "Auto Mine is a game pass (Store)", "error") return end
		data.AutoMine = not data.AutoMine
		player:SetAttribute("AutoMine", data.AutoMine)
	elseif action == "StudioPass" then
		if RunService:IsStudio() and Config.FreePassesInStudio and Config.GamePasses[arg] then
			Owns[player][arg] = true
			notify(player, "[Studio] Test pass granted: " .. Config.GamePasses[arg].Name, "buy")
			updatePetAttr(player, data)
		end
	elseif action == "Sell" then
		-- remote sell only for VIP ("sell anywhere" perk)
		if hasPass(player, "VIP") then sell(player) return end
		notify(player, "Sell anywhere is a VIP perk. Find a 💰 pad!", "error")
	end
	sync(player)
end)

-- proximity prompts placed by the WorldBuilder
for _, pp in ipairs(World:GetDescendants()) do
	if pp:IsA("ProximityPrompt") and pp:GetAttribute("Action") then
		pp.Triggered:Connect(function(player)
			local action = pp:GetAttribute("Action")
			local arg = pp:GetAttribute("Arg")
			if action == "Hatch" then hatch(player, arg)
			elseif action == "Portal" then teleport(player, arg)
			else OpenUIRemote:FireClient(player, action, arg) end
		end)
	end
end

---------------------------------------------------------------- game passes
MPS.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or not Owns[player] then return end
	for name, pass in pairs(Config.GamePasses) do
		if pass.Id == passId then
			Owns[player][name] = true
			notify(player, "🎉 Thanks! " .. pass.Name .. " unlocked", "rare")
		end
	end
	local data = Data[player]
	if data then updatePetAttr(player, data) end
	sync(player)
end)

---------------------------------------------------------------- player lifecycle
local function save(player)
	local data = Data[player]
	if not data or not store or NoSave[player] then return end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, data)
	end)
	if not ok then warn("[MineRush] save failed:", err) end
end

Players.PlayerAdded:Connect(function(player)
	local data = defaultData()
	if store then
		local ok, saved = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(saved) == "table" then
			for k, v in pairs(saved) do data[k] = v end
		elseif not ok then
			NoSave[player] = true
			warn("[MineRush] could not load data, saving disabled for this session")
		end
	else
		NoSave[player] = true
	end
	if not player.Parent then return end
	data.Tool = math.clamp(data.Tool, 1, #Config.Tools)
	data.Backpack = math.clamp(data.Backpack, 1, #Config.Backpacks)
	Data[player] = data

	Owns[player] = {}
	for name, pass in pairs(Config.GamePasses) do
		if pass.Id > 0 then
			local ok, owns = pcall(function() return MPS:UserOwnsGamePassAsync(player.UserId, pass.Id) end)
			if ok and owns then Owns[player][name] = true end
		end
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Parent = ls
	ls.Parent = player

	player:SetAttribute("AutoMine", data.AutoMine and hasPass(player, "AutoMine"))
	refreshLevelQuest(data)
	updatePetAttr(player, data)

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		giveTool(player)
		overheadTag(player, char)
	end)
	if player.Character then
		giveTool(player)
		overheadTag(player, player.Character)
	end
	sync(player)
	if boss then BossRemote:FireClient(player, "spawn", boss.HP, boss.Max, boss.Pos) end
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	Data[player] = nil
	NoSave[player] = nil
	Owns[player] = nil
	lastHit[player] = nil
	lastSell[player] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(save, p) end
	task.wait(3)
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do task.spawn(save, p) end
	end
end)

---------------------------------------------------------------- world events loop
task.spawn(function()
	while true do
		task.wait(Config.EventInterval)
		currentEvent = (rng:NextNumber() < 0.6) and "OreRush" or "ShinyStorm"
		eventEnds = os.time() + Config.EventDuration
		notifyAll(currentEvent == "OreRush" and "⚡ ORE RUSH! x2 coins for 2 minutes!" or "✨ SHINY STORM! x5 shiny ores for 2 minutes!", "rare")
		syncAll()
		task.wait(Config.EventDuration)
		currentEvent = nil
		syncAll()
	end
end)

---------------------------------------------------------------- global leaderboards
local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	nameCache[userId] = ok and n or ("User" .. userId)
	return nameCache[userId]
end

local function short(n)
	local units = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	while n >= 1000 and i < #units do n /= 1000 i += 1 end
	return (i == 1 and tostring(math.floor(n)) or string.format("%.1f", n)) .. units[i]
end

local function refreshBoard(ods, boardName)
	local board = World.Leaderboards:FindFirstChild(boardName)
	if not ods or not board then return end
	local ok, pages = pcall(function() return ods:GetSortedAsync(false, 10) end)
	if not ok then return end
	local sg = board:FindFirstChildOfClass("SurfaceGui")
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local row = sg and sg:FindFirstChild("Row" .. rank)
		if row then
			local id = tonumber(string.match(entry.key, "%d+"))
			row.Text = rank .. ". " .. (id and nameOf(id) or "?") .. " — " .. short(entry.value)
		end
	end
end

task.spawn(function()
	while true do
		for p, d in pairs(Data) do
			if topEarned then pcall(function() topEarned:SetAsync("p_" .. p.UserId, math.floor(d.TotalEarned)) end) end
			if topRebirths then pcall(function() topRebirths:SetAsync("p_" .. p.UserId, d.Rebirths) end) end
		end
		refreshBoard(topEarned, "TopEarned")
		refreshBoard(topRebirths, "TopRebirths")
		task.wait(90)
	end
end)

-- periodic sync (event timers, daily countdown)
task.spawn(function()
	while true do
		task.wait(5)
		syncAll()
	end
end)
