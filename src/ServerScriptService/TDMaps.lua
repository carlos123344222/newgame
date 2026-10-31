-- Mapas del Tower Defense. Ninguno está en el juego: cada uno vive en ServerStorage.MapasTD.<id> (el modelo y su
-- terreno, un TerrainRegion "Terreno" con el atributo Corner) y solo se carga (Maps.get) donde se juega.
-- · Servidor público: los lobbies. Al empezar, TowerDefenseLobbies manda al grupo a un servidor reservado de este
--   mismo lugar con los datos del viaje {td = {map, diff, waves, from}}.
-- · Servidor de partida (reservado): carga solo ese mapa, mete en él a cada jugador que llega (y al reaparecer si
--   muere) y, al salir o acabar la partida, le devuelve a un servidor de lobbies (Maps.travelHome).
-- · En Studio no hay viajes: el lobby carga el mapa aquí mismo. El atributo de Workspace "TestPartida"
--   ("Mapa|Dificultad|Oleadas") simula un servidor de partida.
-- En un mapa el jugador está en el modo "td" (atributo Mode: Juego no le deja empezar visitas) y su atributo TDMap
-- dice en cuál. Cada modelo de mapa lleva los atributos Origin, Bounds, Spawn, PathWidth y las carpetas Camino y
-- ReturnPortal.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(RS.Config)
local TD = require(RS.TowerDefense)
local TDMatch = require(script.Parent.TDMatch)
local Remote = RS.Remote
local LobbyRemote = RS.LobbyRemote
local Storage = ServerStorage:WaitForChild("MapasTD")

local Maps = {}
Maps.list = {}

-- ¿Es este el servidor de una partida? (lo apuntó el servidor de lobbies al reservarlo: ServidorPartida)
local TEST = RunService:IsStudio() and workspace:GetAttribute("TestPartida")
Maps.isMatchServer = require(script.Parent.ServidorPartida).isMatchServer

-- Guarda (y congela) o descongela los datos de un jugador antes de viajar (Juego). Sin Juego, no hace nada.
function Maps.saveFor(plr, freeze)
	local f = script.Parent:FindFirstChild("GuardarJugador")
	if f then
		pcall(f.Invoke, f, plr, freeze)
	end
end
-- de vuelta en la explanada de los lobbies, entre el arco y el altar, mirando al altar
local BACK = CFrame.lookAt(Vector3.new(222, 3.5, 0), Vector3.new(246, 3.5, 0))
Maps.BACK = BACK
local SLOTS = 8

local function back()
	return BACK * CFrame.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 4)
end

local function new(info, map)
	local Z = {id = info.id, name = info.name, info = info, map = map, BACK = BACK}
	-- Z.onArrive(jugadores, ajustes): lo pone TDMatch para meter al grupo que llega en la partida
	Z.onArrive = nil

	-- sitio de cada jugador sobre la plataforma de llegada: en dos filas, mirando al mapa
	local function slot(i)
		local spawn = map:GetAttribute("Spawn")
		local col, row = (i - 1) % 4, (i - 1) // 4
		return spawn * CFrame.new((col - 1.5) * 4.5, 3, row * 4.5 - 2.25)
	end

	-- (en el servidor de partida no se mira Mode: al morir, Juego lo borra y al reaparecer vuelve al mapa)
	function Z.inMap(plr)
		return (Maps.isMatchServer or plr:GetAttribute("Mode") == "td") and plr:GetAttribute("TDMap") == info.id
	end

	-- El grupo de un lobby llega al mapa. settings: {diff, waves} elegidos en el lobby
	function Z.send(group, lobbyId, settings)
		local arrived = {}
		for i, plr in group do
			local char = plr.Parent and plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (hum and hum.Health > 0) or plr:GetAttribute("Mode") ~= nil then
				continue
			end
			plr:SetAttribute("TDMap", info.id)
			plr:SetAttribute("Mode", "td")
			plr:SetAttribute("TDLobby", lobbyId)
			hum.Sit = false
			char:PivotTo(slot((i - 1) % SLOTS + 1))
			LobbyRemote:FireClient(plr, "Arrived", info.name)
			table.insert(arrived, plr)
		end
		if Z.onArrive and #arrived > 0 then
			Z.onArrive(arrived, settings or {})
		end
	end

	-- Sale del mapa. to: CFrame donde aparece (nil = no se le mueve: ha muerto o se ha ido). En el servidor de partida
	-- salir es volver a los lobbies.
	function Z.leave(plr, to)
		if not Z.inMap(plr) then
			return
		end
		plr:SetAttribute("Mode", nil)
		plr:SetAttribute("TDLobby", nil)
		plr:SetAttribute("TDMap", nil)
		if Maps.isMatchServer and plr.Parent then
			return Maps.travelHome(plr)
		end
		local char = plr.Character
		if to and char then
			char:PivotTo(to)
		end
		LobbyRemote:FireClient(plr, "LeftMap")
	end
	Z.slot = slot

	-- Portal morado: de vuelta a los lobbies
	local portal = map:WaitForChild("ReturnPortal")
	local prompt = portal:FindFirstChildWhichIsA("ProximityPrompt", true)
	local veil = portal:FindFirstChild("Velo", true)
	local function goBack(plr)
		if Z.inMap(plr) then
			Z.leave(plr, back())
		end
	end
	if prompt then
		prompt.Triggered:Connect(goBack)
	end
	if veil then
		veil.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local plr = model and Players:GetPlayerFromCharacter(model)
			if plr then
				goBack(plr)
			end
		end)
	end

	-- Red de seguridad: si alguien se cae o se sale del mapa, vuelve a la plataforma
	function Z.contains(pos)
		local o = map:GetAttribute("Origin")
		local b = map:GetAttribute("Bounds") -- Rect: (x0, z0) - (x1, z1) relativos al centro del mapa
		local p = o:PointToObjectSpace(pos)
		return p.Y > -15 and p.X > b.Min.X and p.X < b.Max.X and p.Z > b.Min.Y and p.Z < b.Max.Y
	end
	function Z.rescue(plr)
		local char = plr.Character
		if char then
			char:PivotTo(slot(math.random(SLOTS)))
		end
	end
	return Z
end

---------- Cargar un mapa (la primera vez que hace falta) ----------
local loading = {}
function Maps.get(id)
	local info = TD.mapInfo(id)
	local stored = Storage:FindFirstChild(id)
	if not (info and stored) then
		warn("Tower Defense: falta el mapa ServerStorage.MapasTD." .. tostring(id))
		return nil
	end
	while loading[id] do
		task.wait()
	end
	if Maps[id] then
		return Maps[id]
	end
	loading[id] = true
	local ok, err = pcall(function()
		local region = stored:FindFirstChild("Terreno")
		if region then
			local c = region:GetAttribute("Corner")
			workspace.Terrain:PasteRegion(region, Vector3int16.new(c.X, c.Y, c.Z), true)
		end
		local map = stored:FindFirstChildOfClass("Model"):Clone()
		-- la decoración importada no lleva física: suelta, el faro o los árboles se caían (y gastaban servidor)
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and not d.Anchored then
				local m = d:FindFirstAncestorOfClass("Model")
				if not (m and m:FindFirstChildOfClass("Humanoid")) then
					d.Anchored = true
				end
			end
		end
		map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- (con StreamingEnabled: el mapa entero siempre en el cliente)
		map.Parent = workspace
		local Z = new(info, map)
		TDMatch(Z)
		Maps[id] = Z
		table.insert(Maps.list, Z)
	end)
	loading[id] = nil
	if not ok then
		warn("Tower Defense: no se pudo cargar " .. id .. ": " .. tostring(err))
	end
	return Maps[id]
end

-- El mapa en el que está jugando (o nil)
function Maps.of(plr)
	local Z = Maps[plr:GetAttribute("TDMap") or ""]
	return Z and Z.inMap(plr) and Z or nil
end

---------- Viajes ----------
-- Lo que se lleva cada viaje a una partida (validado: viene en los datos del viaje)
function Maps.cleanSettings(s)
	if typeof(s) ~= "table" or not TD.mapInfo(s.map) or not Storage:FindFirstChild(s.map) then
		return nil
	end
	return {
		map = s.map,
		diff = TD.DIFFS[s.diff] and s.diff or "Normal",
		waves = table.find(TD.WAVE_OPTIONS, s.waves) and s.waves or TD.WAVES,
		from = typeof(s.from) == "string" and s.from or nil,
		host = typeof(s.host) == "number" and s.host or nil, -- UserId del anfitrión del lobby
	}
end

-- Pantalla de viaje del cliente (LobbyUI) y la que conserva al llegar (ReplicatedFirst.LlegadaTD)
function Maps.announceTravel(plr, where, s)
	LobbyRemote:FireClient(plr, "Traveling", where, s and {map = s.map, diff = s.diff, waves = s.waves})
end

local settings -- servidor de partida: los ajustes de la partida (del primero que llega)
local homeTries = {} -- [jugador] = intentos de volver a los lobbies

-- Servidor de partida: de vuelta a los lobbies (a cualquier servidor público)
function Maps.travelHome(plr)
	if not plr.Parent then
		return
	end
	if TEST then
		-- (Studio: no hay viajes; aparece en la explanada de los lobbies)
		local char = plr.Character
		if char then
			char:PivotTo(BACK)
		end
		LobbyRemote:FireClient(plr, "LeftMap")
		return
	end
	local tries = (homeTries[plr] or 0) + 1
	homeTries[plr] = tries
	if tries == 1 then
		Maps.saveFor(plr, true)
		Maps.announceTravel(plr, "lobby")
	end
	-- (a un servidor público cualquiera, no al de origen: si se quedó vacío al salir el grupo, Roblox ya lo cerró y
	-- un viaje con ServerInstanceId a un servidor cerrado se queda colgado en la pantalla de viaje)
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({fromMatch = true})
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, {plr}, opts)
	if not ok then
		warn("Tower Defense: no se pudo volver al lobby: " .. tostring(err))
		Maps.homeFailed(plr)
		return
	end
	-- a veces el viaje se cuelga sin error (p. ej. su servidor de lobbies ya se cerró): si sigue aquí, otro intento
	-- (con margen: arrancar un servidor nuevo tarda; reintentar en mitad de un viaje lento lo rompe)
	task.delay(60, function()
		if plr.Parent and homeTries[plr] == tries then
			warn("Tower Defense: el viaje al lobby no llegó; se reintenta")
			Maps.homeFailed(plr)
		end
	end)
end

function Maps.homeFailed(plr)
	if not homeTries[plr] then
		return
	end
	if homeTries[plr] >= 4 then
		-- sus datos ya están guardados: al volver a entrar aparece en los lobbies
		plr:Kick("Couldn't get you back to the lobby. Your progress is saved: just rejoin!")
		return
	end
	task.delay(2, Maps.travelHome, plr)
end

if Maps.isMatchServer then
	-- Ajustes de la partida: los trae el primero que llega (o el atributo de prueba de Studio)
	local function settingsFrom(plr)
		if TEST then
			local m, d, w = string.match(TEST, "^([^|]+)|?([^|]*)|?(%d*)$")
			return Maps.cleanSettings({map = m, diff = d, waves = tonumber(w)})
		end
		local data = plr:GetJoinData().TeleportData
		return Maps.cleanSettings(typeof(data) == "table" and data.td)
	end

	-- Al aparecer: al mapa (la primera vez entra en la partida; si murió, vuelve a su sitio)
	local function place(plr, char)
		local Z = settings and Maps.get(settings.map)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1) -- (Juego lo acaba de colocar en su jardín)
		if not (Z and root and plr.Parent and plr.Character == char) then
			return
		end
		if plr:GetAttribute("TDMap") == Z.id then
			plr:SetAttribute("Mode", "td")
			char:PivotTo(Z.slot(math.random(8)))
		elseif plr:GetAttribute("Mode") == nil then
			Z.send({plr}, 0, settings)
		end
	end

	local function arrive(plr)
		settings = settings or settingsFrom(plr)
		if not settings then
			warn("Tower Defense: " .. plr.Name .. " llegó sin datos de partida")
			return Maps.travelHome(plr)
		end
		Maps.get(settings.map) -- (mientras, Juego carga sus datos y su personaje)
		plr.CharacterAdded:Connect(function(char)
			place(plr, char)
		end)
		if plr.Character then
			place(plr, plr.Character)
		end
	end
	Players.PlayerAdded:Connect(arrive)
	for _, plr in Players:GetPlayers() do
		task.spawn(arrive, plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		homeTries[plr] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(plr, _, msg)
		if homeTries[plr] then
			warn("Tower Defense: viaje al lobby fallido: " .. tostring(msg))
			Maps.homeFailed(plr)
		end
	end)
end

-- "My House" del menú estando en un mapa: a tu casa (Juego hace lo mismo cuando ya no estás en el modo "td")
Remote.OnServerEvent:Connect(function(plr, action)
	local Z = action == "GoHome" and Maps.of(plr)
	if Z then
		local plot = plr:GetAttribute("Plot")
		Z.leave(plr, plot and Config.Plots[plot] and Config.frontOf(Config.Plots[plot]) * CFrame.new(0, 3, 0) or BACK)
	end
end)

-- Lobby: morir en un mapa es salir de él (reapareces en tu jardín). En una partida, reapareces en el mapa (arriba).
local function watch(plr)
	plr.CharacterRemoving:Connect(function()
		local Z = not Maps.isMatchServer and Maps.of(plr)
		if Z then
			Z.leave(plr)
		end
	end)
end
for _, plr in Players:GetPlayers() do
	watch(plr)
end
Players.PlayerAdded:Connect(watch)

return Maps
