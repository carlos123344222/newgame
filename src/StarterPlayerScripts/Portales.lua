-- Portales blancos de las puertas: brillo que "respira" y la animación de cruzarlos.
-- El portal es opaco y sólido para los jugadores (la puerta está cerrada por fuera y por dentro). Al caminar contra
-- él: la cámara se acerca, el personaje avanza hacia la luz y se desvanece, un círculo blanco cubre la pantalla y
-- apareces al otro lado (dentro, mirando a la casa; fuera, en el porche mirando a la calle). El servidor ve tu nueva
-- posición y te pone en modo "home" (tu casa) o empieza la visita (casa ajena), como siempre.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer

local Portales = {busy = false}

local IN_DEPTH, OUT_DEPTH = 6, -5.2 -- dónde apareces al cruzar (profundidad desde la puerta): lejos del portal
local TRIGGER = 2.6 -- a qué distancia del portal, caminando hacia él, empieza la animación
local ARRIVE_ZOOM = 4 -- la cámara llega pegada al personaje (si no, se quedaría contra el portal)
local WHITE = Color3.fromRGB(236, 240, 255)
local LILAC = Color3.fromRGB(212, 204, 255)

local portals = {} -- [modelo Portal] = {glow, light, emitters, seed, boost}

local function addPortal(m)
	task.spawn(function()
		local glow = m:WaitForChild("Glow", 10)
		if not glow or not m.Parent then
			return
		end
		local emitters = {}
		for _, e in glow:GetChildren() do
			if e:IsA("ParticleEmitter") then
				table.insert(emitters, e)
			end
		end
		portals[m] = {glow = glow, emitters = emitters, light = glow:FindFirstChildOfClass("PointLight"), seed = math.random() * 10, boost = 0}
	end)
end
for _, m in CollectionService:GetTagged("Portal") do
	addPortal(m)
end
CollectionService:GetInstanceAddedSignal("Portal"):Connect(addPortal)
CollectionService:GetInstanceRemovedSignal("Portal"):Connect(function(m)
	portals[m] = nil
end)

---------- Pantalla: un círculo de luz que crece hasta cubrirlo todo ----------
local gui = UI.new("ScreenGui", {Name = "PortalFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45}, player:WaitForChild("PlayerGui"))
local white = UI.new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(250, 248, 255), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, gui)
local ring = UI.new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1}, gui)
UI.new("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
UI.new("UIAspectRatioConstraint", {AspectRatio = 1}, ring)
local ringGradient = UI.new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 186, 255)), Rotation = 90}, ring)

local function charParts(char)
	local list = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(list, d)
		end
	end
	return list
end

-- Cruza el portal de esta casa (entering = de fuera adentro)
local function cross(house, model, entering)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local origin = house:GetAttribute("Origin")
	local p = portals[model]
	if not (root and origin and p) then
		return
	end
	Portales.busy = true
	UI.lockMovement(true)
	local cam = workspace.CurrentCamera
	local firstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson
	local inward = origin.LookVector
	local dir = entering and inward or -inward
	local center = (origin * CFrame.new(0, 3, 0)).Position -- centro del portal, a la altura del pecho
	local glow = p.glow
	glow.CanCollide = false -- solo en este cliente: deja que el personaje se meta en la luz
	-- casa principal (diseño 3D): su puerta se abre sola (HauntClient) y se entra en la oscuridad, con fundido a negro
	local ext = house:FindFirstChild("Exterior")
	if ext then
		ext:SetAttribute("EntryAt", os.clock())
		UI.sound("Swoosh", 0.7)
	else
		p.boost = 1
		for _, e in p.emitters do
			e:Emit(25)
		end
		UI.sound("Portal")
		UI.sound("Sparkle", 0.8)
	end
	local veil = ext and Color3.new(0, 0, 0) or Color3.fromRGB(250, 248, 255)
	white.BackgroundColor3, ring.BackgroundColor3 = veil, ext and veil or Color3.new(1, 1, 1)
	ringGradient.Enabled = not ext

	-- 1) la cámara se acerca y el personaje camina hacia la luz desvaneciéndose
	if not firstPerson then
		cam.CameraType = Enum.CameraType.Scriptable
		local right = dir:Cross(Vector3.yAxis)
		local camGoal = CFrame.lookAt(center - dir * 7.5 + right * 1.6 + Vector3.new(0, 2.4, 0), center + Vector3.new(0, 0.4, 0))
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {CFrame = camGoal}):Play()
	end
	local parts = firstPerson and {} or charParts(char)
	local start = root.Position
	if ext then
		task.wait(0.2) -- que la puerta empiece a abrirse antes de echar a andar
	end
	local goal = Vector3.new(center.X, start.Y, center.Z) + dir * (ext and 1.8 or 0.6) -- en la casa principal, hasta el umbral oscuro
	local t0, dur = os.clock(), ext and 0.8 or 0.55
	while os.clock() - t0 < dur and root.Parent do
		local a = (os.clock() - t0) / dur
		local pos = start:Lerp(goal, a * a)
		root.CFrame = CFrame.lookAt(pos, pos + dir)
		for _, part in parts do
			part.LocalTransparencyModifier = a * 0.9
		end
		RunService.RenderStepped:Wait()
	end

	-- 2) un círculo de luz crece hasta cubrir la pantalla
	ring.Size = UDim2.fromScale(0.05, 0.05)
	ring.BackgroundTransparency = 0.3
	TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.fromScale(2.4, 2.4), BackgroundTransparency = 0}):Play()
	TweenService:Create(white, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0}):Play()
	task.wait(0.34)

	-- 3) al otro lado
	local dest = entering and origin * CFrame.new(0, 3, -IN_DEPTH) or origin * CFrame.new(0, 3, -OUT_DEPTH) * CFrame.Angles(0, math.pi, 0)
	if char.Parent then
		char:PivotTo(dest)
	end
	for _, part in parts do
		part.LocalTransparencyModifier = 0
	end
	glow.CanCollide = true
	if not firstPerson then
		-- bajar un instante el zoom máximo deja la cámara cerca (al restaurarlo no vuelve a alejarse sola)
		local keepMax = player.CameraMaxZoomDistance
		player.CameraMaxZoomDistance = math.max(player.CameraMinZoomDistance, ARRIVE_ZOOM)
		local look = dest.LookVector
		cam.CFrame = CFrame.lookAt(dest.Position - look * ARRIVE_ZOOM + Vector3.new(0, 2, 0), dest.Position + look * 6)
		cam.CameraType = Enum.CameraType.Custom
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		player.CameraMaxZoomDistance = keepMax
	end
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(0, 0)
	task.wait(0.12)
	TweenService:Create(white, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	UI.lockMovement(false)
	task.wait(0.6)
	Portales.busy = false
end

---------- ¿Caminas contra un portal? ----------
RunService.Heartbeat:Connect(function()
	if Portales.busy then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0 and hum.WalkSpeed > 0) then
		return
	end
	local move = hum.MoveDirection
	if move.Magnitude < 0.1 then
		return
	end
	for model in portals do
		local house = model.Parent
		local origin = house and house:GetAttribute("Origin")
		if origin then
			local x, y, z = Config.toHouse(origin, root.Position)
			if math.abs(x) < Config.DOOR_W / 2 - 0.3 and y > -1.5 and y < Config.DOOR_H then
				local toward = move:Dot(origin.LookVector)
				if z < 0 and z > -TRIGGER and toward > 0.35 then
					task.spawn(cross, house, model, true)
					return
				elseif z > 0 and z < TRIGGER and toward < -0.35 then
					task.spawn(cross, house, model, false)
					return
				end
			end
		end
	end
end)

---------- Brillo que respira ----------
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 20 then
		return
	end
	local step = acc
	acc = 0
	local t = os.clock()
	for m, p in portals do
		if not m.Parent then
			portals[m] = nil
			continue
		end
		p.boost = math.max(0, p.boost - step * 1.2)
		local w = math.sin(t * 2 + p.seed) * 0.5 + 0.5
		p.glow.Color = LILAC:Lerp(WHITE, math.min(1, w + p.boost))
		if p.light then
			p.light.Brightness = 1.1 + 0.5 * w + p.boost * 2.5
			p.light.Range = 16 + p.boost * 8
		end
	end
end)

return Portales
