-- Mine Rush Simulator : Client
-- HUD, shops, pets, map, codes, mining input, hit effects, zone ambience,
-- gates, pet followers, boss bar, hatch animation, guide beam.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local MPS = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Config = require(RS:WaitForChild("Config"))
local ModelLibrary = require(RS:WaitForChild("ModelLibrary"))
local Remotes = RS:WaitForChild("Remotes")
local R = {}
for _, n in ipairs({ "Mine", "Action", "Sync", "Notify", "HitFx", "OpenUI", "Hatch", "Boss" }) do
	R[n] = Remotes:WaitForChild(n)
end

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local World = workspace:WaitForChild("World")
local OresFolder = workspace:WaitForChild("Ores")

local V3 = Vector3.new
local rgb = Color3.fromRGB
local U2 = UDim2.new
local FONT = Enum.Font.FredokaOne

local state = { Coins = 0, Tool = 1, Backpack = 1, Bag = 0, Capacity = 15, Mult = 1, Pets = {}, Equipped = {}, Passes = {}, Quest = { Text = "...", Amount = 1 }, QuestProgress = 0, QuestIndex = 1, Rebirths = 0, RebirthCost = 0, DailyIn = 0, Streak = 0, Slots = 3 }

---------------------------------------------------------------- helpers
local function fmt(n)
	n = tonumber(n) or 0
	local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	while math.abs(n) >= 1000 and i < #units do n /= 1000 i += 1 end
	if i == 1 then return tostring(math.floor(n)) end
	return string.format(n < 10 and "%.2f" or "%.1f", n) .. units[i]
end

local function timeStr(s)
	s = math.max(0, math.floor(s))
	local h, m = s // 3600, (s % 3600) // 60
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m " .. (s % 60) .. "s"
end

local sounds = {}
for name, id in pairs(Config.Sounds) do
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.5
	s.Parent = SoundService
	sounds[name] = s
end
local function play(name)
	local s = sounds[name]
	if s then SoundService:PlayLocalSound(s) end
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o) return o end
local function stroke(o, c, t) new("UIStroke", { Color = c or rgb(0, 0, 0), Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) return o end
local function grad(o, a, b) new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = 90 }, o) return o end

local function label(parent, text, size, pos, color, scaled)
	return new("TextLabel", {
		Text = text, Size = size, Position = pos or U2(), BackgroundTransparency = 1, Font = FONT,
		TextColor3 = color or rgb(255, 255, 255), TextScaled = scaled ~= false, TextStrokeTransparency = 0.4,
	}, parent)
end

local function button(parent, text, color, size, pos)
	local b = new("TextButton", {
		Text = text, Size = size, Position = pos or U2(), BackgroundColor3 = color, Font = FONT,
		TextColor3 = rgb(255, 255, 255), TextScaled = true, AutoButtonColor = false, TextStrokeTransparency = 0.3,
	}, parent)
	corner(b, 10)
	stroke(b, color:Lerp(rgb(0, 0, 0), 0.5), 2)
	grad(b, rgb(255, 255, 255), rgb(200, 200, 200))
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	local base = b.Size
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = U2(base.X.Scale * 1.05, base.X.Offset * 1.05, base.Y.Scale * 1.05, base.Y.Offset * 1.05) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = base }):Play()
	end)
	b.MouseButton1Click:Connect(function() play("Buy") end)
	return b
end

local gui = new("ScreenGui", { Name = "MineRushUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
new("UIScale", { Scale = isMobile and 0.75 or 1 }, gui)

---------------------------------------------------------------- toasts
local toastHolder = new("Frame", { Size = U2(0, 420, 0, 300), Position = U2(0.5, -210, 1, -390), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, toastHolder)
local toastColors = { info = rgb(60, 70, 100), error = rgb(170, 50, 50), sell = rgb(40, 150, 70), buy = rgb(50, 110, 200), rare = rgb(190, 120, 20), full = rgb(200, 90, 30) }
local function toast(text, kind)
	local f = new("TextLabel", { Size = U2(1, 0, 0, 38), BackgroundColor3 = toastColors[kind] or toastColors.info, Text = text, Font = FONT, TextScaled = true, TextColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0.4, BackgroundTransparency = 0.1 }, toastHolder)
	corner(f, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, f)
	if kind == "error" or kind == "full" then play("Error") elseif kind == "sell" then play("Sell") end
	task.delay(3.2, function()
		TweenService:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		f:Destroy()
	end)
	local kids = 0
	for _, c in ipairs(toastHolder:GetChildren()) do if c:IsA("TextLabel") then kids += 1 end end
	if kids > 5 then
		for _, c in ipairs(toastHolder:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() break end end
	end
end
local lastFullToast = 0
R.Notify.OnClientEvent:Connect(function(text, kind)
	if kind == "full" then
		if os.clock() - lastFullToast < 4 then return end
		lastFullToast = os.clock()
	end
	toast(text, kind)
end)

---------------------------------------------------------------- HUD (top-left stats)
local stats = new("Frame", { Size = U2(0, 270, 0, 150), Position = U2(0, 12, 0, 12), BackgroundColor3 = rgb(20, 24, 36), BackgroundTransparency = 0.15 }, gui)
corner(stats, 14)
stroke(stats, rgb(255, 200, 60), 2)
local coinsLbl = label(stats, "💰 0", U2(1, -20, 0, 40), U2(0, 10, 0, 6), rgb(255, 220, 80))
coinsLbl.TextXAlignment = Enum.TextXAlignment.Left
local multLbl = label(stats, "x1.00 coins", U2(0.5, -10, 0, 22), U2(0, 10, 0, 48), rgb(150, 255, 150))
multLbl.TextXAlignment = Enum.TextXAlignment.Left
local rebLbl = label(stats, "🌟 0", U2(0.5, -10, 0, 22), U2(0.5, 0, 0, 48), rgb(255, 170, 255))
rebLbl.TextXAlignment = Enum.TextXAlignment.Right
local bagBg = new("Frame", { Size = U2(1, -20, 0, 26), Position = U2(0, 10, 0, 78), BackgroundColor3 = rgb(40, 40, 50) }, stats)
corner(bagBg, 8)
local bagFill = new("Frame", { Size = U2(0, 0, 1, 0), BackgroundColor3 = rgb(80, 200, 255) }, bagBg)
corner(bagFill, 8)
local bagLbl = label(bagBg, "🎒 0 / 15", U2(1, 0, 1, 0), nil)
bagLbl.ZIndex = 2
local toolLbl = label(stats, "⛏ Wooden Pickaxe", U2(1, -20, 0, 22), U2(0, 10, 0, 112), rgb(220, 220, 255))
toolLbl.TextXAlignment = Enum.TextXAlignment.Left

-- event banner (top center)
local eventBanner = new("TextLabel", { Size = U2(0, 420, 0, 36), Position = U2(0.5, -210, 0, 8), BackgroundColor3 = rgb(200, 120, 20), Font = FONT, TextScaled = true, TextColor3 = rgb(255, 255, 255), Visible = false, TextStrokeTransparency = 0.3 }, gui)
corner(eventBanner, 10)
stroke(eventBanner, rgb(255, 230, 120), 2)

-- zone banner
local zoneBanner = label(gui, "", U2(0, 600, 0, 70), U2(0.5, -300, 0.2, 0), rgb(255, 255, 255))
zoneBanner.TextTransparency = 1
zoneBanner.TextStrokeTransparency = 1
local zoneSub = label(zoneBanner, "", U2(1, 0, 0, 28), U2(0, 0, 1, 0), rgb(220, 220, 220))
zoneSub.TextTransparency = 1
zoneSub.TextStrokeTransparency = 1

-- boss bar
local bossBar = new("Frame", { Size = U2(0, 460, 0, 46), Position = U2(0.5, -230, 0, 52), BackgroundColor3 = rgb(30, 15, 15), Visible = false }, gui)
corner(bossBar, 10)
stroke(bossBar, rgb(255, 90, 60), 2)
local bossFill = new("Frame", { Size = U2(1, -8, 0, 18), Position = U2(0, 4, 1, -22), BackgroundColor3 = rgb(230, 60, 40) }, bossBar)
corner(bossFill, 6)
local bossLbl = label(bossBar, "⚔ " .. Config.Boss.Name, U2(1, 0, 0, 22), U2(0, 0, 0, 2), rgb(255, 200, 180))
local bossFillMax = bossFill.Size

---------------------------------------------------------------- quest panel (right)
local questPanel = new("Frame", { Size = U2(0, 290, 0, 118), Position = U2(1, -302, 0, 12), BackgroundColor3 = rgb(20, 24, 36), BackgroundTransparency = 0.15 }, gui)
corner(questPanel, 14)
stroke(questPanel, rgb(120, 200, 255), 2)
local qTitle = label(questPanel, "📜 Quest 1", U2(1, -20, 0, 24), U2(0, 10, 0, 6), rgb(120, 200, 255))
qTitle.TextXAlignment = Enum.TextXAlignment.Left
local qText = label(questPanel, "", U2(1, -20, 0, 36), U2(0, 10, 0, 30), rgb(255, 255, 255))
qText.TextXAlignment = Enum.TextXAlignment.Left
qText.TextWrapped = true
local qBg = new("Frame", { Size = U2(1, -110, 0, 22), Position = U2(0, 10, 0, 84), BackgroundColor3 = rgb(40, 40, 50) }, questPanel)
corner(qBg, 8)
local qFill = new("Frame", { Size = U2(0, 0, 1, 0), BackgroundColor3 = rgb(90, 220, 120) }, qBg)
corner(qFill, 8)
local qProg = label(qBg, "0/1", U2(1, 0, 1, 0))
qProg.ZIndex = 2
local claimBtn = button(questPanel, "Claim", rgb(60, 180, 80), U2(0, 84, 0, 30), U2(1, -94, 0, 80))
claimBtn.Visible = false
claimBtn.MouseButton1Click:Connect(function() R.Action:FireServer("ClaimQuest") end)

---------------------------------------------------------------- windows
local windows = {}
local refreshers = {}
local function makeWindow(name, title, color)
	local f = new("Frame", { Name = name, Size = U2(0, 560, 0, 420), Position = U2(0.5, -280, 0.5, -210), BackgroundColor3 = rgb(22, 26, 40), Visible = false }, gui)
	corner(f, 16)
	stroke(f, color, 3)
	local top = new("Frame", { Size = U2(1, 0, 0, 52), BackgroundColor3 = color }, f)
	corner(top, 16)
	grad(top, rgb(255, 255, 255), rgb(170, 170, 170))
	label(top, title, U2(1, -80, 1, -10), U2(0, 16, 0, 5)).TextXAlignment = Enum.TextXAlignment.Left
	local close = button(top, "X", rgb(200, 60, 60), U2(0, 40, 0, 40), U2(1, -46, 0, 6))
	close.MouseButton1Click:Connect(function() f.Visible = false end)
	local body = new("Frame", { Size = U2(1, -20, 1, -66), Position = U2(0, 10, 0, 58), BackgroundTransparency = 1 }, f)
	windows[name] = { Frame = f, Body = body }
	return body
end

local function openWindow(name)
	for k, w in pairs(windows) do
		if k ~= name then w.Frame.Visible = false end
	end
	local w = windows[name]
	if not w then return end
	w.Frame.Visible = not w.Frame.Visible
	if w.Frame.Visible then
		w.Frame.Position = U2(0.5, -280, 0.55, -210)
		TweenService:Create(w.Frame, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Position = U2(0.5, -280, 0.5, -210) }):Play()
		if refreshers[name] then refreshers[name]() end
	end
end

local function scroller(parent, size, pos)
	local s = new("ScrollingFrame", { Size = size, Position = pos or U2(), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = U2(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, parent)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	return s
end
local function clear(s)
	for _, c in ipairs(s:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end
local function row(parent, order, color)
	local r = new("Frame", { Size = U2(1, -10, 0, 62), BackgroundColor3 = color or rgb(35, 40, 58), LayoutOrder = order }, parent)
	corner(r, 10)
	return r
end

---------------------------------------------------------------- shop
local shopBody = makeWindow("Shop", "🛒 Shop", rgb(240, 160, 40))
local shopTab = "Tools"
local tabBar = new("Frame", { Size = U2(1, 0, 0, 38), BackgroundTransparency = 1 }, shopBody)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabBar)
local shopList = scroller(shopBody, U2(1, 0, 1, -46), U2(0, 0, 0, 46))
for _, t in ipairs({ { "Tools", "⛏ Tools" }, { "Packs", "🎒 Backpacks" }, { "Passes", "⭐ Store" } }) do
	local b = button(tabBar, t[2], rgb(70, 90, 140), U2(0, 160, 1, 0))
	b.MouseButton1Click:Connect(function()
		shopTab = t[1]
		refreshers.Shop()
	end)
end

refreshers.Shop = function()
	clear(shopList)
	if shopTab == "Tools" or shopTab == "Packs" then
		local list = shopTab == "Tools" and Config.Tools or Config.Backpacks
		local current = shopTab == "Tools" and state.Tool or state.Backpack
		for i, def in ipairs(list) do
			local r = row(shopList, i, i == current and rgb(40, 70, 50) or nil)
			local sw = new("Frame", { Size = U2(0, 46, 0, 46), Position = U2(0, 8, 0, 8), BackgroundColor3 = def.Color or rgb(150, 110, 70) }, r)
		corner(sw, 10)
			local n = label(r, def.Name, U2(0.5, -60, 0, 28), U2(0, 62, 0, 4))
			n.TextXAlignment = Enum.TextXAlignment.Left
			local info
			if shopTab == "Tools" then
				local opens = ""
				for _, z in ipairs(Config.Zones) do if z.RequiredTier == i then opens = "  🔓 " .. z.Name end end
				info = "💥 " .. def.Power .. " dmg  ⏱ " .. def.Cooldown .. "s" .. opens
			else
				info = "🎒 Holds " .. def.Capacity .. " ores"
			end
			local d = label(r, info, U2(0.62, -60, 0, 22), U2(0, 62, 0, 34), rgb(200, 200, 220))
			d.TextXAlignment = Enum.TextXAlignment.Left
			local btn
			if i <= current then
				btn = button(r, i == current and "Equipped" or "Owned", rgb(90, 90, 100), U2(0, 130, 0, 42), U2(1, -140, 0, 10))
			else
				local can = state.Coins >= def.Cost
				btn = button(r, "💰 " .. fmt(def.Cost), can and rgb(60, 170, 80) or rgb(150, 60, 60), U2(0, 130, 0, 42), U2(1, -140, 0, 10))
				btn.MouseButton1Click:Connect(function()
					R.Action:FireServer(shopTab == "Tools" and "BuyTool" or "BuyPack", i)
				end)
			end
		end
	else
		local order = 0
		for key, pass in pairs(Config.GamePasses) do
			order += 1
			local r = row(shopList, order, rgb(50, 40, 70))
			local n = label(r, "⭐ " .. pass.Name, U2(0.6, 0, 0, 28), U2(0, 12, 0, 4), rgb(255, 220, 120))
			n.TextXAlignment = Enum.TextXAlignment.Left
			local d = label(r, pass.Desc, U2(0.65, 0, 0, 22), U2(0, 12, 0, 34), rgb(210, 200, 230))
			d.TextXAlignment = Enum.TextXAlignment.Left
			local owned = state.Passes[key]
			local btn = button(r, owned and "Owned" or "Buy", owned and rgb(90, 90, 100) or rgb(60, 140, 230), U2(0, 130, 0, 42), U2(1, -140, 0, 10))
			if not owned then
				btn.MouseButton1Click:Connect(function()
					if pass.Id > 0 then
						MPS:PromptGamePassPurchase(player, pass.Id)
					elseif state.IsStudio then
						R.Action:FireServer("StudioPass", key)
					else
						toast("This pass is not set up yet", "error")
					end
				end)
			end
		end
	end
end

---------------------------------------------------------------- pets
local petsBody = makeWindow("Pets", "🐾 Pets", rgb(120, 200, 90))
local petsInfo = label(petsBody, "", U2(1, 0, 0, 26), U2(), rgb(180, 255, 160))
local petsList = scroller(petsBody, U2(1, 0, 1, -34), U2(0, 0, 0, 34))
refreshers.Pets = function()
	clear(petsList)
	petsInfo.Text = "Equipped best " .. state.Slots .. " • Bonus +" .. math.floor((state.PetBonus or 0) * 100) .. "% • " .. #state.Pets .. "/" .. Config.MaxPets
	local sorted = table.clone(state.Pets)
	table.sort(sorted, function(a, b)
		local pa, pb = Config.PetByName[a.Name], Config.PetByName[b.Name]
		return (pa and pa.Bonus or 0) > (pb and pb.Bonus or 0)
	end)
	if #sorted == 0 then
		label(petsList, "No pets yet! Hatch eggs at the 🥚 Hatchery in town.", U2(1, -10, 0, 40), nil, rgb(200, 200, 200))
	end
	for k, p in ipairs(sorted) do
		local def = Config.PetByName[p.Name]
		if def then
			local eq = state.Equipped[p.Id] or state.Equipped[tostring(p.Id)]
			local r = row(petsList, k, eq and rgb(40, 70, 50) or nil)
			local sw = new("Frame", { Size = U2(0, 46, 0, 46), Position = U2(0, 8, 0, 8), BackgroundColor3 = def.Color }, r)
			corner(sw, 23)
			local rc = Config.Rarities[def.Rarity].Color
			stroke(sw, rc, 3)
			local n = label(r, def.Name .. (eq and "  ✅" or ""), U2(0.55, -60, 0, 28), U2(0, 62, 0, 4))
			n.TextXAlignment = Enum.TextXAlignment.Left
			local d = label(r, def.Rarity .. " • +" .. math.floor(def.Bonus * 100) .. "% coins", U2(0.55, -60, 0, 22), U2(0, 62, 0, 34), rc)
			d.TextXAlignment = Enum.TextXAlignment.Left
			local del = button(r, "🗑 Delete", rgb(170, 60, 60), U2(0, 110, 0, 40), U2(1, -120, 0, 11))
			del.MouseButton1Click:Connect(function() R.Action:FireServer("DeletePet", p.Id) end)
		end
	end
end

---------------------------------------------------------------- map / teleport
local mapBody = makeWindow("Map", "🗺 Map", rgb(80, 160, 230))
local mapList = scroller(mapBody, U2(1, 0, 1, 0))
refreshers.Map = function()
	clear(mapList)
	local entries = { { 0, "🏘 Miner's Town", 1 } }
	for i, z in ipairs(Config.Zones) do table.insert(entries, { i, z.Name, z.RequiredTier }) end
	for k, e in ipairs(entries) do
		local unlocked = state.Tool >= e[3]
		local r = row(mapList, k, unlocked and nil or rgb(50, 35, 40))
		local n = label(r, (unlocked and "" or "🔒 ") .. e[2], U2(0.6, 0, 0, 30), U2(0, 12, 0, 4))
		n.TextXAlignment = Enum.TextXAlignment.Left
		local d = label(r, unlocked and "Unlocked" or ("Needs " .. Config.Tools[e[3]].Name), U2(0.6, 0, 0, 20), U2(0, 12, 0, 36), unlocked and rgb(150, 255, 150) or rgb(255, 150, 150))
		d.TextXAlignment = Enum.TextXAlignment.Left
		local b = button(r, "Teleport", unlocked and rgb(60, 140, 230) or rgb(90, 90, 100), U2(0, 130, 0, 42), U2(1, -140, 0, 10))
		b.MouseButton1Click:Connect(function()
			R.Action:FireServer("Teleport", e[1])
			windows.Map.Frame.Visible = false
		end)
	end
end

---------------------------------------------------------------- codes
local codesBody = makeWindow("Codes", "🎟 Codes", rgb(200, 90, 200))
label(codesBody, "Enter a code (follow the game for new ones!)", U2(1, 0, 0, 30), U2(0, 0, 0, 20), rgb(230, 200, 255))
local codeBox = new("TextBox", { Size = U2(1, -40, 0, 54), Position = U2(0, 20, 0, 70), BackgroundColor3 = rgb(40, 40, 60), Font = FONT, TextScaled = true, TextColor3 = rgb(255, 255, 255), PlaceholderText = "CODE HERE", Text = "", ClearTextOnFocus = false }, codesBody)
corner(codeBox, 10)
local redeem = button(codesBody, "Redeem", rgb(60, 170, 80), U2(0, 200, 0, 50), U2(0.5, -100, 0, 140))
redeem.MouseButton1Click:Connect(function()
	R.Action:FireServer("Code", codeBox.Text)
	codeBox.Text = ""
end)

---------------------------------------------------------------- rebirth
local rebBody = makeWindow("Rebirth", "🌟 Rebirth", rgb(230, 90, 200))
local rebText = label(rebBody, "", U2(1, -20, 0, 150), U2(0, 10, 0, 10), rgb(255, 230, 255))
rebText.TextWrapped = true
local rebBtn = button(rebBody, "REBIRTH", rgb(200, 70, 200), U2(0, 240, 0, 60), U2(0.5, -120, 0, 200))
rebBtn.MouseButton1Click:Connect(function()
	R.Action:FireServer("Rebirth")
	windows.Rebirth.Frame.Visible = false
end)
refreshers.Rebirth = function()
	local nextMult = 1 + (state.Rebirths + 1) * Config.RebirthBonus
	rebText.Text = "Rebirth resets coins, tool and backpack\nbut gives a PERMANENT coin boost.\n\nYou keep all pets!\n\nCost: 💰 " .. fmt(state.RebirthCost) .. "\nNext rebirth bonus: x" .. string.format("%.1f", nextMult)
	rebBtn.BackgroundColor3 = state.Coins >= state.RebirthCost and rgb(200, 70, 200) or rgb(110, 70, 110)
end

---------------------------------------------------------------- daily
local dailyBody = makeWindow("Daily", "🎁 Daily Reward", rgb(240, 200, 60))
local dailyText = label(dailyBody, "", U2(1, -20, 0, 120), U2(0, 10, 0, 20), rgb(255, 245, 200))
dailyText.TextWrapped = true
local dailyBtn = button(dailyBody, "Claim", rgb(60, 170, 80), U2(0, 220, 0, 60), U2(0.5, -110, 0, 180))
dailyBtn.MouseButton1Click:Connect(function() R.Action:FireServer("Daily") end)
refreshers.Daily = function()
	local ready = (state.DailyIn or 0) <= 0
	dailyText.Text = "Come back every day to grow your streak (up to x7)!\n\nCurrent streak: 🔥 " .. (state.Streak or 0) .. "\n" .. (ready and "Your reward is ready!" or ("Next reward in " .. timeStr(state.DailyIn)))
	dailyBtn.BackgroundColor3 = ready and rgb(60, 170, 80) or rgb(90, 90, 100)
end

---------------------------------------------------------------- left menu buttons
local menu = new("Frame", { Size = U2(0, 90, 0, 470), Position = U2(0, 12, 0.5, -200), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { Padding = UDim.new(0, 8) }, menu)
local autoBtn
for _, m in ipairs({
	{ "Shop", "🛒\nShop", rgb(240, 160, 40) }, { "Pets", "🐾\nPets", rgb(110, 190, 80) },
	{ "Map", "🗺\nMap", rgb(70, 150, 220) }, { "Rebirth", "🌟\nRebirth", rgb(210, 80, 190) },
	{ "Daily", "🎁\nDaily", rgb(230, 190, 50) }, { "Codes", "🎟\nCodes", rgb(170, 80, 190) },
	{ "Auto", "🤖\nAuto", rgb(90, 90, 110) },
}) do
	local b = button(menu, m[2], m[3], U2(0, 84, 0, 58))
	if m[1] == "Auto" then
		autoBtn = b
		b.MouseButton1Click:Connect(function() R.Action:FireServer("ToggleAuto") end)
	else
		b.MouseButton1Click:Connect(function() openWindow(m[1]) end)
	end
end
-- VIP sell anywhere
local sellBtn = button(gui, "💰 SELL", rgb(40, 160, 70), U2(0, 120, 0, 46), U2(0, 290, 0, 116))
sellBtn.Visible = false
sellBtn.MouseButton1Click:Connect(function() R.Action:FireServer("Sell") end)

R.OpenUI.OnClientEvent:Connect(function(what, arg)
	if what == "Shop" then
		shopTab = arg == "Packs" and "Packs" or "Tools"
		if not windows.Shop.Frame.Visible then openWindow("Shop") else refreshers.Shop() end
	elseif what == "Quest" then
		toast("📜 Old Miner Joe: " .. (state.Quest.Text or ""), "info")
		if state.QuestProgress >= (state.Quest.Amount or 1) then R.Action:FireServer("ClaimQuest") end
	elseif windows[what] then
		openWindow(what)
	end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.F then openWindow("Shop")
	elseif k == Enum.KeyCode.P then openWindow("Pets")
	elseif k == Enum.KeyCode.M then openWindow("Map")
	elseif k == Enum.KeyCode.R then R.Action:FireServer("ToggleAuto") end
end)

---------------------------------------------------------------- hatch animation
local hatchOverlay = new("Frame", { Size = U2(1, 0, 1, 60), Position = U2(0, 0, 0, -60), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 50 }, gui)
local hatchGlow = new("Frame", { Size = U2(0, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = U2(0.5, 0, 0.5, -40), BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 1, ZIndex = 51 }, hatchOverlay)
corner(hatchGlow, 999)
local hatchView = new("ViewportFrame", { Size = U2(0, 360, 0, 360), AnchorPoint = Vector2.new(0.5, 0.5), Position = U2(0.5, 0, 0.5, -40), BackgroundTransparency = 1, Ambient = rgb(165, 165, 175), LightColor = rgb(255, 250, 240), LightDirection = V3(-0.6, -1, -0.8), ZIndex = 52 }, hatchOverlay)
local hatchCam = new("Camera", { FieldOfView = 35 }, hatchView)
hatchView.CurrentCamera = hatchCam
local hatchName = label(hatchOverlay, "", U2(0, 600, 0, 70), U2(0.5, -300, 0.5, 140))
hatchName.ZIndex = 53
local hatchRarity = label(hatchOverlay, "", U2(0, 400, 0, 40), U2(0.5, -200, 0.5, 210))
hatchRarity.ZIndex = 53

local function showInViewport(model)
	for _, ch in ipairs(hatchView:GetChildren()) do
		if ch ~= hatchCam then ch:Destroy() end
	end
	model:PivotTo(CFrame.identity)
	local _, size = model:GetBoundingBox()
	local dist = math.max(size.X, size.Y, size.Z) * 1.9 + 1.5
	hatchCam.CFrame = CFrame.lookAt(V3(0, size.Y * 0.15, dist), Vector3.zero)
	model.Parent = hatchView
end

R.Hatch.OnClientEvent:Connect(function(eggIndex, petName)
	local egg = Config.Eggs[eggIndex]
	local def = Config.PetByName[petName]
	if not egg or not def then return end
	hatchOverlay.Visible = true
	hatchOverlay.BackgroundTransparency = 1
	TweenService:Create(hatchOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	hatchName.Text = ""
	hatchRarity.Text = ""
	hatchGlow.Size = U2(0, 0, 0, 0)
	hatchGlow.BackgroundTransparency = 1

	local eggModel = ModelLibrary.BuildEgg(egg, 5.2, true)
	showInViewport(eggModel)
	for k = 1, 10 do
		local tilt = (k % 2 == 0 and 1 or -1) * math.rad(6 + k * 1.5)
		eggModel:PivotTo(CFrame.Angles(0, k * 0.25, tilt))
		task.wait(0.12 - k * 0.006)
	end
	play("Hatch")
	local rc = Config.Rarities[def.Rarity].Color
	hatchGlow.BackgroundColor3 = rc
	hatchGlow.BackgroundTransparency = 0.1
	TweenService:Create(hatchGlow, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = U2(0, 300, 0, 300), BackgroundTransparency = 0.6 }):Play()

	local pet = ModelLibrary.BuildPet(def, Config)
	showInViewport(pet)
	local spinStart = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local tt = os.clock() - spinStart
		local cf = CFrame.Angles(0, math.pi + math.sin(tt * 1.4) * 0.6, 0) * CFrame.new(0, math.sin(tt * 3) * 0.15, 0)
		pet:PivotTo(cf)
		ModelLibrary.AnimatePet(pet, cf, tt)
	end)
	hatchName.Text = def.Name .. "!"
	hatchName.TextColor3 = rc
	hatchRarity.Text = def.Rarity .. " • +" .. math.floor(def.Bonus * 100) .. "% coins"
	hatchRarity.TextColor3 = rc
	task.wait(2.2)
	TweenService:Create(hatchOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(hatchGlow, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	task.wait(0.3)
	spin:Disconnect()
	pet:Destroy()
	hatchOverlay.Visible = false
end)


---------------------------------------------------------------- tutorial
-- Shown once per player (saved on the server as TutorialDone); can be reopened with the ❓ button.
local tutSteps = {
	{ "⛏ Welcome to Mine Rush!", "Mine ores, sell them for coins, buy better tools and unlock new zones. Let's learn the basics!" },
	{ "1. Mine ores", "Follow the yellow beam to Sunny Meadow. Click an ore (or hold the mouse) to mine it. Mine 3 ores.", function(s0) return (state.TotalMined or 0) >= (s0.TotalMined or 0) + 3 end },
	{ "2. Sell your ores", "Ores go into your backpack. Step on a 💰 sell pad to turn them into coins.", function(s0) return (state.Coins or 0) > (s0.Coins or 0) end },
	{ "3. Upgrade", "Press F (or the Shop button) to buy stronger pickaxes and bigger backpacks.", function() return windows.Shop and windows.Shop.Frame.Visible end },
	{ "4. Quests", "Your quest is shown on the left. Complete it and talk to Old Miner Joe in town to get the reward." },
	{ "5. Pets", "Hatch eggs at the 🥚 Hatchery in town. Pets boost your coins. Press P to equip your best pets." },
	{ "6. New zones", "Better tools unlock new zones with richer ores. Press M to open the map and teleport. Good luck, miner!" },
}

local tutFrame = new("Frame", { Name = "Tutorial", Size = U2(0, 460, 0, 170), Position = U2(0.5, -230, 0, 90), BackgroundColor3 = rgb(22, 26, 40), BackgroundTransparency = 0.08, Visible = false, ZIndex = 40 }, gui)
corner(tutFrame, 14)
stroke(tutFrame, rgb(255, 200, 70), 2)
local tutTitle = label(tutFrame, "", U2(1, -24, 0, 30), U2(0, 12, 0, 8), rgb(255, 210, 90))
tutTitle.TextXAlignment = Enum.TextXAlignment.Left
tutTitle.ZIndex = 41
local tutText = label(tutFrame, "", U2(1, -24, 0, 70), U2(0, 12, 0, 42), rgb(235, 235, 245), false)
tutText.TextSize = 18
tutText.TextWrapped = true
tutText.TextXAlignment = Enum.TextXAlignment.Left
tutText.TextYAlignment = Enum.TextYAlignment.Top
tutText.ZIndex = 41
local tutStepLabel = label(tutFrame, "", U2(0, 80, 0, 22), U2(0, 12, 1, -36), rgb(160, 165, 190))
tutStepLabel.TextXAlignment = Enum.TextXAlignment.Left
tutStepLabel.ZIndex = 41
local tutSkip = button(tutFrame, "Skip", rgb(90, 90, 105), U2(0, 90, 0, 34), U2(1, -212, 1, -44))
local tutNext = button(tutFrame, "Next ▶", rgb(60, 150, 80), U2(0, 110, 0, 34), U2(1, -116, 1, -44))
tutSkip.ZIndex = 41
tutNext.ZIndex = 41
local tutHelp = button(gui, "❓", rgb(70, 110, 190), U2(0, 40, 0, 40), U2(1, -50, 0.5, -20))

local tutIndex, tutSnapshot = 0, {}
local function tutShow(i)
	tutIndex = i
	local step = tutSteps[i]
	if not step then
		tutFrame.Visible = false
		R.Action:FireServer("TutorialDone")
		return
	end
	tutSnapshot = { TotalMined = state.TotalMined, Coins = state.Coins }
	tutTitle.Text = step[1]
	tutText.Text = step[2]
	tutStepLabel.Text = i .. " / " .. #tutSteps
	tutNext.Text = (i == #tutSteps) and "Finish ✔" or "Next ▶"
	tutFrame.Visible = true
	tutFrame.Position = U2(0.5, -230, 0, 70)
	TweenService:Create(tutFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = U2(0.5, -230, 0, 90) }):Play()
end
tutNext.MouseButton1Click:Connect(function() tutShow(tutIndex + 1) end)
tutSkip.MouseButton1Click:Connect(function() tutShow(#tutSteps + 1) end)
tutHelp.MouseButton1Click:Connect(function() tutShow(1) end)

task.spawn(function()
	while state.TutorialDone == nil do task.wait(0.5) end -- wait for the first sync
	if not state.TutorialDone then tutShow(1) end
	while true do
		task.wait(0.4)
		local step = tutFrame.Visible and tutSteps[tutIndex]
		if step and step[3] and step[3](tutSnapshot) then
			play("Buy")
			toast("✅ " .. step[1], "sell")
			tutShow(tutIndex + 1)
		end
	end
end)

---------------------------------------------------------------- gates (client-side unlock)
local function refreshGates()
	for _, g in ipairs(World:WaitForChild("Gates"):GetChildren()) do
		if g:IsA("BasePart") then
			local open = state.Tool >= (g:GetAttribute("RequiredTier") or 1)
			if g:GetAttribute("Sign") then
				for _, b in ipairs(g:GetChildren()) do
					if b:IsA("BillboardGui") then b.Enabled = not open end
				end
			else
				g.CanCollide = not open
				g.Transparency = open and 1 or 0.1
			end
		end
	end
end

---------------------------------------------------------------- sync
local lastTool, lastCoins = 0, 0
R.Sync.OnClientEvent:Connect(function(s)
	for k, v in pairs(s) do state[k] = v end
	coinsLbl.Text = "💰 " .. fmt(state.Coins)
	if state.Coins > lastCoins and lastCoins > 0 then
		TweenService:Create(coinsLbl, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), { Rotation = 3 }):Play()
	end
	lastCoins = state.Coins
	multLbl.Text = string.format("x%.2f coins", state.Mult)
	rebLbl.Text = "🌟 " .. state.Rebirths
	local ratio = math.clamp(state.Bag / math.max(1, state.Capacity), 0, 1)
	TweenService:Create(bagFill, TweenInfo.new(0.2), { Size = U2(ratio, 0, 1, 0), BackgroundColor3 = ratio >= 1 and rgb(240, 80, 60) or rgb(80, 200, 255) }):Play()
	bagLbl.Text = "🎒 " .. state.Bag .. " / " .. state.Capacity .. (ratio >= 1 and "  FULL!" or "")
	toolLbl.Text = "⛏ " .. Config.Tools[state.Tool].Name .. "  •  🐾 +" .. math.floor((state.PetBonus or 0) * 100) .. "%"
	qTitle.Text = "📜 Quest " .. state.QuestIndex
	qText.Text = state.Quest.Text or ""
	local qa = math.max(1, state.Quest.Amount or 1)
	local qp = math.min(state.QuestProgress, qa)
	qFill.Size = U2(qp / qa, 0, 1, 0)
	qProg.Text = fmt(qp) .. " / " .. fmt(qa) .. "  •  💰" .. fmt(state.Quest.Reward or 0)
	claimBtn.Visible = qp >= qa
	if state.Event then
		eventBanner.Visible = true
		eventBanner.Text = (state.Event == "OreRush" and "⚡ ORE RUSH x2 COINS" or "✨ SHINY STORM x5 SHINIES") .. "  •  " .. timeStr(state.EventLeft)
	else
		eventBanner.Visible = false
	end
	autoBtn.BackgroundColor3 = player:GetAttribute("AutoMine") and rgb(60, 190, 90) or rgb(90, 90, 110)
	sellBtn.Visible = state.Passes.VIP == true
	if state.Tool ~= lastTool then
		lastTool = state.Tool
		refreshGates()
	end
	for name, w in pairs(windows) do
		if w.Frame.Visible and refreshers[name] then refreshers[name]() end
	end
end)
player:GetAttributeChangedSignal("AutoMine"):Connect(function()
	autoBtn.BackgroundColor3 = player:GetAttribute("AutoMine") and rgb(60, 190, 90) or rgb(90, 90, 110)
	toast(player:GetAttribute("AutoMine") and "🤖 Auto Mine ON" or "🤖 Auto Mine OFF", "buy")
end)

---------------------------------------------------------------- mining
local holding = false
local lastSwing = 0
local hover
local hl = Instance.new("Highlight")
hl.FillTransparency = 1
hl.OutlineColor = rgb(255, 240, 120)
hl.DepthMode = Enum.HighlightDepthMode.Occluded

local function mineableFrom(inst)
	while inst and inst ~= workspace do
		if inst:IsA("Model") and (inst.Parent == OresFolder or inst:GetAttribute("Boss")) then return inst end
		inst = inst.Parent
	end
	return nil
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function nearestOre(maxDist)
	local r = root()
	if not r then return nil end
	local best, bd = nil, maxDist
	for _, m in ipairs(OresFolder:GetChildren()) do
		local pp = m.PrimaryPart
		if pp and (m:GetAttribute("Tier") or 1) <= state.Tool then
			local d = (pp.Position - r.Position).Magnitude - pp.Size.X / 2
			if d < bd then best, bd = m, d end
		end
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("Boss") then
			local d = (m:GetPivot().Position - r.Position).Magnitude - 10
			if d < bd then best, bd = m, d end
		end
	end
	return best
end

local function inRange(m)
	local r = root()
	if not r or not m or not m.Parent then return false end
	if m:GetAttribute("Boss") then return (m:GetPivot().Position - r.Position).Magnitude < 28 end
	local pp = m.PrimaryPart
	return pp and (pp.Position - r.Position).Magnitude <= Config.MineRange + pp.Size.X - 1
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = true
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

local function swingTool()
	local c = player.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	if not t or not t:GetAttribute("MineTool") then return false end
	if not t:GetAttribute("BaseGrip") then t:SetAttribute("BaseGrip", t.Grip) end
	local base = t:GetAttribute("BaseGrip")
	t.Grip = base * CFrame.Angles(math.rad(-70), 0, 0)
	task.delay(0.12, function() if t.Parent then t.Grip = base end end)
	return true
end

RunService.RenderStepped:Connect(function()
	-- hover highlight
	local target = mineableFrom(mouse.Target)
	if target ~= hover then
		hover = target
		hl.Adornee = target
		hl.Parent = target and workspace.CurrentCamera or nil
	end
	local auto = player:GetAttribute("AutoMine")
	if not holding and not auto then return end
	local tool = Config.Tools[state.Tool]
	if os.clock() - lastSwing < tool.Cooldown then return end
	if state.Bag >= state.Capacity and not (target and target:GetAttribute("Boss")) then
		if holding and os.clock() - lastFullToast > 4 then lastFullToast = os.clock() toast("🎒 Backpack full! Go to a 💰 Sell pad", "full") end
		return
	end
	local chosen = (target and inRange(target)) and target or nil
	if not chosen then
		chosen = nearestOre(Config.MineRange)
		if chosen and not inRange(chosen) then chosen = nil end
	end
	if not chosen then return end
	if not swingTool() then return end
	lastSwing = os.clock()
	R.Mine:FireServer(chosen)
end)

---------------------------------------------------------------- hit effects
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace.CurrentCamera

local function damageNumber(pos, dmg, crit)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = V3(0.2, 0.2, 0.2), Position = pos + V3(math.random() * 2 - 1, 0, math.random() * 2 - 1) }, fxFolder)
	local bb = new("BillboardGui", { Size = U2(0, crit and 110 or 80, 0, crit and 50 or 36), AlwaysOnTop = true, LightInfluence = 0 }, p)
	local l = label(bb, (crit and "CRIT " or "") .. fmt(dmg), U2(1, 0, 1, 0), nil, crit and rgb(255, 90, 60) or rgb(255, 255, 255))
	l.TextStrokeTransparency = 0
	TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = p.Position + V3(0, 4, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 0.85)
end

local function flyingChunks(pos, color)
	local r = root()
	for k = 1, 7 do
		local c = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Size = V3(0.7, 0.7, 0.7), Color = color or rgb(200, 200, 200), Material = Enum.Material.Neon, CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) }, fxFolder)
		local burst = pos + V3(math.random(-5, 5), math.random(2, 6), math.random(-5, 5))
		local t1 = TweenService:Create(c, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = burst })
		t1:Play()
		task.delay(0.25 + k * 0.03, function()
			local rr = root()
			if rr and c.Parent then
				TweenService:Create(c, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = rr.Position, Size = V3(0.2, 0.2, 0.2) }):Play()
			end
			Debris:AddItem(c, 0.35)
		end)
	end
end

local camShake = 0
R.HitFx.OnClientEvent:Connect(function(pos, dmg, crit, broke, color)
	damageNumber(pos, dmg, crit)
	if broke then
		play("Break")
		flyingChunks(pos, color)
		camShake = math.max(camShake, 0.15)
	else
		play("Hit")
		if crit then camShake = math.max(camShake, 0.1) end
	end
end)

---------------------------------------------------------------- boss
R.Boss.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "spawn" then
		bossBar.Visible = true
		bossFill.Size = U2((bossFillMax.X.Scale) * (a / b), bossFillMax.X.Offset * (a / b), bossFillMax.Y.Scale, bossFillMax.Y.Offset)
		bossLbl.Text = "⚔ " .. Config.Boss.Name .. "  " .. fmt(a) .. " / " .. fmt(b)
	elseif kind == "hp" then
		local ratio = math.clamp(a / b, 0, 1)
		TweenService:Create(bossFill, TweenInfo.new(0.15), { Size = U2(bossFillMax.X.Scale * ratio, bossFillMax.X.Offset * ratio, bossFillMax.Y.Scale, bossFillMax.Y.Offset) }):Play()
		bossLbl.Text = "⚔ " .. Config.Boss.Name .. "  " .. fmt(a) .. " / " .. fmt(b)
	elseif kind == "slam" then
		local r = root()
		if r and (r.Position - a).Magnitude < 32 then
			camShake = 0.6
			local away = (r.Position - a) * V3(1, 0, 1)
			if away.Magnitude < 0.1 then away = V3(1, 0, 0) end
			r.AssemblyLinearVelocity = away.Unit * 70 + V3(0, 45, 0)
		end
		-- shockwave ring
		local ring = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Size = V3(0.5, 4, 4), CFrame = CFrame.new(a + V3(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(255, 150, 80), Material = Enum.Material.Neon, Transparency = 0.2 }, fxFolder)
		TweenService:Create(ring, TweenInfo.new(0.6), { Size = V3(0.5, 64, 64), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.7)
	else
		bossBar.Visible = false
		if kind == "dead" then camShake = 0.5 end
	end
end)

---------------------------------------------------------------- zone ambience + locked-zone guard
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChild("ZoneColor")
local currentZone = -1
local weather = new("Part", { Name = "Weather", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = V3(80, 1, 80) }, fxFolder)
local weatherFx = {
	Frozen = new("ParticleEmitter", { Enabled = false, Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 120, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(6, 9), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), Size = NumberSequence.new(0.35), Color = ColorSequence.new(rgb(255, 255, 255)), Acceleration = V3(2, 0, 1) }, weather),
	Volcano = new("ParticleEmitter", { Enabled = false, Texture = "rbxasset://textures/particles/fire_main.dds", Rate = 40, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(0.4), LightEmission = 1, Color = ColorSequence.new(rgb(255, 150, 40), rgb(255, 60, 0)), Acceleration = V3(0, 3, 0) }, weather),
	Grotto = new("ParticleEmitter", { Enabled = false, Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 30, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.5, 1.5), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.3), LightEmission = 1, Color = ColorSequence.new(rgb(200, 140, 255), rgb(90, 220, 255)) }, weather),
	Void = new("ParticleEmitter", { Enabled = false, Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 50, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.3, 1), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.5), LightEmission = 1, Color = ColorSequence.new(rgb(255, 255, 255), rgb(190, 120, 255)) }, weather),
	Meadow = new("ParticleEmitter", { Enabled = false, Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 8, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25), LightEmission = 1, Color = ColorSequence.new(rgb(255, 255, 150)) }, weather),
}

local function applyZone(z)
	local ambience = z == 0 and Config.HubAmbience or Config.Zones[z].Ambience
	local ti = TweenInfo.new(2)
	if atmosphere then TweenService:Create(atmosphere, ti, { Density = ambience.Density, Color = ambience.Fog, Haze = ambience.Haze }):Play() end
	if cc then TweenService:Create(cc, ti, { TintColor = ambience.Tint, Brightness = ambience.Brightness, Saturation = ambience.Saturation, Contrast = ambience.Contrast }):Play() end
	TweenService:Create(Lighting, ti, { ClockTime = ambience.ClockTime, Ambient = ambience.Ambient, OutdoorAmbient = ambience.Ambient }):Play()
	local kind = z > 0 and Config.Zones[z].Kind or ""
	for k, e in pairs(weatherFx) do e.Enabled = (k == kind) end
	-- banner
	zoneBanner.Text = z == 0 and "🏘 Miner's Town" or Config.Zones[z].Name
	zoneSub.Text = z == 0 and "Shops • Eggs • Quests • Rebirth" or ("Ores: " .. Config.Zones[z].Ores[1].Name .. ", " .. Config.Zones[z].Ores[2].Name .. ", " .. Config.Zones[z].Ores[3].Name)
	for _, l in ipairs({ zoneBanner, zoneSub }) do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.3
	end
	task.delay(2.5, function()
		for _, l in ipairs({ zoneBanner, zoneSub }) do
			TweenService:Create(l, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local guardCooldown = 0
task.spawn(function()
	while true do
		task.wait(0.4)
		local r = root()
		if r then
			local z = Config.ZoneAt(r.Position)
			if z > 0 and state.Tool < Config.Zones[z].RequiredTier and os.clock() > guardCooldown then
				guardCooldown = os.clock() + 2
				local sp = World.Spawns:FindFirstChild("Zone0")
				if sp then player.Character:PivotTo(CFrame.new(sp.Position + V3(0, 3, 0))) end
				toast("🔒 " .. Config.Zones[z].Name .. " needs the " .. Config.Tools[Config.Zones[z].RequiredTier].Name, "error")
				z = 0
			end
			if z ~= currentZone then
				currentZone = z
				applyZone(z)
			end
			weather.Position = r.Position + V3(0, 25, 0)
		end
	end
end)

---------------------------------------------------------------- pets following players
local petModels = {} -- [player] = { list of parts }
local function buildPet(def)
	local m = ModelLibrary.BuildPet(def, Config)
	m.Parent = fxFolder
	return m
end

local function rebuildPets(p)
	if petModels[p] then
		for _, m in ipairs(petModels[p]) do m:Destroy() end
	end
	petModels[p] = {}
	local ok, names = pcall(function() return HttpService:JSONDecode(p:GetAttribute("Pets") or "[]") end)
	if not ok then return end
	for _, n in ipairs(names) do
		local def = Config.PetByName[n]
		if def then table.insert(petModels[p], buildPet(def)) end
	end
end

local function watchPlayer(p)
	rebuildPets(p)
	p:GetAttributeChangedSignal("Pets"):Connect(function() rebuildPets(p) end)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p)
	if petModels[p] then for _, m in ipairs(petModels[p]) do m:Destroy() end end
	petModels[p] = nil
end)

---------------------------------------------------------------- spinning / bobbing decor
local spinners = {}
local function addSpinner(inst)
	local base = inst:IsA("Model") and inst:GetPivot() or (inst:IsA("BasePart") and inst.CFrame)
	if base then table.insert(spinners, { Inst = inst, Base = base }) end
end
for _, s in ipairs(World:WaitForChild("Spin"):GetChildren()) do addSpinner(s) end
World.Spin.ChildAdded:Connect(function(s) task.wait() addSpinner(s) end)

---------------------------------------------------------------- guide beam (new players)
local guideAtt0 = Instance.new("Attachment")
local guideTarget = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = V3(1, 1, 1) }, fxFolder)
local guideAtt1 = new("Attachment", {}, guideTarget)
local guideBeam = new("Beam", { Attachment0 = guideAtt0, Attachment1 = guideAtt1, Width0 = 1.2, Width1 = 1.2, FaceCamera = true, LightEmission = 1, Color = ColorSequence.new(rgb(255, 230, 90)), Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureMode = Enum.TextureMode.Static, TextureLength = 3, TextureSpeed = 2, Transparency = NumberSequence.new(0.3), Enabled = false }, guideTarget)

local places = {
	tool = V3(-38, 18, 4), backpack = V3(38, 18, 4), hatch = V3(0, 18, -40),
	boss = Config.ArenaCenter + V3(0, 3, 0), rebirth = V3(30, 18, -32),
}
local function nearestSellPad(from)
	local best, bd = nil, math.huge
	for _, p in ipairs(World.SellPads:GetChildren()) do
		local d = (p.Position - from).Magnitude
		if d < bd then best, bd = p, d end
	end
	return best and best.Position + V3(0, 2, 0)
end
local function oreZone(name)
	for i, z in ipairs(Config.Zones) do
		for _, o in ipairs(z.Ores) do if o.Name == name then return i end end
	end
	return 1
end
local function guidePoint(r)
	if state.QuestIndex > Config.GuideUntilQuest then return nil end
	if state.Bag >= state.Capacity then return nearestSellPad(r.Position) end
	local q = state.Quest
	if state.QuestProgress >= (q.Amount or 1) then return V3(14, 18, 26) end
	if q.Type == "earn" then
		if state.Bag > 0 then return nearestSellPad(r.Position) end
		q = { Type = "mine" }
	end
	if places[q.Type] then return places[q.Type] end
	if q.Type == "mine" or q.Type == "shiny" then
		local z = q.Target and oreZone(q.Target) or 1
		if Config.ZoneAt(r.Position) == z then
			local o = nearestOre(250)
			return o and o.PrimaryPart and o.PrimaryPart.Position
		end
		local sp = World.Spawns:FindFirstChild("Zone" .. z)
		return sp and sp.Position
	end
	return nil
end

local guideTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	-- spinners
	for _, s in ipairs(spinners) do
		local inst = s.Inst
		if inst.Parent then
			local sx, sy, sz = inst:GetAttribute("SpinX") or 0, inst:GetAttribute("SpinY") or 0, inst:GetAttribute("SpinZ") or 0
			local bob = inst:GetAttribute("Bob") or 0
			local cf = s.Base * CFrame.new(0, math.sin(t * 1.5) * bob, 0) * CFrame.Angles(t * sx, t * sy, t * sz)
			if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
		end
	end
	-- pets
	for p, list in pairs(petModels) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			for k, m in ipairs(list) do
				local a = (k - (#list + 1) / 2) * 0.7
				local back = r.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 5.5)
				local goal = CFrame.new(back.Position + V3(0, math.sin(t * 3 + k) * 0.4 - 0.5, 0)) * r.CFrame.Rotation
				local cur = m:GetPivot()
				local nextCf = cur:Lerp(goal, math.clamp(dt * 8, 0, 1))
				if (cur.Position - goal.Position).Magnitude > 60 then nextCf = goal end
				m:PivotTo(nextCf)
				ModelLibrary.AnimatePet(m, nextCf, t + k)
			end
		end
	end
	-- camera shake
	if camShake > 0 then
		camShake = math.max(0, camShake - dt)
		local m = camShake * 0.6
		camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * m * 0.1, (math.random() - 0.5) * m * 0.1, 0)
	end
	-- guide beam
	guideTimer += dt
	if guideTimer > 0.3 then
		guideTimer = 0
		local r = root()
		local gp = r and guidePoint(r)
		if gp and (gp - r.Position).Magnitude > 10 then
			guideAtt0.Parent = r
			guideTarget.Position = gp + V3(0, 2, 0)
			guideBeam.Enabled = true
		else
			guideBeam.Enabled = false
		end
	end
end)

---------------------------------------------------------------- start
refreshGates()
R.Action:FireServer("Ready")
toast("⛏ Welcome to Mine Rush! Hold click on ores to mine. F = Shop, M = Map, P = Pets", "info")
