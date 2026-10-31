-- Tower Defense (servidor): una partida cooperativa por mapa. Tus sustos son las tropas.
-- TDMaps llama a esta función con cada mapa al cargarlo. Cuando un grupo llega al mapa (Z.send) empieza una
-- partida con los ajustes del lobby (dificultad y oleadas), o se une a la que ya está en marcha.
-- Oleadas de cazafantasmas (los bots visitantes, con sus animaciones de miedo de NPCAnim) salen de la entrada y
-- recorren el camino hasta la casa encantada. Las tropas les meten miedo; con la barra llena huyen y todo el equipo
-- cobra dinero de partida. Cada oleada superada paga monedas del juego (las de comprar sustos).
-- Para los clientes: atributos de <mapa>.TD (Phase, Wave, Waves, Diff, HP, NextAt, Left, Votes...), del jugador
-- (TDCash, TDMap) y de cada tropa y enemigo. Efectos y avisos: TDRemote.
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Config = require(RS.Config)
local TD = require(RS.TowerDefense)
local Remote = RS.TDRemote
local Assets = RS.Assets
local BotTemplate = ServerStorage.Bot
local Outfits = require(RS.Outfits)
local Misiones = require(game:GetService("ServerScriptService").MisionesServidor) -- (lo que cuenta para las misiones)
local flat = TD.flat

if not PhysicsService:IsCollisionGroupRegistered("Bots") then
	PhysicsService:RegisterCollisionGroup("Bots") -- (Juego hace que no choquen entre sí ni con los jugadores)
end
-- Lo que no es suelo en los mapas (muros invisibles de los límites, arcos, carteles, decoración) no frena a los
-- cazafantasmas: solo pisan el camino, los puentes y el terreno. (En varios mapas el camino empezaba al otro lado del
-- muro del borde y se quedaban parados en la entrada hasta que les sacaba el rescate de atascos.)
if not PhysicsService:IsCollisionGroupRegistered("TDDeco") then
	PhysicsService:RegisterCollisionGroup("TDDeco")
end
PhysicsService:CollisionGroupSetCollidable("Bots", "TDDeco", false)

local function now()
	return workspace:GetServerTimeNow()
end

-- Gemas: atributo del jugador (Gems) que guarda Juego. Con el pase 2x Gems, las
-- gemas valen doble. Devuelve lo que ha sumado
local function addAttr(plr, name, n)
	if name == "Gems" and plr:GetAttribute("Pass_Gems2x") then
		n *= 2
	end
	plr:SetAttribute(name, (plr:GetAttribute(name) or 0) + n)
	return n
end

local function addCash(plr, n)
	plr:SetAttribute("TDCash", (plr:GetAttribute("TDCash") or 0) + math.floor(n + 0.5))
end

-- variantes, variación de tono y límites en ReplicatedStorage.Sfx
local Sfx = require(RS.Sfx)
local function sound(name, parent, pitch)
	if parent then
		Sfx.play(name, parent, nil, pitch)
	end
end

local function poof(bot)
	local r = bot:FindFirstChild("HumanoidRootPart")
	local fx = Assets:FindFirstChild("Poof")
	if r and fx then
		local p = fx:Clone()
		p.Parent = r
		p:Emit(30)
	end
	task.delay(0.15, bot.Destroy, bot)
end

---------- Cazafantasmas: el bot vestido según su tipo (ropa y complementos: módulo Outfits) ----------
local function makeEnemy(def)
	local bot = BotTemplate:Clone()
	Outfits.dress(bot, def)
	-- los expertos llevan linterna (sin sombras: puede haber muchos)
	local hand = bot:FindFirstChild("RightHand")
	if def.torch and hand then
		local torch = Instance.new("Part")
		torch.Name = "Linterna"
		torch.Size = Vector3.new(0.35, 0.35, 1.2)
		torch.Color = Color3.fromRGB(30, 30, 34)
		torch.Material = Enum.Material.Metal
		torch.CanCollide = false
		torch.Massless = true
		torch.CollisionGroup = "Bots"
		torch.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, torch
		weld.Parent = torch
		local spot = Instance.new("SpotLight")
		spot.Range, spot.Angle, spot.Brightness = 22, 50, 2
		spot.Color = Color3.fromRGB(255, 240, 210)
		spot.Parent = torch
		torch.Parent = bot
	end
	if def.golden then
		local torso = bot:FindFirstChild("UpperTorso")
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = def.shirt
		sparkles.Parent = torso
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = def.shirt, 10, 1.5
		glow.Parent = torso
	end
	-- los ocultos se ven medio transparentes (TowerDefenseUI) y solo los atacan las tropas que detectan
	if def.hidden then
		bot:SetAttribute("Hidden", true)
	end
	local hum = bot.Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	if def.scale ~= 1 then
		bot:ScaleTo(def.scale)
	end
	if def.fly then
		hum.AutomaticScalingEnabled = false -- (si no, el escalado automático le devuelve la altura normal)
		hum.HipHeight += 3.5 -- vuela sobre el camino: las trampillas no le alcanzan
	end
	return bot
end

return function(Z)
	local map = Z.map
	do
		local tds = map:FindFirstChild("MapaTDS")
		local lane, floor = tds and tds:FindFirstChild("Camino"), tds and tds:FindFirstChild("Suelo")
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and d.CollisionGroup == "Default" and not (lane and d:IsDescendantOf(lane) or floor and d:IsDescendantOf(floor)) then
				d.CollisionGroup = "TDDeco"
			end
		end
	end
	local root = Instance.new("Folder")
	root.Name = "TD"
	local towersF = Instance.new("Folder")
	towersF.Name = "Towers"
	towersF.Parent = root
	local enemiesF = Instance.new("Folder")
	enemiesF.Name = "Enemies"
	enemiesF.Parent = root
	root.Parent = map

	local match -- la partida de este mapa (los grupos que llegan después se unen a ella)

	local function path()
		return TD.path(map)
	end

	local function tell(...)
		for plr in match.players do
			Remote:FireClient(plr, ...)
		end
	end

	local function diff()
		return TD.DIFFS[match.diff]
	end

	local function waveCash(w)
		return TD.waveCash(TD.effWave(w, match.waves)) * TD.cashScale(match.waves) * diff().cash
	end
	local function waveCoins(w)
		if match.endless then
			-- Modo Infinito: desde la 20 las monedas crecen despacio (no se puede farmear)
			return math.floor(TD.waveCoins(math.min(w, 20)) * (1 + 0.02 * math.max(0, w - 20)) * diff().coins + 0.5)
		end
		return math.floor(TD.waveCoins(TD.effWave(w, match.waves)) * TD.cashScale(match.waves) * diff().coins + 0.5)
	end

	-- Votos para saltar la espera. Entre oleadas cuenta también quien tiene "Auto skip" (atributo TDAuto del jugador:
	-- se queda puesto entre partidas); la preparación inicial solo se salta votando.
	local function countVotes(m)
		local votes = 0
		for plr in m.players do
			if m.votes[plr] or ((m.phase == "break" or m.canSkip) and plr:GetAttribute("TDAuto")) then
				votes += 1
			end
		end
		return votes
	end

	-- Estado para las interfaces
	local function sync()
		local m = match
		root:SetAttribute("Active", m ~= nil)
		if not m then
			return
		end
		local votes = countVotes(m)
		root:SetAttribute("Phase", m.phase)
		-- en plena oleada, NextAt es cuándo empieza la siguiente aunque no se haya despejado (0: la última no tiene tiempo)
		local nextAt = m.nextAt
		if m.phase == "wave" then
			nextAt = m.waveTime < math.huge and now() + math.max(0, m.waveTime - m.waveClock) / m.speed or 0
		end
		root:SetAttribute("NextAt", nextAt)
		root:SetAttribute("Wave", m.wave)
		root:SetAttribute("Waves", m.waves)
		root:SetAttribute("Diff", m.diff)
		local bw = m.phase == "wave" and m.wave or m.wave + 1
		root:SetAttribute("Bonus", math.floor(waveCash(math.max(1, m.endless and bw or math.min(bw, m.waves))) + 0.5))
		root:SetAttribute("Endless", m.endless == true)
		root:SetAttribute("HP", m.hp)
		root:SetAttribute("MaxHP", TD.BASE_HP)
		root:SetAttribute("Left", m.toSpawn + m.alive)
		root:SetAttribute("Alive", m.alive)
		root:SetAttribute("CanSkip", m.canSkip == true)
		root:SetAttribute("Players", m.count)
		root:SetAttribute("Total", m.total)
		root:SetAttribute("Kills", m.kills)
		root:SetAttribute("Speed", m.speed)
		root:SetAttribute("Host", m.host and m.host.UserId or 0) -- (solo él cambia la velocidad)
		root:SetAttribute("Votes", votes)
		root:SetAttribute("VotesNo", m.noCount or 0)
		root:SetAttribute("VotesNeed", m.count // 2 + 1)
		root:SetAttribute("Again", m.againCount or 0) -- ("Play Again" en la pantalla de resultados)
	end

	local function setPhase(phase, wait)
		match.phase = phase
		match.canSkip = false
		match.nextAt = wait and now() + wait or 0
		table.clear(match.votes)
		table.clear(match.no)
		match.noCount = 0
	end

	---------- Cazafantasmas ----------
	-- at: studs recorridos del camino donde aparece (nil = en la entrada)
	local function spawnEnemy(kind, at)
		local m = match
		local def = TD.Enemies[kind]
		local e = TD.effWave(m.wave, m.waves)
		local hp = math.floor(def.hp * TD.hpScale(e, m.count) * TD.diffHp(m.diff, e, Z.id, m.waves) * (m.endless and TD.endlessHp(e) or 1) + 0.5)
		local bot = makeEnemy(def)
		local p = path()
		local pos, i = p.pts[1], 2
		if at then
			pos, i = TD.pointAt(at, map)
		end
		local start = pos + Vector3.new((math.random() - 0.5) * 3, 3.3 * def.scale + (def.fly and 3.5 or 0), (math.random() - 0.5) * 3)
		-- (se mueve el modelo entero: fuera del workspace las uniones no arrastran los complementos)
		bot:PivotTo(CFrame.lookAt(start, Vector3.new(p.pts[i].X, start.Y, p.pts[i].Z)))
		bot:SetAttribute("Kind", kind)
		bot:SetAttribute("HP", hp)
		bot:SetAttribute("MaxHP", hp)
		bot:SetAttribute("Fear", 0)
		bot:SetAttribute("Shield", def.shield and 100 or nil) -- % de escudo que le queda (barra azul)
		-- NPCAnim: agachados, mirando a todas partes y, con miedo, temblando; los jefes marchan erguidos (Walk: su paso)
		bot:SetAttribute("Walk", def.boss and "march" or "sneak")
		bot:SetAttribute("Anim", def.boss and "march" or "sneak")
		bot:SetAttribute("AnimAt", now())
		bot.Parent = enemiesF
		bot.HumanoidRootPart:SetNetworkOwner(nil)
		CollectionService:AddTag(bot, "Visitor")
		CollectionService:AddTag(bot, "TDEnemy")
		local t = now()
		m.enemies[bot] = {
			model = bot, def = def, hum = bot.Humanoid, root = bot.HumanoidRootPart, hp = hp, max = hp,
			shield = def.shield and hp * def.shield or 0, shieldMax = def.shield and hp * def.shield or 0, i = i, progress = at or 0, lastProg = at or 0, lastMove = t,
			slow = 0, slowUntil = 0, stunUntil = 0, terrify = 0, terrifyUntil = 0, trapped = 0, status = "",
			burstUntil = 0, burstReady = 0, abilityAt = t + 2,
			burnDps = 0, burnUntil = 0, fleeUntil = 0, inspireUntil = 0, inspireMult = 1, dashUntil = 0,
			cds = {}, -- cuándo puede volver a usar cada habilidad
		}
		m.alive += 1
		-- echa a andar ya (sin esperar a la vuelta del bucle)
		bot.Humanoid.WalkSpeed = def.speed * m.speed * diff().speed
		bot.Humanoid:MoveTo(p.pts[i])
		if def.boss then
			tell("Boss", bot, def.name)
		end
	end

	local finish -- se define más abajo

	-- Huye: se desmaya o sale corriendo hacia la entrada gritando. Todo el equipo cobra; la tropa que le dio el último
	-- susto (tw) se apunta la baja.
	local function kill(e, tw)
		local m = match
		if not m or m.enemies[e.model] ~= e then
			return
		end
		m.enemies[e.model] = nil
		m.alive -= 1
		m.kills += 1
		if tw then
			tw.kills += 1
			tw.model:SetAttribute("Kills", tw.kills)
			Config.addXP(tw.owner, tw.type, Config.XP_TD_KILL) -- la tropa sube de nivel
			local info = m.players[tw.owner]
			if info then
				info.kills += 1
				tw.owner:SetAttribute("TDKills", info.kills)
				Misiones.add(tw.owner, "tdKill", 1)
			end
			-- el Vampiro se bebe el miedo: la casa recupera vida
			if tw.stats.drain and m.hp < TD.BASE_HP and m.hp > 0 then
				m.hp = math.min(TD.BASE_HP, m.hp + tw.stats.drain)
				tell("Drain", e.root.Position, tw.model, tw.stats.drain)
			end
		end
		local bot = e.model
		bot:SetAttribute("HP", 0)
		bot:SetAttribute("Fear", 100)
		bot:SetAttribute("Status", "")
		CollectionService:RemoveTag(bot, "TDEnemy")
		local cash = e.def.cash * diff().cash
		for plr in m.players do
			addCash(plr, cash)
		end
		tell("Kill", e.root.Position, math.floor(cash + 0.5), e.def.boss)
		-- el padre de familia huye... y sus hijos siguen solos (se crean en el bucle, fuera del recorrido de enemigos)
		if e.def.split and not m.over then
			for k = 1, e.def.split.n do
				table.insert(m.queue, {e.def.split.kind, math.max(0, e.progress - k * 2)})
			end
		end
		-- los jefes caen redondos (como el Brut de TDS); los demás, la mitad huye y la otra mitad se desmaya
		local panic = not e.def.boss and math.random() < 0.5
		bot:SetAttribute("Anim", panic and "panic" or "faint")
		bot:SetAttribute("AnimAt", now())
		sound(math.random() < 0.5 and "Scream" or "Scream2", bot:FindFirstChild("Head"), (0.9 + math.random() * 0.35) / e.def.scale)
		if panic then
			e.hum.WalkSpeed = 22
			e.hum:MoveTo(path().pts[math.max(1, e.i - 3)])
		else
			e.root.Anchored = true
		end
		task.delay(panic and 1.4 or (e.def.boss and 3 or 1.8), poof, bot)
	end

	-- Llegó a la casa: le quita vida
	local function leak(e)
		local m = match
		if m.enemies[e.model] ~= e then
			return
		end
		m.enemies[e.model] = nil
		m.alive -= 1
		m.hp = math.max(0, m.hp - e.def.leak)
		tell("Leak", e.def.leak, e.root.Position)
		sound("Poof", e.root)
		poof(e.model)
		if m.hp <= 0 then
			finish(false)
		end
	end

	local function hurt(e, amount, tw)
		if match.enemies[e.model] ~= e then
			return
		end
		local t = now()
		if t < e.terrifyUntil then
			amount *= 1 + e.terrify
		end
		if e.def.armor then
			amount *= 1 - e.def.armor
		end
		-- el escudo aguanta primero
		if e.shield > 0 and amount ~= math.huge then
			local absorbed = math.min(e.shield, amount)
			e.shield -= absorbed
			amount -= absorbed
			e.model:SetAttribute("Shield", math.ceil(e.shield / e.shieldMax * 100))
			if e.shield <= 0 then
				sound("WoodBreak", e.root, 1.3)
				tell("ShieldBreak", e.root.Position)
			end
		end
		if e.def.burst and t >= e.burstReady then
			e.burstUntil = t + e.def.burst.time
			e.burstReady = t + e.def.burst.cd
		end
		-- estadísticas: miedo causado por la tropa y por su dueño (y por tipo, para la tropa MVP)
		local dealt = math.min(e.hp, amount)
		if tw then
			tw.damage += dealt
			tw.model:SetAttribute("Damage", math.floor(tw.damage))
			local info = match.players[tw.owner]
			if info then
				info.damage += dealt
				info.byType[tw.type] = (info.byType[tw.type] or 0) + dealt
				tw.owner:SetAttribute("TDFear", math.floor(info.damage))
			end
		end
		e.hp -= amount
		if e.hp <= 0 then
			return kill(e, tw)
		end
		e.model:SetAttribute("HP", math.ceil(e.hp))
		e.model:SetAttribute("Fear", math.floor((1 - e.hp / e.max) * 100))
	end

	local function heal(e, amount)
		e.hp = math.min(e.max, e.hp + amount)
		e.model:SetAttribute("HP", math.ceil(e.hp))
		e.model:SetAttribute("Fear", math.floor((1 - e.hp / e.max) * 100))
	end

	-- ¿Puede usar ya esta habilidad? (cada una con su propia espera, a la velocidad de la partida)
	local function ready(e, key, cd, t)
		if t >= (e.cds[key] or 0) then
			e.cds[key] = t + cd / match.speed
			return true
		end
		return false
	end

	local function around(e, radius)
		local list = {}
		for _, o in match.enemies do
			if flat(o.root.Position - e.root.Position) <= radius then
				table.insert(list, o)
			end
		end
		return list
	end

	local function setShield(o)
		o.model:SetAttribute("Shield", o.shieldMax > 0 and math.ceil(o.shield / o.shieldMax * 100) or nil)
	end

	-- Habilidades que van solas (curar, regenerarse, llamar a más, limpiar, escudar, saltar, inspirar, cargar, aturdir)
	local function abilities(e, t, dt)
		local def = e.def
		if def.regen and e.hp < e.max then
			heal(e, e.max * def.regen * dt)
		end
		if t < e.abilityAt then
			return -- (un respiro al aparecer)
		end
		local pos = e.root.Position
		if def.heal and ready(e, "heal", def.heal.cd, t) then
			local any = false
			for _, o in around(e, def.heal.radius) do
				if o.hp < o.max then
					heal(o, o.max * def.heal.amount)
					any = true
				end
			end
			if any then
				tell("Heal", pos, def.heal.radius)
			end
		end
		if def.summon and ready(e, "summon", def.summon.cd, t) then
			for k = 1, def.summon.n do
				table.insert(match.queue, {def.summon.kind, math.max(0, e.progress - 3 - k * 2)})
			end
			tell("Summon", pos)
			sound("Laugh", e.root, 0.8)
		end
		if def.cleanse and ready(e, "cleanse", def.cleanse.cd, t) then
			local any = false
			for _, o in around(e, def.cleanse.radius) do
				if t < o.slowUntil or t < o.stunUntil or t < o.burnUntil or t < o.terrifyUntil or t < o.fleeUntil then
					o.slowUntil, o.stunUntil, o.burnUntil, o.terrifyUntil, o.fleeUntil = 0, 0, 0, 0, 0
					any = true
				end
			end
			if any then
				tell("Cleanse", pos, def.cleanse.radius)
				sound("Sparkle", e.root, 0.8)
			end
		end
		if def.barrier and ready(e, "barrier", def.barrier.cd, t) then
			for _, o in around(e, def.barrier.radius) do
				local cap = o.max * def.barrier.amount
				if o.shield < cap then
					o.shield = cap
					o.shieldMax = math.max(o.shieldMax, cap)
					setShield(o)
				end
			end
			tell("Barrier", pos, def.barrier.radius)
			sound("Sparkle", e.root, 1.2)
		end
		if def.blink and ready(e, "blink", def.blink.cd, t) and e.progress + def.blink.dist < path().total - 8 then
			local to, i = TD.pointAt(e.progress + def.blink.dist, map)
			local nxt = path().pts[i]
			local y = e.root.Position.Y
			e.root.CFrame = CFrame.lookAt(Vector3.new(to.X, y, to.Z), Vector3.new(nxt.X, y, nxt.Z))
			e.i = i
			e.progress += def.blink.dist
			e.lastProg = e.progress
			tell("Blink", pos, Vector3.new(to.X, y, to.Z))
			sound("Whoosh", e.root, 1.3)
		end
		if def.inspire and ready(e, "inspire", def.inspire.cd, t) then
			for _, o in around(e, def.inspire.radius) do
				o.inspireUntil = t + def.inspire.time / match.speed
				o.inspireMult = def.inspire.mult
			end
			tell("Inspire", pos, def.inspire.radius)
		end
		if def.dash and ready(e, "dash", def.dash.cd, t) then
			e.dashUntil = t + def.dash.time / match.speed
		end
		if def.disable and ready(e, "disable", def.disable.cd, t) then
			local any = false
			for _, tw in match.towers do
				if flat(tw.pos - pos) <= def.disable.radius then
					tw.disabledUntil = t + def.disable.time / match.speed
					tw.model:SetAttribute("Disabled", tw.disabledUntil)
					any = true
				end
			end
			if any then
				tell("Disable", pos, def.disable.radius)
				sound("Flashlight", e.root)
			end
		end
	end

	-- La trampilla lo devuelve d studs atrás por el camino
	local function knockBack(e, d)
		local pos, i = TD.pointAt(e.progress - d, map)
		local nxt = path().pts[i]
		local y = e.root.Position.Y
		e.root.CFrame = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(nxt.X, y, nxt.Z))
		e.i = i
		e.progress = math.max(0, e.progress - d)
		e.lastProg = e.progress
	end

	local function move(e, t, dt)
		-- el fuego (velas, bruja, jinete, dragón) asusta poco a poco
		if t < e.burnUntil then
			hurt(e, e.burnDps * dt, e.burnBy and e.burnBy.model.Parent and e.burnBy or nil)
			if match.enemies[e.model] ~= e then
				return
			end
		end
		local p = path()
		local pos = e.root.Position
		-- huyendo (Banshee): vuelve hacia el punto anterior del camino
		local fleeing = t < e.fleeUntil and e.i > 2
		local target
		if fleeing then
			target = p.pts[e.i - 1]
			if flat(target - pos) < 2.5 then
				e.i -= 1
				fleeing = e.i > 2
				target = fleeing and p.pts[e.i - 1] or p.pts[e.i]
			end
		else
			target = p.pts[e.i]
			if flat(target - pos) < 2.5 then
				e.i += 1
				if e.i > #p.pts then
					return leak(e)
				end
				target = p.pts[e.i]
			end
		end
		if fleeing ~= (e.fled == true) then
			e.fled = fleeing
			e.model:SetAttribute("Anim", fleeing and "panic" or (e.def.boss and "march" or "sneak"))
			e.model:SetAttribute("AnimAt", now())
		end
		abilities(e, t, dt)
		if match.enemies[e.model] ~= e then
			return
		end
		local speed = e.def.speed * match.speed * diff().speed
		if t < e.stunUntil then
			speed = 0
		elseif t < e.slowUntil then
			speed *= 1 - e.slow
		end
		if t < e.burstUntil then
			speed *= e.def.burst.mult
		end
		if t < e.dashUntil then
			speed *= e.def.dash.mult
		end
		if t < e.inspireUntil then
			speed *= e.inspireMult
		end
		if fleeing then
			speed = math.max(speed, e.def.speed * match.speed * 0.9)
		end
		-- estados que se ven sobre su cabeza
		local status = (t < e.stunUntil and "💫" or "") .. (t < e.slowUntil and "🐢" or "") .. (t < e.terrifyUntil and "😨" or "")
			.. (t < e.burnUntil and "🔥" or "") .. (fleeing and "😱" or "") .. (e.shield > 0 and "🛡" or "")
			.. ((t < e.burstUntil or t < e.dashUntil) and "💨" or "") .. (t < e.inspireUntil and "🎵" or "")
		if status ~= e.status then
			e.status = status
			e.model:SetAttribute("Status", status)
		end
		e.hum.WalkSpeed = speed
		e.hum:MoveTo(target)
		e.progress = p.cum[e.i] - flat(p.pts[e.i] - pos)
		-- si aun así se atasca en algo (1.5 s sin avanzar), salta al siguiente punto del camino
		if e.progress > e.lastProg + 1 or speed < 2 or fleeing then
			e.lastProg, e.lastMove = e.progress, t
		elseif t - e.lastMove > 1.5 then
			e.root.CFrame = CFrame.new(target.X, pos.Y, target.Z)
			e.lastMove = t
		end
	end

	---------- Tropas ----------
	local WOOD = Color3.fromRGB(40, 28, 22)

	local function part(props, parent)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, false
		for k, v in props do
			p[k] = v
		end
		p.Parent = parent
		return p
	end

	-- (con la skin que su dueño tenga equipada en ese susto: solo cambia el aspecto, la tropa es la misma)
	local function buildTower(t, cf, owner)
		local m = Assets.Scares[Config.skinFor(owner, t)]:Clone()
		m.Name = t
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Hitbox" or d.Name == "Path" or d.Name == "Range" then
					d:Destroy()
				else
					d.Anchored, d.CanCollide, d.CanTouch = true, false, false
					if d:GetAttribute("T") then
						d.Transparency = d:GetAttribute("T") -- lo que en casa aparece al asustar, aquí se ve siempre
					end
				end
			elseif d:IsA("Sound") or d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		m:PivotTo(cf)
		-- lo que cuelga del techo (la luz, la araña) cuelga aquí de un poste
		if Config.Scares[t].ceiling then
			part({Name = "Poste", Size = Vector3.new(0.8, 13.6, 0.8), CFrame = cf * CFrame.new(0, 6.8, 2.4), Material = Enum.Material.Wood, Color = WOOD}, m)
			part({Name = "Brazo", Size = Vector3.new(0.6, 0.6, 3.2), CFrame = cf * CFrame.new(0, 13.3, 1.1), Material = Enum.Material.Wood, Color = WOOD}, m)
		end
		-- marca del sitio de la tropa (invisible: la peana de cada nivel la pone cada cliente, TowerDefenseUI)
		part({
			Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4.6, 4.6), CFrame = cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Neon, Color = Config.Categories[Config.Scares[t].cat].color, Transparency = 1,
		}, m)
		return m
	end

	local function syncTower(tw)
		local m = tw.model
		m:SetAttribute("Level", tw.level)
		m:SetAttribute("Spent", tw.spent)
		m:SetAttribute("Target", tw.mode)
		m:SetAttribute("Income", tw.stats.income)
	end

	local function pick(tw, list)
		local best, score
		for _, e in list do
			local s
			if tw.mode == "Last" then
				s = -e.progress
			elseif tw.mode == "Strong" then
				s = e.hp + e.shield + e.progress * 0.001
			elseif tw.mode == "Close" then
				s = -flat(e.root.Position - tw.pos)
			else
				s = e.progress
			end
			if not best or s > score then
				best, score = e, s
			end
		end
		return best
	end

	-- ¿Puede esta tropa ver (y atacar) a este cazafantasmas? Los ocultos solo los ven las que detectan o están junto a
	-- un Espejo
	local function sees(tw, e)
		return not e.def.hidden or tw.stats.detect or tw.reveal
	end

	-- Mejoras de los Espejos (support) a las tropas de su alrededor: no se acumulan, cuenta la mejor
	local function auras()
		local supports = {}
		for _, tw in match.towers do
			tw.buffDmg, tw.buffRange, tw.reveal = 0, 0, false
			if tw.stats.kind == "support" then
				table.insert(supports, tw)
			end
		end
		for _, sp in supports do
			local b = sp.stats.buff
			for _, tw in match.towers do
				if tw.stats.kind ~= "support" and flat(tw.pos - sp.pos) <= sp.stats.range then
					tw.buffDmg = math.max(tw.buffDmg, b.dmg)
					tw.buffRange = math.max(tw.buffRange, b.range)
					tw.reveal = true
				end
			end
		end
		for _, tw in match.towers do
			local buffed = tw.buffDmg > 0
			if buffed ~= (tw.buffed == true) then
				tw.buffed = buffed
				tw.model:SetAttribute("Buffed", buffed or nil)
			end
		end
	end

	local function attack(tw, t)
		local s = tw.stats
		if s.kind == "farm" or s.kind == "support" or t < (tw.disabledUntil or 0) then
			return
		end
		local range = s.range * (1 + (tw.buffRange or 0))
		local dmg = s.dmg * (1 + (tw.buffDmg or 0))
		local list = {}
		for _, e in match.enemies do
			if flat(e.root.Position - tw.pos) <= range and sees(tw, e) and (s.kind ~= "trap" or (not e.def.boss and not e.def.fly and t - e.trapped > 3)) then
				table.insert(list, e)
			end
		end
		if #list == 0 then
			-- sin nadie a quien morder, el frenesí se enfría
			if tw.frenzy and t - (tw.lastAttack or 0) > s.cd * 2.5 then
				tw.frenzy = 0
				tw.model:SetAttribute("Frenzy", nil)
			end
			return
		end
		local target = pick(tw, list)
		local hits = s.kind == "aoe" and list or {target}
		if s.kind == "splash" then
			hits = {}
			for _, e in match.enemies do
				if flat(e.root.Position - target.root.Position) <= s.splash and sees(tw, e) then
					table.insert(hits, e)
				end
			end
		end
		-- rebotes (Poltergeist): salta al más cercano que aún no haya recibido, cada vez con un 15% menos
		local chain, scale = nil, {}
		if s.chain then
			chain = {}
			local last, got = target, {[target] = true}
			for k = 1, s.chain - 1 do
				local best, bd
				for _, e in match.enemies do
					local d = flat(e.root.Position - last.root.Position)
					if not got[e] and d <= 11 and sees(tw, e) and (not best or d < bd) then
						best, bd = e, d
					end
				end
				if not best then
					break
				end
				got[best] = true
				table.insert(hits, best)
				scale[best] = 0.85 ^ k
				table.insert(chain, best.root.Position)
				last = best
			end
		end
		local k = match.speed
		-- frenesí (Hombre Lobo): cada ataque seguido, un 12% más rápido (hasta 5)
		local cd = s.cd
		if s.frenzy then
			tw.frenzy = (t - (tw.lastAttack or 0) <= s.cd * 2.5) and math.min(5, (tw.frenzy or 0) + 1) or 0
			cd *= 1 - 0.12 * tw.frenzy
			tw.model:SetAttribute("Frenzy", tw.frenzy > 0 and tw.frenzy or nil)
		end
		tw.lastAttack = t
		tw.ready = t + cd / k
		local instant = s.execute and not target.def.boss and math.random() < s.execute
		tell("Hit", tw.model, target.root.Position, instant and -1 or math.floor(dmg + 0.5), chain)
		for _, e in hits do
			local steady = e.def.steady
			if s.slow and not steady then
				e.slow, e.slowUntil = s.slow, t + s.slowTime / k
			end
			if s.stun and not steady then
				e.stunUntil = t + s.stun * (e.def.boss and 0.4 or 1) / k
			end
			if s.terrify then
				e.terrify, e.terrifyUntil = s.terrify, t + s.terrifyTime / k
			end
			if s.burn then
				-- se queda el fuego más fuerte
				if t >= e.burnUntil or s.burn.dps >= e.burnDps then
					e.burnDps, e.burnBy = s.burn.dps * (1 + (tw.buffDmg or 0)), tw
				end
				e.burnUntil = math.max(e.burnUntil, t + s.burn.time / k)
			end
			if s.flee and not steady then
				e.fleeUntil = math.max(e.fleeUntil, t + s.flee * (e.def.boss and 0.35 or 1) / k)
			end
			if s.knock then
				if not steady then
					knockBack(e, s.knock)
				end
				e.trapped = t
			elseif s.kind == "trap" then
				e.trapped = t
			end
			hurt(e, (instant and e == target) and math.huge or dmg * (scale[e] or 1), tw)
		end
	end

	---------- Partida ----------
	local function startWave(w)
		local m = match
		m.wave = w
		m.startedAt = m.startedAt or now() -- (el tiempo de la partida cuenta desde la primera oleada)
		setPhase("wave")
		m.spawnedAt = nil
		m.waveClock = 0
		local lastWave = not m.endless and w >= m.waves
		m.waveTime = lastWave and math.huge or TD.waveTime(TD.effWave(w, m.waves))
		local groups = TD.wave(w, m.count, m.waves, Z.info.roster)
		m.total = m.alive -- (los que quedan de la anterior cuentan para la barra de progreso)
		for _, g in groups do
			m.toSpawn += g[2]
			m.total += g[2]
		end
		tell("Wave", w, lastWave)
		task.spawn(function()
			for _, g in groups do
				for _ = 1, g[2] do
					if match ~= m or m.over then
						return
					end
					spawnEnemy(g[1])
					m.toSpawn -= 1
					task.wait(g[3] / m.speed)
				end
				task.wait(1 / m.speed)
			end
			if match == m and m.wave == w then
				m.spawnedAt = now() -- ya han salido todos: al poco se puede votar pasar a la siguiente
			end
		end)
	end

	-- Paga la oleada w a todos (al despejarla, o al acabarse su tiempo: timeUp)
	local function payWave(w, timeUp)
		local m = match
		local cash, coins = math.floor(waveCash(w) + 0.5), waveCoins(w)
		local bonus = timeUp and 0 or math.floor(cash * TD.CLEAR_BONUS + 0.5) -- por despejarla a tiempo
		-- los Pozos de Almas pagan a su dueño
		for _, tw in m.towers do
			if tw.stats.income and m.players[tw.owner] then
				addCash(tw.owner, tw.stats.income)
				tw.earned = (tw.earned or 0) + tw.stats.income
				tw.model:SetAttribute("Earned", tw.earned)
				tell("Income", tw.model, tw.stats.income, tw.owner)
			end
		end
		-- cada tipo de tropa desplegada gana experiencia por oleada
		local deployed = {}
		for _, tw in m.towers do
			deployed[tw.owner] = deployed[tw.owner] or {}
			deployed[tw.owner][tw.type] = true
		end
		for plr, types in deployed do
			for t in types do
				Config.addXP(plr, t, Config.XP_TD_WAVE)
			end
		end
		for plr, info in m.players do
			addCash(plr, cash + bonus)
			local stats = plr:FindFirstChild("leaderstats")
			if stats then
				stats.Coins.Value += coins
				info.coins += coins
			end
			info.gems += addAttr(plr, "Gems", Config.TD_GEMS_WAVE)
			Config.addPlayerXP(plr, Config.PXP_TD_WAVE) -- experiencia del jugador (su nivel)
			info.xp += Config.PXP_TD_WAVE
			if not timeUp then
				Misiones.add(plr, "tdWave", 1)
			end
		end
		tell("Cleared", w, cash, coins, timeUp, bonus)
	end

	local function clearWave()
		local m = match
		local w = m.wave
		payWave(w)
		if not m.endless and w >= m.waves then
			return finish(true)
		end
		setPhase("break", TD.BREAK)
	end

	function finish(won)
		local m = match
		m.over = true
		setPhase(won and "won" or "lost", 15)
		m.again, m.againCount = {}, 0
		-- ganar paga más cuanto más larga y difícil es la partida (monedas, gemas, piezas y experiencia)
		local winCoins = math.floor(TD.WIN_COINS * (0.4 + 0.6 * m.waves / 20) * diff().coins + 0.5)
		local winXP = math.floor(25 * (0.4 + 0.6 * m.waves / 20) * diff().coins + 0.5)
		for plr, info in m.players do
			local stats = plr:FindFirstChild("leaderstats")
			if won and stats then
				stats.Coins.Value += winCoins
				info.coins += winCoins
			end
			if won then
				-- ganar da gemas (más cuanto más larga la partida): se gastan en las skins de la Shop
				local gems = math.floor(Config.TD_GEMS_WIN * (0.5 + m.waves / 20) * diff().coins + 0.5)
				info.gems += addAttr(plr, "Gems", gems)
				Config.addPlayerXP(plr, winXP)
				info.xp += winXP
				Misiones.add(plr, "tdWin", 1)
			end
			-- Modo Infinito (siempre acaba al caer la casa): premio por oleadas superadas y récords
			local record, cleared = false, math.max(0, m.wave - 1)
			if m.endless then
				local gemsE = math.floor(cleared / 5) * 2
				local coinsE = math.floor(cleared * 12 * diff().coins + 0.5)
				if stats then
					stats.Coins.Value += coinsE
					info.coins += coinsE
				end
				info.gems += addAttr(plr, "Gems", gemsE)
				local key = "EB_" .. Z.id
				record = cleared > (plr:GetAttribute(key) or 0)
				if record then
					plr:SetAttribute(key, cleared)
				end
				local mapIndex = 0
				for i, info2 in TD.MAPS do
					if info2.id == Z.id then
						mapIndex = i
					end
				end
				plr:SetAttribute("EndlessRun", cleared * 100 + mapIndex) -- (Juego: récord del mes para el tablero)
			end
			-- su tropa MVP: el tipo que más miedo ha metido
			local mvp, best = nil, 0
			for t, d in info.byType do
				if d > best then
					mvp, best = t, d
				end
			end
			Remote:FireClient(plr, "End", {
				endless = m.endless == true, record = record,
				won = won, waves = won and m.wave or m.wave - 1, total = m.waves, diff = m.diff, coins = info.coins, stars = TD.stars(won, m.hp),
				kills = info.kills, damage = math.floor(info.damage), mvp = mvp, mvpDamage = math.floor(best), teamKills = m.kills,
				-- (pantalla de fin: tiempo, mapa, experiencia y gemas ganadas, piezas, vida que queda y tus tropas)
				time = math.floor(now() - (m.startedAt or now())), map = Z.name, xp = info.xp, pxp = plr:GetAttribute("PXP") or 0,
				gems = info.gems, parts = info.parts, hp = m.hp, maxHp = TD.BASE_HP, troops = TD.loadout(plr),
			})
		end
		-- los que quedan en el camino se esfuman
		for _, e in m.enemies do
			poof(e.model)
		end
		table.clear(m.enemies)
		table.clear(m.queue)
		m.alive, m.toSpawn = 0, 0
	end

	-- Fin: todos de vuelta a la explanada de los lobbies
	-- (los que votaron "Play Again" se quedan y empiezan otra en el mismo mapa con los mismos ajustes)
	local function closeMatch()
		local m = match
		match = nil
		local again = {}
		for plr in m.players do
			for _, a in {"TDCash", "TDFear", "TDKills"} do
				plr:SetAttribute(a, nil)
			end
			if plr.Parent and Z.inMap(plr) then
				if m.again and m.again[plr] then
					table.insert(again, plr)
				else
					Z.leave(plr, Z.BACK * CFrame.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 4))
				end
			end
		end
		towersF:ClearAllChildren()
		enemiesF:ClearAllChildren()
		sync()
		if #again > 0 then
			for i, plr in again do
				local char = plr.Character
				if char then
					char:PivotTo(Z.slot(i))
				end
			end
			Z.onArrive(again, {diff = m.diff, waves = m.waves, host = m.host and m.host.UserId})
		end
	end

	local function addPlayer(plr)
		local m = match
		if m.players[plr] then
			return
		end
		m.players[plr] = {coins = 0, damage = 0, kills = 0, byType = {}, gems = 0, xp = 0, parts = {}}
		m.count += 1
		Misiones.add(plr, "tdPlay", 1)
		plr:SetAttribute("TDFear", 0)
		plr:SetAttribute("TDKills", 0)
		-- quien llega tarde trae algo más para ponerse al día
		plr:SetAttribute("TDCash", TD.START_CASH + (TD.SHORT_BONUS[m.waves] or 0) + math.floor(120 * m.wave * TD.cashScale(m.waves)))
	end

	local function removePlayer(plr)
		local m = match
		m.players[plr] = nil
		m.votes[plr] = nil
		if m.again and m.again[plr] then
			m.again[plr] = nil
			m.againCount -= 1
		end
		if m.no[plr] then
			m.no[plr] = nil
			m.noCount -= 1
		end
		m.count -= 1
		for model, tw in m.towers do
			if tw.owner == plr then
				m.towers[model] = nil
				model:Destroy()
			end
		end
		if plr.Parent then
			for _, a in {"TDCash", "TDFear", "TDKills"} do
				plr:SetAttribute(a, nil)
			end
		end
		if m.host == plr then
			m.host = next(m.players) -- el anfitrión se fue: pasa a otro
		end
		if m.count <= 0 then
			closeMatch()
		end
	end

	-- settings: {diff, waves} del lobby (si ya hay partida, el grupo se une a ella con sus ajustes)
	Z.onArrive = function(group, settings)
		if match and match.over then
			closeMatch() -- la anterior ya había acabado: sus jugadores vuelven ya
		end
		if not match then
			match = {
				players = {}, count = 0, towers = {}, enemies = {}, alive = 0, toSpawn = 0, total = 0, kills = 0, wave = 0,
				hp = TD.BASE_HP, votes = {}, no = {}, noCount = 0, speed = 1, queue = {},
				diff = TD.DIFFS[settings.diff] and settings.diff or "Normal",
				waves = table.find(TD.WAVE_OPTIONS, settings.waves) and settings.waves or TD.WAVES,
				hostId = settings.host,
			}
			match.endless = TD.isEndless(match.waves)
			setPhase("setup", TD.SETUP)
		elseif settings.diff and (settings.diff ~= match.diff or settings.waves ~= match.waves) then
			for _, plr in group do
				Remote:FireClient(plr, "Error", ("Joined the match in progress: %s, %d waves"):format(match.diff, match.waves))
			end
		end
		for _, plr in group do
			addPlayer(plr)
			-- anfitrión: el del lobby (viene en los ajustes); hasta que llegue, el primero que esté
			if plr.UserId == match.hostId or not match.host then
				match.host = plr
			end
		end
		sync()
	end

	---------- Lo que piden los jugadores ----------
	local actions = {}

	local function fail(plr, why)
		Remote:FireClient(plr, "Error", why)
	end

	-- Una tropa suya de la partida
	local function mine(plr, model)
		local tw = match and match.players[plr] and not match.over and match.towers[model]
		return tw and tw.owner == plr and tw or nil
	end

	function actions.Place(plr, t, pos, rot)
		local m = match
		local troop = TD.Troops[t]
		if not (m and m.players[plr]) or m.over or not troop or typeof(pos) ~= "Vector3" or typeof(rot) ~= "number" or rot ~= rot then
			return
		end
		if not TD.owns(plr, t) then
			return fail(plr, "You don't own this scare: buy it in the Shop!")
		end
		if not table.find(TD.loadout(plr), t) then
			return fail(plr, "Equip it in your Troops loadout first")
		end
		local n, units = 0, 0
		for _, tw in m.towers do
			if tw.owner == plr then
				units += 1
				n += tw.type == t and 1 or 0
			end
		end
		if n >= TD.limit(t) then
			return fail(plr, ("Limit reached: %d %s"):format(TD.limit(t), Config.Scares[t].name))
		end
		if units >= TD.MAX_UNITS then
			return fail(plr, ("Troop limit reached: %d"):format(TD.MAX_UNITS))
		end
		local cash = plr:GetAttribute("TDCash") or 0
		if cash < troop.cost then
			return fail(plr, ("You need $%d more"):format(troop.cost - cash))
		end
		local ok, why, at = TD.canPlace(t, pos, nil, map)
		if not ok then
			return fail(plr, why)
		end
		addCash(plr, -troop.cost)
		local cf = CFrame.new(at) * CFrame.Angles(0, rot, 0)
		local model = buildTower(t, cf, plr)
		model:SetAttribute("Type", t)
		model:SetAttribute("Owner", plr.UserId)
		model:SetAttribute("OwnerName", plr.DisplayName)
		local mastery = Config.troopLevel(plr, t)
		model:SetAttribute("Mastery", mastery)
		model:SetAttribute("PlacedAt", now()) -- (los clientes la sacan del suelo de un salto)
		local tw = {
			model = model, type = t, owner = plr, level = 1, spent = troop.cost, stats = TD.stats(t, 1, mastery), mastery = mastery,
			mode = troop.target or "First", pos = at, ready = now() + 0.4, damage = 0, kills = 0,
		}
		syncTower(tw)
		m.towers[model] = tw
		model.Parent = towersF
		tell("Placed", model, plr)
		Misiones.add(plr, "tdPlace", 1)
	end

	function actions.Upgrade(plr, model)
		local tw = mine(plr, model)
		if not tw or tw.level >= TD.MAX_LEVEL then
			return
		end
		local cost = TD.upgradeCost(tw.type, tw.level)
		local cash = plr:GetAttribute("TDCash") or 0
		if cash < cost then
			return fail(plr, ("You need $%d more"):format(cost - cash))
		end
		addCash(plr, -cost)
		tw.level += 1
		tw.spent += cost
		tw.stats = TD.stats(tw.type, tw.level, tw.mastery)
		syncTower(tw)
		tell("Upgraded", model, tw.level)
	end

	function actions.Sell(plr, model)
		local tw = mine(plr, model)
		if not tw then
			return
		end
		match.towers[model] = nil
		addCash(plr, TD.sellValue(tw.spent))
		tell("Sold", tw.pos, TD.sellValue(tw.spent), plr)
		-- ya no cuenta ni ataca; los clientes la ven girar y encogerse antes de que desaparezca
		model:SetAttribute("Sold", true)
		task.delay(0.6, model.Destroy, model)
	end

	-- mode: uno de TD.TARGETS; sin él, el siguiente
	function actions.Target(plr, model, mode)
		local tw = mine(plr, model)
		if tw then
			tw.mode = table.find(TD.TARGETS, mode) and mode or TD.TARGETS[(table.find(TD.TARGETS, tw.mode) or 0) % #TD.TARGETS + 1]
			syncTower(tw)
		end
	end

	-- Velocidad x1 / x2 para todo el equipo (solo el anfitrión)
	function actions.Speed(plr)
		local m = match
		if m and m.players[plr] and not m.over and m.host == plr then
			m.speed = m.speed == 1 and 2 or 1
			tell("Speed", m.speed, plr.DisplayName)
		end
	end

	-- "Leave" del HUD: de vuelta a la explanada de los lobbies
	function actions.Leave(plr)
		Z.leave(plr, Z.BACK * CFrame.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 4))
	end

	function actions.Skip(plr)
		local m = match
		if m and m.players[plr] and (m.phase == "setup" or m.phase == "break" or m.canSkip) then
			m.votes[plr] = true
			if m.no[plr] then
				m.no[plr] = nil
				m.noCount -= 1
			end
		end
	end

	-- "No" en el voto de saltar: solo cuenta para el marcador (la espera sigue su curso)
	function actions.SkipNo(plr)
		local m = match
		if m and m.players[plr] and (m.phase == "break" or m.canSkip) and not m.votes[plr] and not m.no[plr] then
			m.no[plr] = true
			m.noCount += 1
		end
	end

	-- "Play Again" en los resultados: se queda para otra partida; si votan todos, empieza ya
	function actions.Again(plr)
		local m = match
		if m and m.players[plr] and m.over and m.again and not m.again[plr] then
			m.again[plr] = true
			m.againCount += 1
			if m.againCount >= m.count then
				m.nextAt = math.min(m.nextAt, now() + 1.2)
			end
		end
	end

	-- "Auto skip": entre oleadas vota solo por ti
	function actions.AutoSkip(plr)
		if match and match.players[plr] then
			plr:SetAttribute("TDAuto", not plr:GetAttribute("TDAuto") or nil)
		end
	end

	-- todos los mapas escuchan TDRemote: cada uno atiende solo a sus jugadores
	Remote.OnServerEvent:Connect(function(plr, action, ...)
		local f = actions[action]
		if f and Z.inMap(plr) then
			f(plr, ...)
		end
	end)

	---------- Bucle ----------
	local last = now()
	local function tick()
		local m = match
		local t = now()
		local dt = t - last
		last = t
		if not m then
			return
		end
		for plr in m.players do
			if not (plr.Parent and Z.inMap(plr)) then
				removePlayer(plr) -- se fue por el portal, a su casa, murió o salió del juego
			end
		end
		if match ~= m then
			return
		end
		if m.phase == "wave" then
			m.waveClock += dt * m.speed
			auras()
			for _, e in m.enemies do
				if m.over then
					break
				end
				move(e, t, dt * m.speed)
			end
			for _, tw in m.towers do
				if m.over then
					break
				end
				if t >= tw.ready then
					attack(tw, t)
				end
			end
			-- los que han llamado o dejado otros cazafantasmas (no se puede añadir mientras se recorre m.enemies)
			for _, q in m.queue do
				if not m.over then
					spawnEnemy(q[1], q[2])
				end
			end
			table.clear(m.queue)
			-- (no en la última: no hay siguiente)
			m.canSkip = m.spawnedAt ~= nil and (m.endless or m.wave < m.waves) and t >= m.spawnedAt + TD.SKIP_DELAY / m.speed
			if not m.over and m.toSpawn == 0 and m.alive == 0 then
				clearWave()
			elseif not m.over and m.canSkip and countVotes(m) >= m.count // 2 + 1 then
				-- votaron pasar: cobran la oleada (sin bonus de despejarla) y llega la siguiente con estos aún en el camino
				payWave(m.wave, true)
				startWave(m.wave + 1)
			elseif not m.over and m.toSpawn == 0 and m.waveClock >= m.waveTime then
				-- se acabó el tiempo: cobran la oleada y llega la siguiente (los que quedan siguen en el camino)
				payWave(m.wave, true)
				startWave(m.wave + 1)
			end
		elseif m.phase == "setup" or m.phase == "break" then
			if t >= m.nextAt or countVotes(m) >= m.count // 2 + 1 then
				startWave(m.wave + 1)
			end
		elseif t >= m.nextAt then
			closeMatch() -- "won" / "lost": tras la pantalla de resultados
			return
		end
		sync()
	end

	sync()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(tick)
			if not ok then
				warn("Tower Defense (" .. Z.id .. "): " .. tostring(err))
			end
		end
	end)
end
