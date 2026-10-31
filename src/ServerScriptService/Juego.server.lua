-- Tu Casa Encantada (servidor): parcelas, casas, sustos, visitas, bots, dinero y guardado.
-- Multijugador: cada jugador tiene su casa en la calle y aparece delante de ella. A cualquier casa se entra
-- andando por la puerta: en la de otro empieza una visita (a ver si llegas al fondo); en la tuya, el modo "home"
-- (solo desde dentro se coloca, mueve y prueba lo que asusta).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(RS.Config)
local Builder = require(SSS.HouseBuilder)
local Behaviors = require(SSS.ScareBehaviors)
local Outfits = require(RS.Outfits)
local Misiones = require(SSS.MisionesServidor) -- (las misiones: M.add cuando pasa algo que piden)
local Remote = RS.Remote
local Assets = RS.Assets
local BotTemplate = ServerStorage.Bot
local D = Config.ROOM_D

-- Sin acceso a DataStore (Studio sin permisos de API) se juega igual, pero no se guarda.
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, "TuCasaEncantada2")
if not okStore then
	store = nil
end
-- En Studio se leen los datos de verdad pero no se escribe nada (ni el bloqueo de sesión): las pruebas no tocan las
-- partidas reales. Para probar el guardado en Studio, atributo StudioSave = true en Workspace.
local READ_ONLY = RunService:IsStudio() and not workspace:GetAttribute("StudioSave")
local LOCK_TRIES = 6 -- intentos de cargar mientras otro servidor aún tiene al jugador (el último se lo queda igualmente)
-- Servidor de una partida del Tower Defense (ServidorPartida): ahí tu casa no recibe visitantes
local MATCH_SERVER = require(SSS.ServidorPartida).isMatchServer
-- Modos en los que el dueño está en el Tower Defense: su casa se queda cerrada
local AWAY = {lobby = true, travel = true, td = true}

-- Chars = jugadores, Bots = visitantes bot, Portal = el portal blanco de cada puerta.
-- El portal es sólido para los jugadores (la puerta está "cerrada": se cruza con la animación del cliente,
-- Portales.lua) pero los bots lo atraviesan andando.
for _, g in {"Chars", "Bots", "Portal"} do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable("Chars", "Chars", false)
PhysicsService:CollisionGroupSetCollidable("Bots", "Bots", false)
PhysicsService:CollisionGroupSetCollidable("Bots", "Chars", false)
PhysicsService:CollisionGroupSetCollidable("Bots", "Portal", false)

local houses = {} -- [parcela] = casa (de jugador o NPC)
local state = {} -- [jugador] = {house, inv, houses, home, placed, canSave, likes, tut}
local visits = {} -- [jugador o bot] = visita en curso
local liked = {} -- [UserId del dueño] = {[UserId de quien dio 👍] = true} (una vez por servidor)
local endVisit, syncVisitors

-- Cada jugador aparece en su jardín: lo cargamos nosotros cuando su casa ya está construida
Players.CharacterAutoLoads = false
local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "Spawns"
spawnFolder.Parent = workspace
local plotSpawns = {}
for i, origin in Config.Plots do
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Parcela" .. i
	sp.Anchored = true
	sp.CanCollide, sp.CanQuery, sp.CanTouch = false, false, false
	sp.Transparency = 1
	sp.Size = Vector3.new(4, 0.2, 4)
	sp.CFrame = Config.frontOf(origin)
	sp.Neutral = true
	sp.Duration = 0
	for _, d in sp:GetChildren() do
		d:Destroy() -- sin la calcomanía de spawn
	end
	sp.Parent = spawnFolder
	plotSpawns[i] = sp
end

---------- Utilidades ----------
local function depthOf(h, pos)
	local p = h.cf:PointToObjectSpace(pos)
	return p.X, -p.Z
end

-- ¿Dentro de qué casa está esta posición? (y a qué profundidad)
local function houseAt(pos)
	for _, h in houses do
		local x, y, z = Config.toHouse(h.cf, pos)
		if math.abs(x) < h.roomW / 2 and y > -2 and y < h.roomH + 2 and z > 0 and z < h.rooms * D then
			return h, z
		end
	end
	return nil, 0
end

-- En tu jardín, mirando a la puerta
local function frontOf(h)
	return Config.frontOf(h.cf) * CFrame.new(0, 3, 0)
end

local function flatDist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- En el jardín, delante del porche, mirando a la calle
local function outside(h)
	return h.cf * CFrame.new(0, 3 - Config.FLOOR_Y, 11) * CFrame.Angles(0, math.pi, 0)
end

local function setGroup(model, group)
	local function set(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = group or "Chars"
		end
	end
	for _, p in model:GetDescendants() do
		set(p)
	end
	model.DescendantAdded:Connect(set)
end

-- pitch: tono (la voz de cada visitante); variantes, variación de tono y límites en ReplicatedStorage.Sfx
local Sfx = require(RS:WaitForChild("Sfx"))
local function sound(name, parent, pitch)
	if parent then
		Sfx.play(name, parent, nil, pitch)
	end
end

-- En un punto fijo del mundo: para lo que va a desaparecer enseguida (el bot al esfumarse)
local function soundAt(name, pos)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	sound(name, a)
	Debris:AddItem(a, 10)
end

local function exclaim(model, text, color)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(70, 70)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = bb
	bb.Parent = head
	Debris:AddItem(bb, 1.4)
end

---------- Monedas ----------
-- El visitante asustado suelta monedas que saltan y caen botando por el suelo de la casa. Solo el dueño las recoge:
-- su cliente las atrae al acercarse y pide "Collect" (aquí se comprueba que sean suyas y que esté cerca).
local coinSeq = 0

-- Lo que vale todo lo que hay sin recoger en el suelo de una casa
local function pileOf(h)
	local folder = h.model:FindFirstChild("Coins")
	local pile = 0
	for _, c in folder and folder:GetChildren() or {} do
		pile += c:GetAttribute("Value") or 0
	end
	return pile
end

local function dropCoins(h, pos, amount)
	local owner = h.owner
	if not (owner and owner.Parent and h.model.Parent) then
		return
	end
	-- con muchas sin recoger (más cuanto más nivel), cada vez sueltan menos: hay que volver a casa a por ellas. Con la
	-- Aspiradora cuenta lo que ha juntado mientras no estás (su depósito), con un tope mayor
	local st = state[owner]
	local vac = st and st.vacuum
	local mult = Config.coinPileMult(pileOf(h) + (vac and st.tank or 0), Config.playerLevel(owner), vac and Config.VACUUM_CAP or 1)
	local blood = Config.bloodNight(workspace:GetServerTimeNow())
	local pass = owner:GetAttribute("Pass_Coins2x") and 2 or 1 -- (pase 2x Coins)
	amount = math.floor(amount * Config.COIN_RATE * mult * (blood and Config.BLOOD_COINS or 1) * pass + 0.5)
	if mult < 0.5 and os.clock() - (h.pileWarn or -math.huge) > 120 then
		h.pileWarn = os.clock()
		Remote:FireClient(owner, "Info", vac and "Your Soul Vacuum is full! Go home to empty it or visitors will drop less"
			or "Your house is overflowing with coins! Collect them or visitors will drop less")
	end
	if amount <= 0 then
		return
	end
	local folder = h.model:FindFirstChild("Coins")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Coins"
		folder.Parent = h.model
	end
	local loose = folder:GetChildren()
	local n = math.clamp(math.ceil(amount / Config.COIN_VALUE), math.min(3, amount), 8) -- al menos 3: que se vea el puñado
	local base, extra = math.floor(amount / n), amount % n
	-- demasiadas piezas en el suelo: lo nuevo se suma a las que ya hay (que crecen un poco); no se pierde nada
	if #loose + n > Config.COIN_MAX then
		for k = 1, n do
			local c = loose[math.random(#loose)]
			local v = (c:GetAttribute("Value") or 0) + base + (k <= extra and 1 or 0)
			c:SetAttribute("Value", v)
			local d = math.min(1.3 + v / 40, 2.4)
			c.Size = Vector3.new(0.22, d, d)
		end
		return
	end
	local x0, _, z0 = Config.toHouse(h.cf, pos)
	for k = 1, n do
		coinSeq += 1
		local c = Instance.new("Part")
		c.Name = "Coin"
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(0.22, 1.3, 1.3)
		c.Material = Enum.Material.Neon -- brillan: se ven bien en las salas oscuras
		c.Color = Color3.fromRGB(255, 186, 48)
		c.Anchored = true
		c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
		c.CastShadow = false
		c:SetAttribute("Id", coinSeq)
		c:SetAttribute("Value", base + (k <= extra and 1 or 0))
		c:SetAttribute("Born", os.clock())
		-- sale disparada hacia arriba y cae botando cerca, siempre dentro de la casa
		local a = math.random() * math.pi * 2
		local r = 1.5 + math.random() * 2.5
		local lx = math.clamp(x0 + math.cos(a) * r, -h.roomW / 2 + 1.5, h.roomW / 2 - 1.5)
		local lz = math.clamp(z0 + math.sin(a) * r, 2, h.rooms * D - 1.5)
		local land = h.cf * CFrame.new(lx, 0.8, -lz) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		local start = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * land.Rotation
		c.CFrame = start
		c.Parent = folder
		local peak = start:Lerp(land, 0.5) + Vector3.new(0, 3 + math.random() * 1.5, 0)
		TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = peak}):Play()
		task.delay(0.22, function()
			if c.Parent then
				TweenService:Create(c, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {CFrame = land}):Play()
			end
		end)
	end
end

---------- Aspiradora de almas ----------
-- Con la aspiradora (st.vacuum, atributo Vacuum) las monedas no se quedan en el suelo: al caer vuelan a la boca de la
-- aspiradora del jardín (la animación es de cada cliente: Monedas, por el atributo Sucked) y van a tu dinero. Mientras
-- no estás (a más de VACUUM_AWAY de tu casa) se quedan en su depósito (st.tank) y al volver te las da de golpe con la
-- pantalla "Welcome back" (WelcomeBack). Al salir del juego o viajar, el depósito pasa a tu dinero.
local VacuumTemplate = Assets:FindFirstChild("Aspiradora")
-- sitios del jardín (x, z, giro) por orden: el primero libre. Lejos del porche (su barandilla llega a x 6.9) y de
-- Don Calabaza (Tutorial, en 4.6/9.6: es del cliente y aquí no se ve). El último es el de siempre, por si nada cabe.
local VACUUM_SPOTS = {{10.8, 7.5, -60}, {-11.5, 4.5, 60}, {10.5, 4.5, -60}, {5.6, 7.4, -60}}
local function placeVacuum(h)
	local old = h.model:FindFirstChild("Aspiradora")
	local st = h.owner and state[h.owner]
	if not (st and st.vacuum and VacuumTemplate) then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local m = VacuumTemplate:Clone()
	-- en el jardín, con la boquilla hacia el camino
	local bcf, size = m:GetBoundingBox()
	local lift = m:GetPivot().Y - (bcf.Y - size.Y / 2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {h.model:FindFirstChild("Coins"), h.model:FindFirstChild("Bot")}
	local function free(cf)
		local box = cf * CFrame.new(0, size.Y / 2 + 0.35, 0)
		for _, p in workspace:GetPartBoundsInBox(box, size + Vector3.new(0.6, -0.7, 0.6), params) do
			if p.Transparency < 1 and not p:FindFirstAncestorOfClass("Humanoid") and not (p.Parent and p.Parent:FindFirstChildOfClass("Humanoid")) then
				return false
			end
		end
		return true
	end
	local at
	for _, s in VACUUM_SPOTS do
		at = h.cf * CFrame.new(s[1], -Config.FLOOR_Y, s[2]) * CFrame.Angles(0, math.rad(s[3]), 0)
		if free(at) then
			break
		end
	end
	m:PivotTo(at * CFrame.new(0, lift, 0))
	m.Parent = h.model
end

local function nearHome(plr, h)
	if plr:GetAttribute("Mode") == "home" then
		return true
	end
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - Config.frontOf(h.cf).Position).Magnitude < Config.VACUUM_AWAY
end

-- (cada 0.25 s) aspira las monedas que ya han caído
local function vacuumTick()
	for _, h in houses do
		local owner = h.owner
		local st = owner and state[owner]
		local folder = st and st.vacuum and h.model:FindFirstChild("Coins")
		for _, c in folder and folder:GetChildren() or {} do
			if not c:GetAttribute("Sucked") and os.clock() - (c:GetAttribute("Born") or 0) > 0.9 then
				c:SetAttribute("Sucked", true)
				task.delay(0.6, function()
					if not c.Parent then
						return
					end
					local v = c:GetAttribute("Value") or 0
					c:Destroy()
					if owner.Parent and state[owner] == st then
						if st.awaySince then
							st.tank += v
							if st.house then
								st.house.model:SetAttribute("Tank", st.tank)
							end
						else
							owner.leaderstats.Coins.Value += v
							st.sucked += v
							Misiones.add(owner, "coins", v)
						end
					end
				end)
			end
		end
	end
end

-- (cada 0.5 s) ¿está en casa? Al volver tras WELCOME_MIN segundos fuera, el depósito pasa a su dinero
local function awayTick()
	for plr, st in state do
		local h = st.house
		if not (st.vacuum and h and plr.Parent) then
			continue
		end
		if nearHome(plr, h) then
			if st.awaySince then
				local away = os.clock() - st.awaySince
				local tank = st.tank
				st.awaySince, st.tank = nil, 0
				h.model:SetAttribute("Tank", 0)
				if tank > 0 then
					plr.leaderstats.Coins.Value += tank
					Misiones.add(plr, "coins", tank)
					if away >= Config.WELCOME_MIN then
						Remote:FireClient(plr, "WelcomeBack", tank, math.floor(away))
					else
						st.sucked += tank
					end
				end
			end
			if st.sucked > 0 then
				Remote:FireClient(plr, "Vacuum", st.sucked) -- "+N" sobre la aspiradora
				st.sucked = 0
			end
		elseif not st.awaySince then
			st.awaySince, st.tank = os.clock(), 0
		end
	end
end

local function syncFear(v)
	if v.player then
		v.player:SetAttribute("Fear", math.floor(v.fear + 0.5))
	elseif v.bar then
		v.bar.Size = UDim2.fromScale(v.fear / 100, 1)
		v.bot:SetAttribute("Fear", math.floor(v.fear + 0.5))
	end
end

-- Capa de animación del bot; la dibuja cada cliente (NPCAnim): sneak, startle, panic, faint o cheer
local function anim(v, name)
	if v.bot then
		v.bot:SetAttribute("Anim", name)
		v.bot:SetAttribute("AnimAt", workspace:GetServerTimeNow())
	end
end

---------- API para los sustos ----------
local api = {}

function api.alive(v)
	return visits[v.key] == v
end

function api.visitsIn(h)
	local list = {}
	for _, v in visits do
		if v.house == h and v.ready then
			table.insert(list, v)
		end
	end
	return list
end

function api.addFear(v, amount)
	if visits[v.key] ~= v then
		return
	end
	v.fear = math.min(v.maxFear or 100, v.fear + amount * (v.courage or 1))
	v.calmAt = os.clock() + 2
	syncFear(v)
	if v.fear >= 100 then
		endVisit(v, "fled")
	end
end

function api.endVisit(v, result)
	endVisit(v, result)
end

function api.fx(v, kind, a, b)
	if v.player then
		Remote:FireClient(v.player, "FX", kind, a, b)
	end
end

function api.sound(name, parent)
	sound(name, parent)
end

-- Monedas de más que suelta un susto (el Pozo de Almas), como las de asustar
function api.coins(v, pos, amount)
	if v.house.owner and v.bot and amount > 0 then
		dropCoins(v.house, pos, math.floor(amount * (v.mult or 1) + 0.5))
	end
end

-- La trampilla te devuelve al principio de la sala en la que estás (al punto de la ruta más cercano, que puede
-- haber sustos en mitad del camino)
function api.toRoomStart(v)
	local h = v.house
	local _, z = depthOf(h, v.root.Position)
	local room = math.clamp(math.floor(z / D), 0, h.rooms - 1)
	local x, depth = 0, room * D + 3.5
	local best = math.huge
	for _, p in h.route or {} do
		if math.abs(p.Y - depth) < best then
			best, x, depth = math.abs(p.Y - depth), p.X, p.Y
		end
	end
	local cf = h.cf * CFrame.new(x, 3, -depth)
	local model = v.player and v.player.Character or v.bot
	if model then
		model:PivotTo(cf)
	end
end

Behaviors.init(api)

---------- Sustos ----------
local function trigger(s, v)
	local h = v.house
	s.busy = true
	s.model:SetAttribute("Busy", true) -- (los clientes paran su animación de reposo: ScareIdle)
	v.lastBy = s.type
	if v.bot then
		v.scaredAt = os.clock()
	end
	-- solo pagan los visitantes bot (los jugadores que te visitan no: no se puede farmear entre amigos)
	if h.owner and v.bot then
		local now = os.clock()
		v.combo = now - v.lastScare <= Config.COMBO_WINDOW and v.combo + 1 or 1
		v.lastScare = now
		-- el susto ha funcionado: el visitante suelta monedas (más con combo) y el dueño ve qué lo ha asustado
		-- cada nivel de la tropa paga un poco más, y gana experiencia
		local lv = Config.troopLevel(h.owner, s.type)
		dropCoins(h, v.root.Position, math.floor(s.def.pay * v.combo * (v.mult or 1) * (1 + Config.LEVEL_PAY * (lv - 1)) + 0.5))
		sound("Coins", v.root)
		Config.addXP(h.owner, s.type, Config.XP_SCARE)
		Config.addPlayerXP(h.owner, Config.PXP_SCARE)
		if h.owner.Parent then
			Remote:FireClient(h.owner, "Scared", v.combo > 1 and ("Combo x%d!"):format(v.combo) or s.def.name, s.pos + Vector3.new(0, 7, 0))
		end
	end
	task.spawn(function()
		local ok, err = pcall(Behaviors[s.type], s, h, v)
		if not ok then
			warn("Susto " .. s.type .. ": " .. tostring(err))
		end
		s.busy = false
		if s.model.Parent then
			s.model:SetAttribute("Busy", nil)
		end
	end)
end

---------- Casas ----------
local function updateHouse(h)
	local power, count = 0, 0
	for _, s in h.scares do
		power += s.def.fear
		count += Config.slots(s.type) -- espacios ocupados (los grandes cuentan por 2 o 3)
	end
	h.power, h.count = power, count
	-- la ruta de la puerta al fondo, esquivando lo sólido: la siguen los visitantes bot
	h.route = Config.route(h.model, h.rooms)
	h.routeVer = (h.routeVer or 0) + 1
	h.model:SetAttribute("Power", power)
	h.model:SetAttribute("Rooms", h.rooms)
	h.model:SetAttribute("HouseName", h.name)
	local st = h.owner and state[h.owner]
	local likes = st and st.likes or 0
	h.model:SetAttribute("Likes", likes)
	if h.refs then
		h.refs.boardName.Text = h.name
		h.refs.boardLikes.Text = h.owner and ("👍 %d"):format(likes) or "Nobody lives here...?"
		h.refs.topText.Text = h.owner and h.name or "" -- (sin dueño: sin cartel en el cielo, ya lo dice el del jardín)
	end
	if h.owner then
		h.owner:SetAttribute("Placed", count)
		-- los tipos que tiene colocados ("Armario,Luz"): cuentan como suyos para el equipo del Tower Defense (TD.owns)
		local types = {}
		for _, s in h.scares do
			if not table.find(types, s.type) then
				table.insert(types, s.type)
			end
		end
		h.owner:SetAttribute("PlacedTypes", table.concat(types, ","))
	end
end

---------- Contadores de los rankings ----------
-- Del día (UTC): el ranking de la calle y la Casa del día (atributos TodayScared / TodayLikes de la casa, los lee
-- Rankings). Del mes: los tableros de la plaza (atributos M_Scared, M_XP, M_Likes y M_Endless del jugador; al guardar
-- van a los OrderedDataStore de cada tablero). Se guardan con la partida (st.counters).
local function counters(st)
	local now = os.time()
	local day, month = now // 86400, os.date("!%Y-%m", now)
	local c = st.counters
	if c.day ~= day then
		c.day, c.dScared, c.dLikes = day, 0, 0
	end
	if c.month ~= month then
		c.month, c.mScared, c.mXP, c.mLikes, c.mEndless = month, 0, 0, 0, 0
	end
	return c
end

local function syncCounters(plr, st)
	local c = counters(st)
	plr:SetAttribute("M_Scared", c.mScared)
	plr:SetAttribute("M_XP", plr:GetAttribute("PXP") or 0) -- (tablero Most Experience: experiencia total)
	plr:SetAttribute("M_Likes", c.mLikes)
	plr:SetAttribute("M_Endless", c.mEndless)
	if st.house then
		st.house.model:SetAttribute("TodayScared", c.dScared)
		st.house.model:SetAttribute("TodayLikes", c.dLikes)
	end
end

local function count(plr, field, n)
	local st = plr and state[plr]
	if st and n > 0 then
		local c = counters(st)
		c[field] += n
		syncCounters(plr, st)
	end
end

-- 👍 en el cartel de una casa ajena (una vez por casa y servidor)
local function like(plr, h)
	local owner = h.owner
	if not owner or owner == plr or not owner.Parent then
		return
	end
	local who = liked[owner.UserId] or {}
	liked[owner.UserId] = who
	if who[plr.UserId] then
		return Remote:FireClient(plr, "Info", "You already liked this house 👍")
	end
	who[plr.UserId] = true
	local st = state[owner]
	if st then
		st.likes += 1
		count(owner, "dLikes", 1)
		count(owner, "mLikes", 1)
	end
	updateHouse(h)
	sound("Like", h.refs and h.refs.likePrompt and h.refs.likePrompt.Parent)
	Remote:FireClient(plr, "Liked", h.name)
	Remote:FireClient(owner, "GotLike", plr.DisplayName)
end

-- Estrellas de fusión de un susto colocado: atributo Star, chispas del color de la estrella y ★ encima (todo cuelga
-- del Hitbox, que los comportamientos no tocan)
local function decorate(m, star)
	m:SetAttribute("Star", star > 0 and star or nil)
	local hb = m:FindFirstChild("Hitbox")
	if not hb then
		return
	end
	for _, name in {"StarFX", "Stars"} do
		local old = hb:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if star <= 0 then
		return
	end
	local col = Config.STAR_COLORS[star]
	local a = Instance.new("Attachment")
	a.Name = "StarFX"
	a.Position = Vector3.new(0, -1.3, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 3 + star * 3
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(1, 2.4)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 0.6, 0)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25 + star * 0.08), NumberSequenceKeypoint.new(1, 0)})
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = a
	a.Parent = hb
	local bb = Instance.new("BillboardGui")
	bb.Name = "Stars"
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, math.min(m:GetExtentsSize().Y, 9) - 0.7, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = string.rep("★", star)
	l.TextColor3 = col
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromRGB(30, 18, 40)
	l.Parent = bb
	bb.Parent = hb
end

-- El modelo de un susto colocado: con la skin que el dueño tenga equipada en ese susto (Config.skinFor), pero es el
-- mismo susto (se llama como él y se comporta igual); atributo Skin: la skin, si lleva
local function scareModel(h, t, x, z, r, id, star)
	local look = Config.skinFor(h.owner, t)
	local m = Assets.Scares[look]:Clone()
	m.Name = t
	m:SetAttribute("Skin", look ~= t and look or nil)
	m:PivotTo(Config.scareCFrame(h.cf, x, z, r))
	m:SetAttribute("Id", id)
	m:SetAttribute("R", r)
	Behaviors.prepare(m, t)
	decorate(m, star)
	return m
end

local function spawnScare(h, t, x, z, r)
	h.nextId += 1
	local star = h.owner and Config.starOf(h.owner, t) or 0
	local m = scareModel(h, t, x, z, r, h.nextId, star)
	m.Parent = h.model.Scares
	h.scares[h.nextId] = {type = t, def = Config.starDef(t, star), star = star, model = m, pos = m:GetPivot().Position, cf = m:GetPivot(), x = x, z = z, r = r,
		hits = setmetatable({}, {__mode = "k"})} -- hits[visitante] = cuándo lo asustó (por persona, no por visita)
end

-- Cambia el aspecto de los sustos t ya colocados (al equipar o quitar una skin). Los que están asustando a alguien
-- esperan a terminar, para no cortar su susto a medias
-- Cambia la estrella de los sustos t ya colocados (al fusionar): sus datos y su aura, sin rehacer el modelo
local function restar(h, t, star)
	for _, s in h.scares do
		if s.type == t then
			s.star = star
			s.def = Config.starDef(t, star)
			if s.model.Parent then
				decorate(s.model, star)
			end
		end
	end
end

local function reskin(h, t)
	for id, s in h.scares do
		if s.type == t then
			task.spawn(function()
				while s.busy and h.scares[id] == s do
					task.wait(0.25)
				end
				if h.scares[id] ~= s or not s.model.Parent then
					return
				end
				local m = scareModel(h, t, s.x, s.z, s.r, id, s.star)
				s.model:Destroy()
				s.model = m
				m.Parent = h.model.Scares
			end)
		end
	end
end

local startVisit -- se define más abajo

local function rebuild(h)
	-- medidas de dentro según la casa (la Grand Haunted Manor es más ancha, más alta y con más espacios)
	h.roomW, h.roomH, h.spaces = Config.houseDims(h.template, h.rooms)
	h.model:SetAttribute("RoomW", h.roomW)
	h.model:SetAttribute("RoomH", h.roomH)
	h.model:SetAttribute("Spaces", h.spaces)
	h.refs = Builder.build(h)
	if h.refs.likePrompt then
		h.refs.likePrompt.Triggered:Connect(function(plr)
			like(plr, h)
		end)
	end
	updateHouse(h)
end

local function createHouse(i, owner, rooms, npc, template)
	local model = Instance.new("Model")
	model.Name = "Casa" .. i
	model:SetAttribute("Origin", Config.Plots[i])
	model:SetAttribute("Owner", owner and owner.UserId or 0)
	local scares = Instance.new("Folder")
	scares.Name = "Scares"
	scares.Parent = model
	local h = {
		i = i, cf = Config.Plots[i], owner = owner, npc = npc, model = model, rooms = rooms, template = template,
		name = owner and (owner.DisplayName .. "'s House") or npc.name,
		id = owner and owner.UserId or ("npc" .. i),
		scares = {}, nextId = 0, nextBot = 0, power = 0, count = 0,
	}
	rebuild(h)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- (con StreamingEnabled: la casa entera siempre en el cliente)
	model.Parent = workspace.Casas
	houses[i] = h
	if npc then
		for _, s in npc.scares do
			if Config.canPlace(model, rooms, s[1], s[2], s[3], s[4]) then
				spawnScare(h, s[1], s[2], s[3], s[4])
			else
				warn("Susto mal colocado en " .. npc.name .. ": " .. s[1])
			end
		end
		updateHouse(h)
	end
	return h
end

-- Coloca los sustos guardados; los que no caben (o pasan del límite de la casa) vuelven a la mochila
local function placeAll(plr, h, placed)
	local st = state[plr]
	local n = 0
	for _, p in placed do
		local t, x, z, r = p[1], p[2], p[3], p[4]
		if Config.Scares[t] and n + Config.slots(t) <= h.spaces and Config.canPlace(h.model, h.rooms, t, x, z, r) then
			spawnScare(h, t, x, z, r)
			n += Config.slots(t)
		elseif Config.Scares[t] then
			st.inv[t] = (st.inv[t] or 0) + 1
			plr:SetAttribute("Inv_" .. t, st.inv[t])
		end
	end
	updateHouse(h)
end

local function removeHouse(h)
	for _, v in visits do
		if v.house == h then
			endVisit(v, "quit")
		end
	end
	if h.bot then
		h.bot:Destroy()
	end
	houses[h.i] = nil
	h.model:Destroy()
end

local function npcHouse(i)
	local npc = Config.NPCHouses[(i - 1) % #Config.NPCHouses + 1]
	return createHouse(i, nil, npc.rooms, npc, npc.template)
end

---------- Bots visitantes ----------
local GOLD = Color3.fromRGB(255, 196, 50)
-- complementos que van en la mano derecha (esos visitantes no llevan linterna)
local RIGHT_HAND = {camera = true, pizza = true, cane = true, katana = true, sword = true, staff = true, scepter = true, crossbow = true, axe = true, silversword = true, pitchfork = true, brush = true, wand = true, flask = true, kingscepter = true}

-- El bot de un visitante (vdef de Config.Visitors) con su ropa, su linterna, la barra de miedo, su nombre con el color
-- de su rareza y, de raro para arriba, un aura (los míticos arcoíris: el color lo cambia cada cliente, NPCAnim)
local function makeBot(vdef, rarity)
	local bot = BotTemplate:Clone()
	Outfits.dress(bot, vdef)
	local light = true
	for _, g in vdef.gear or {} do
		if RIGHT_HAND[g] then
			light = false
		end
	end
	-- linterna en la mano
	local hand = bot:FindFirstChild("RightHand")
	if hand and light then
		local torch = Instance.new("Part")
		torch.Name = "Linterna"
		torch.Size = Vector3.new(0.35, 0.35, 1.2)
		torch.Color = Color3.fromRGB(30, 30, 34)
		torch.Material = Enum.Material.Metal
		torch.CanCollide = false
		torch.Massless = true
		torch.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, torch
		weld.Parent = torch
		local spot = Instance.new("SpotLight")
		spot.Range = 26
		spot.Angle = 50
		spot.Brightness = 1.2
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 240, 210)
		spot.Parent = torch
		torch.Parent = bot
	end
	local head = bot:FindFirstChild("Head")
	-- barra de miedo sobre la cabeza, con el nombre y la rareza
	local bb = Instance.new("BillboardGui")
	bb.Name = "Visitante"
	bb.Size = UDim2.fromOffset(150, 40)
	bb.StudsOffset = Vector3.new(0, 2.6 + (vdef.scale or 1) * 0.4, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Name = "Nombre"
	name.Size = UDim2.new(1, 0, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 15
	name.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), rarity.id == "Common" and 0.3 or 0)
	name.TextStrokeTransparency = 0.2
	name.Text = vdef.name
	name.Parent = bb
	if rarity.id ~= "Common" then
		local tag = Instance.new("TextLabel")
		tag.Name = "Rareza"
		tag.Position = UDim2.fromOffset(0, -14)
		tag.Size = UDim2.new(1, 0, 0, 14)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.GothamBlack
		tag.TextSize = 11
		tag.TextColor3 = rarity.color
		tag.TextStrokeTransparency = 0.3
		tag.Text = string.upper(rarity.name)
		tag.Parent = bb
	end
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.5, -32, 0, 22)
	back.Size = UDim2.fromOffset(64, 9)
	back.BackgroundColor3 = Color3.fromRGB(20, 10, 20)
	back.BorderSizePixel = 0
	back.Parent = bb
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	bar.BorderSizePixel = 0
	bar.Parent = back
	bb.Parent = head
	-- aura según la rareza: chispas y luz de su color; desde épico, contorno; legendario y mítico, un haz de luz
	local torso = bot:FindFirstChild("UpperTorso")
	local idx = Config.RarityIndex[rarity.id]
	local variant = vdef.variant and Config.VariantById[vdef.variant]
	local color = variant and variant.color or vdef.golden and GOLD or rarity.color
	if torso and (idx >= 3 or variant) then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Aura"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		sparkles.LightEmission = 1
		sparkles.Rate = 6 + idx * 4
		sparkles.Lifetime = NumberRange.new(0.8, 1.6)
		sparkles.Speed = NumberRange.new(0.5, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.35 + idx * 0.05, 0)
		sparkles.Parent = torso
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = color, 7 + idx * 1.5, 0.55 + idx * 0.1
		glow.Parent = torso
	end
	if idx >= 4 or variant then
		local hl = Instance.new("Highlight")
		hl.Name = "Contorno"
		hl.FillTransparency = 0.85
		hl.FillColor = color
		hl.OutlineColor = color
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = bot
	end
	-- legendario o más: un círculo de runas bajo sus pies del que suben chispas y, desde mítico, orbes que le dan
	-- vueltas (los hace girar cada cliente: VisitorBook, por el Weld "Giro")
	local root = bot:FindFirstChild("HumanoidRootPart")
	if idx >= 5 and root then
		local function part(props, parent)
			local p = Instance.new("Part")
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
			p.Material = Enum.Material.Neon
			for k, val in props do
				p[k] = val
			end
			p.Parent = parent
			return p
		end
		local function spinner(name, y, speed)
			local hub = part({Name = name, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = root.CFrame * CFrame.new(0, y, 0)}, bot)
			local w = Instance.new("Weld")
			w.Name = "Giro"
			w.Part0, w.Part1, w.C0 = root, hub, CFrame.new(0, y, 0)
			w:SetAttribute("Speed", speed)
			w.Parent = hub
			return hub
		end
		local function stick(p, hub)
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = hub, p
			wc.Parent = p
		end
		local R = idx >= 7 and 3.6 or idx >= 6 and 3.1 or 2.6
		local feet = -(bot.Humanoid.HipHeight + root.Size.Y / 2) + 0.08 -- (a ras de suelo)
		local ring = spinner("AuraRunas", feet, idx >= 6 and 0.9 or 0.6)
		-- anillo de trazos y, dentro, runas en rombo
		local N = 18
		for k = 0, N - 1 do
			local a = k / N * math.pi * 2
			stick(part({Size = Vector3.new(2 * math.pi * R / N * 0.62, 0.06, 0.16), Color = color, Transparency = 0.15,
				CFrame = ring.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R)}, ring), ring)
			if k % 3 == 0 then
				stick(part({Size = Vector3.new(0.38, 0.06, 0.38), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Transparency = 0.1,
					CFrame = ring.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R * 0.72) * CFrame.Angles(0, math.pi / 4, 0)}, ring), ring)
			end
		end
		-- resplandor del suelo y chispas que suben del anillo
		local disc = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, R * 2.1, R * 2.1), Color = color, Transparency = 0.82,
			CFrame = ring.CFrame * CFrame.Angles(0, 0, math.pi / 2)}, ring)
		stick(disc, ring)
		local rise = Instance.new("ParticleEmitter")
		rise.Name = "Chispas"
		rise.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		rise.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		rise.LightEmission = 1
		rise.Shape, rise.ShapeStyle = Enum.ParticleEmitterShape.Cylinder, Enum.ParticleEmitterShapeStyle.Surface
		rise.EmissionDirection = Enum.NormalId.Left -- (el cilindro está tumbado: su eje X apunta hacia arriba)
		rise.Rate = idx >= 7 and 40 or idx >= 6 and 26 or 16
		rise.Lifetime = NumberRange.new(1.2, 2.2)
		rise.Speed = NumberRange.new(2, 4.5)
		rise.SpreadAngle = Vector2.new(6, 6)
		rise.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)})
		rise.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
		rise.Parent = disc
		local glowFloor = Instance.new("PointLight")
		glowFloor.Color, glowFloor.Range, glowFloor.Brightness = color, R * 2.5, 0.8
		glowFloor.Parent = disc
		if idx >= 6 then
			-- orbes que giran a la altura del pecho, dejando una estela
			local orbit = spinner("AuraOrbes", 0.4, -1.6)
			for k = 0, (idx >= 7 and 4 or 2) do
				local a = k / (idx >= 7 and 5 or 3) * math.pi * 2
				local orb = part({Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Color = color:Lerp(Color3.new(1, 1, 1), 0.3),
					CFrame = orbit.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, math.sin(a * 2) * 0.6, -R * 0.7)}, orbit)
				stick(orb, orbit)
				if vdef.secret then
					-- al Rey Calabaza le dan vueltas calabacitas talladas que arden (mirando hacia fuera)
					orb.Color, orb.Material, orb.Size = Color3.fromRGB(255, 132, 26), Enum.Material.SmoothPlastic, Vector3.new(0.75, 0.62, 0.75)
					local out = orbit.CFrame * CFrame.Angles(0, a, 0)
					for s = -1, 1, 2 do
						stick(part({Size = Vector3.new(0.13, 0.13, 0.05), Color = Color3.fromRGB(255, 214, 90), CFrame = CFrame.new(orb.Position) * out.Rotation * CFrame.new(s * 0.14, 0.06, -0.37) * CFrame.Angles(0, 0, math.pi / 4)}, orbit), orbit)
					end
					stick(part({Size = Vector3.new(0.3, 0.07, 0.05), Color = Color3.fromRGB(255, 214, 90), CFrame = CFrame.new(orb.Position) * out.Rotation * CFrame.new(0, -0.12, -0.36)}, orbit), orbit)
					stick(part({Size = Vector3.new(0.09, 0.22, 0.09), Color = Color3.fromRGB(70, 110, 40), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(orb.Position) * CFrame.new(0, 0.38, 0)}, orbit), orbit)
				end
				local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
				t0.Position, t1.Position = Vector3.new(0, 0.22, 0), Vector3.new(0, -0.22, 0)
				t0.Parent, t1.Parent = orb, orb
				local trail = Instance.new("Trail")
				trail.Attachment0, trail.Attachment1 = t0, t1
				trail.Lifetime = 0.45
				trail.LightEmission = 1
				trail.Color = ColorSequence.new(color)
				trail.Transparency = NumberSequence.new(0.2, 1)
				trail.FaceCamera = true
				trail.Parent = orb
			end
		end
	end
	if vdef.rainbow or vdef.cosmic then
		bot:SetAttribute("Rainbow", vdef.rainbow == true)
		bot:SetAttribute("Cosmic", vdef.cosmic == true)
	end
	if vdef.scale and vdef.scale ~= 1 then
		bot:ScaleTo(vdef.scale)
	end
	return bot, bar
end

-- Cada cuánto llega el siguiente bot: cuanto más poder y 👍 tiene la casa, más visitantes atrae
local function nextBotDelay(h)
	local boost = 1 + h.power / 800 + (h.model:GetAttribute("Likes") or 0) / 20 -- (el miedo de los fuertes ya es enorme: Config, curva de potencia)
	return math.max(4, math.random(Config.BOT_EVERY[1], Config.BOT_EVERY[2]) / boost)
end

-- Camina hacia una profundidad (z) de la casa (y x lateral, si se da); devuelve false si se acabó el tiempo
local function walkTo(bot, h, z, timeout, x)
	local hum = bot.Humanoid
	local target = (h.cf * CFrame.new(x or 0, 0, -z)).Position
	local t0 = os.clock()
	while bot.Parent and flatDist(bot.HumanoidRootPart.Position, target) > 2 do
		if os.clock() - t0 > timeout then
			return false
		end
		hum:MoveTo(target)
		task.wait(0.15)
	end
	return true
end

-- Punto de la ruta al que ir desde (x, z): el más cercano, o el siguiente si ese ya queda atrás
local function nextWaypoint(route, x, z)
	local best, bd = 1, math.huge
	for i, p in route do
		local d = (p - Vector2.new(x, z)).Magnitude
		if d < bd then
			best, bd = i, d
		end
	end
	if route[best].Y <= z + 0.3 and route[best + 1] then
		best += 1
	end
	return best
end

-- Recorre la ruta de la casa hacia la puerta (para salir sin chocar con los sustos que hay en el camino)
local function walkOut(bot, h, timeout)
	local route = h.route
	if route and bot.Parent then
		local x, z = depthOf(h, bot.HumanoidRootPart.Position)
		local best, bd = 1, math.huge
		for i, p in route do
			local d = (p - Vector2.new(x, z)).Magnitude
			if d < bd then
				best, bd = i, d
			end
		end
		for i = best, 1, -1 do
			if not walkTo(bot, h, route[i].Y, timeout, route[i].X) then
				return false
			end
		end
	end
	return true
end

local function finishBot(h, bot, delay)
	task.delay(delay, function()
		local poof = Assets:FindFirstChild("Poof")
		if poof and bot.Parent then
			local p = poof:Clone()
			p.Parent = bot.HumanoidRootPart
			p:Emit(30)
			soundAt("Poof", bot.HumanoidRootPart.Position)
			task.wait(0.15)
		end
		bot:Destroy()
		if h.bot == bot then
			h.bot = nil
			h.nextBot = os.clock() + nextBotDelay(h)
		end
	end)
end

-- Suerte extra (solo Config.LUCK_ADMINS): el cliente pide x1 / x10 / x100 y aquí se comprueba quién es
local luckRemote = Instance.new("RemoteEvent")
luckRemote.Name = "LuckBoost"
luckRemote.OnServerEvent:Connect(function(plr, n)
	if Config.LUCK_ADMINS[plr.UserId] and table.find(Config.LUCK_BOOSTS, n) then
		plr:SetAttribute("LuckBoost", n)
	end
end)
luckRemote.Parent = RS

local function spawnBot(h)
	-- ¿quién llega? casi siempre alguien normal; muy de vez en cuando, alguien raro... o algo legendario
	local boost = h.owner and h.owner:GetAttribute("LuckBoost") or 1
	if h.owner and h.owner:GetAttribute("Pass_Lucky") then
		boost *= Config.LUCKY_BOOST -- (pase Lucky Visitors)
	end
	-- en la Noche de Sangre, mucha más suerte (de rareza y de materia)
	local blood = Config.bloodNight(workspace:GetServerTimeNow())
	local vdef, rarity = Config.rollVisitor(nil, Config.playerLevel(h.owner), boost * (blood and Config.BLOOD_LUCK or 1)) -- (más nivel del dueño, más suerte)
	-- y rarísima vez, hecho de otra materia (oro, hielo, diamante...: Config.Variants), con más monedas
	local variant = not (vdef.variant or vdef.rainbow or vdef.cosmic or vdef.secret) and Config.rollVariant(nil, boost * (blood and Config.BLOOD_VARIANT or 1)) or nil
	if variant then
		vdef = setmetatable({variant = variant.id, name = variant.name .. " " .. vdef.name, mult = (vdef.mult or 1) * variant.mult}, {__index = vdef})
	end
	local bot, bar = makeBot(vdef, rarity)
	local hum = bot.Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- (el nombre va en su cartel, con su rareza)
	hum.DisplayName = vdef.name
	bot:SetAttribute("VisitorId", vdef.id)
	bot:SetAttribute("Rarity", rarity.id)
	bot:SetAttribute("Variant", variant and variant.id or vdef.variant)
	if h.owner and h.owner.Parent then
		if variant then
			Remote:FireClient(h.owner, "VisitorVariant", vdef.id, variant.id)
		elseif rarity.id ~= "Common" then
			Remote:FireClient(h.owner, "Visitor", vdef.id)
		end
	end
	if (Config.RarityIndex[rarity.id] >= 5 or variant) and h.owner then
		Remote:FireAllClients("VisitorAnnounce", h.owner.DisplayName, vdef.id, variant and variant.id)
	end
	if vdef.secret and h.owner then
		-- el Rey Calabaza: aviso a lo grande para todo el servidor (VisitorBook: cartel, sonido y mensaje en el chat)
		Remote:FireAllClients("SecretAnnounce", h.owner.DisplayName, vdef.id, h.owner.UserId)
	end
	-- los raros (y los de otra materia) van despacio: da tiempo a volver a casa a verlos
	local pace = Config.visitorSpeed(rarity, variant)
	hum.WalkSpeed = math.random(9, 12) * (vdef.speed or 1) * pace
	-- cuanto más nivel tiene el dueño (y mejor es su casa), menos se asustan sus visitantes, pero más monedas sueltan
	local ownerLv = Config.playerLevel(h.owner)
	local homeFear, homeCoins = Config.houseFear(h.owner), Config.houseCoins(h.owner)
	bot:PivotTo(h.cf * CFrame.new(math.random(-1, 1), 3 - Config.FLOOR_Y, 21))
	bot.Parent = h.model
	setGroup(bot, "Bots") -- atraviesan el portal (los jugadores no: lo cruzan con la animación)
	bot.HumanoidRootPart:SetNetworkOwner(nil)
	CollectionService:AddTag(bot, "Visitor") -- sus animaciones las pone cada cliente (NPCAnim)
	h.bot = bot
	local v = {
		key = bot, bot = bot, hum = hum, root = bot.HumanoidRootPart, house = h, bar = bar, speed = hum.WalkSpeed,
		fear = 0, calmAt = 0, courage = (0.75 + math.random() * 0.6) * rarity.courage * (vdef.courage or 1) * Config.levelFear(ownerLv) * homeFear, combo = 0, lastScare = -math.huge,
		voice = (0.9 + math.random() * 0.35) / (vdef.scale or 1), -- cada visitante grita con su propio tono
		mult = (vdef.mult or 1) * Config.levelCoins(ownerLv) * homeCoins, vdef = vdef, variant = variant and variant.id,
	}
	visits[bot] = v
	task.spawn(function()
		-- llega por el jardín hasta la puerta
		for _, z in {-16, -7.5, -2.2} do
			if not walkTo(bot, h, z, 12) or visits[bot] ~= v then
				return endVisit(v, "quit")
			end
		end
		-- en el umbral se para nervioso (NPCAnim: agachado, linterna delante y el puño en la boca) mientras la
		-- puerta se abre sola con un crujido; luego se arma de valor y entra
		hum:MoveTo(v.root.Position)
		anim(v, "sneak")
		bot:SetAttribute("Fear", 45)
		task.wait(1.1 + math.random() * 0.6)
		bot:SetAttribute("Fear", 0)
		if not walkTo(bot, h, -1, 8) or visits[bot] ~= v then
			return endVisit(v, "quit")
		end
		local deadline = os.clock() + 90 / pace
		local wp, routeVer = 1, -1
		while visits[bot] == v do
			if v.scaredAt then
				-- se lleva un susto: se para, da un respingo con las manos a la cara y grita (animación "startle")
				v.scaredAt = nil
				hum:MoveTo(v.root.Position)
				anim(v, "startle")
				sound(math.random() < 0.5 and "Scream" or "Scream2", bot.Head, v.voice)
				exclaim(bot, "!")
				task.wait(1 + math.random() * 0.3)
				if visits[bot] == v and bot:GetAttribute("Anim") == "startle" then
					anim(v, "sneak")
				end
			else
				-- recorre la casa hasta el fondo siguiendo la ruta (esquiva los sustos que hay en el camino); después da media
				-- vuelta y se va
				local x, z = depthOf(h, v.root.Position)
				if z >= h.rooms * D - 5 then
					endVisit(v, "done")
				elseif os.clock() > deadline then
					endVisit(v, "quit")
				else
					-- con miedo camina más despacio
					hum.WalkSpeed = v.speed * (1 - 0.3 * math.clamp((v.fear - 40) / 60, 0, 1))
					local route = h.route
					local goal = (h.cf * CFrame.new(0, 0, -(h.rooms * D - 3.5))).Position
					if route and #route > 0 then
						if routeVer ~= h.routeVer then
							routeVer = h.routeVer
							wp = nextWaypoint(route, x, z)
						end
						local p = route[math.min(wp, #route)]
						goal = (h.cf * CFrame.new(p.X, 0, -(wp > #route and h.rooms * D - 3.5 or p.Y))).Position
						if wp <= #route and flatDist(v.root.Position, goal) < 1.6 then
							wp += 1
						end
					end
					hum:MoveTo(goal)
					task.wait(0.12)
				end
			end
		end
	end)
end

-- Atributo Visitors del jugador ("id:veces,id:veces") para su Libro de Visitantes
function syncVisitors(plr)
	local st = state[plr]
	if not st then
		return
	end
	local list = {}
	for id, n in st.visitors do
		if Config.VisitorById[id] then
			table.insert(list, id .. ":" .. n)
		end
	end
	plr:SetAttribute("Visitors", table.concat(list, ","))
	-- y los materiales de cada uno ("id.material:veces"), para su ficha en el Index
	local mats = {}
	for key, n in st.mats do
		local id, m = key:match("^(%w+)%.(%w+)$")
		if id and Config.VisitorById[id] and Config.VariantById[m] then
			table.insert(mats, key .. ":" .. n)
		end
	end
	plr:SetAttribute("VisitorMats", table.concat(mats, ","))
end

---------- Visitas ----------
-- result: "done" (recorrió toda la casa) | "caught" | "fled" | "quit" | "left" (salió por el portal)
function endVisit(v, result)
	if visits[v.key] ~= v then
		return
	end
	visits[v.key] = nil
	local h = v.house
	if (result == "caught" or result == "fled") and h.owner and v.bot then
		-- del susto final se le cae un buen puñado de monedas
		dropCoins(h, v.root.Position, Config.FLEE_BONUS * (v.mult or 1))
		sound("Coins", v.root)
		-- el susto que lo ha rematado gana experiencia extra
		if v.lastBy then
			Config.addXP(h.owner, v.lastBy, Config.XP_FINISH)
		end
		-- el dueño gana experiencia de jugador (más cuanto más raro era el visitante)
		Config.addPlayerXP(h.owner, Config.PXP_FINISH * (v.vdef and Config.RarityIndex[v.vdef.rarity] or 1))
		Misiones.add(h.owner, "scare", 1)
		if v.vdef and (Config.RarityIndex[v.vdef.rarity] or 1) >= Config.RarityIndex.Rare then
			Misiones.add(h.owner, "rare", 1)
		end
		local ost = state[h.owner]
		if ost then
			ost.scared += 1
			h.owner.leaderstats.Scared.Value = ost.scared
			count(h.owner, "dScared", 1)
			count(h.owner, "mScared", 1)
			-- Libro de Visitantes: cuántos de cada tipo has asustado; el primero de un tipo nuevo da premio
			local vdef = v.vdef
			if vdef and v.bot then
				local n = (ost.visitors[vdef.id] or 0) + 1
				ost.visitors[vdef.id] = n
				-- llegó hecho de otra materia: se apunta en su ficha (el primero de esa materia, con aviso)
				if v.variant then
					local key = vdef.id .. "." .. v.variant
					ost.mats[key] = (ost.mats[key] or 0) + 1
					if ost.mats[key] == 1 and h.owner.Parent then
						Remote:FireClient(h.owner, "VisitorMat", vdef.id, v.variant)
					end
				end
				syncVisitors(h.owner)
				if n == 1 then
					local bonus = math.floor(Config.VISITOR_DISCOVER_BONUS * (vdef.mult or 1) + 0.5)
					h.owner.leaderstats.Coins.Value += bonus
					Remote:FireClient(h.owner, "VisitorNew", vdef.id, bonus)
				end
			end
		end
		if h.owner.Parent then
			Remote:FireClient(h.owner, "Scared", result == "caught" and "Caught!" or "Fled in terror!", v.root.Position + Vector3.new(0, 6, 0))
		end
	end

	if v.bot then
		local bot = v.bot
		local hum = v.hum
		if result == "done" then
			-- ha llegado al fondo sin desmayarse: lo celebra (animación "cheer") y se marcha por el portal
			exclaim(bot, "😎")
			sound("Yeah", bot.Head, v.voice)
			v.root.Anchored = true
			anim(v, "cheer")
			task.delay(1.5, function()
				if not bot.Parent then
					return
				end
				v.root.Anchored = false
				anim(v, "sneak")
				hum.WalkSpeed = v.speed
				if walkOut(bot, h, 14) then
					for _, z in {-1, -8, -20} do
						if not walkTo(bot, h, z, 14) then
							break
						end
					end
				end
				finishBot(h, bot, 0)
			end)
		elseif result == "caught" then
			-- se desmaya y cae de espaldas (animación "faint")
			exclaim(bot, "💫")
			sound("Scream", bot.Head, v.voice)
			task.delay(0.85, sound, "Thud", v.root) -- cae al suelo
			v.root.Anchored = true
			anim(v, "faint")
			finishBot(h, bot, 2.4)
		elseif result == "fled" then
			-- sale corriendo de la casa gritando con los brazos en alto (animación "panic")
			exclaim(bot, "😱")
			sound("Scream2", bot.Head, v.voice)
			anim(v, "panic")
			hum.WalkSpeed = 24
			task.spawn(function()
				if walkOut(bot, h, 8) then
					for _, z in {-1, -8, -20} do
						if not walkTo(bot, h, z, 8) then
							break
						end
					end
				end
				finishBot(h, bot, 0)
			end)
		else
			finishBot(h, bot, 0)
		end
		return
	end

	local plr = v.player
	-- premio a la valentía: llegar al fondo de una casa ajena paga (cada casa, una vez cada BRAVE_COOLDOWN)
	local pst = state[plr]
	if result == "done" and not v.test and pst and h.count > 0 and h.owner ~= plr then
		local now = os.clock()
		Misiones.add(plr, "brave", 1)
		if now - (pst.brave[h.id] or -math.huge) > Config.BRAVE_COOLDOWN then
			pst.brave[h.id] = now
			local reward = math.floor(Config.BRAVE_BASE + h.power * Config.BRAVE_PER_FEAR)
			plr.leaderstats.Coins.Value += reward
			Remote:FireClient(plr, "Reward", reward)
		else
			Remote:FireClient(plr, "Reward", 0, math.ceil(Config.BRAVE_COOLDOWN - (now - pst.brave[h.id])))
		end
	end
	Remote:FireClient(plr, "VisitEnd", result, h.name)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if result == "left" then
		-- ya está fuera: sin teletransporte
		if hum then
			hum.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
		end
		if plr:GetAttribute("Mode") == "visit" then
			plr:SetAttribute("Mode", nil)
		end
		plr:SetAttribute("Fear", nil)
		return
	end
	if hum then
		hum.WalkSpeed = 0
	end
	task.delay(result == "quit" and 0.45 or 2.4, function()
		if char and char.Parent and hum then
			char:PivotTo(outside(h))
			hum.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
		end
		if plr.Parent and plr:GetAttribute("Mode") == "visit" then
			plr:SetAttribute("Mode", nil)
		end
		plr:SetAttribute("Fear", nil)
	end)
end

-- walked: ha entrado andando por el portal (sin fundido ni teletransporte). Si no, empieza desde la entrada.
function startVisit(plr, h, test, walked)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or visits[plr] or plr:GetAttribute("Mode") then
		return
	end
	-- cuanto más nivel tiene quien visita, más valiente es (Config.visitFear: x0.5 a nivel 1, x0.04 y sin desmayarse
	-- a nivel máximo; probando tu propia casa, como un visitante normal)
	local lv = Config.playerLevel(plr)
	local brave = test and 1 or Config.visitFear(lv)
	local v = {
		key = plr, player = plr, house = h, root = root, hum = hum, test = test, walked = walked,
		fear = 0, calmAt = 0, combo = 0, lastScare = -math.huge, courage = brave,
		maxFear = not test and lv >= Config.PLAYER_MAX_LEVEL and 95 or nil,
	}
	if brave < 0.99 then
		Remote:FireClient(plr, "Brave", lv, brave)
	end
	visits[plr] = v
	plr:SetAttribute("Mode", "visit")
	plr:SetAttribute("Fear", 0)
	Remote:FireClient(plr, "VisitStart", h.name, test, h.cf.LookVector, walked, h.model)
	if walked then
		hum.WalkSpeed = Config.VISIT_SPEED
		v.ready = true
		v.calmUntil = os.clock() + 1.5 -- un respiro al entrar: ningún susto salta mientras se lee el cartel
		return
	end
	hum.WalkSpeed = 0
	task.delay(0.55, function()
		if visits[plr] ~= v then
			return
		end
		char:PivotTo(h.cf * CFrame.new(0, 3, -3))
		hum.WalkSpeed = Config.VISIT_SPEED
		v.ready = true
		v.calmUntil = os.clock() + 1.5
	end)
end

---------- En casa (solo se edita desde dentro) ----------
local actions = {}

function actions.Exit(plr)
	local v = visits[plr]
	if v then
		return endVisit(v, "quit")
	end
	local st = state[plr]
	if plr:GetAttribute("Mode") == "home" and st and st.house and plr.Character then
		plr:SetAttribute("Mode", nil)
		plr.Character:PivotTo(outside(st.house))
	end
end

function actions.GoHome(plr)
	local st = state[plr]
	if st and st.house and not plr:GetAttribute("Mode") and plr.Character then
		plr.Character:PivotTo(frontOf(st.house))
	end
end

-- Atajos del menú (teletransporte a la Ruleta y a la explanada de los lobbies del Tower Defense). Los destinos van en
-- atributos de Workspace (TP_<sitio>) y el cliente se mueve él mismo, al instante (su personaje es suyo: la física la
-- lleva él). Aquí solo sale la nube de humo donde estaba y donde llega, para que la vean todos.
local travelAt = {}
local function poofAt(pos)
	local poof = Assets:FindFirstChild("Poof")
	if not poof then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local p = poof:Clone()
	p.Parent = a
	p:Emit(30)
	soundAt("Poof", pos)
	Debris:AddItem(a, 4)
end
do
	local booth = workspace.Mapa:FindFirstChild("Tiendas") and workspace.Mapa.Tiendas:FindFirstChild("Ruleta")
	local counter = booth and booth:FindFirstChild("Mostrador", true)
	if counter then
		local stand = counter.CFrame * CFrame.new(0, 1.4, -8) -- (el mostrador mira hacia -Z: el frente)
		workspace:SetAttribute("TP_wheel", CFrame.lookAt(stand.Position, Vector3.new(counter.Position.X, stand.Position.Y, counter.Position.Z)))
	end
	workspace:SetAttribute("TP_td", require(SSS.TDMaps).BACK)
end
function actions.GoTo(plr, where, from)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local to = typeof(where) == "string" and workspace:GetAttribute("TP_" .. where)
	if not (root and typeof(to) == "CFrame") or plr:GetAttribute("Mode") or os.clock() < (travelAt[plr] or 0) then
		return
	end
	travelAt[plr] = os.clock() + 0.5
	-- (de dónde salió: lo dice el cliente, pero solo vale si está cerca de donde le ve el servidor)
	if typeof(from) == "Vector3" and (from - root.Position).Magnitude < 40 then
		poofAt(from)
	end
	poofAt(to.Position)
end
Players.PlayerRemoving:Connect(function(plr)
	travelAt[plr] = nil
end)

function actions.Test(plr)
	local st = state[plr]
	if st and st.house and plr:GetAttribute("Mode") == "home" then
		plr:SetAttribute("Mode", nil)
		startVisit(plr, st.house, true)
	end
end

-- Progreso del tutorial del alcalde Calabaza (0 = nuevo ... 4 = terminado; ver Tutorial.lua)
function actions.Tut(plr, step)
	local st = state[plr]
	if st and typeof(step) == "number" and step == step then
		st.tut = math.clamp(math.max(st.tut, math.floor(step)), 0, 4)
		plr:SetAttribute("Tut", st.tut)
		-- al colocar el primer susto en el tutorial, el primer visitante llega enseguida para enseñarlo
		local h = st.house
		if st.tut == 3 and h and h.count > 0 and not h.bot then
			h.nextBot = math.min(h.nextBot, os.clock() + 0.5)
		end
	end
end

-- Recoger una moneda de tu casa (el cliente la ha atraído al acercarte)
function actions.Collect(plr, id)
	local st = state[plr]
	local h = st and st.house
	local folder = h and h.model:FindFirstChild("Coins")
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not (folder and root) or typeof(id) ~= "number" then
		return
	end
	for _, c in folder:GetChildren() do
		if c:GetAttribute("Id") == id then
			if (c.Position - root.Position).Magnitude < Config.COIN_MAGNET + 10 then
				local value = c:GetAttribute("Value") or 0
				c:Destroy()
				plr.leaderstats.Coins.Value += value
				Misiones.add(plr, "coins", value)
				Remote:FireClient(plr, "Coin", value)
			end
			return
		end
	end
end

function actions.Place(plr, t, x, z, r)
	local st = state[plr]
	local h = st and st.house
	if not h or plr:GetAttribute("Mode") ~= "home" or not Config.Scares[t] or (st.inv[t] or 0) < 1 then
		return
	end
	if typeof(x) ~= "number" or typeof(z) ~= "number" or typeof(r) ~= "number" then
		return
	end
	x, z, r = math.round(x * 2) / 2, math.round(z * 2) / 2, math.round(r) % 4
	if r ~= r then
		return
	end
	if h.count + Config.slots(t) > h.spaces then
		return Remote:FireClient(plr, "Info", Config.slots(t) > 1 and ("Not enough space: it takes %d spaces"):format(Config.slots(t)) or "Scare limit reached: buy a bigger house")
	end
	local ok, why = Config.canPlace(h.model, h.rooms, t, x, z, r)
	if not ok then
		return Remote:FireClient(plr, "Info", why or "You can't place it there")
	end
	for _, v in visits do
		if v.house == h and v.player then
			return Remote:FireClient(plr, "Info", "Wait for the visitor to leave")
		end
	end
	st.inv[t] -= 1
	plr:SetAttribute("Inv_" .. t, st.inv[t])
	spawnScare(h, t, x, z, r)
	updateHouse(h)
	Misiones.add(plr, "place", 1)
	if h.count == 1 and not h.bot then
		h.nextBot = os.clock() + 1.5 -- el primer visitante llega enseguida
	end
end

function actions.Pickup(plr, id)
	local st = state[plr]
	local h = st and st.house
	local s = h and h.scares[id]
	if not s or plr:GetAttribute("Mode") ~= "home" then
		return
	end
	if s.busy then
		return Remote:FireClient(plr, "Info", "It's scaring someone: wait a moment")
	end
	h.scares[id] = nil
	s.model:Destroy()
	st.inv[s.type] = (st.inv[s.type] or 0) + 1
	plr:SetAttribute("Inv_" .. s.type, st.inv[s.type])
	updateHouse(h)
end

-- Se muda a otra de sus casas: la de la parcela se reconstruye con el nuevo diseño y sus salas. Las visitas en curso
-- se acaban, las monedas sueltas van directas al dueño y los sustos que no quepan vuelven a la mochila.
local function moveIn(plr, def)
	local st = state[plr]
	st.home = def.id
	plr:SetAttribute("Home", def.id)
	local h = st.house
	if not h then
		return
	end
	for _, v in visits do
		if v.house == h then
			endVisit(v, "quit")
		end
	end
	if plr:GetAttribute("Mode") == "home" and plr.Character then
		plr:SetAttribute("Mode", nil)
		plr.Character:PivotTo(frontOf(h))
	end
	local coins = h.model:FindFirstChild("Coins")
	local loose = 0
	for _, c in coins and coins:GetChildren() or {} do
		loose += c:GetAttribute("Value") or 0
		c:Destroy()
	end
	if loose > 0 then
		plr.leaderstats.Coins.Value += loose
		Remote:FireClient(plr, "Coin", loose)
	end
	local placed = {}
	for _, s in h.scares do
		table.insert(placed, {s.type, s.x, s.z, s.r})
		s.model:Destroy()
	end
	h.scares = {}
	h.rooms, h.template = def.rooms, def.template
	rebuild(h)
	placeAll(plr, h, placed)
	plr:SetAttribute("Rooms", h.rooms)
	plr:SetAttribute("Spaces", h.spaces)
end

-- what: un susto, o "House" con el id de la casa (si ya es tuya, te mudas a ella gratis)
function actions.Buy(plr, what, id)
	local st = state[plr]
	if not st then
		return
	end
	local money = plr.leaderstats.Coins
	if what == "House" then
		local def = Config.house(id)
		if not def or st.home == def.id then
			return
		end
		if not table.find(st.houses, def.id) then
			if money.Value < def.price then
				return Remote:FireClient(plr, "Info", ("You need %d more 💰"):format(def.price - money.Value))
			end
			money.Value -= def.price
			table.insert(st.houses, def.id)
			plr:SetAttribute("Houses", table.concat(st.houses, ","))
			Remote:FireClient(plr, "Bought", "House", def.name)
		end
		return moveIn(plr, def)
	end
	local item = Config.Scares[what]
	if not item then
		return
	end
	if not Config.inShop(what) then
		return Remote:FireClient(plr, "Info", "Not sold for coins: get it from " .. Config.sourceText(what))
	end
	if money.Value < item.price then
		return Remote:FireClient(plr, "Info", ("You need %d more 💰"):format(item.price - money.Value))
	end
	money.Value -= item.price
	st.inv[what] = (st.inv[what] or 0) + 1
	plr:SetAttribute("Inv_" .. what, st.inv[what])
	Remote:FireClient(plr, "Bought", what, item.name)
	Misiones.add(plr, "buy", 1)
end

-- Equipo del Tower Defense: hasta 6 sustos (que existan, sin repetir). Lo usa TDMatch (TD.loadout).
function actions.Loadout(plr, list)
	local st = state[plr]
	if not st or typeof(list) ~= "table" then
		return
	end
	local clean = {}
	for _, t in list do
		if typeof(t) == "string" and Config.Scares[t] and not Config.Scares[t].special and not table.find(clean, t) and #clean < 6 then
			table.insert(clean, t)
		end
	end
	st.loadout = clean
	plr:SetAttribute("Loadout", table.concat(clean, ","))
end

-- Tags: se compran con monedas (y se equipan al comprarlos); EquipTag(id) se pone uno que tengas, EquipTag(nil) se lo quita
function actions.BuyTag(plr, id)
	local st = state[plr]
	local tag = typeof(id) == "string" and Config.TagById[id]
	if not st or not tag or table.find(st.tags, id) then
		return
	end
	local money = plr.leaderstats.Coins
	if money.Value < tag.price then
		return Remote:FireClient(plr, "Info", ("You need %d more 💰"):format(tag.price - money.Value))
	end
	money.Value -= tag.price
	table.insert(st.tags, id)
	st.tag = id
	plr:SetAttribute("Tags", table.concat(st.tags, ","))
	plr:SetAttribute("Tag", id)
	Remote:FireClient(plr, "TagBought", id)
end

function actions.EquipTag(plr, id)
	local st = state[plr]
	if not st or (id ~= nil and not table.find(st.tags, id)) then
		return
	end
	st.tag = id
	plr:SetAttribute("Tag", id)
end

---------- Ruletas y skins ----------
local function give(plr, t)
	local st = state[plr]
	st.inv[t] = (st.inv[t] or 0) + 1
	plr:SetAttribute("Inv_" .. t, st.inv[t])
	if Config.Scares[t].cat == "Legendario" then
		Misiones.add(plr, "legend", 1)
	end
end

local function addAttr(plr, name, n)
	plr:SetAttribute(name, (plr:GetAttribute(name) or 0) + n)
end

-- ¿No ha tenido nunca este susto? (ni en la mochila ni colocado): el cliente lo celebra con un "NEW!"
local function isNew(plr, t)
	local st = state[plr]
	if (st.inv[t] or 0) > 0 then
		return false
	end
	for _, s in st.house and st.house.scares or {} do
		if s.type == t then
			return false
		end
	end
	return true
end

---------- Shop: Aspiradora de almas y ofertas del día ----------
-- how: cómo la ha conseguido (nil: ya era suya, al entrar: sin celebración)
local function grantVacuum(plr, how)
	local st = state[plr]
	if not st or st.vacuum then
		return
	end
	st.vacuum = true
	plr:SetAttribute("Vacuum", true)
	if st.house then
		placeVacuum(st.house)
	end
	if how then
		Remote:FireClient(plr, "VacuumGot", how)
		Remote:FireAllClients("VacuumAnnounce", plr.DisplayName)
	end
end

---------- Robux: pases, packs de monedas y gemas (también de regalo) y sustos ----------
-- El cliente pide RobuxBuy(tipo, id, regaloA): el servidor apunta qué ha pedido y abre la compra de Roblox.
-- ProcessReceipt lo entrega una sola vez por PurchaseId (st.receipts, que va en la partida) y guarda en el momento:
-- si no se puede guardar, Roblox lo reintenta más tarde. Con id 0 (sin crear aún): en Studio se da sin pagar, para
-- probar; publicado, "coming soon".
local PRODUCT = {} -- [productId] = {pack = def} | {tier = i}
for _, p in Config.PackById do
	if p.product ~= 0 then
		PRODUCT[p.product] = {pack = p}
	end
end
for i, t in Config.ScareTiers do
	if t.product ~= 0 then
		PRODUCT[t.product] = {tier = i}
	end
end
local PASS = {} -- [gamePassId] = def
for _, p in Config.Passes do
	if p.pass ~= 0 then
		PASS[p.pass] = p
	end
end
local gifts = {} -- [jugador] = {[productId] = UserId a quien regala} (solo mientras está la compra abierta)
local save -- (más abajo)

local function ownsPass(plr, p)
	return plr:GetAttribute(p.id == "Vacuum" and "Vacuum" or "Pass_" .. p.id) == true
end

local function grantPass(plr, p, how)
	if p.id == "Vacuum" then
		return grantVacuum(plr, how)
	end
	if not state[plr] or ownsPass(plr, p) then
		return
	end
	plr:SetAttribute("Pass_" .. p.id, true)
	if how then
		Remote:FireClient(plr, "PassGot", p.id)
	end
end

-- monedas o gemas del pack (to: a quien se regala)
local function grantPack(plr, pack, to)
	local target = to or plr
	if pack.gems then
		addAttr(target, "Gems", pack.amount)
	else
		target.leaderstats.Coins.Value += pack.amount
	end
	Remote:FireClient(target, "PackGot", pack.id, to and plr.DisplayName or nil)
	if to then
		Remote:FireClient(plr, "GiftSent", pack.id, to.DisplayName)
	end
end

local function grantScare(plr, t)
	local new = isNew(plr, t)
	give(plr, t)
	Remote:FireClient(plr, "GotScare", t, new, "robux")
	Remote:FireAllClients("Announce", plr.DisplayName, t, "robux")
end

-- Sin id: en Studio se da al momento (pruebas); publicado, aún no se vende
local function noId(plr, grant, ...)
	if RunService:IsStudio() then
		grant(...)
	else
		Remote:FireClient(plr, "Info", "Robux purchases are coming very soon!")
	end
end

function actions.RobuxBuy(plr, kind, id, giftTo)
	local st = state[plr]
	if not st or typeof(id) ~= "string" then
		return
	end
	if kind == "pass" then
		local p = Config.PassById[id]
		if not p then
			return
		end
		if ownsPass(plr, p) then
			return Remote:FireClient(plr, "Info", ("You already own %s!"):format(p.name))
		end
		if p.pass ~= 0 then
			return MarketplaceService:PromptGamePassPurchase(plr, p.pass)
		end
		return noId(plr, grantPass, plr, p, "studio")
	end
	local product, to
	if kind == "pack" then
		local p = Config.PackById[id]
		if not p then
			return
		end
		product = p.product
		if typeof(giftTo) == "number" then
			to = Players:GetPlayerByUserId(giftTo)
			if not (to and to ~= plr and state[to]) then
				return Remote:FireClient(plr, "Info", "That player isn't in this server anymore")
			end
		end
		if product == 0 then
			return noId(plr, grantPack, plr, p, to)
		end
		gifts[plr] = gifts[plr] or {}
		gifts[plr][product] = to and to.UserId or nil
	elseif kind == "scare" then
		local i, tier = Config.scareTier(id)
		if not i then
			return
		end
		product = tier.product
		if product == 0 then
			return noId(plr, grantScare, plr, id)
		end
		-- (se guarda con la partida: si la compra llega cuando ya ha vuelto a entrar, sigue sabiendo cuál era)
		st.rbxScare[tostring(i)] = id
	else
		return
	end
	MarketplaceService:PromptProductPurchase(plr, product)
end

MarketplaceService.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local st = plr and state[plr]
	local what = PRODUCT[info.ProductId]
	if not (st and what) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(st.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if what.pack then
		local toId = gifts[plr] and gifts[plr][info.ProductId]
		local to = toId and Players:GetPlayerByUserId(toId)
		if gifts[plr] then
			gifts[plr][info.ProductId] = nil
		end
		if to and not state[to] then
			to = nil
		end
		if toId and not to then
			Remote:FireClient(plr, "Info", "Your friend left the server, so the gift is yours! 🎁")
		end
		grantPack(plr, what.pack, to)
	else
		local t = st.rbxScare[tostring(what.tier)]
		if t and Config.scareTier(t) == what.tier then
			grantScare(plr, t)
		else
			-- (no se sabe qué susto era: su valor en gemas, al precio del pack más grande)
			local best = Config.PackById.gems5
			local gems = math.floor(Config.ScareTiers[what.tier].robux * best.amount / best.robux + 0.5)
			addAttr(plr, "Gems", gems)
			Remote:FireClient(plr, "Info", ("Your purchase arrived as %d gems 💎"):format(gems))
		end
	end
	table.insert(st.receipts, info.PurchaseId)
	if #st.receipts > 60 then
		table.remove(st.receipts, 1)
	end
	if READ_ONLY or save(plr) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, bought)
	if bought and PASS[id] then
		grantPass(plr, PASS[id], "robux")
	end
end)

-- Al entrar: los pases que ya tiene
local function checkPasses(plr)
	for id, p in PASS do
		task.spawn(function()
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, id)
			if ok and has and plr.Parent then
				grantPass(plr, p, nil)
			end
		end)
	end
end

-- Oferta k del día (una vez cada una)
function actions.DailyBuy(plr, k)
	local st = state[plr]
	local day = Config.dailyDay(workspace:GetServerTimeNow())
	local deal = typeof(k) == "number" and Config.dailyDeals(day)[k]
	if not st or not deal then
		return
	end
	if st.daily.day ~= day then
		st.daily = {day = day, bought = {}}
	end
	if st.daily.bought[k] then
		return Remote:FireClient(plr, "Info", "You already bought this deal today")
	end
	local money = plr.leaderstats.Coins
	if money.Value < deal.price then
		return Remote:FireClient(plr, "Info", ("You need %d more 💰"):format(deal.price - money.Value))
	end
	money.Value -= deal.price
	st.daily.bought[k] = true
	local list = {}
	for n in st.daily.bought do
		table.insert(list, n)
	end
	plr:SetAttribute("DailyBought", day .. ":" .. table.concat(list, ","))
	local new = isNew(plr, deal.scare)
	give(plr, deal.scare)
	Remote:FireClient(plr, "GotScare", deal.scare, new, "daily")
end

-- Gira la ruleta i: cobra (o gasta la tirada gratis), elige casilla según los pesos del periodo actual (con el pity:
-- tras pity-1 tiradas sin premio gordo, solo cuentan las casillas gordas) y da el susto. El cliente anima la ruleta
-- hasta esa casilla; la ruleta gigante de la plaza gira para todos y los premios gordos se anuncian al servidor.
local spinning = {}
function actions.Spin(plr, i, free)
	local st = state[plr]
	local wheel = Config.Wheels[i]
	if not st or not wheel or (spinning[plr] or 0) > os.clock() then
		return
	end
	local now = workspace:GetServerTimeNow()
	if free == true and i == Config.FREE_SPIN_WHEEL then
		if now < st.freeAt then
			return Remote:FireClient(plr, "Info", "Your free spin isn't ready yet")
		end
		st.freeAt = now + Config.FREE_SPIN_EVERY
		plr:SetAttribute("FreeSpinAt", st.freeAt)
	else
		local money = plr.leaderstats.Coins
		if money.Value < wheel.price then
			return Remote:FireClient(plr, "Info", ("You need %d more 💰"):format(wheel.price - money.Value))
		end
		money.Value -= wheel.price
	end
	spinning[plr] = os.clock() + Config.WHEEL_SPIN_TIME
	local period = Config.wheelPeriod(now)
	local prizes = Config.wheelPrizes(i, period)
	local streak = st.pity[i] + 1
	local pool, total = {}, 0
	for n, p in prizes do
		if streak < wheel.pity or Config.isJackpot(p.scare) then
			table.insert(pool, n)
			total += p.w
		end
	end
	local r, k = math.random() * total, pool[#pool]
	for _, n in pool do
		r -= prizes[n].w
		if r <= 0 then
			k = n
			break
		end
	end
	local t = prizes[k].scare
	local jackpot = Config.isJackpot(t)
	st.pity[i] = jackpot and 0 or streak
	plr:SetAttribute("Pity" .. i, st.pity[i])
	local new = isNew(plr, t)
	give(plr, t) -- ya, aunque la animación aún gire: si sale del juego no lo pierde
	Misiones.add(plr, "spin", 1)
	Remote:FireClient(plr, "Spin", i, period, k, t, new)
	local booth = workspace.Mapa:FindFirstChild("Tiendas") and workspace.Mapa.Tiendas:FindFirstChild("Ruleta")
	if booth then
		booth:SetAttribute("SpinTier", i)
		booth:SetAttribute("SpinPeriod", period)
		booth:SetAttribute("SpinSlot", k)
		booth:SetAttribute("SpinSeq", (booth:GetAttribute("SpinSeq") or 0) + 1)
	end
	if jackpot then
		task.delay(Config.WHEEL_SPIN_TIME, function()
			Remote:FireAllClients("Announce", plr.DisplayName, t, "wheel")
		end)
	end
end

-- Pone (o quita, s = nil) la skin s en el susto base y cambia el aspecto de los que ya tiene colocados
local function equipSkin(plr, base, s)
	plr:SetAttribute("Skin_" .. base, s)
	local st = state[plr]
	if st and st.house then
		reskin(st.house, base)
	end
end

-- Skins (ofertas de la Shop): se compran UNA vez con gemas, solo las que están en oferta ahora para ese jugador
-- (Config.skinOffers: las de los sustos base que tiene en la mochila, colocados o con estrellas, que aún no son suyas),
-- al precio de la oferta. No dan ningún susto: la skin se queda suya y se equipa en su susto al momento.
function actions.BuySkin(plr, t)
	local st = state[plr]
	local def = typeof(t) == "string" and Config.Scares[t]
	if not st or not def or not def.skin then
		return
	end
	if Config.ownsSkin(plr, t) then
		return Remote:FireClient(plr, "Info", "You already own this skin!")
	end
	local function unlocked(s)
		local base = Config.Scares[s].base
		return (not isNew(plr, base) or Config.starOf(plr, base) > 0) and not Config.ownsSkin(plr, s)
	end
	local offer
	for _, o in Config.skinOffers(Config.skinPeriod(workspace:GetServerTimeNow()), unlocked) do
		if o.skin == t then
			offer = o
		end
	end
	if not offer then
		return Remote:FireClient(plr, "Info", "That skin offer has ended!")
	end
	local gems = plr:GetAttribute("Gems") or 0
	if gems < offer.price then
		return Remote:FireClient(plr, "Info", ("You need %d more 💎"):format(offer.price - gems))
	end
	plr:SetAttribute("Gems", gems - offer.price)
	plr:SetAttribute("OwnSkin_" .. t, true)
	equipSkin(plr, def.base, t)
	Remote:FireClient(plr, "GotSkin", t)
	if def.gems >= Config.SKIN_ANNOUNCE then
		Remote:FireAllClients("Announce", plr.DisplayName, t, "skin")
	end
end

-- Equipa una skin suya en su susto (s = el nombre del susto base: vuelve al original)
function actions.EquipSkin(plr, s)
	local def = typeof(s) == "string" and Config.Scares[s]
	if not state[plr] or not def then
		return
	end
	if def.skin then
		if Config.ownsSkin(plr, s) then
			equipSkin(plr, def.base, s)
		end
	elseif Config.SkinsOf[s] then
		equipSkin(plr, s, nil)
	end
end

-- Fusión (Caldero de Hexa): funde copias repetidas de un susto de la mochila y sube su estrella. Vale para todos los de
-- ese tipo, también los colocados. Hay que estar junto al caldero.
local FUSE_REACH = 30
-- Fusionar: se funden STAR_COST copias y te queda una, la fusionada, con la estrella nueva (antes se fundían todas y,
-- si no tenías más, te quedabas sin el susto). Cuentan las de la mochila y las colocadas en tu casa: se gastan primero
-- las de la mochila y, si faltan, se recogen de la casa (las que quedan colocadas ya brillan con la estrella).
local function fuseCopies(st, t)
	local placed = {}
	if st.house then
		for id, s in st.house.scares do
			if s.type == t then
				table.insert(placed, {id = id, s = s})
			end
		end
	end
	return (st.inv[t] or 0) + #placed, placed
end
function actions.Fuse(plr, t)
	local st = state[plr]
	local def = typeof(t) == "string" and Config.Scares[t]
	if not st or not def or def.skin then
		return
	end
	if st.frozen then
		return Remote:FireClient(plr, "Info", "You're travelling: try again in a moment")
	end
	local station = workspace.Mapa:FindFirstChild("Tiendas") and workspace.Mapa.Tiendas:FindFirstChild("Fusion")
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not (station and root and (root.Position - station:GetPivot().Position).Magnitude < FUSE_REACH) then
		return Remote:FireClient(plr, "Info", "Get closer to Hexa's Cauldron to fuse")
	end
	local star = Config.starOf(plr, t)
	if star >= Config.STAR_MAX then
		return Remote:FireClient(plr, "Info", "Already at max stars!")
	end
	local cost = Config.STAR_COST[star + 1]
	local total, placed = fuseCopies(st, t)
	if total < cost then
		return Remote:FireClient(plr, "Info", ("You need %d copies to fuse (you have %d)"):format(cost, total))
	end
	-- se gastan cost - 1 copias (la que queda es la fusionada): primero de la mochila, luego de la casa
	local use = cost - 1
	local fromBag = math.min(st.inv[t] or 0, use)
	local fromHouse = {}
	for _, p in placed do
		if #fromHouse >= use - fromBag then
			break
		end
		if not p.s.busy then
			table.insert(fromHouse, p)
		end
	end
	if fromBag + #fromHouse < use then
		return Remote:FireClient(plr, "Info", "Your scares are busy scaring someone: wait a moment")
	end
	st.inv[t] = (st.inv[t] or 0) - fromBag
	plr:SetAttribute("Inv_" .. t, st.inv[t])
	for _, p in fromHouse do
		st.house.scares[p.id] = nil
		p.s.model:Destroy()
	end
	star += 1
	plr:SetAttribute("Star_" .. t, star)
	Misiones.add(plr, "fuse", 1)
	if st.house then
		restar(st.house, t, star)
		updateHouse(st.house)
	end
	Remote:FireClient(plr, "Fused", t, star)
	if star == Config.STAR_MAX and Config.isJackpot(t) then
		Remote:FireAllClients("Announce", plr.DisplayName, t, "fuse")
	end
	task.spawn(save, plr) -- (se guarda ya: una fusión no se pierde aunque el servidor se cierre)
end

---------- Perfil de otro jugador (PerfilJugador) ----------
-- Botón "Visit house" del panel: te lleva delante de la casa de ese jugador
function actions.VisitPlayer(plr, userId)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	local tst = target and target ~= plr and state[target]
	if not (tst and tst.house and plr.Character) or plr:GetAttribute("Mode") or os.clock() < (travelAt[plr] or 0) then
		return
	end
	travelAt[plr] = os.clock() + 1
	local root = plr.Character:FindFirstChild("HumanoidRootPart")
	if root then
		poofAt(root.Position)
	end
	local to = frontOf(tst.house)
	plr.Character:PivotTo(to)
	poofAt(to.Position)
end

---------- Panel de administrador (AdminPanel; solo Config.isAdmin) ----------
-- El cliente manda Remote:FireServer("Admin", comando, userId del objetivo, valor, valor2). Aquí se vuelve a comprobar
-- quién lo pide: un exploit puede disparar el remote, pero no pasar de esta comprobación.
local TextService = game:GetService("TextService")
local function adminTell(plr, text)
	Remote:FireClient(plr, "Notice", text)
end
local function charOf(p)
	local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return root and p.Character, root
end
local adminCmds = {}
function adminCmds.BloodStart(plr)
	workspace:SetAttribute("BloodOff", nil)
	workspace:SetAttribute("BloodForce", workspace:GetServerTimeNow() + Config.BLOOD_LENGTH)
	return "Blood Night started (" .. Config.BLOOD_LENGTH .. " s)"
end
function adminCmds.BloodStop(plr)
	workspace:SetAttribute("BloodForce", nil)
	local on, at = Config.bloodNight(workspace:GetServerTimeNow())
	if on then
		workspace:SetAttribute("BloodOff", at) -- (la del reloj que estaba en marcha también se corta)
	end
	return "Blood Night stopped"
end
function adminCmds.Coins(plr, target, n)
	local money = target.leaderstats.Coins
	money.Value = math.max(0, money.Value + n)
	return ("%+d coins to %s (now %d)"):format(n, target.Name, money.Value)
end
function adminCmds.Gems(plr, target, n)
	target:SetAttribute("Gems", math.max(0, (target:GetAttribute("Gems") or 0) + n))
	return ("%+d gems to %s"):format(n, target.Name)
end
function adminCmds.XP(plr, target, n)
	target:SetAttribute("PXP", math.max(0, (target:GetAttribute("PXP") or 0) + n))
	return ("%+d XP to %s (level %d)"):format(n, target.Name, Config.playerLevel(target))
end
function adminCmds.Level(plr, target, n)
	local lv = math.clamp(math.floor(n), 1, Config.PLAYER_MAX_LEVEL)
	target:SetAttribute("PXP", Config.pxpTotal(lv))
	return ("%s is now level %d"):format(target.Name, lv)
end
function adminCmds.Scare(plr, target, t, n)
	if typeof(t) ~= "string" or not Config.Scares[t] then
		return nil, "Unknown scare"
	end
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 50)
	for _ = 1, n do
		give(target, t)
	end
	adminTell(target, ("An admin gave you %d× %s!"):format(n, Config.Scares[t].name))
	return ("%d× %s to %s"):format(n, Config.Scares[t].name, target.Name)
end
function adminCmds.Luck(plr, target, n)
	if not table.find(Config.LUCK_BOOSTS, n) then
		return nil, "Luck must be 1, 10 or 100"
	end
	target:SetAttribute("LuckBoost", n)
	return ("Luck x%d for %s"):format(n, target.Name)
end
function adminCmds.TpTo(plr, target)
	local me = charOf(plr)
	local _, root = charOf(target)
	if not (me and root) or plr:GetAttribute("Mode") then
		return nil, "Can't teleport now"
	end
	me:PivotTo(root.CFrame * CFrame.new(0, 0, 4))
	return "Teleported to " .. target.Name
end
function adminCmds.Bring(plr, target)
	local _, root = charOf(plr)
	local them = charOf(target)
	if not (root and them) or target:GetAttribute("Mode") then
		return nil, target.Name .. " can't be moved now (inside a house?)"
	end
	them:PivotTo(root.CFrame * CFrame.new(0, 0, -4))
	return "Brought " .. target.Name
end
function adminCmds.Kick(plr, target)
	if Config.isAdmin(target) then
		return nil, "You can't kick an admin"
	end
	target:Kick("You were kicked by an admin.")
	return "Kicked " .. target.Name
end
function adminCmds.Announce(plr, _, text)
	if typeof(text) ~= "string" or #text == 0 or #text > 200 then
		return nil, "Write a message (max 200 letters)"
	end
	-- (los mensajes que ven todos tienen que pasar el filtro de Roblox)
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, plr.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil, "The text filter failed, try again"
	end
	Remote:FireAllClients("AdminAnnounce", plr.DisplayName, filtered)
	return "Announcement sent"
end
-- los que no necesitan un jugador objetivo
local NO_TARGET = {BloodStart = true, BloodStop = true, Announce = true}
function actions.Admin(plr, cmd, userId, a, b)
	local f = typeof(cmd) == "string" and adminCmds[cmd]
	if not (Config.isAdmin(plr) and f) then
		return
	end
	local target
	if not NO_TARGET[cmd] then
		target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
		if not (target and state[target]) then
			return adminTell(plr, "That player isn't in the server")
		end
		if cmd ~= "Scare" and (typeof(a) ~= "number" or a ~= a or math.abs(a) > 1e9) and cmd ~= "TpTo" and cmd ~= "Bring" and cmd ~= "Kick" then
			return adminTell(plr, "Write a valid number")
		end
	end
	local ok, msg, err = pcall(f, plr, target, a, b)
	if not ok then
		warn("Admin " .. cmd .. ": " .. tostring(msg))
		return adminTell(plr, "Error: " .. tostring(msg))
	end
	adminTell(plr, msg or err or "Done")
end

Remote.OnServerEvent:Connect(function(plr, action, ...)
	local f = actions[action]
	if f then
		f(plr, ...)
	end
end)

---------- Jugadores ----------
-- Carga con bloqueo de sesión (campo lock = JobId del servidor que tiene al jugador): si otro servidor aún lo tiene
-- (está guardando al salir), espera y reintenta; el último intento se lo queda igualmente (ese servidor se cayó).
-- Devuelve los datos (nil si es nuevo) y si se pueden guardar.
local function load(plr)
	if not store then
		return nil, false
	end
	local key = "u" .. plr.UserId
	if READ_ONLY then
		local ok, data = pcall(store.GetAsync, store, key)
		return ok and data or nil, false
	end
	for try = 1, LOCK_TRIES do
		local busy = false
		local ok, data = pcall(store.UpdateAsync, store, key, function(old)
			busy = false
			if old and old.lock and old.lock ~= game.JobId and try < LOCK_TRIES then
				busy = true
				return nil
			end
			old = old or {}
			old.lock = game.JobId
			return old
		end)
		if ok and not busy then
			return data and data.money ~= nil and data or nil, true
		end
		if not ok then
			warn("No se cargaron los datos de " .. plr.Name .. ": " .. tostring(data))
		end
		if not plr.Parent then
			return nil, false
		end
		task.wait(try * 1.5)
	end
	return nil, false
end

---------- Rankings de la plaza (OrderedDataStore por tablero y mes; los dibuja el script Rankings) ----------
local rankStores = {}
local function rankStore(kind, month)
	local key = ("R1_%s_%s"):format(kind, month)
	if not rankStores[key] then
		rankStores[key] = DataStoreService:GetOrderedDataStore(key)
	end
	return rankStores[key]
end
local okProfiles, profiles = pcall(DataStoreService.GetDataStore, DataStoreService, "Perfiles1") -- {n, d, lv} para los tableros
local RANK_FIELDS = {Scared = "mScared", XP = "mXP", Likes = "mLikes", Endless = "mEndless"}
local function writeRanks(plr, st)
	local c = counters(st)
	for kind, field in RANK_FIELDS do
		-- (Most Experience: la experiencia total, la que da el nivel, para que más experiencia sea siempre más nivel)
		local v = math.floor(kind == "XP" and (plr:GetAttribute("PXP") or 0) or c[field] or 0)
		local k = c.month .. kind
		if v > 0 and st.sent[k] ~= v and pcall(function()
			rankStore(kind, c.month):SetAsync("u" .. plr.UserId, v)
		end) then
			st.sent[k] = v
		end
	end
	local lv = Config.playerLevel(plr)
	if okProfiles and st.sent.lv ~= lv and pcall(profiles.SetAsync, profiles, "u" .. plr.UserId, {n = plr.Name, d = plr.DisplayName, lv = lv}) then
		st.sent.lv = lv
	end
end

-- release: suelta el bloqueo (sale del juego o viaja a otro servidor). Devuelve si se ha guardado
function save(plr, release)
	local st = state[plr]
	if not (st and st.canSave) or st.frozen then
		return -- si la carga falló, no machacamos lo guardado (frozen: ya se guardó al viajar a otro servidor)
	end
	if workspace:GetAttribute("NoSave") then
		return -- pruebas en Studio: atributo NoSave en Workspace = no se guarda nada
	end
	local h = st.house
	local placed = st.placed
	if h then
		placed = {}
		for _, s in h.scares do
			table.insert(placed, {s.type, s.x, s.z, s.r})
		end
	end
	local data = {
		lock = not release and game.JobId or nil,
		money = plr.leaderstats.Coins.Value + (st.tank or 0), -- (con lo que la Aspiradora guarda en su depósito)
		vacuum = st.vacuum or nil, -- Aspiradora de almas (comprada con gemas antes de ser solo de Robux)
		receipts = st.receipts, -- compras con Robux ya entregadas (PurchaseId)
		rbxScare = st.rbxScare, -- el susto pedido en cada escalón de Robux
		daily = st.daily, -- ofertas del día compradas hoy
		counters = st.counters, -- contadores del día y del mes (rankings)
		endless = (function() -- récords del Modo Infinito: el mejor (oleada * 100 + mapa) y el de cada mapa
			local maps = {}
			for name, v in plr:GetAttributes() do
				if name:sub(1, 3) == "EB_" and typeof(v) == "number" then
					maps[name:sub(4)] = v
				end
			end
			return {best = plr:GetAttribute("EndlessBest") or 0, maps = maps}
		end)(),
		houses = st.houses,
		home = st.home,
		inv = st.inv,
		placed = placed,
		likes = st.likes,
		tut3 = st.tut, -- "tut3": tutorial con demostración dentro (monedas); el progreso de versiones anteriores no vale
		scared = st.scared,
		loadout = st.loadout, -- equipo del Tower Defense
		quests = Misiones.export(plr), -- misiones (MisionesServidor)
		tags = st.tags, -- tags comprados en la Shop...
		tag = st.tag, -- ...y el equipado
		xp = (function() -- experiencia de cada tropa (sus niveles)
			local x = {}
			for t in Config.Scares do
				local n = plr:GetAttribute("XP_" .. t)
				if n and n > 0 then
					x[t] = n
				end
			end
			return x
		end)(),
		skins = (function() -- skins compradas...
			local x = {}
			for _, s in Config.SkinOrder do
				if Config.ownsSkin(plr, s) then
					table.insert(x, s)
				end
			end
			return x
		end)(),
		equip = (function() -- ...y la equipada en cada susto
			local x = {}
			for base in Config.SkinsOf do
				x[base] = Config.equippedSkin(plr, base)
			end
			return x
		end)(),
		stars = (function() -- estrellas de fusión de cada tipo
			local x = {}
			for t in Config.Scares do
				local n = plr:GetAttribute("Star_" .. t)
				if n and n > 0 then
					x[t] = n
				end
			end
			return x
		end)(),
		visitors = st.visitors, -- Libro de Visitantes
		mats = st.mats, -- materiales de cada visitante ("id.material" = veces)
		pxp = plr:GetAttribute("PXP") or 0, -- experiencia del jugador (su nivel)
		gems = plr:GetAttribute("Gems") or 0,
		pity = st.pity, -- tiradas seguidas sin premio gordo, por ruleta
		freeAt = st.freeAt, -- cuándo toca la siguiente tirada gratis (GetServerTimeNow)
		parts = (function()
			local p = {}
			for id in Config.Parts do
				p[id] = plr:GetAttribute("Part_" .. id) or 0
			end
			return p
		end)(),
		day = st.day, -- día (os.time() // 86400) del último premio diario...
		streak = st.streak, -- ...y cuántos días seguidos lleva
		t = os.time(), -- para las ganancias mientras no estás
	}
	local stolen = false
	local ok, err = pcall(store.UpdateAsync, store, "u" .. plr.UserId, function(old)
		-- otro servidor tiene ya al jugador: no pisamos sus datos con los nuestros (más viejos)
		stolen = old ~= nil and old.lock ~= nil and old.lock ~= game.JobId
		return not stolen and data or nil
	end)
	if not ok then
		warn("No se guardaron los datos de " .. plr.Name .. ": " .. tostring(err))
	elseif stolen then
		warn("Los datos de " .. plr.Name .. " ya los tiene otro servidor: aquí no se guardan más")
		st.canSave = false
	else
		writeRanks(plr, st)
		return true
	end
	return false
end

-- Las monedas sin recoger pasan a su dinero (al salir del juego o viajar al Tower Defense)
local function bankCoins(plr)
	local st = state[plr]
	local h = st and st.house
	if not h then
		return
	end
	local pile = pileOf(h) + st.tank -- (y lo que guardaba la Aspiradora)
	st.tank, st.awaySince = 0, nil
	local folder = h.model:FindFirstChild("Coins")
	if folder then
		folder:ClearAllChildren()
	end
	if pile > 0 then
		plr.leaderstats.Coins.Value += pile
	end
end

-- Antes de viajar a otro servidor (Tower Defense, TDMaps.saveFor): se guarda ya y se congela, para que el servidor
-- de destino cargue lo último y este no lo machaque al salir. Si el viaje falla se descongela (freeze = false).
local saveFn = Instance.new("BindableFunction")
saveFn.Name = "GuardarJugador"
saveFn.OnInvoke = function(plr, freeze)
	local st = state[plr]
	if not st then
		return
	end
	st.frozen = nil
	if freeze then
		bankCoins(plr)
		save(plr, true)
		st.frozen = true
		-- si el viaje se cuelga sin avisar y el jugador sigue aquí, se descongela: si no, nada de lo que hiciera
		-- después (fusiones, ruleta, monedas) se guardaría
		task.delay(75, function()
			if state[plr] == st and st.frozen and plr.Parent then
				st.frozen = nil
				save(plr)
			end
		end)
	end
end
saveFn.Parent = SSS

-- Elige parcela: una con casa NPC vacía (sin visitantes), si la hay
local function pickPlot()
	local fallback
	for i in Config.Plots do
		local h = houses[i]
		if not h then
			return i
		elseif h.npc then
			local busy = false
			for _, v in visits do
				if v.house == h then
					busy = true
				end
			end
			if not busy then
				return i
			end
			fallback = fallback or i
		end
	end
	return fallback
end

-- Le da parcela y casa (con sus sustos guardados). Si la calle está llena se queda sin casa (sus sustos siguen
-- guardados) y la recibe en cuanto alguien se vaya.
local function giveHouse(plr)
	local st = state[plr]
	local i = pickPlot()
	if not (st and i) then
		return false
	end
	if houses[i] then
		removeHouse(houses[i])
	end
	local def = Config.house(st.home) or Config.Houses[1]
	local h = createHouse(i, plr, def.rooms, nil, def.template)
	st.house = h
	placeAll(plr, h, st.placed)
	placeVacuum(h)
	syncCounters(plr, st)
	plr:SetAttribute("Plot", i)
	return true
end

-- Carga el personaje en el jardín de su casa (o en la plaza si no le tocó parcela)
local function spawnPlayer(plr)
	if not plr.Parent then
		return
	end
	local st = state[plr]
	local h = st and st.house
	plr.RespawnLocation = h and plotSpawns[h.i] or workspace:FindFirstChild("SpawnLocation")
	plr:LoadCharacter()
end

local function onCharacter(plr, char)
	setGroup(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			task.delay(Players.RespawnTime, function()
				if plr.Parent and plr.Character == char then
					spawnPlayer(plr)
				end
			end)
		end)
	end
end

local function onPlayerAdded(plr)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Coins"
	money.Parent = leaderstats
	local scaredStat = Instance.new("IntValue")
	scaredStat.Name = "Scared" -- visitantes que han huido o han sido atrapados en tu casa
	scaredStat.Parent = leaderstats
	local levelStat = Instance.new("IntValue")
	levelStat.Name = "Level" -- nivel del jugador (Config.playerLevelOf de PXP)
	levelStat.Value = 1
	levelStat.Parent = leaderstats
	plr:GetAttributeChangedSignal("PXP"):Connect(function()
		levelStat.Value = Config.playerLevel(plr)
	end)
	leaderstats.Parent = plr

	local data, canSave = load(plr)
	if not plr.Parent then
		return
	end
	-- no se pudo leer su partida: mejor que vuelva a entrar que jugar desde cero sin guardar
	if store and not canSave and not READ_ONLY then
		plr:Kick("We couldn't load your save (Roblox servers are busy). Your progress is safe: please rejoin in a moment!")
		return
	end
	data = data or {money = Config.START_MONEY, inv = table.clone(Config.StarterScares), placed = {}}
	data.inv = typeof(data.inv) == "table" and data.inv or {}
	-- Skins compradas y la equipada en cada susto. Antes las skins eran sustos aparte: las que tenga en la mochila o
	-- colocadas pasan a ser skins suyas (equipadas) y cada copia vuelve a ser su susto original, con sus estrellas
	local ownSkins, equip = {}, {}
	for _, s in typeof(data.skins) == "table" and data.skins or {} do
		if Config.Scares[s] and Config.Scares[s].skin then
			ownSkins[s] = true
		end
	end
	for base, s in typeof(data.equip) == "table" and data.equip or {} do
		equip[base] = s
	end
	local function oldSkin(s)
		local base = Config.Scares[s].base
		ownSkins[s] = true
		equip[base] = equip[base] or s
		return base
	end
	for s, n in table.clone(data.inv) do
		if Config.Scares[s] and Config.Scares[s].skin then
			data.inv[s] = nil
			if typeof(n) == "number" and n > 0 then
				local base = oldSkin(s)
				data.inv[base] = (data.inv[base] or 0) + n
			end
		end
	end
	for _, p in data.placed or {} do
		if Config.Scares[p[1]] and Config.Scares[p[1]].skin then
			p[1] = oldSkin(p[1])
		end
	end
	for s, n in typeof(data.stars) == "table" and table.clone(data.stars) or {} do
		local def = Config.Scares[s]
		if def and def.skin then
			data.stars[s] = nil
			if typeof(n) == "number" and n > (data.stars[def.base] or 0) then
				data.stars[def.base] = n
			end
		end
	end
	for s in ownSkins do
		plr:SetAttribute("OwnSkin_" .. s, true)
	end
	for base, s in equip do
		if ownSkins[s] and Config.Scares[s].base == base then
			plr:SetAttribute("Skin_" .. base, s)
		end
	end
	money.Value = data.money
	-- casas compradas (la primera la tiene todo el mundo); las que ya no existan en Config se ignoran
	local owned = {Config.Houses[1].id}
	for _, id in data.houses or {} do
		if Config.house(id) and not table.find(owned, id) then
			table.insert(owned, id)
		end
	end
	local home = table.find(owned, data.home) and Config.house(data.home) or Config.Houses[1]
	local st = {
		houses = owned, home = home.id, inv = data.inv, placed = data.placed, canSave = canSave,
		likes = data.likes or 0, tut = data.tut3 or 0, scared = data.scared or 0, brave = {},
		day = data.day or 0, streak = data.streak or 0, loadout = data.loadout or {},
		visitors = data.visitors or {}, -- Libro de Visitantes: [id] = veces asustado
		mats = typeof(data.mats) == "table" and data.mats or {}, -- ["id.material"] = veces asustado hecho de esa materia
		tags = {},
		vacuum = data.vacuum == true, tank = 0, sucked = 0, -- Aspiradora de almas (tank: lo que junta mientras no estás)
		daily = typeof(data.daily) == "table" and data.daily or {day = 0, bought = {}},
		counters = typeof(data.counters) == "table" and data.counters or {}, sent = {},
		receipts = typeof(data.receipts) == "table" and data.receipts or {},
		rbxScare = typeof(data.rbxScare) == "table" and data.rbxScare or {},
	}
	st.daily.bought = st.daily.bought or {}
	for _, id in data.tags or {} do
		if Config.TagById[id] and not table.find(st.tags, id) then
			table.insert(st.tags, id)
		end
	end
	st.tag = table.find(st.tags, data.tag) and data.tag or nil
	plr:SetAttribute("Tags", table.concat(st.tags, ","))
	plr:SetAttribute("Tag", st.tag)
	state[plr] = st
	syncVisitors(plr)
	plr:SetAttribute("Loadout", table.concat(st.loadout, ","))
	plr:SetAttribute("Gems", data.gems or 0)
	local pxp = typeof(data.pxp) == "number" and data.pxp or 0
	if Config.MAX_LEVEL_USERS[plr.UserId] then
		pxp = math.max(pxp, Config.pxpTotal(Config.PLAYER_MAX_LEVEL)) -- (siempre al nivel máximo: Config.MAX_LEVEL_USERS)
	end
	plr:SetAttribute("PXP", pxp)
	Misiones.load(plr, data.quests) -- (con su nivel ya puesto: la misión "Reach level N" parte de él)
	-- experiencia ganada este mes (tablero "Most Experience")
	local lastPXP = plr:GetAttribute("PXP")
	plr:GetAttributeChangedSignal("PXP"):Connect(function()
		local v = plr:GetAttribute("PXP") or 0
		if v > lastPXP then
			count(plr, "mXP", v - lastPXP)
		else
			syncCounters(plr, st) -- (también si baja: el tablero enseña la experiencia total)
		end
		lastPXP = v
	end)
	-- Modo Infinito: récords (EndlessRun lo pone TDMatch al acabar una partida infinita: oleada * 100 + mapa)
	local endless = typeof(data.endless) == "table" and data.endless or {}
	plr:SetAttribute("EndlessBest", endless.best or 0)
	for id, v in endless.maps or {} do
		plr:SetAttribute("EB_" .. id, v)
	end
	plr:GetAttributeChangedSignal("EndlessRun"):Connect(function()
		local v = plr:GetAttribute("EndlessRun") or 0
		local c = counters(st)
		if v > c.mEndless then
			c.mEndless = v
			syncCounters(plr, st)
		end
		if v > (plr:GetAttribute("EndlessBest") or 0) then
			plr:SetAttribute("EndlessBest", v)
		end
	end)
	-- Aspiradora y ofertas del día ya compradas
	plr:SetAttribute("Vacuum", st.vacuum or nil)
	local bought = {}
	for n in st.daily.bought do
		table.insert(bought, n)
	end
	plr:SetAttribute("DailyBought", st.daily.day .. ":" .. table.concat(bought, ","))
	syncCounters(plr, st)
	checkPasses(plr)
	st.pity, st.freeAt = {}, data.freeAt or 0
	for i in Config.Wheels do
		st.pity[i] = data.pity and data.pity[i] or 0
		plr:SetAttribute("Pity" .. i, st.pity[i])
	end
	plr:SetAttribute("FreeSpinAt", st.freeAt)
	for id in Config.Parts do
		plr:SetAttribute("Part_" .. id, data.parts and data.parts[id] or 0)
	end
	for t, n in data.xp or {} do
		if Config.Scares[t] and typeof(n) == "number" then
			plr:SetAttribute("XP_" .. t, n)
		end
	end
	for t, n in data.stars or {} do
		if Config.Scares[t] and typeof(n) == "number" then
			plr:SetAttribute("Star_" .. t, math.clamp(math.floor(n), 0, Config.STAR_MAX))
		end
	end
	scaredStat.Value = st.scared
	plr:SetAttribute("Tut", st.tut)
	-- Quien ya terminó el tutorial: premio diario (con racha) y lo que soltaron los visitantes mientras no estaba
	if st.tut >= 4 and not MATCH_SERVER then
		local today = os.time() // 86400
		if today > st.day then
			st.streak = today == st.day + 1 and st.streak + 1 or 1
			st.day = today
			local prize = Config.DAILY[math.min(st.streak, #Config.DAILY)]
			money.Value += prize
			Remote:FireClient(plr, "Daily", prize, st.streak)
		end
		local away = data.t and math.min(os.time() - data.t, Config.OFFLINE_MAX_H * 3600) or 0
		local pay = 0
		for _, p in data.placed or {} do
			local def = Config.Scares[p[1]] and Config.starDef(p[1], Config.starOf(plr, p[1]))
			pay += def and def.pay or 0
		end
		local earned = math.floor(away / 60 * pay * Config.OFFLINE_RATE)
		if away >= 300 and earned > 0 then
			money.Value += earned
			Remote:FireClient(plr, "Offline", earned, math.floor(away / 60))
		end
	end

	if not giveHouse(plr) then
		Remote:FireClient(plr, "Info", "The street is full! You'll get a house as soon as someone leaves")
	end
	plr:SetAttribute("Rooms", home.rooms)
	plr:SetAttribute("Spaces", select(3, Config.houseDims(home.template, home.rooms)))
	plr:SetAttribute("Houses", table.concat(owned, ","))
	plr:SetAttribute("Home", home.id)
	for t in Config.Scares do
		plr:SetAttribute("Inv_" .. t, st.inv[t] or 0)
	end

	plr.CharacterAdded:Connect(function(char)
		onCharacter(plr, char)
	end)
	plr.CharacterRemoving:Connect(function()
		if visits[plr] then
			endVisit(visits[plr], "quit")
		end
		plr:SetAttribute("Mode", nil)
	end)

	-- Aparece delante de su casa, mirando a la puerta
	if plr.Character then
		-- (en Studio el personaje puede haber cargado antes que este script)
		onCharacter(plr, plr.Character)
		if st.house then
			plr.Character:PivotTo(frontOf(st.house))
		end
	else
		spawnPlayer(plr)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(plr)
	if visits[plr] then
		endVisit(visits[plr], "quit")
	end
	if not (state[plr] and state[plr].frozen) then
		bankCoins(plr)
	end
	save(plr, true)
	Misiones.drop(plr)
	local st = state[plr]
	state[plr] = nil
	spinning[plr] = nil
	gifts[plr] = nil
	liked[plr.UserId] = nil
	local h = st and st.house
	if h then
		removeHouse(h)
		npcHouse(h.i)
		-- la parcela queda libre: para el primero que se quedó sin casa
		for _, other in Players:GetPlayers() do
			local ost = state[other]
			if other ~= plr and ost and not ost.house then
				if giveHouse(other) then
					other.RespawnLocation = plotSpawns[ost.house.i]
					Remote:FireClient(other, "Info", "A house just freed up: it's yours now! 🏠")
				end
				break
			end
		end
	end
end)

-- Todos a la vez: el servidor solo espera unos 30 s al cerrar
game:BindToClose(function()
	local left = 0
	for _, plr in Players:GetPlayers() do
		left += 1
		task.spawn(function()
			save(plr, true)
			left -= 1
		end)
	end
	while left > 0 do
		task.wait()
	end
end)

-- Guardado automático: si el servidor se cae, como mucho se pierden AUTOSAVE segundos
task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE)
		for _, plr in Players:GetPlayers() do
			task.spawn(save, plr)
		end
	end
end)

-- Al arrancar, todas las parcelas tienen una casa abandonada que se puede visitar
for i in Config.Plots do
	npcHouse(i)
end
for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

---------- Bucle principal ----------
local last = os.clock()
local lastVac, lastAway = 0, 0
local bloodOn = false
local function tick()
	local now = os.clock()
	local dt = now - last
	last = now
	-- Noche de Sangre: la misma hora en todos los servidores (los clientes leen el atributo y el horario de Config)
	local blood, bloodAt = Config.bloodNight(workspace:GetServerTimeNow())
	if blood ~= bloodOn then
		bloodOn = blood
		workspace:SetAttribute("BloodNight", blood)
		if blood then
			-- empieza: los visitantes llegan ya
			for _, h in houses do
				h.nextBot = math.min(h.nextBot, now + 1 + math.random() * 2)
			end
		end
	end
	workspace:SetAttribute("BloodAt", bloodAt)
	if now - lastVac >= 0.25 then
		lastVac = now
		vacuumTick()
	end
	if now - lastAway >= 0.5 then
		lastAway = now
		awayTick()
	end
	for _, v in visits do
		if visits[v.key] ~= v then
			continue
		end
		local h = v.house
		local pos = v.root.Position
		local x, z = depthOf(h, pos)
		if not v.ready and v.bot and z > 1 then
			v.ready = true -- el bot ya está dentro: anda agachado con la linterna por delante
			anim(v, "sneak")
		end
		if not v.ready then
			continue
		end
		if v.player and z < 0.2 and math.abs(x) < Config.DOOR_W then
			endVisit(v, "left") -- ha salido andando por la puerta
			continue
		end
		-- si alguien sale de la casa por un fallo, se acaba la visita
		if v.player and (math.abs(x) > h.roomW / 2 + 4 or z < -4 or z > h.rooms * D + 4) then
			endVisit(v, "quit")
			continue
		end
		-- ha llegado al fondo sin desmayarse (como los bots): lo celebra y aparece fuera
		if v.player and z > h.rooms * D - 4 then
			endVisit(v, "done")
			continue
		end
		for _, s in h.scares do
			if v.calmUntil and now < v.calmUntil then
				break
			end
			if not s.busy and now - (s.hits[v.key] or -math.huge) > Config.RESCARE and Config.inReach(s.def, s.cf, pos) then
				s.hits[v.key] = now
				trigger(s, v)
				if visits[v.key] ~= v then
					break
				end
			end
		end
		if visits[v.key] == v and now > v.calmAt and v.fear > 0 then
			v.fear = math.max(0, v.fear - Config.FEAR_DECAY * dt)
			syncFear(v)
		end
	end
	-- ¿Quién cruza el portal de una casa? En la tuya pasas a "home"; en otra empieza la visita.
	for _, plr in Players:GetPlayers() do
		local st = state[plr]
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (st and root and hum and hum.Health > 0) then
			continue
		end
		local mode = plr:GetAttribute("Mode")
		local h, z = houseAt(root.Position)
		if mode == nil and h and z > 0.8 then
			if h == st.house then
				plr:SetAttribute("Mode", "home")
			else
				startVisit(plr, h, false, true)
			end
		elseif mode == "home" and (h ~= st.house or z < 0.2) then
			plr:SetAttribute("Mode", nil)
		end
	end
	for _, h in houses do
		-- mientras el dueño está en el Tower Defense (lobby, viaje, partida o su servidor), a su casa no llega nadie
		local owner = h.owner
		if owner and not MATCH_SERVER and h.count > 0 and now >= h.nextBot and not AWAY[owner:GetAttribute("Mode")]
			and owner:GetAttribute("TDCash") == nil and owner:GetAttribute("TDMap") == nil then
			if not h.bot then
				spawnBot(h)
			elseif bloodOn then
				-- Noche de Sangre: más visitantes y varios a la vez
				local n = 0
				for _, v in visits do
					n += (v.bot and v.house == h) and 1 or 0
				end
				if n < Config.BLOOD_MAX_BOTS then
					spawnBot(h)
				end
			end
			if bloodOn then
				h.nextBot = now + nextBotDelay(h) / Config.BLOOD_RATE
			end
		end
	end
end

while true do
	task.wait(0.1)
	local ok, err = pcall(tick)
	if not ok then
		warn(err)
	end
end
