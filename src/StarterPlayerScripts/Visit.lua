-- Visitar una casa: primera persona, linterna, miedo (latido, viñeta, colores) y sustos en pantalla.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")

local Assets = RS:WaitForChild("Assets")
local Remote = RS:WaitForChild("Remote")
local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local Visit = {active = false}

local flashlight = Instance.new("Part")
flashlight.Name = "Linterna"
flashlight.Anchored, flashlight.CanCollide, flashlight.CanQuery, flashlight.CanTouch = true, false, false, false
flashlight.Transparency = 1
flashlight.Size = Vector3.one * 0.2
local beam = Instance.new("SpotLight")
beam.Range = 60
beam.Angle = 55
beam.Brightness = 4
beam.Color = Color3.fromRGB(255, 240, 215)
beam.Shadows = true
beam.Parent = flashlight
local glow = Instance.new("PointLight") -- un poco de luz alrededor para no ir totalmente a ciegas
glow.Range = 7
glow.Brightness = 0.35
glow.Color = Color3.fromRGB(200, 210, 255)
glow.Parent = flashlight

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "MiedoLocal"
grade.Enabled = false
grade.Parent = Lighting

local function loop(name, volume)
	local s = Assets.Sounds:FindFirstChild(name)
	if not s then
		return nil
	end
	s = s:Clone()
	s.Looped = true
	s.Volume = volume or s.Volume
	s.Parent = SoundService
	return s
end
local heartbeat = loop("Heartbeat", 0)
-- (la música de la visita la pone Musica mientras Visit.active)

local saved
local torchOn = true
local house -- la casa que visitas (para el progreso hasta el fondo)
local knocked = false -- te han pillado o te has desmayado: todo suena apagado hasta salir
local walked, nextCreak, lastPos = 0, 6, nil -- crujidos del suelo al andar

local function shake(intensity, time)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			local k = 1 - (os.clock() - t0) / time
			hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * intensity * k
			task.wait(0.025)
		end
		hum.CameraOffset = Vector3.zero
	end)
end

-- Linterna: F o el botón de la pantalla (en móvil no hay teclas)
function Visit.toggleLight()
	if not Visit.active then
		return
	end
	torchOn = not torchOn
	beam.Enabled = torchOn
	UI.setLight(torchOn)
	UI.sound("Flashlight")
end

local function onAction(name, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if name == "Huir" then
		Remote:FireServer("Exit")
	elseif name == "Linterna" then
		Visit.toggleLight()
	end
	return Enum.ContextActionResult.Sink
end

-- walked: has entrado cruzando el portal blanco de la puerta (la animación la pone Portales.lua)
function Visit.start(name, test, inward, walked, model)
	if Visit.active then
		return
	end
	Visit.active = true
	Visit.lastResult = nil
	house = model
	UI.toggleShop(false)
	UI.menu.Visible = false
	if not walked then
		UI.sound("Swoosh")
		UI.fadeOut(0.45)
	end
	lastPos = nil
	task.delay(walked and 0 or 0.65, function()
		if not Visit.active then
			return
		end
		saved = {Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, ExposureCompensation = Lighting.ExposureCompensation}
		Lighting.Ambient = Color3.fromRGB(16, 13, 22) -- muy oscuro, pero se intuyen las siluetas
		Lighting.OutdoorAmbient = Color3.fromRGB(18, 16, 26)
		Lighting.ExposureCompensation = 0
		grade.Enabled = true
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		torchOn = true
		beam.Enabled = true
		UI.setLight(true)
		flashlight.Parent = camera
		if heartbeat then
			heartbeat:Play()
		end
		UI.visitHud.Visible = true
		UI.setFear(0)
		UI.setHint("Make it to the back!", "F flashlight  ·  Q run away  ·  Walk out the door to leave", "trophy")
		UI.setProgress(0, "")
		UI.titleCard(name, test and "Test run" or "Try not to scream...")
		ContextActionService:BindAction("Huir", onAction, false, Enum.KeyCode.Q)
		ContextActionService:BindAction("Linterna", onAction, false, Enum.KeyCode.F)
		if not walked then
			UI.fadeIn(0.9)
		end
	end)
	-- la cámara mira hacia dentro de la casa (en primera persona el personaje gira hacia donde mira la cámara)
	if walked then
		return
	end
	for _, t in {0.75, 1.1} do
		task.delay(t, function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if Visit.active and root and inward then
				local eye = root.Position + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.lookAt(eye, eye + inward)
			end
		end)
	end
end

function Visit.finish(result)
	Visit.lastResult = result
	if result == "left" then
		return -- ha salido cruzando el portal: sin fundido (la animación la pone Portales.lua)
	end
	if result == "done" then
		-- ha llegado al fondo sin desmayarse
		UI.big("You made it!", Visit.reward and ("Bravery bonus: +%d coins"):format(Visit.reward) or "You survived the haunted house", UI.GREEN, 2.3)
		Visit.reward = nil
		UI.sound("Win")
		UI.duck(0.2, 3)
		UI.flash(Color3.fromRGB(255, 220, 120), 0.5, 0.8)
		UI.confetti(90)
	elseif result == "caught" then
		UI.flash(Color3.fromRGB(160, 0, 0), 0, 1.6)
		UI.big("You got caught!", "Try again", UI.RED, 2.3)
		UI.sound("Caught")
		knocked = true
		shake(2, 0.6)
	elseif result == "fled" then
		UI.flash(Color3.fromRGB(60, 0, 20), 0, 1.6)
		UI.big("You fainted!", "Too scared...", UI.RED, 2.3)
		UI.sound("Faint")
		task.delay(0.35, UI.sound, "Thud")
		knocked = true
	end
	task.delay(result == "quit" and 0 or 1.9, function()
		if Visit.active then
			UI.fadeOut(0.4)
		end
	end)
end

function Visit.stop()
	if not Visit.active then
		return
	end
	Visit.active = false
	ContextActionService:UnbindAction("Huir")
	ContextActionService:UnbindAction("Linterna")
	if saved then
		for k, v in saved do
			Lighting[k] = v
		end
		saved = nil
	end
	grade.Enabled = false
	flashlight.Parent = nil
	if heartbeat then
		heartbeat:Stop()
	end
	knocked = false
	UI.muffle(0)
	UI.visitHud.Visible = false
	UI.setVignette(0)
	UI.menu.Visible = true
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 10 -- saca la cámara de la cabeza
	task.delay(0.2, function()
		player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
	end)
	UI.fadeIn(0.6)
end

-- Un susto te ha pillado: destello, sacudida y golpe de cámara
function Visit.scare(intensity, color)
	if not Visit.active then
		return
	end
	intensity = intensity or 1
	UI.flash(color or Color3.new(1, 1, 1), math.clamp(0.75 - intensity * 0.35, 0, 0.7), 0.5 + intensity * 0.3)
	shake(0.5 + intensity * 0.6, 0.3 + intensity * 0.25)
	camera.FieldOfView = 70 + intensity * 14
	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {FieldOfView = 70}):Play()
	-- el bajón de la música y un golpe grave (en los sustos fuertes) hacen que cada susto pegue más
	UI.duck(math.clamp(1 - intensity * 0.5, 0.15, 0.8), 1 + intensity)
	if intensity >= 1 then
		UI.sound("Boom", math.min(1, intensity * 0.55))
	end
end

-- La trampilla: caes a oscuras y apareces al principio de la sala
function Visit.fall()
	if not Visit.active then
		return
	end
	UI.flash(Color3.new(0, 0, 0), 0, 1.1)
	shake(1.5, 0.5)
	UI.sound("Whoosh", 0.6, 0.7) -- caes...
	task.delay(0.4, UI.sound, "Thud") -- ...y aterrizas al principio de la sala
	UI.big("A trapdoor!", "Back to the start of the room", UI.ORANGE, 1.6)
end

RunService.RenderStepped:Connect(function()
	if not Visit.active then
		return
	end
	-- delante de la cara: si la luz queda dentro de la cabeza, su sombra la tapa
	if flashlight.Parent ~= camera then
		flashlight.Parent = camera
	end
	flashlight.CFrame = camera.CFrame * CFrame.new(0.45, -0.4, -1.4)
	-- progreso hasta el fondo de la casa (el servidor da la visita por superada a 4 studs de la pared del fondo)
	local origin = house and house.Parent and house:GetAttribute("Origin")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if origin and root then
		local rooms = house:GetAttribute("Rooms") or 1
		local _, _, z = Config.toHouse(origin, root.Position)
		local room = math.clamp(math.floor(z / Config.ROOM_D) + 1, 1, rooms)
		UI.setProgress(z / (rooms * Config.ROOM_D - 4), ("Room %d of %d"):format(room, rooms))
	end
	-- el suelo cruje de vez en cuando al andar
	if root then
		local flat = root.Position * Vector3.new(1, 0, 1)
		walked += (flat - (lastPos or flat)).Magnitude
		lastPos = flat
		if walked > nextCreak then
			walked, nextCreak = 0, 5 + math.random() * 9
			UI.sound("Creak", 0.5 + math.random() * 0.5)
		end
	end
	local fear = (player:GetAttribute("Fear") or 0) / 100
	if heartbeat then
		heartbeat.Volume = 0.08 + fear * 0.9
		heartbeat.PlaybackSpeed = 0.85 + fear * 0.8
	end
	-- con miedo la música se oye como con los oídos tapados; si te han pillado, todo
	UI.muffle(knocked and 1 or fear * 0.5, knocked and 1 or 0)
	UI.setVignette(0.15 + fear * 0.75)
	grade.Saturation = -0.25 - fear * 0.55
	grade.Contrast = 0.1 + fear * 0.25
	grade.TintColor = Color3.new(1, 1 - fear * 0.25, 1 - fear * 0.25)
	-- con mucho miedo la linterna falla
	beam.Brightness = (fear > 0.65 and math.random() < 0.08) and 0.4 or 4
end)

player:GetAttributeChangedSignal("Fear"):Connect(function()
	UI.setFear(player:GetAttribute("Fear") or 0)
end)

return Visit
