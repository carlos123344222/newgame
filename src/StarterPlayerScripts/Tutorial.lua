-- Tutorial del alcalde Calabaza (Mayor Pumpkin): se enseña, no se explica.
-- Fuera (nada más pulsar PLAY): dos frases y una flecha "ENTER!" sobre tu portal.
-- Dentro: una mano arrastra un susto desde la barra hasta un círculo brillante del suelo (con el susto en fantasma);
-- cuando lo colocas, la cámara te enseña al primer visitante entrando, asustándose y soltando monedas; unas flechas
-- doradas señalan las monedas hasta que las recoges y al final la mano señala el botón Shop.
-- Progreso guardado en el servidor (atributo Tut, dato "tut3"):
-- 0 nuevo · 1 ya habló fuera · 2 ya entró (falta colocar) · 3 colocado (falta ver el susto y recoger) · 4 terminado.
-- Después el alcalde se queda en tu jardín: te sigue con la mirada, saluda, "Talk" da consejos y Help te vuelve a
-- señalar el portal.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local Assets = RS:WaitForChild("Assets")
local UI = require(script.Parent:WaitForChild("UI"))
local Calabaza = require(script.Parent:WaitForChild("Calabaza"))
local Dialogo = require(script.Parent:WaitForChild("Dialogo"))
local Monedas = require(script.Parent:WaitForChild("Monedas"))
local Portales = require(script.Parent:WaitForChild("Portales"))
local player = Players.LocalPlayer
local Houses = workspace:WaitForChild("Casas")

local Tutorial = {}

local O, C = '<font color="#E8650A">', "</font>"
local LINES = {
	intro = {
		"Booo! Hee hee! I'm " .. O .. "Mayor Pumpkin" .. C .. ", mayor of this haunted street.",
		"This house is " .. O .. "YOURS" .. C .. "! Step through the portal... I'll show you how to scare!",
	},
	done = {"Hee hee hee! What a scream! You're a natural!"},
	noCoins = {"Hmm... they walked right past it! Put your scares close to the middle, where visitors walk."},
	noPlot = {
		"Booo! I'm " .. O .. "Mayor Pumpkin" .. C .. ". Oh dear... there are no free houses on this street today.",
		"But you can step through the portals of other houses... if you dare!",
	},
	follow = {"Need help? Into your house! Inside, drag scares onto the floor. Hee hee!"},
	help = {
		"Need help? That's what I'm here for!",
		"Drag scares from the bar onto the floor of your house and wait for visitors.",
		"Scared visitors drop " .. O .. "coins" .. C .. ": walk over them to pick them up!",
	},
	tips = {
		"If your scares go off one after another you get a " .. O .. "combo" .. C .. "... and twice the coins!",
		"Trapdoors send visitors back to the start of the room. Hee hee hee!",
		"The " .. O .. "clown" .. C .. " chases visitors through the whole house. It's very expensive... but so worth it!",
		"If a visitor faints from fear or gets caught, they drop a big pile of coins!",
		"Bigger houses in the " .. O .. "Shop" .. C .. " have more rooms: " .. Config.SCARES_PER_ROOM .. " more scares per room!",
		"Your coins wait on the floor of your house. Go inside to pick them up!",
		"Unclaimed houses belong to nobody... visit them if you dare. Hee hee!",
	},
}

local step = 0
local npc -- el alcalde en tu jardín (solo lo ves tú)
local prompt
local arrow -- "ENTER!" sobre tu portal
local running = false
local greeted = false
local busy = false -- enseñando algo (la mano o la escena del visitante)

local function myHouse()
	local plot = player:GetAttribute("Plot")
	return plot and Houses:FindFirstChild("Casa" .. plot)
end

local function setStep(n)
	if n > step then
		step = n
		Remote:FireServer("Tut", n)
		if n >= 2 then
			UI.sound("Success") -- paso del tutorial superado
		end
	end
end

-- Sin moverse mientras habla (y con la cámara mirándole si está cerca)
local function talk(lines, frame)
	UI.lockMovement(true)
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local framed = false
	if frame and npc and npc.model.Parent and root and (root.Position - npc.root.Position).Magnitude < 30 then
		local head = npc.root.Position + Vector3.new(0, 5.4 * npc.S, 0)
		local dir = ((head - root.Position) * Vector3.new(1, 0, 1)).Unit
		local right = dir:Cross(Vector3.yAxis)
		local pos = root.Position - dir * 6.5 - right * 2.6 + Vector3.new(0, 3.2, 0)
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {CFrame = CFrame.lookAt(pos, head)}):Play()
		framed = true
	end
	if npc then
		npc.wave = true
		npc:jump()
		task.delay(1.6, function()
			npc.wave = false
		end)
	end
	Dialogo.say(lines, {npc = npc})
	if framed then
		cam.CameraType = Enum.CameraType.Custom
	end
	UI.lockMovement(false)
end

---------- El alcalde en el jardín ----------
local function placeNpc()
	local h = myHouse()
	local origin = h and h:GetAttribute("Origin")
	if not origin then
		if npc then
			npc.model.Parent = nil
		end
		return
	end
	if not npc then
		npc = Calabaza.new({scale = 0.82, light = true})
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Mayor Pumpkin"
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Parent = npc.chest
		prompt.Triggered:Connect(function()
			if running or Dialogo.active then
				return
			end
			running = true
			local tips = LINES.tips
			talk({tips[math.random(#tips)]}, true)
			running = false
		end)
	end
	local pos = (origin * CFrame.new(4.6, -Config.FLOOR_Y, 9.6)).Position
	local spawnAt = Config.frontOf(origin).Position
	npc.home = CFrame.lookAt(pos, Vector3.new(spawnAt.X, pos.Y, spawnAt.Z))
	npc.root = npc.home
	npc:update(0)
	npc.model.Parent = workspace
end

RunService.RenderStepped:Connect(function(dt)
	if not (npc and npc.model.Parent) then
		return
	end
	local cam = workspace.CurrentCamera
	if (cam.CFrame.Position - npc.home.Position).Magnitude > 160 then
		return
	end
	-- cuando estás cerca se gira poco a poco hacia ti y te sigue con la mirada; la primera vez te saluda
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dist = root and (root.Position - npc.home.Position).Magnitude or math.huge
	local goal = npc.home
	if dist < 26 then
		local p = npc.home.Position
		goal = CFrame.lookAt(p, Vector3.new(root.Position.X, p.Y, root.Position.Z))
		npc.lookAt = root.Position + Vector3.new(0, 1.5, 0)
	else
		npc.lookAt = nil
	end
	if dist < 14 and not greeted and not Dialogo.active then
		greeted = true
		npc.wave = true
		npc:jump()
		task.delay(1.6, function()
			npc.wave = false
		end)
	elseif dist > 30 then
		greeted = false
	end
	npc.root = npc.root:Lerp(goal, math.min(1, dt * 4))
	npc:update(dt)
end)

---------- Flecha sobre tu portal ----------
local function showArrow(on)
	if on and not arrow then
		local h = myHouse()
		local mark = h and h:FindFirstChild("DoorMark", true)
		if not mark then
			return
		end
		arrow = UI.new("BillboardGui", {Name = "Entra", Size = UDim2.fromOffset(240, 136), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 200}, mark)
		local holder = UI.new("Frame", {Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1}, arrow)
		local label = UI.new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = Color3.fromRGB(255, 140, 20), Text = "ENTER!"}, holder)
		UI.new("UIStroke", {Color = UI.INK, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round}, label)
		local down = UI.piece("arrow", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(52, 52), ImageColor3 = UI.ORANGE}, arrow)
		task.spawn(function()
			while arrow and arrow.Parent do
				local k = math.abs(math.sin(os.clock() * 3.5))
				label.Size = UDim2.fromScale(0.86 + 0.14 * k, 0.86 + 0.14 * k) -- late como un corazón
				label.Rotation = math.sin(os.clock() * 2.2) * 4
				down.Position = UDim2.new(0.5, 0, 0, 74 + k * 8)
				RunService.RenderStepped:Wait()
			end
		end)
	elseif not on and arrow then
		arrow:Destroy()
		arrow = nil
	end
end

---------- Pantalla del tutorial: la mano, la carta que arrastra y un bloqueo para la escena ----------
local gui = UI.new("ScreenGui", {Name = "TutorialFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30}, player:WaitForChild("PlayerGui"))
-- durante la escena nada se pulsa (un Frame activo se traga los clics sin poner el cursor de mano)
local blocker = UI.new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true, Visible = false}, gui)
local card = UI.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(88, 112), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 2}, gui)
UI.new("UICorner", {CornerRadius = UDim.new(0, 14)}, card)
UI.new("UIStroke", {Color = UI.ORANGE, Thickness = 4}, card)
UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(110, 70, 170), Color3.fromRGB(30, 18, 50))}, card)
local cardName = UI.new("TextLabel", {Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, Font = UI.TITLE, TextScaled = true, TextColor3 = UI.WHITE, TextStrokeTransparency = 0, Text = "", ZIndex = 3}, card)
-- la mano: guante del kit; el ancla es la punta del dedo
local hand = UI.icon("hand", {AnchorPoint = Vector2.new(0.48, 0.06), Size = UDim2.fromOffset(86, 86), Visible = false, ZIndex = 4}, gui)
local handScale = UI.new("UIScale", {}, hand)

-- Centro de un botón del HUD en coordenadas de esta pantalla (la del HUD no ignora la barra de arriba)
local function centerOf(button)
	return button.AbsolutePosition + button.AbsoluteSize / 2 + GuiService:GetGuiInset()
end

-- Qué susto enseñar y dónde: el primero que tengas, en un sitio libre de la primera sala
local function demoPlan(h)
	local t
	for _, name in Config.ScareOrder do
		if (player:GetAttribute("Inv_" .. name) or 0) > 0 then
			t = name
			break
		end
	end
	if not t then
		return nil
	end
	local rooms = h:GetAttribute("Rooms") or 1
	for _, p in {{-6, 12}, {6, 12}, {-6, 16}, {6, 16}, {0, 12}, {0, 16}} do
		if Config.canPlace(h, rooms, t, p[1], p[2], 0) then
			return t, p[1], p[2]
		end
	end
	return nil
end

-- La mano arrastra la carta del susto hasta el círculo del suelo, una y otra vez, hasta que coloques uno
local function dragDemo(h)
	local t, x, z = demoPlan(h)
	local slot = t and UI.slots[t]
	if not slot then
		return false
	end
	while Portales.busy do
		task.wait(0.1)
	end
	local origin = h:GetAttribute("Origin")
	local spotCF = Config.scareCFrame(origin, x, z, 0)
	local def = Config.Scares[t]
	-- círculo brillante en el suelo y el susto en fantasma, justo donde va
	local d = math.max(def.size.X, def.size.Y) + 1.5
	local ring = Instance.new("Part")
	ring.Name = "TutorialSpot"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, d, d)
	ring.CFrame = spotCF * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = UI.ORANGE
	ring.Parent = workspace
	local ghost = Assets.Scares[t]:Clone()
	for _, p in ghost:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			p.Transparency = (p.Name == "Hitbox" or p.Name == "Path") and 1 or math.max(p:GetAttribute("T") or p.Transparency, 0.72)
		elseif p:IsA("Sound") or p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Script") then
			p:Destroy()
		end
	end
	ghost:PivotTo(spotCF)
	UI.new("Highlight", {FillColor = UI.ORANGE, FillTransparency = 0.6, OutlineColor = UI.ORANGE}, ghost)
	ghost.Parent = workspace
	-- la carta es como la de la barra: el susto en 3D y su nombre
	local vp = UI.viewport(t, card, {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 76), ZIndex = 3})
	cardName.Text = def.name
	hand.Visible = true
	local t0 = os.clock()
	while h.Parent and step == 2 and (player:GetAttribute("Placed") or 0) == 0 do
		local cam = workspace.CurrentCamera
		local from = centerOf(slot.button)
		local sp = cam:WorldToViewportPoint(spotCF.Position)
		local to = sp.Z > 0 and Vector2.new(sp.X, sp.Y) or Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y * 0.4)
		local shown = player:GetAttribute("Mode") == "home" and UI.buildBar.Visible and not Dialogo.active and not blocker.Visible
		local u = ((os.clock() - t0) % 2.4) / 2.4 -- 0..1 en cada vuelta
		local pos, alpha, press = from, 1, 1
		if u < 0.12 then -- aparece sobre la carta y la "pulsa"
			alpha, press = 1 - u / 0.12, 1 - 0.18 * (u / 0.12)
		elseif u < 0.62 then -- la arrastra en curva hasta el suelo
			local a = (u - 0.12) / 0.5
			a = a * a * (3 - 2 * a)
			local mid = (from + to) / 2 - Vector2.new(0, 120)
			pos = from:Lerp(mid, a):Lerp(mid:Lerp(to, a), a)
			alpha, press = 0, 0.82
		elseif u < 0.75 then -- la suelta
			pos, alpha, press = to, 0, 0.82 + 0.18 * ((u - 0.62) / 0.13)
		else -- se desvanece y espera
			pos, alpha = to, (u - 0.75) / 0.25
		end
		hand.Position = UDim2.fromOffset(pos.X, pos.Y)
		hand.ImageTransparency = shown and alpha or 1
		handScale.Scale = press
		card.Position = UDim2.fromOffset(pos.X - 6, pos.Y - 50)
		card.Visible = shown and u >= 0.12 and u < 0.68
		ring.Transparency = 0.25 + 0.45 * (math.sin(os.clock() * 5) * 0.5 + 0.5)
		RunService.RenderStepped:Wait()
	end
	hand.Visible, card.Visible = false, false
	vp:Destroy()
	ring:Destroy()
	ghost:Destroy()
	return true
end

-- La mano (desde arriba: los botones están abajo del todo) pulsa un botón mientras late, se ilumina y suelta
-- anillos dorados; para antes si lo abres. Los botones del kit ya traen su UIScale ("pop" al pasar el ratón).
local function tapButton(button, seconds)
	local sc = button:FindFirstChildOfClass("UIScale") or UI.new("UIScale", {}, button)
	local color = button.BackgroundColor3
	local ping = UI.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3}, gui)
	UI.new("UICorner", {CornerRadius = UDim.new(0, 16)}, ping)
	local pingStroke = UI.new("UIStroke", {Color = UI.GOLD, Thickness = 4}, ping)
	hand.Rotation, hand.AnchorPoint = 180, Vector2.new(0.52, 0.94) -- hacia abajo: la punta queda abajo
	hand.Visible = true
	local t0 = os.clock()
	while os.clock() - t0 < seconds and button.Parent and not UI.shop.Visible do
		local t = os.clock() - t0
		local k = math.abs(math.sin(t * 5))
		sc.Scale = 1 + 0.08 * k
		button.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3 * k)
		local c = centerOf(button)
		local size = button.AbsoluteSize
		local u = (t % 0.9) / 0.9
		ping.Position = UDim2.fromOffset(c.X, c.Y)
		ping.Size = UDim2.fromOffset(size.X + 6 + u * 36, size.Y + 6 + u * 36)
		pingStroke.Transparency = u
		local shown = button.Visible and size.X > 0
		ping.Visible = shown
		local tap = math.abs(math.sin(t * 4))
		hand.Position = UDim2.fromOffset(c.X, c.Y + 4 - tap * 12) -- la punta del dedo dentro del botón
		hand.ImageTransparency = shown and 0 or 1
		handScale.Scale = 0.85 + 0.15 * tap
		RunService.RenderStepped:Wait()
	end
	hand.Visible = false
	hand.Rotation, hand.AnchorPoint = 0, Vector2.new(0.48, 0.06)
	ping:Destroy()
	sc.Scale = 1
	button.BackgroundColor3 = color
end

local function shopButton()
	return UI.buildBar.Visible and UI.buildShopButton or UI.shopButton
end

-- Flecha dorada que bota sobre una moneda hasta que la recoges
local function markCoin(c)
	if c:FindFirstChild("TutorialArrow") then
		return
	end
	local bb = UI.new("BillboardGui", {Name = "TutorialArrow", Size = UDim2.fromOffset(60, 60), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120}, c)
	UI.piece("arrow", {Size = UDim2.fromScale(1, 1), ImageColor3 = UI.GOLD}, bb)
	task.spawn(function()
		while bb.Parent do
			bb.StudsOffset = Vector3.new(0, 1.6 + math.abs(math.sin(os.clock() * 5)), 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function coinsOf(h)
	local folder = h:FindFirstChild("Coins")
	return folder and folder:GetChildren() or {}
end

-- La escena: el primer visitante entra, el susto lo asusta y suelta monedas; después, a recogerlas
local function scareDemo(h)
	local before = Monedas.total
	local old = {} -- monedas que ya estaban (de otras visitas)
	for _, c in coinsOf(h) do
		old[c] = true
	end
	local function newCoins()
		local n = 0
		for _, c in coinsOf(h) do
			if not old[c] then
				n += 1
			end
		end
		return n
	end
	-- espera al visitante (el servidor lo manda enseguida al colocar el primer susto)
	local bot
	local t0 = os.clock()
	while not bot and os.clock() - t0 < 40 and h.Parent do
		for _, b in CollectionService:GetTagged("Visitor") do
			if b:IsDescendantOf(h) then
				bot = b
			end
		end
		task.wait(0.2)
	end
	local scares = h:FindFirstChild("Scares")
	local first, firstZ -- el susto más cerca de la entrada: el primero que se encontrará
	local origin = h:GetAttribute("Origin")
	for _, s in scares and scares:GetChildren() or {} do
		local _, _, z = Config.toHouse(origin, s:GetPivot().Position)
		if not firstZ or z < firstZ then
			first, firstZ = s, z
		end
	end
	if bot and first and player:GetAttribute("Mode") == "home" and not Dialogo.active then
		-- la cámara se aparta detrás del susto y enseña el portal por el que entra el visitante
		local sx, _, sz = Config.toHouse(origin, first:GetPivot().Position)
		local rooms = h:GetAttribute("Rooms") or 1
		local side = sx < 0 and 1 or -1
		local camPos = (origin * CFrame.new(side * 8, 10, -math.min(sz + 6, rooms * Config.ROOM_D - 1.5))).Position
		local look = (origin * CFrame.new(sx * 0.4, 2.5, -(sz * 0.5))).Position
		local cam = workspace.CurrentCamera
		local saved = cam.CFrame
		UI.lockMovement(true)
		Monedas.paused = true -- que se queden en el suelo: si caen a tu lado las recogerías sin verlas
		blocker.Visible = true
		UIS.MouseIconEnabled = false
		local bar = UI.buildBar.Visible
		UI.buildBar.Visible = false
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {CFrame = CFrame.lookAt(camPos, look)}):Play()
		local t1 = os.clock()
		while newCoins() == 0 and bot.Parent and os.clock() - t1 < 16 do
			task.wait(0.1)
		end
		if newCoins() > 0 then
			task.wait(1.8) -- deja ver cómo saltan y caen las monedas
		end
		-- vuelve a donde estaba la cámara
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {CFrame = saved}):Play()
		task.wait(0.6)
		cam.CameraType = Enum.CameraType.Custom
		UI.buildBar.Visible = bar and player:GetAttribute("Mode") == "home"
		blocker.Visible = false
		UIS.MouseIconEnabled = true
		Monedas.paused = false
		UI.lockMovement(false)
	else
		while bot and bot.Parent and newCoins() == 0 do
			task.wait(0.2)
		end
	end
	if newCoins() == 0 and Monedas.total == before then
		talk(LINES.noCoins, false)
		setStep(4)
		return
	end
	-- flechas sobre las monedas hasta que recoges alguna
	for _, c in coinsOf(h) do
		markCoin(c)
	end
	local folder = h:FindFirstChild("Coins")
	local conn = folder and folder.ChildAdded:Connect(markCoin)
	local t2 = os.clock()
	while Monedas.total == before and os.clock() - t2 < 120 and h.Parent and #coinsOf(h) > 0 do
		task.wait(0.2)
	end
	if conn then
		conn:Disconnect()
	end
	task.wait(1) -- que dé tiempo a recoger el resto
	for _, c in coinsOf(h) do
		local a = c:FindFirstChild("TutorialArrow")
		if a then
			a:Destroy()
		end
	end
	talk(LINES.done, false)
	setStep(4)
	tapButton(shopButton(), 7)
end

---------- Pasos ----------
local function check()
	if busy or not player:GetAttribute("Plot") then
		return
	end
	local h = myHouse()
	if not h then
		return
	end
	local home = player:GetAttribute("Mode") == "home"
	if step == 1 then
		showArrow(not home)
		if home then
			setStep(2)
		end
	end
	if step == 2 and home then
		busy = true
		if (player:GetAttribute("Placed") or 0) == 0 then
			task.wait(0.6)
			dragDemo(h)
		end
		if (player:GetAttribute("Placed") or 0) > 0 then
			setStep(3)
		end
		busy = false
	end
	if step == 3 then
		busy = true
		scareDemo(h)
		busy = false
	end
end

-- Empieza (o retoma) el tutorial. Se llama justo al pulsar PLAY, ya delante de tu casa.
function Tutorial.start()
	step = player:GetAttribute("Tut") or 0
	placeNpc()
	player:GetAttributeChangedSignal("Plot"):Connect(placeNpc)
	if not player:GetAttribute("Plot") then
		task.spawn(talk, LINES.noPlot, false)
		return
	end
	if step <= 0 then
		running = true
		greeted = true
		talk(LINES.intro, true)
		setStep(1)
		running = false
	end
	for _, name in {"Mode", "Placed"} do
		player:GetAttributeChangedSignal(name):Connect(function()
			task.spawn(check)
		end)
	end
	check()
end

-- Botón de ayuda (solo está en la calle): te vuelve a señalar tu portal; dentro ya te enseña la mano
function Tutorial.help()
	if running or busy or Dialogo.active then
		return
	end
	running = true
	if myHouse() and player:GetAttribute("Mode") == nil then
		talk(LINES.follow, true)
		showArrow(true)
		task.delay(8, function()
			if step ~= 1 then
				showArrow(false)
			end
		end)
	else
		talk(LINES.help, true)
	end
	running = false
end

-- Si la casa se reconstruye (habitación nueva), la flecha se recoloca
Houses.DescendantAdded:Connect(function(d)
	if d.Name == "DoorMark" and arrow then
		showArrow(false)
		task.defer(check)
	end
end)

return Tutorial
