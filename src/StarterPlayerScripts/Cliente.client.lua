-- Tu Casa Encantada (cliente): une la portada, el tutorial de Don Calabaza, la interfaz, el modo edición
-- (dentro de tu casa), las visitas y el ambiente.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Remote = RS:WaitForChild("Remote")
local Assets = RS:WaitForChild("Assets")
local UI = require(script.Parent:WaitForChild("UI"))
local Build = require(script.Parent:WaitForChild("Build"))
local Visit = require(script.Parent:WaitForChild("Visit"))
local Portada = require(script.Parent:WaitForChild("Portada"))
local Tutorial = require(script.Parent:WaitForChild("Tutorial"))
local Musica = require(script.Parent:WaitForChild("Musica"))
local Sfx = require(RS:WaitForChild("Sfx"))
require(script.Parent:WaitForChild("Portales")) -- portales de las puertas: brillo y animación al cruzarlos
require(script.Parent:WaitForChild("NPCAnim")) -- animaciones de los bots visitantes (diseño en Claude Design)
require(script.Parent:WaitForChild("Llamas")) -- las llamas de los faroles se mecen y titilan
local Monedas = require(script.Parent:WaitForChild("Monedas")) -- monedas que sueltan los visitantes asustados
local player = Players.LocalPlayer
local Houses = workspace:WaitForChild("Casas")

-- Aviso de arriba fuera de casa: el de la calle o, al cruzar el puente, el de la explanada del Tower Defense
local TD_EDGE = 172 -- el barranco entre la calle y la explanada (Mapa.Limites.BarrancoEste*)
local hintZone
local function townHint()
	-- en plena partida del Tower Defense manda su HUD (el aviso tapaba el marcador)
	if player:GetAttribute("TDCash") ~= nil then
		hintZone = nil
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = root and root.Position.X > TD_EDGE and "td" or "town"
	if zone == hintZone then
		return
	end
	hintZone = zone
	if zone == "td" then
		UI.setHint("Tower Defense", "Walk into a lobby to team up  ·  Your scares are the troops!", "skull")
	else
		UI.setHint("Explore the street", "Scared visitors drop coins in your house  ·  Survive a neighbor's house for a bravery bonus!", "house")
	end
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if player:GetAttribute("Mode") == nil then
			townHint()
		end
	end
end)

local function myHouse()
	local plot = player:GetAttribute("Plot")
	return plot and Houses:FindFirstChild("Casa" .. plot)
end

local function refresh()
	UI.refreshBuild(player:GetAttribute("Placed") or 0, player:GetAttribute("Rooms") or 1, player:GetAttribute("Spaces"))
	UI.refreshHouses()
end

---------- Modos: calle / en casa (edición) / visita ----------
local mode = "none"
local function applyMode()
	local new = player:GetAttribute("Mode")
	if new == mode then
		return
	end
	local old = mode
	mode = new
	UI.reverb(new == "home" or new == "visit") -- dentro de una casa, eco de sala
	if old == "home" then
		Build.exit()
	end
	if old == "visit" then
		Visit.stop()
	end
	if new == "home" then
		local h = myHouse()
		if h then
			Build.enter(h)
		end
		refresh()
	elseif new == nil then
		UI.menu.Visible = true
		hintZone = nil
		townHint()
	end
end
player:GetAttributeChangedSignal("Mode"):Connect(applyMode)

player.AttributeChanged:Connect(function(name)
	if name ~= "Mode" and name ~= "Fear" then
		refresh()
	end
end)

---------- Botones ----------
UI.shopButton.Activated:Connect(function()
	UI.toggleShop()
end)
UI.homeButton.Activated:Connect(function()
	if not player:GetAttribute("Plot") then
		return UI.toast("No free houses left on this server", UI.RED)
	end
	Remote:FireServer("GoHome")
end)
-- Atajos: teletransporte a la Ruleta y a los lobbies del Tower Defense, al instante (como My House). Los destinos los
-- pone el servidor en Workspace (TP_<sitio>); el servidor solo añade la nube de humo de salida y de llegada.
local TD = require(RS:WaitForChild("TowerDefense"))
local TRAVEL = {
	{order = 8, art = "wheelart", text = "Wheel", color = Color3.fromRGB(255, 80, 170), where = "wheel", arrive = "Wheel of Fright", icon = "wheel"},
	{order = 10, portrait = TD.mapInfo("ZombieHollow") and TD.mapInfo("ZombieHollow").image, text = "Defense", color = Color3.fromRGB(226, 60, 84),
		where = "td", arrive = "Tower Defense", icon = "swords"},
}
local lastTravel = 0
local function travel(d)
	if player:GetAttribute("Mode") then
		return UI.toast("Leave first, then teleport", UI.RED)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local to = workspace:GetAttribute("TP_" .. d.where)
	if not (root and hum and hum.Health > 0 and typeof(to) == "CFrame") or os.clock() - lastTravel < 0.6 then
		return
	end
	lastTravel = os.clock()
	Remote:FireServer("GoTo", d.where, root.Position)
	-- (con StreamingEnabled: que el suelo de allí esté cargado antes de aparecer; si ya lo está, no espera nada)
	pcall(player.RequestStreamAroundAsync, player, to.Position, 1)
	if not (root.Parent and hum.Health > 0) then
		return
	end
	hum.Sit = false
	char:PivotTo(to)
	root.AssemblyLinearVelocity = Vector3.zero
	UI.sound("Portal")
	UI.flash(d.color, 0.35, 0.5)
	UI.toast(d.arrive, d.color, d.icon)
end

for _, d in TRAVEL do
	local b = UI.menuButton(d.order, d.art or "wheel", d.text, d.color)
	if d.portrait then
		-- retrato redondo del mapa (dentro del icono, para que crezca con él al pasar el ratón)
		local ic = b:FindFirstChild("Icon")
		if ic then
			ic.ImageTransparency = 1
			local ring = UI.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8),
				BackgroundColor3 = d.color:Lerp(UI.WHITE, 0.35), ZIndex = ic.ZIndex}, ic)
			UI.new("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
			UI.new("UIStroke", {Color = UI.INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, ring)
			local photo = UI.new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -7, 1, -7),
				BackgroundTransparency = 1, Image = d.portrait, ScaleType = Enum.ScaleType.Crop, ZIndex = ic.ZIndex + 1}, ring)
			UI.new("UICorner", {CornerRadius = UDim.new(1, 0)}, photo)
			UI.icon("swords", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.8), Size = UDim2.fromScale(0.5, 0.5), ZIndex = ic.ZIndex + 2}, ring)
		end
	end
	-- rayito en la esquina: es un teletransporte
	local bolt = UI.icon("lightning", {Name = "Teleport", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(30, 30),
		Rotation = 12, ZIndex = 6}, b)
	task.spawn(function()
		local t0 = os.clock() + d.order
		while bolt.Parent do
			bolt.Rotation = 12 + math.sin((os.clock() - t0) * 3) * 8
			task.wait(1 / 30)
		end
	end)
	b.Activated:Connect(function()
		travel(d)
	end)
end
UI.helpButton.Activated:Connect(function()
	task.spawn(Tutorial.help)
end)
UI.rotateButton.Activated:Connect(Build.rotate)
UI.testButton.Activated:Connect(function()
	Remote:FireServer("Test")
end)
UI.buildShopButton.Activated:Connect(function()
	UI.toggleShop(true)
end)
UI.exitButton.Activated:Connect(function()
	Remote:FireServer("Exit")
end)
UI.leaveButton.Activated:Connect(function()
	Remote:FireServer("Exit")
end)
UI.lightButton.Activated:Connect(function()
	Visit.toggleLight()
end)
for t, slot in UI.slots do
	slot.button.MouseButton1Down:Connect(function()
		UI.hideTip()
		Build.startDrag(t, false)
	end)
end

---------- Mensajes del servidor ----------
local floaters = Instance.new("Folder")
floaters.Name = "Flotantes"
floaters.Parent = workspace -- creado en el cliente: solo lo ves tú
-- cada moneda seguida suena una nota más alta de la escala mayor: recoger un puñado "canta". Si llegan muchas a la
-- vez (vuelves a casa y te esperaban docenas), las notas se reparten en un arpegio rápido en vez de sonar todas juntas.
local SCALE = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19}
local streak, noteAt = 0, 0

-- "+12 💰" que sube desde el susto que ha funcionado
local function floatText(pos, text, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = pos
	p.Parent = floaters
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = p
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Font = UI.TITLE
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	label.Text = text
	label.Parent = bb
	local outline = UI.new("UIStroke", {Color = UI.INK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round}, label)
	TweenService:Create(outline, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
	TweenService:Create(label, TweenInfo.new(0.22, Enum.EasingStyle.Back), {Size = UDim2.fromScale(1, 1)}):Play() -- salta al aparecer
	TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {Position = pos + Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(p, 1.7)
end

-- Lo que llega mientras se ve la portada o se pasa a la calle se enseña cuando ya se juega
local function whenPlaying(f)
	task.spawn(function()
		repeat
			task.wait(0.5)
		until not Portada.active and UI.gui.Enabled
		task.wait(1.5)
		f()
	end)
end

Remote.OnClientEvent:Connect(function(kind, ...)
	local a, b, c, d, e = ...
	if kind == "Notice" then
		UI.toast(a, UI.GOLD, "bell")
		UI.sound("Jingle")
	elseif kind == "Reward" then
		-- premio a la valentía por llegar al fondo de una casa ajena (0 = esta casa ya te pagó hace poco)
		Visit.reward = a > 0 and a or nil
		if a > 0 then
			UI.sound("Cash")
		else
			UI.toast(("This house already paid you · again in %ds"):format(b), UI.ORANGE)
		end
	elseif kind == "Daily" then
		whenPlaying(function()
			UI.big("Daily reward!", ("Day %d streak  ·  +%d coins"):format(b, a), UI.GOLD, 3.5)
			UI.sound("Win")
			UI.sound("CoinTransfer")
			UI.flash(Color3.fromRGB(255, 220, 120), 0.6, 0.8)
			local vs = workspace.CurrentCamera.ViewportSize
			UI.coinFly(Vector2.new(vs.X / 2, vs.Y * 0.45), 10)
		end)
	elseif kind == "Offline" then
		-- ganancias mientras no estabas: la pantalla "Welcome back" (Eventos)
		whenPlaying(function()
			task.wait(3)
			if UI.showWelcome then
				UI.showWelcome(a, b * 60, true)
			end
		end)
	elseif kind == "Scared" then
		-- uno de tus sustos ha funcionado: su nombre (o el combo) sube desde él
		floatText(b, a, Color3.fromRGB(255, 240, 220))
	elseif kind == "Coin" then
		-- has recogido una moneda de tu casa
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			floatText(root.Position + Vector3.new(math.random() - 0.5, 3, math.random() - 0.5), ("+%d"):format(a), UI.GOLD)
			-- la moneda vuela de ti al contador
			local sp, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
			if onScreen then
				UI.coinFly(Vector2.new(sp.X, sp.Y), 1)
			end
		end
		UI.combo()
		Monedas.collected(a)
		local now = os.clock()
		if now - noteAt > 0.8 then
			streak = 0
		end
		if noteAt - now < 0.6 then -- como mucho unas 10 notas en cola
			noteAt = math.max(now, noteAt + 0.06)
			streak = math.min(streak + 1, #SCALE)
			task.delay(noteAt - now, UI.sound, "Coin", 1, 2 ^ (SCALE[streak] / 12))
			if streak == 1 then
				UI.sound("CoinTransfer")
			end
		end
	elseif kind == "Info" then
		UI.toast(a, UI.RED)
	elseif kind == "Bought" then
		UI.toast(("Bought: %s!"):format(b), UI.GREEN, "bag")
		UI.sound("Cash")
		UI.sound("CoinTransfer")
		UI.flash(UI.GREEN, 0.75, 0.4)
		UI.confetti(40)
		refresh()
	elseif kind == "Liked" then
		UI.toast(("You liked %s"):format(a), UI.GREEN, "thumb")
		UI.sound("Success")
	elseif kind == "GotLike" then
		UI.toast(("%s likes your house!"):format(a), UI.GOLD, "thumb")
		UI.sound("Jingle")
	elseif kind == "FX" then
		if a == "scare" then
			Visit.scare(b, c)
		elseif a == "fall" then
			Visit.fall()
		elseif a == "legend" then
			-- los sustos legendarios se presentan con su nombre en grande
			UI.big(string.upper(b), "LEGENDARY SCARE!", c, 1.6)
			UI.flash(c, 0.45, 0.7)
			UI.duck(0.2, 2)
		elseif a == "flash" then
			-- relámpago
			UI.flash(b, 0.1, 0.5)
			task.delay(0.12, UI.flash, b, 0.35, 0.4)
		end
	elseif kind == "VisitStart" then
		Visit.start(a, b, c, d, e)
	elseif kind == "VisitEnd" then
		Visit.finish(a)
	end
end)

---------- Dinero ----------
local dinero = player:WaitForChild("leaderstats"):WaitForChild("Coins")
UI.setMoney(dinero.Value, true)
dinero.Changed:Connect(function(v)
	UI.setMoney(v)
end)

---------- Flecha "TU CASA" (y sin 👍 en tu propio cartel) ----------
local function markHouse()
	local h = myHouse()
	local yard = h and h:FindFirstChild("Yard")
	if not yard then
		return
	end
	local board = yard:FindFirstChild("SignBoard")
	local likePrompt = board and board:FindFirstChild("LikePrompt")
	if likePrompt then
		likePrompt.Enabled = false
	end
	local sign = yard:FindFirstChild("Sign")
	if not sign or sign:FindFirstChild("Mine") then
		return
	end
	local bb = UI.new("BillboardGui", {Name = "Mine", Size = UDim2.fromOffset(220, 96), SizeOffset = Vector2.new(0, 1.1), AlwaysOnTop = true, LightInfluence = 0}, sign)
	local tag = UI.new("TextLabel", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = UI.TITLE, TextScaled = true, TextColor3 = UI.ORANGE, Text = "YOUR HOUSE"}, bb)
	UI.new("UIStroke", {Color = UI.INK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round}, tag)
	local arrow = UI.piece("arrow", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(46, 46), ImageColor3 = UI.ORANGE}, bb)
	-- la flecha bota
	task.spawn(function()
		while bb.Parent do
			arrow.Position = UDim2.new(0.5, 0, 0, 44 + math.abs(math.sin(os.clock() * 4)) * 6)
			task.wait()
		end
	end)
end
Houses.DescendantAdded:Connect(function(d)
	if d.Name == "Sign" or d.Name == "LikePrompt" then
		task.defer(markHouse)
	end
end)
player:GetAttributeChangedSignal("Plot"):Connect(function()
	markHouse()
	local h = myHouse()
	if h then
		h.AttributeChanged:Connect(refresh)
	end
end)

---------- Ambiente: viento, grillos, animales lejanos, truenos, luces que titilan y música ----------
-- Capas en bucle que se funden según dónde estés (ver el bucle de abajo)
local beds = {}
for _, name in {"Wind", "Crickets"} do
	local t = Assets.Sounds:FindFirstChild(name)
	if t then
		local s = t:Clone()
		s.Looped = true
		s.Parent = SoundService
		beds[name] = {sound = s, full = s.Volume}
		s.Volume = 0
		s:Play()
	end
end

task.spawn(function()
	while true do
		task.wait(math.random(28, 65))
		if not Visit.active and not Portada.active then
			UI.flash(Color3.fromRGB(200, 210, 255), 0.72, 0.45)
			local base = Lighting.Brightness
			Lighting.Brightness = base + 3
			task.wait(0.07)
			Lighting.Brightness = base
			task.wait(0.1)
			Lighting.Brightness = base + 1.5
			task.wait(0.05)
			Lighting.Brightness = base
			task.wait(0.5 + math.random())
			UI.sound("Thunder", 0.7 + math.random() * 0.5)
		end
	end
end)

-- Búho o lobo de vez en cuando, lejos y en una dirección al azar (en 3D: se oye de dónde viene)
task.spawn(function()
	while true do
		task.wait(math.random(18, 40))
		local cam = workspace.CurrentCamera
		if cam and not Visit.active and not Portada.active and player:GetAttribute("TDCash") == nil then
			local a = math.random() * math.pi * 2
			local spot = Instance.new("Attachment")
			spot.WorldPosition = cam.CFrame.Position + Vector3.new(math.cos(a), 0.4, math.sin(a)) * math.random(70, 120)
			spot.Parent = workspace.Terrain
			Sfx.play(math.random() < 0.7 and "Owl" or "Wolf", spot)
			Debris:AddItem(spot, 12)
		end
	end
end)

local flickers = {}
local function addFlicker(l)
	flickers[l] = {base = l.Brightness, seed = math.random() * 100}
end
for _, l in CollectionService:GetTagged("Flicker") do
	addFlicker(l)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(addFlicker)
CollectionService:GetInstanceRemovedSignal("Flicker"):Connect(function(l)
	flickers[l] = nil
end)

local booted = false
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 15 then
		return
	end
	acc = 0
	local t = os.clock()
	for l, f in flickers do
		l.Brightness = f.base * (0.7 + 0.45 * (math.noise(t * 3, f.seed) + 0.5))
	end
	-- dentro de una visita apenas se oye la calle
	local away = Visit.active and 0.15 or 1
	for _, b in beds do
		b.sound.Volume += (b.full * away - b.sound.Volume) * 0.15
	end
	-- la música de cada situación (desde que se sabe si hay portada)
	Musica.set(booted and (
		Portada.active and not Portada.leaving and "title"
			or Visit.active and "visit"
			or player:GetAttribute("TDCash") ~= nil and (Musica.boss and "boss" or "td")
			or "town"
	) or nil)
end)

---------- Arranque: portada → tu casa → Don Calabaza ----------
townHint()
refresh()
markHouse()
applyMode()
-- (quien llega de un viaje del Tower Defense, a su partida o de vuelta a los lobbies, se salta la portada)
local tp = game:GetService("TeleportService"):GetLocalPlayerTeleportData()
if typeof(tp) == "table" and (tp.td or tp.fromMatch) then
	UI.gui.Enabled = true
	task.spawn(Tutorial.start, tp.td ~= nil)
else
	UI.gui.Enabled = false
	Portada.show(function()
		UI.gui.Enabled = true
		Tutorial.start()
	end)
end
booted = true
