-- Mapa del Tower Defense (cliente): al llegar, cartel; mientras estás en el mapa (modo "td") la noche de Halloween se
-- aclara un poco con luz de luna morada para que se vea bien el camino. Al salir vuelve la noche normal del juego.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(RS:WaitForChild("Config"))
local TD = require(RS:WaitForChild("TowerDefense"))
local LobbyRemote = RS:WaitForChild("LobbyRemote")
local UI = require(script.Parent:WaitForChild("UI"))
local player = Players.LocalPlayer

local function inMap()
	return player:GetAttribute("Mode") == "td"
end

---------- Luz de luna mientras estás en el mapa ----------
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "TDGrade"
grade.Parent = Lighting
local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local LIGHT = {"Ambient", "OutdoorAmbient", "ExposureCompensation", "ClockTime", "Brightness"}
local savedLight, savedAtmos = {}, atmos and {Color = atmos.Color, Decay = atmos.Decay, Density = atmos.Density, Haze = atmos.Haze, Glare = atmos.Glare}
for _, k in LIGHT do
	savedLight[k] = Lighting[k]
end
local MOON = {Ambient = Color3.fromRGB(140, 126, 186), OutdoorAmbient = Color3.fromRGB(160, 144, 210), ExposureCompensation = 0.7}
local MOON_ATMOS = {Color = Color3.fromRGB(120, 96, 170), Decay = Color3.fromRGB(70, 44, 110), Density = 0.3, Haze = 1.2, Glare = 0}

-- Cada mapa puede traer su propia luz (TD.MAPS[i].light: verde en el pantano, azul helado en la montaña...)
local function preset()
	local info = TD.mapInfo(player:GetAttribute("TDMap") or "")
	local l = info and info.light
	if not l then
		return MOON, MOON_ATMOS, {Saturation = 0.15, Contrast = 0.08, Brightness = 0, TintColor = Color3.new(1, 1, 1)}
	end
	local grading = {Saturation = 0.15, Contrast = 0.08, Brightness = 0, TintColor = Color3.new(1, 1, 1)}
	for k, v in l.grade or {} do
		grading[k] = v
	end
	-- (ClockTime y Brightness son opcionales: un atardecer, una noche más clara...)
	return {Ambient = l.Ambient, OutdoorAmbient = l.OutdoorAmbient, ExposureCompensation = l.ExposureCompensation, ClockTime = l.ClockTime, Brightness = l.Brightness}, l.atmos or MOON_ATMOS, grading
end

local function ambience(on)
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	if on then
		for _, k in LIGHT do
			savedLight[k] = Lighting[k]
		end
	end
	local light, air, grading = preset()
	TweenService:Create(Lighting, info, on and light or savedLight):Play()
	TweenService:Create(grade, info, on and grading or {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1)}):Play()
	if atmos then
		TweenService:Create(atmos, info, on and air or savedAtmos):Play()
	end
end

-- Lo que solo se ve dentro de su mapa (la aurora de Frozen Peak se vería en el cielo de los mapas vecinos)
local function skyFor(id)
	for _, info in TD.MAPS do
		local m = workspace:FindFirstChild(info.id)
		local aurora = m and m:FindFirstChild("MapaTDS") and m.MapaTDS:FindFirstChild("Aurora")
		if aurora then
			for _, p in aurora:GetChildren() do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = info.id == id and 0 or 1
				end
			end
		end
	end
end
skyFor(nil)

-- Desde un mapa no se ven la calle ni las casas (ni el cartel "YOUR HOUSE"): se quitan solo en tu pantalla
local TOWN = {"Mapa", "Casas"}
local hidden = {}
local function showTown(on)
	for _, name in TOWN do
		if on then
			if hidden[name] then
				hidden[name].Parent = workspace
				hidden[name] = nil
			end
		elseif not hidden[name] then
			hidden[name] = workspace:FindFirstChild(name)
			if hidden[name] then
				hidden[name].Parent = nil
			end
		end
	end
end

local active = false
local function setActive(on)
	if on ~= active then
		active = on
		ambience(on)
		showTown(not on)
	end
	skyFor(on and player:GetAttribute("TDMap") or nil)
end
player:GetAttributeChangedSignal("Mode"):Connect(function()
	setActive(inMap())
end)
-- (TDMap llega a la vez que Mode: si cambia estando ya en un mapa, se vuelve a aplicar la luz de ese mapa)
player:GetAttributeChangedSignal("TDMap"):Connect(function()
	if active and inMap() then
		ambience(true)
	end
	skyFor(inMap() and player:GetAttribute("TDMap") or nil)
end)
setActive(inMap())

LobbyRemote.OnClientEvent:Connect(function(kind, a)
	if kind == "Arrived" then
		UI.sound("Portal")
		UI.flash(Color3.fromRGB(255, 255, 255), 0.4, 1)
		UI.big(string.upper(a or Config.TD_MAP_NAME), "Ghost hunters are coming for the haunted house... scare them away with YOUR scares!", Color3.fromRGB(255, 150, 40), 4)
	elseif kind == "LeftMap" then
		UI.sound("Portal")
	end
end)
