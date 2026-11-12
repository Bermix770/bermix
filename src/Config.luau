-- Mine Rush Simulator : shared configuration (server + client)
-- Все цифры баланса здесь. All balance numbers live here.

local Config = {}

Config.DataStoreName = "MineRush_v2"
Config.MineRange = 16           -- studs from character to ore
Config.RespawnTime = 5          -- seconds before a mined ore respawns
Config.RebirthBaseCost = 250000
Config.RebirthBonus = 0.5       -- +50% coins per rebirth
Config.EventInterval = 480      -- random world event every 8 minutes
Config.EventDuration = 120
Config.DailyCooldown = 72000    -- 20h
Config.DailyStreakWindow = 172800 -- 48h to keep streak
Config.CritChance = 0.12
Config.CritMultiplier = 2
Config.ShinyChance = 0.02
Config.ShinyMultiplier = 5
Config.MaxPets = 60
Config.EquipSlots = 3
Config.VIPExtraSlots = 2
Config.GuideUntilQuest = 12     -- show guide arrow for new players

-- Game pass IDs. 0 = disabled. Create passes on the Creator Dashboard and paste IDs here.
Config.GamePasses = {
	DoubleCoins = { Id = 0, Name = "x2 Coins", Desc = "Double coins forever" },
	AutoMine    = { Id = 0, Name = "Auto Mine", Desc = "Mines the nearest ore for you" },
	VIP         = { Id = 0, Name = "VIP", Desc = "+25% coins, +2 pet slots, VIP tag" },
	LuckyPets   = { Id = 0, Name = "Lucky Eggs", Desc = "x2 luck for rare pets" },
}
Config.FreePassesInStudio = true -- lets you test passes in Studio

Config.Codes = {
	RELEASE = { Coins = 500 },
	MINER   = { Coins = 1500 },
	DEEPER  = { Coins = 10000 },
	VOID    = { Coins = 250000 },
}

-- Sounds (built-in Studio sounds; swap for your own asset IDs)
Config.Sounds = {
	Hit = "rbxasset://sounds/swordslash.wav",
	Break = "rbxasset://sounds/collide.wav",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	Hatch = "rbxasset://sounds/victory.wav",
	Error = "rbxasset://sounds/button.wav",
}

function Config.RebirthCost(rebirths)
	return Config.RebirthBaseCost * (rebirths + 1) ^ 1.6
end

-- Tools: Power = damage per hit, Cooldown = seconds between hits
Config.Tools = {
	{ Name = "Wooden Pickaxe", Power = 1,   Cooldown = 0.5,  Cost = 0,       Color = Color3.fromRGB(150, 105, 60),  Material = Enum.Material.Wood,   Kind = "Pickaxe" },
	{ Name = "Stone Pickaxe",  Power = 2,   Cooldown = 0.45, Cost = 150,     Color = Color3.fromRGB(130, 130, 130), Material = Enum.Material.Slate,  Kind = "Pickaxe" },
	{ Name = "Iron Pickaxe",   Power = 4,   Cooldown = 0.4,  Cost = 800,     Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal,  Kind = "Pickaxe" },
	{ Name = "Steel Pickaxe",  Power = 8,   Cooldown = 0.35, Cost = 3000,    Color = Color3.fromRGB(90, 110, 140),  Material = Enum.Material.DiamondPlate, Kind = "Pickaxe" },
	{ Name = "Gold Drill",     Power = 15,  Cooldown = 0.3,  Cost = 12000,   Color = Color3.fromRGB(255, 200, 40),  Material = Enum.Material.Foil,   Kind = "Drill" },
	{ Name = "Ruby Pickaxe",   Power = 30,  Cooldown = 0.3,  Cost = 45000,   Color = Color3.fromRGB(220, 30, 60),   Material = Enum.Material.Glass,  Kind = "Pickaxe", Glow = true },
	{ Name = "Diamond Drill",  Power = 60,  Cooldown = 0.25, Cost = 150000,  Color = Color3.fromRGB(120, 240, 255), Material = Enum.Material.Glass,  Kind = "Drill", Glow = true },
	{ Name = "Frost Hammer",   Power = 120, Cooldown = 0.25, Cost = 500000,  Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Ice,    Kind = "Hammer", Glow = true },
	{ Name = "Plasma Drill",   Power = 250, Cooldown = 0.2,  Cost = 1500000, Color = Color3.fromRGB(255, 80, 255),  Material = Enum.Material.Neon,   Kind = "Drill", Glow = true },
	{ Name = "Void Breaker",   Power = 600, Cooldown = 0.15, Cost = 5000000, Color = Color3.fromRGB(110, 0, 200),   Material = Enum.Material.Neon,   Kind = "Hammer", Glow = true },
}

Config.Backpacks = {
	{ Name = "Pouch",        Capacity = 10,    Cost = 0,       Color = Color3.fromRGB(140, 100, 60) },
	{ Name = "Sack",         Capacity = 25,    Cost = 120,     Color = Color3.fromRGB(190, 160, 110) },
	{ Name = "Backpack",     Capacity = 60,    Cost = 700,     Color = Color3.fromRGB(60, 120, 200) },
	{ Name = "Big Backpack", Capacity = 150,   Cost = 3000,    Color = Color3.fromRGB(60, 170, 80) },
	{ Name = "Miner's Pack", Capacity = 400,   Cost = 15000,   Color = Color3.fromRGB(230, 150, 30) },
	{ Name = "Mega Pack",    Capacity = 1000,  Cost = 80000,   Color = Color3.fromRGB(200, 40, 60) },
	{ Name = "Titan Pack",   Capacity = 3000,  Cost = 400000,  Color = Color3.fromRGB(120, 230, 255) },
	{ Name = "Void Bag",     Capacity = 10000, Cost = 2500000, Color = Color3.fromRGB(110, 0, 200) },
}

-- Ambience: lighting the client blends to when you enter an area
local function amb(t)
	return t
end
Config.HubAmbience = amb({ Fog = Color3.fromRGB(200, 225, 255), Density = 0.28, Haze = 1, Tint = Color3.new(1, 1, 1), Brightness = 0.02, Saturation = 0, Contrast = 0.05, ClockTime = 14, Ambient = Color3.fromRGB(120, 120, 130) })

-- Zones (3D layout). Spawn = where ores appear (rays cast down onto terrain/platforms)
Config.Zones = {
	{
		Name = "Sunny Meadow", RequiredTier = 1, Kind = "Meadow",
		Center = Vector3.new(0, 10, 175), Radius = 85, OreCount = 55,
		Spawn = { MinR = 0, MaxR = 78, StartY = 120, MinY = 5, MaxY = 60 },
		RockColor = Color3.fromRGB(125, 125, 118),
		Ambience = amb({ Fog = Color3.fromRGB(210, 235, 255), Density = 0.25, Haze = 0.8, Tint = Color3.fromRGB(255, 250, 235), Brightness = 0.03, Saturation = 0.04, Contrast = 0.05, ClockTime = 14, Ambient = Color3.fromRGB(130, 130, 120) }),
		Ores = {
			{ Name = "Stone", HP = 2, Value = 1, Weight = 65, Size = 4, Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.Slate, Style = "Rock" },
			{ Name = "Coal",  HP = 5, Value = 3, Weight = 30, Size = 4.2, Color = Color3.fromRGB(35, 35, 35), Material = Enum.Material.Basalt, Style = "Rock" },
			{ Name = "Amber", HP = 9, Value = 8, Weight = 5, Size = 4.2, Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
		},
	},
	{
		Name = "Dark Caves", RequiredTier = 3, Kind = "Caves",
		Center = Vector3.new(210, 10, 68), Radius = 80, OreCount = 55,
		Spawn = { MinR = 0, MaxR = 38, StartY = 44, MinY = 10, MaxY = 41 },
		RockColor = Color3.fromRGB(70, 62, 58),
		Ambience = amb({ Fog = Color3.fromRGB(25, 20, 18), Density = 0.6, Haze = 0, Tint = Color3.fromRGB(255, 215, 170), Brightness = -0.03, Saturation = -0.1, Contrast = 0.07, ClockTime = 0, Ambient = Color3.fromRGB(70, 55, 45) }),
		Ores = {
			{ Name = "Copper", HP = 10, Value = 7,  Weight = 55, Size = 4.5, Color = Color3.fromRGB(205, 115, 60),  Material = Enum.Material.Metal, Style = "Metal" },
			{ Name = "Iron",   HP = 14, Value = 11, Weight = 38, Size = 4.5, Color = Color3.fromRGB(215, 195, 175), Material = Enum.Material.Metal, Style = "Metal" },
			{ Name = "Emerald", HP = 25, Value = 30, Weight = 7, Size = 4.5, Color = Color3.fromRGB(40, 220, 110), Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
		},
	},
	{
		Name = "Crystal Grotto", RequiredTier = 5, Kind = "Grotto",
		Center = Vector3.new(153, -40, -210), Radius = 55, OreCount = 50,
		Spawn = { MinR = 0, MaxR = 36, StartY = -25, MinY = -64, MaxY = -40 },
		RockColor = Color3.fromRGB(60, 45, 90),
		Ambience = amb({ Fog = Color3.fromRGB(70, 30, 120), Density = 0.55, Haze = 0, Tint = Color3.fromRGB(220, 190, 255), Brightness = 0, Saturation = 0.05, Contrast = 0.05, ClockTime = 0, Ambient = Color3.fromRGB(90, 60, 140) }),
		Ores = {
			{ Name = "Gold",     HP = 45, Value = 35, Weight = 55, Size = 5, Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Foil,  Style = "Metal" },
			{ Name = "Amethyst", HP = 70, Value = 60, Weight = 38, Size = 5, Color = Color3.fromRGB(170, 90, 255), Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
			{ Name = "Moonstone", HP = 110, Value = 130, Weight = 7, Size = 5, Color = Color3.fromRGB(210, 240, 255), Material = Enum.Material.Neon, Style = "Crystal", Glow = true },
		},
	},
	{
		Name = "Lava Volcano", RequiredTier = 6, Kind = "Volcano",
		Center = Vector3.new(-176, 10, -243), Radius = 118, OreCount = 60,
		Spawn = { MinR = 30, MaxR = 100, StartY = 200, MinY = 8, MaxY = 120 },
		RockColor = Color3.fromRGB(40, 30, 28),
		Ambience = amb({ Fog = Color3.fromRGB(120, 50, 25), Density = 0.45, Haze = 2, Tint = Color3.fromRGB(255, 200, 170), Brightness = 0, Saturation = 0.03, Contrast = 0.07, ClockTime = 17.6, Ambient = Color3.fromRGB(120, 60, 40) }),
		Ores = {
			{ Name = "Ruby",     HP = 150, Value = 140, Weight = 55, Size = 5.5, Color = Color3.fromRGB(230, 20, 50), Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
			{ Name = "Obsidian", HP = 240, Value = 230, Weight = 38, Size = 5.5, Color = Color3.fromRGB(30, 15, 45),  Material = Enum.Material.Glass, Style = "Rock" },
			{ Name = "Magma Core", HP = 400, Value = 520, Weight = 7, Size = 5.5, Color = Color3.fromRGB(255, 110, 20), Material = Enum.Material.Neon, Style = "Crystal", Glow = true },
		},
	},
	{
		Name = "Frozen Peaks", RequiredTier = 8, Kind = "Frozen",
		Center = Vector3.new(-285, 10, 93), Radius = 112, OreCount = 60,
		Spawn = { MinR = 0, MaxR = 100, StartY = 200, MinY = 5, MaxY = 110 },
		RockColor = Color3.fromRGB(180, 200, 215),
		Ambience = amb({ Fog = Color3.fromRGB(220, 235, 255), Density = 0.5, Haze = 2.5, Tint = Color3.fromRGB(225, 240, 255), Brightness = 0.05, Saturation = -0.15, Contrast = 0.05, ClockTime = 10, Ambient = Color3.fromRGB(150, 170, 200) }),
		Ores = {
			{ Name = "Sapphire",   HP = 600,  Value = 600,  Weight = 55, Size = 6, Color = Color3.fromRGB(30, 80, 255),   Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
			{ Name = "Frost Core", HP = 1000, Value = 1100, Weight = 38, Size = 6, Color = Color3.fromRGB(160, 255, 255), Material = Enum.Material.Ice, Style = "Crystal", Glow = true },
			{ Name = "Aurora Gem", HP = 1600, Value = 2400, Weight = 7, Size = 6, Color = Color3.fromRGB(120, 255, 170), Material = Enum.Material.Neon, Style = "Crystal", Glow = true },
		},
	},
	{
		Name = "The Void", RequiredTier = 10, Kind = "Void",
		Center = Vector3.new(0, 300, 0), Radius = 140, OreCount = 50,
		Spawn = {
			StartY = 360, MinY = 270, MaxY = 335,
			Islands = {}, -- filled in below
		},
		RockColor = Color3.fromRGB(25, 10, 40),
		Ambience = amb({ Fog = Color3.fromRGB(30, 0, 60), Density = 0.4, Haze = 0, Tint = Color3.fromRGB(230, 200, 255), Brightness = 0, Saturation = 0.05, Contrast = 0.08, ClockTime = 0, Ambient = Color3.fromRGB(110, 60, 160) }),
		Ores = {
			{ Name = "Void Shard", HP = 3000, Value = 3500, Weight = 60, Size = 6.5, Color = Color3.fromRGB(120, 0, 200),   Material = Enum.Material.Neon, Style = "Crystal", Glow = true },
			{ Name = "Starstone",  HP = 6000, Value = 8000, Weight = 33, Size = 6.5, Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon, Style = "Crystal", Glow = true },
			{ Name = "Singularity", HP = 12000, Value = 25000, Weight = 7, Size = 6.5, Color = Color3.fromRGB(10, 10, 10), Material = Enum.Material.Glass, Style = "Crystal", Glow = true },
		},
	},
}

-- Void floating islands (shared by world builder and ore spawner)
Config.VoidIslands = { { X = 0, Y = 300, Z = 0, R = 30 } }
for i = 1, 5 do
	local a = math.rad(i * 72)
	table.insert(Config.VoidIslands, { X = math.sin(a) * 100, Y = 296 + (i % 3) * 8, Z = math.cos(a) * 100, R = 20 })
end
Config.Zones[6].Spawn.Islands = Config.VoidIslands

Config.HubCenter = Vector3.new(0, 16, 0)
Config.HubRadius = 62
Config.ArenaCenter = Vector3.new(0, 10, -150)

-- Which area is a position in? returns zone index, or 0 for hub / wilderness
function Config.ZoneAt(pos)
	if pos.Y > 220 then return 6 end
	for i, z in ipairs(Config.Zones) do
		if i ~= 6 then
			local flat = Vector3.new(pos.X - z.Center.X, 0, pos.Z - z.Center.Z).Magnitude
			if z.Kind == "Grotto" then
				if flat < z.Radius and pos.Y < -5 then return i end
			elseif flat < z.Radius and pos.Y < 200 then
				return i
			end
		end
	end
	return 0
end

-- Pets
Config.Rarities = {
	Common    = { Color = Color3.fromRGB(200, 200, 200), Order = 1 },
	Uncommon  = { Color = Color3.fromRGB(90, 220, 90),   Order = 2 },
	Rare      = { Color = Color3.fromRGB(70, 150, 255),  Order = 3 },
	Epic      = { Color = Color3.fromRGB(180, 80, 255),  Order = 4 },
	Legendary = { Color = Color3.fromRGB(255, 190, 30),  Order = 5 },
	Mythic    = { Color = Color3.fromRGB(255, 60, 120),  Order = 6 },
}

Config.Eggs = {
	{
		Name = "Meadow Egg", Cost = 400, RequiredTier = 1, Color = Color3.fromRGB(240, 230, 180),
		Pets = {
			{ Name = "Dirt Pup",      Rarity = "Common",    Chance = 45,  Bonus = 0.05, Color = Color3.fromRGB(150, 110, 70) },
			{ Name = "Pebble Cat",    Rarity = "Common",    Chance = 30,  Bonus = 0.07, Color = Color3.fromRGB(160, 160, 160) },
			{ Name = "Copper Bunny",  Rarity = "Uncommon",  Chance = 17,  Bonus = 0.12, Color = Color3.fromRGB(205, 120, 60) },
			{ Name = "Golden Mole",   Rarity = "Rare",      Chance = 7,   Bonus = 0.25, Color = Color3.fromRGB(255, 205, 50) },
			{ Name = "Rainbow Worm",  Rarity = "Legendary", Chance = 1,   Bonus = 0.75, Color = Color3.fromRGB(255, 100, 200) },
		},
	},
	{
		Name = "Crystal Egg", Cost = 60000, RequiredTier = 5, Color = Color3.fromRGB(180, 120, 255),
		Pets = {
			{ Name = "Quartz Fox",    Rarity = "Uncommon",  Chance = 45,  Bonus = 0.3,  Color = Color3.fromRGB(240, 240, 255) },
			{ Name = "Amethyst Owl",  Rarity = "Rare",      Chance = 35,  Bonus = 0.45, Color = Color3.fromRGB(170, 90, 255) },
			{ Name = "Gem Golem",     Rarity = "Epic",      Chance = 17,  Bonus = 0.8,  Color = Color3.fromRGB(80, 220, 200) },
			{ Name = "Prism Dragon",  Rarity = "Legendary", Chance = 3,   Bonus = 1.8,  Color = Color3.fromRGB(255, 255, 255) },
		},
	},
	{
		Name = "Magma Egg", Cost = 900000, RequiredTier = 6, Color = Color3.fromRGB(255, 90, 30),
		Pets = {
			{ Name = "Ember Lizard",  Rarity = "Rare",      Chance = 50,  Bonus = 1.0, Color = Color3.fromRGB(255, 120, 40) },
			{ Name = "Lava Hound",    Rarity = "Epic",      Chance = 35,  Bonus = 1.6, Color = Color3.fromRGB(200, 40, 20) },
			{ Name = "Phoenix",       Rarity = "Legendary", Chance = 14,  Bonus = 3.0, Color = Color3.fromRGB(255, 200, 40) },
			{ Name = "Inferno Titan", Rarity = "Mythic",    Chance = 1,   Bonus = 7.0, Color = Color3.fromRGB(255, 50, 0) },
		},
	},
	{
		Name = "Void Egg", Cost = 8000000, RequiredTier = 10, Color = Color3.fromRGB(60, 0, 110),
		Pets = {
			{ Name = "Shadow Cat",    Rarity = "Epic",      Chance = 55,  Bonus = 4,  Color = Color3.fromRGB(40, 20, 60) },
			{ Name = "Star Whale",    Rarity = "Legendary", Chance = 38,  Bonus = 7,  Color = Color3.fromRGB(100, 130, 255) },
			{ Name = "Void Emperor",  Rarity = "Mythic",    Chance = 7,   Bonus = 15, Color = Color3.fromRGB(150, 0, 255) },
		},
	},
}

Config.PetByName = {}
for eggIndex, egg in ipairs(Config.Eggs) do
	for _, pet in ipairs(egg.Pets) do
		pet.Egg = eggIndex
		Config.PetByName[pet.Name] = pet
	end
end

-- World boss (co-op)
Config.Boss = {
	Name = "Stone Golem",
	FirstSpawn = 150,      -- seconds after server start
	Interval = 540,        -- then every 9 minutes
	Lifetime = 180,
	BaseHP = 1500,
	HPPerPower = 70,       -- extra HP per point of tool power of every player online
	CoinsPerDamage = 6,
	FreeEggChance = 0.3,   -- chance to get a free hatch from best unlocked egg
}

-- Quest chain. Types: mine (Target = ore or nil), earn, tool, backpack, rebirth, hatch, boss, shiny
Config.Quests = {
	{ Type = "mine", Target = "Stone", Amount = 10, Reward = 50,  Text = "Mine 10 Stone in Sunny Meadow" },
	{ Type = "mine", Target = "Coal",  Amount = 5,  Reward = 75,  Text = "Mine 5 Coal" },
	{ Type = "earn", Amount = 200,  Reward = 100, Text = "Sell ores for 200 coins" },
	{ Type = "tool", Amount = 2,    Reward = 150, Text = "Buy the Stone Pickaxe at the Tool Shop" },
	{ Type = "backpack", Amount = 2, Reward = 150, Text = "Upgrade to the Sack" },
	{ Type = "hatch", Amount = 1,   Reward = 300, Text = "Hatch a Meadow Egg in town" },
	{ Type = "mine", Target = "Amber", Amount = 3, Reward = 400, Text = "Find 3 rare Amber" },
	{ Type = "tool", Amount = 3,    Reward = 500, Text = "Get the Iron Pickaxe to open Dark Caves" },
	{ Type = "mine", Target = "Iron",   Amount = 15, Reward = 800, Text = "Mine 15 Iron deep in the caves" },
	{ Type = "mine", Target = "Copper", Amount = 20, Reward = 900, Text = "Mine 20 Copper" },
	{ Type = "boss", Amount = 1,    Reward = 2000, Text = "Help defeat the Stone Golem in the Arena" },
	{ Type = "backpack", Amount = 4, Reward = 2000, Text = "Get the Big Backpack" },
	{ Type = "tool", Amount = 4,    Reward = 3000, Text = "Buy the Steel Pickaxe" },
	{ Type = "shiny", Amount = 1,   Reward = 4000, Text = "Mine a ✨ Shiny ore" },
	{ Type = "earn", Amount = 20000, Reward = 5000, Text = "Sell ores for 20K coins" },
	{ Type = "tool", Amount = 5,    Reward = 8000, Text = "Get the Gold Drill to open Crystal Grotto" },
	{ Type = "mine", Target = "Gold",     Amount = 30, Reward = 12000, Text = "Mine 30 Gold underground" },
	{ Type = "mine", Target = "Amethyst", Amount = 20, Reward = 15000, Text = "Mine 20 Amethyst" },
	{ Type = "hatch", Amount = 3,   Reward = 20000, Text = "Hatch 3 more eggs" },
	{ Type = "tool", Amount = 6,    Reward = 25000, Text = "Get the Ruby Pickaxe to open Lava Volcano" },
	{ Type = "mine", Target = "Ruby",     Amount = 40, Reward = 50000, Text = "Mine 40 Ruby on the volcano" },
	{ Type = "mine", Target = "Obsidian", Amount = 30, Reward = 70000, Text = "Mine 30 Obsidian" },
	{ Type = "boss", Amount = 3,    Reward = 90000, Text = "Defeat the Stone Golem 3 times" },
	{ Type = "rebirth", Amount = 1, Reward = 100000, Text = "Rebirth for the first time" },
	{ Type = "tool", Amount = 8,    Reward = 250000, Text = "Get the Frost Hammer to open Frozen Peaks" },
	{ Type = "mine", Target = "Sapphire",   Amount = 50, Reward = 400000, Text = "Mine 50 Sapphire" },
	{ Type = "mine", Target = "Frost Core", Amount = 30, Reward = 600000, Text = "Mine 30 Frost Cores" },
	{ Type = "mine", Target = "Aurora Gem", Amount = 5, Reward = 900000, Text = "Find 5 Aurora Gems" },
	{ Type = "tool", Amount = 10,   Reward = 1500000, Text = "Get the Void Breaker and take the portal to The Void" },
	{ Type = "mine", Target = "Void Shard", Amount = 50, Reward = 2000000, Text = "Mine 50 Void Shards" },
	{ Type = "mine", Target = "Starstone",  Amount = 30, Reward = 3000000, Text = "Mine 30 Starstones" },
	{ Type = "mine", Target = "Singularity", Amount = 3, Reward = 6000000, Text = "Find 3 Singularities" },
}

return Config
