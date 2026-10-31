-- Eventos (cliente): la tarjeta "Welcome back" de la esquina (Aspiradora de almas y ganancias mientras no
-- estabas), el "+N" de la aspiradora y sus almas girando, la Noche de Sangre (cielo rojo, luna de sangre, aviso y
-- cuenta atrás), el aviso de valentía al visitar una casa y la corona de la Casa del día (gira y flota).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Portada = require(script.Parent:WaitForChild("Portada"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer
local new, round = UI.new, UI.round
local Houses = workspace:WaitForChild("Casas")
local BLOOD = Color3.fromRGB(235, 36, 54)

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- lo que llega en la portada o mientras otra pantalla grande está abierta, cuando ya se juega
local function whenPlaying(f)
	task.spawn(function()
		repeat
			task.wait(0.3)
		until not Portada.active and UI.gui.Enabled
		f()
	end)
end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then
		return ("%dh %02dm"):format(s // 3600, s % 3600 // 60)
	end
	return ("%d:%02d"):format(s // 60, s % 60)
end

-- "2h 05m", "45m 30s", "20s": cuánto tiempo has estado fuera
local function fmtAway(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then
		return ("%dh %02dm"):format(s // 3600, s % 3600 // 60)
	elseif s >= 60 then
		return ("%dm %02ds"):format(s // 60, s % 60)
	end
	return s .. "s"
end

---------- Welcome back: tarjeta pequeña en la esquina de abajo a la derecha ----------
-- Entra deslizándose, la cifra sube con tic-tac de monedas y se recoge sola al vaciarse la barra (o con COLLECT).
local WB_TIME = 10
local wb = new("ScreenGui", {Name = "Bienvenida", ResetOnSpawn = false, DisplayOrder = 9, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local slot = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(392, 108), BackgroundTransparency = 1}, wb)
local cardScale = new("UIScale", {}, slot)
local card = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = false}, slot), 18)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(66, 44, 104), Color3.fromRGB(30, 18, 52))}, card)
new("UIStroke", {Color = UI.INK, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, card)
local bevel = round(new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1}, card), 14)
new("UIStroke", {Color = Color3.fromRGB(255, 214, 110), Thickness = 2, Transparency = 0.45}, bevel)
-- brillo de cristal en la mitad de arriba (como los botones del menú)
local shine = round(new("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.45, 0), BackgroundColor3 = UI.WHITE, BorderSizePixel = 0, ZIndex = 1}, card), 14)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0.88, 1)}, shine)
-- la moneda que asoma por la izquierda, con rayos dorados detrás
local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 46, 0.5, 0), Size = UDim2.fromOffset(150, 150), ImageColor3 = UI.GOLD, ImageTransparency = 0.45, ZIndex = 2}, card)
UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 46, 0.5, 0), Size = UDim2.fromOffset(120, 120), ImageColor3 = Color3.fromRGB(255, 200, 80), ImageTransparency = 0.35, ZIndex = 2}, card)
local bigCoin = UI.art("coin", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 46, 0.5, 0), Size = UDim2.fromOffset(74, 74), ZIndex = 4}, card)
local wbTitle = new("TextLabel", {
	Position = UDim2.fromOffset(92, 10), Size = UDim2.fromOffset(170, 22), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = UI.WHITE, Text = "WELCOME BACK!", ZIndex = 4,
}, card)
new("UIStroke", {Color = UI.INK, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round}, wbTitle)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 244, 200), UI.GOLD)}, wbTitle)
local wbAmount = new("TextLabel", {
	Position = UDim2.fromOffset(92, 32), Size = UDim2.fromOffset(170, 40), BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 220, 80), Text = "+0", ZIndex = 4,
}, card)
new("UIStroke", {Color = UI.INK, Thickness = 3.5, LineJoinMode = Enum.LineJoinMode.Round}, wbAmount)
local amountPop = new("UIScale", {}, wbAmount)
local wbSub = new("TextLabel", {
	Position = UDim2.fromOffset(92, 74), Size = UDim2.fromOffset(180, 18), BackgroundTransparency = 1, Font = UI.FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = UI.MUTED, TextStrokeTransparency = 0, Text = "", ZIndex = 4,
}, card)
local collect = UI.button({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -3), Size = UDim2.fromOffset(112, 52), BackgroundColor3 = UI.BUY, Text = "COLLECT",
	Font = UI.TITLE, TextSize = 21, ZIndex = 5,
}, card)
-- barra que se vacía: al llegar a cero se recoge sola
local track = round(new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -36, 0, 5), BackgroundColor3 = Color3.fromRGB(16, 8, 28), BackgroundTransparency = 0.2, ZIndex = 4}, card), UDim.new(1, 0))
local timer = round(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.GOLD, ZIndex = 5}, track), UDim.new(1, 0))

local shownAmount, wbBusy, wbToken = 0, false, 0
RunService.RenderStepped:Connect(function()
	if wb.Enabled then
		rays.Rotation = os.clock() * 30
		bigCoin.Rotation = math.sin(os.clock() * 3) * 12
	end
end)

local queue = {}
local closeWelcome
local function showWelcome(amount, seconds, offline)
	if wbBusy then
		return table.insert(queue, {amount, seconds, offline})
	end
	wbBusy = true
	wbToken += 1
	local token = wbToken
	wbSub.Text = (offline and "Offline earnings · %s" or "Soul Vacuum · away %s"):format(fmtAway(seconds))
	wbAmount.Text = "+0"
	wb.Enabled = true
	-- entra desde la derecha con rebote
	slot.Position = UDim2.new(1, 440, 1, -16)
	tween(slot, 0.5, {Position = UDim2.new(1, -16, 1, -16)}, Enum.EasingStyle.Back)
	timer.Size = UDim2.fromScale(1, 1)
	tween(timer, WB_TIME, {Size = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Linear)
	task.delay(WB_TIME, function()
		if wbToken == token then
			closeWelcome()
		end
	end)
	UI.sound("Win", 0.6)
	-- la cifra sube hasta el total, cada vez más despacio, con tic-tac de monedas
	task.spawn(function()
		local t0, dur = os.clock(), math.clamp(0.8 + math.log10(math.max(10, amount)) * 0.35, 1, 2.2)
		local last = 0
		while os.clock() - t0 < dur and wbToken == token do
			local a = 1 - (1 - (os.clock() - t0) / dur) ^ 3
			shownAmount = math.floor(amount * a)
			wbAmount.Text = "+" .. UI.fmt(shownAmount)
			if os.clock() - last > 0.08 then
				last = os.clock()
				UI.sound("Coin", 0.4, 0.9 + a * 0.8)
			end
			RunService.RenderStepped:Wait()
		end
		if wbToken ~= token then
			return
		end
		wbAmount.Text = "+" .. UI.fmt(amount)
		amountPop.Scale = 1.25
		tween(amountPop, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		UI.sound("CoinTransfer")
	end)
end

function closeWelcome()
	if not wb.Enabled or not wbBusy then
		return
	end
	wbToken += 1
	UI.sound("Cash")
	local p = bigCoin.AbsolutePosition + bigCoin.AbsoluteSize / 2 + GuiService:GetGuiInset()
	UI.coinFly(Vector2.new(p.X, p.Y), 8)
	tween(slot, 0.3, {Position = UDim2.new(1, 440, 1, -16)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.32, function()
		wb.Enabled = false
		wbBusy = false
		local nxt = table.remove(queue, 1)
		if nxt then
			showWelcome(table.unpack(nxt))
		end
	end)
end
UI.showWelcome = showWelcome -- (Cliente: las ganancias mientras no estabas, al entrar)
collect.Activated:Connect(closeWelcome)
UI.uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
	cardScale.Scale = UI.uiScale.Scale
end)
cardScale.Scale = UI.uiScale.Scale

---------- Aspiradora: "+N" sobre ella, las almas que giran y la celebración al conseguirla ----------
local function myVacuum()
	local plot = player:GetAttribute("Plot")
	local h = plot and Houses:FindFirstChild("Casa" .. plot)
	return h and h:FindFirstChild("Aspiradora")
end
local function vacuumPop(n)
	local vac = myVacuum()
	local tank = vac and vac:FindFirstChild("Tank", true)
	if not tank then
		return
	end
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(200, 50), StudsOffsetWorldSpace = Vector3.new(0, 2, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120}, tank)
	local l = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = UI.TITLE, TextScaled = true, TextColor3 = UI.GOLD, Text = "+" .. UI.fmt(n)}, bb)
	new("UIStroke", {Color = UI.INK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round}, l)
	tween(bb, 1.2, {StudsOffsetWorldSpace = Vector3.new(0, 5, 0)})
	tween(l, 1.2, {TextTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.25, bb.Destroy, bb)
	UI.sound("CoinTransfer", 0.7, 1.1)
	UI.punchMoney(0.6)
end

-- almas que dan vueltas dentro del tanque (más deprisa cuanto más lleno está el depósito)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, h in Houses:GetChildren() do
		local vac = h:FindFirstChild("Aspiradora")
		local center = vac and vac:GetAttribute("SoulCenter")
		if center then
			local c = vac:GetPivot() * center
			local speed = 2.2 + math.min(4, (h:GetAttribute("Tank") or 0) / 400)
			for _, o in vac:GetChildren() do
				local k = o:GetAttribute("Orbit")
				if k then
					local a = t * speed + k * 2.094
					o.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 0.45, math.sin(t * 2 + k) * 0.3, math.sin(a) * 0.45))
				end
			end
		end
	end
	-- corona de la Casa del día: gira y flota
	for _, m in CollectionService:GetTagged("SpinCrown") do
		local base = m:GetAttribute("Base")
		if not base then
			base = m:GetPivot()
			m:SetAttribute("Base", base)
		end
		m:PivotTo(base * CFrame.new(0, math.sin(t * 1.6) * 0.8, 0) * CFrame.Angles(0, t * 0.8, math.rad(8) * math.sin(t)))
	end
end)

---------- Noche de Sangre ----------
local pill = round(new("Frame", {
	Name = "BloodNight", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.new(1, 1, 1), Visible = false,
}, UI.gui), UDim.new(1, 0))
local pillGrad = new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 22, 34), Color3.fromRGB(28, 8, 16))}, pill)
local pillStroke = new("UIStroke", {Color = UI.INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, pill)
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 16)}, pill)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, pill)
local moonDisc = round(new("Frame", {Size = UDim2.fromOffset(30, 30), BackgroundColor3 = BLOOD, LayoutOrder = 1}, pill), UDim.new(1, 0))
UI.stroke(moonDisc, UI.INK, 2)
UI.icon("moon", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26)}, moonDisc)
local pillText = new("TextLabel", {
	Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = UI.TITLE, TextSize = 20, TextColor3 = UI.WHITE,
	TextStrokeTransparency = 0, RichText = true, Text = "", LayoutOrder = 2,
}, pill)
new("UIPadding", {PaddingTop = UDim.new(0, 4)}, pillText)
local pillPop = new("UIScale", {}, pill)

-- cielo rojo: corrector de color propio, la atmósfera teñida y una luna de sangre enorme
local grade = Lighting:FindFirstChild("BloodGrade") or new("ColorCorrectionEffect", {Name = "BloodGrade", Enabled = true}, Lighting)
grade.TintColor, grade.Saturation, grade.Contrast = Color3.new(1, 1, 1), 0, 0
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local atmoBase = atmo and {Color = atmo.Color, Decay = atmo.Decay, Haze = atmo.Haze}
local moon = new("Part", {
	Name = "LunaDeSangre", Shape = Enum.PartType.Ball, Size = Vector3.one * 190, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	CastShadow = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 40, 44), Transparency = 1, Position = Vector3.new(-420, 330, -760),
}, workspace)
-- halo rojo alrededor de la luna (detrás de ella) y manchas oscuras como cráteres
local moonGlow = new("BillboardGui", {Size = UDim2.fromOffset(900, 900), LightInfluence = 0, MaxDistance = 1e5, Enabled = false, AlwaysOnTop = false}, moon)
UI.piece("glow2", {Size = UDim2.fromScale(1, 1), ImageColor3 = Color3.fromRGB(255, 40, 50), ImageTransparency = 0.15}, moonGlow)
local craters = {}
for k, c in {{Vector3.new(-30, 40, 0), 46}, {Vector3.new(38, -12, 0), 32}, {Vector3.new(-12, -48, 0), 26}} do
	local p = new("Part", {
		Name = "Crater", Shape = Enum.PartType.Ball, Size = Vector3.one * c[2], Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(150, 16, 24), Transparency = 1,
	}, moon)
	craters[k] = {part = p, off = c[1]}
end
RunService.RenderStepped:Connect(function()
	if moon.Transparency < 1 then
		-- los cráteres, en la cara que mira a la cámara
		local cam = workspace.CurrentCamera.CFrame
		local face = CFrame.lookAt(moon.Position, cam.Position)
		for _, c in craters do
			c.part.Position = (face * CFrame.new(c.off.X, c.off.Y, -moon.Size.X * 0.42)).Position
			c.part.Transparency = moon.Transparency
		end
	end
end)
local bloodShown = nil
local function setBlood(on, instant)
	if bloodShown == on then
		return
	end
	bloodShown = on
	local t = instant and 0 or 3
	tween(grade, t, on and {TintColor = Color3.fromRGB(255, 176, 176), Saturation = 0.15, Contrast = 0.08} or {TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0})
	if atmo then
		tween(atmo, t, on and {Color = Color3.fromRGB(150, 40, 50), Decay = Color3.fromRGB(90, 14, 24), Haze = math.max(atmoBase.Haze, 1.6)} or atmoBase)
	end
	tween(moon, t, {Transparency = on and 0 or 1})
	moonGlow.Enabled = on
	if on and not instant then
		whenPlaying(function()
			UI.big("BLOOD NIGHT!", ("Visitors x%d  ·  Mythic luck x%d  ·  Coins x%g"):format(Config.BLOOD_RATE, Config.BLOOD_LUCK, Config.BLOOD_COINS), BLOOD, 4)
			UI.sound("Thunder", 1.2)
			UI.sound("Boom", 0.8)
			UI.flash(BLOOD, 0.3, 1.2)
			UI.duck(0.25, 3)
		end)
	elseif not on and not instant then
		UI.toast("The Blood Night is over... until next hour", UI.ORANGE, "moon")
	end
end

local warned = false
task.spawn(function()
	setBlood(Config.bloodNight(workspace:GetServerTimeNow()), true)
	while true do
		local now = workspace:GetServerTimeNow()
		local on, at = Config.bloodNight(now)
		setBlood(on)
		local left = at - now
		-- en partida del Tower Defense manda su HUD
		-- (y con una pantalla grande abierta, Catalog esconde la columna del menú: tampoco se enseña)
		local inTD = player:GetAttribute("TDCash") ~= nil or (UI.side and not UI.side.Visible)
		if on then
			pill.Visible = not inTD
			pillText.Text = ("BLOOD NIGHT  <font color=\"#FFD860\">%s</font>  ·  Visitors x%d · Luck x%d"):format(fmtTime(left), Config.BLOOD_RATE, Config.BLOOD_LUCK)
			pillGrad.Color = ColorSequence.new(Color3.fromRGB(196, 30, 48), Color3.fromRGB(96, 8, 22))
			pillStroke.Color = Color3.fromRGB(255, 150, 150)
			pillPop.Scale = 1 + 0.05 * math.abs(math.sin(os.clock() * 3))
			warned = false
		else
			-- los últimos 10 minutos, la cuenta atrás
			pill.Visible = left <= 600 and not inTD
			pillText.Text = ("Blood Night in <font color=\"#FF6A78\">%s</font>"):format(fmtTime(left))
			pillGrad.Color = ColorSequence.new(Color3.fromRGB(70, 22, 34), Color3.fromRGB(28, 8, 16))
			pillStroke.Color = UI.INK
			pillPop.Scale = 1
			if left <= 60 and not warned then
				warned = true
				whenPlaying(function()
					UI.toast("The Blood Night rises in 1 minute! Get your house ready", BLOOD, "moon")
					UI.sound("Bell")
				end)
			end
		end
		task.wait(on and 0.05 or 0.5)
	end
end)

---------- Mensajes del servidor ----------
Remote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "WelcomeBack" then
		whenPlaying(function()
			showWelcome(a, b, false)
		end)
	elseif kind == "Vacuum" then
		vacuumPop(a)
	elseif kind == "VacuumGot" then
		UI.notice("SOUL VACUUM", "It now collects every coin in your house for you", Color3.fromRGB(120, 255, 160), "ghost", 4)
		UI.sound("Success")
		UI.sound("Sparkle")
		UI.confetti(40)
	elseif kind == "VacuumAnnounce" then
		if a ~= player.DisplayName then
			UI.toast(("%s got the Soul Vacuum!"):format(a), Color3.fromRGB(120, 255, 160), "ghost")
			UI.sound("Jingle")
		end
	elseif kind == "Brave" then
		if a >= Config.PLAYER_MAX_LEVEL then
			UI.toast(("Level %d: fearless! No house can make you faint"):format(a), UI.GOLD, "shield")
		else
			UI.toast(("Level %d bravery: you only feel %d%% of the fear"):format(a, math.floor(b * 100 + 0.5)), UI.GOLD, "shield")
		end
	end
end)
