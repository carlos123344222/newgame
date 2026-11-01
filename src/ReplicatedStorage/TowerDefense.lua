-- Tower Defense (compartido por servidor y cliente): tus sustos son las tropas. Cada susto que tienes (en la mochila
-- o colocado en tu casa) se puede desplegar en los mapas (TD.MAPS). Su "daño" es miedo: los cazafantasmas que llegan
-- por el camino huyen al llenarse su barra de miedo. En el lobby el anfitrión elige mapa, dificultad y oleadas.
-- Para equilibrar el modo, toca aquí.
local Players = game:GetService("Players")

local Config = require(script.Parent:WaitForChild("Config"))

local TD = {}

TD.START_CASH = 750
TD.BASE_HP = 100
TD.WAVES = 20
TD.SETUP = 25 -- segundos para colocar antes de la primera oleada
TD.BREAK = 8 -- descanso entre oleadas (se puede saltar votando)
TD.SKIP_DELAY = 3 -- s tras salir el último cazafantasmas de una oleada hasta que se puede votar pasar a la siguiente
TD.MAX_LEVEL = 4
TD.SELL = 0.6 -- al vender recuperas esto de lo gastado (compra + mejoras)
TD.SPACING = 3.5 -- distancia mínima entre tropas
-- Dificultad según los jugadores: en solitario los cazafantasmas aguantan menos (SOLO_HP); cada jugador extra les suma
-- PER_PLAYER_HP de valor y PER_PLAYER_COUNT más cazafantasmas normales por oleada. Las primeras oleadas lo aplican poco
-- a poco (TD.ramp). Cada jugador cobra TODO (oleadas y bajas, como si jugara solo), así que el grupo tiene el doble,
-- triple... de dinero: con estos valores, contando también el dinero extra de las bajas de más, cada persona tiene una
-- partida un poco más difícil que en solitario: ~x1.15 con 2, ~x1.27 con 3 y ~x1.35 con 4.
-- (Antes era 1.25 y 0.35: con 2 jugadores, ~x1.6 por persona, casi el doble de difícil)
TD.SOLO_HP = 0.7
TD.PER_PLAYER_HP = 0.73
TD.PER_PLAYER_COUNT = 0.3
TD.DIFFICULTY = {"Normal", "Hard", "Brutal", "Nightmare"} -- nombre según los jugadores (1, 2, 3, 4+)
TD.WIN_COINS = 600 -- monedas del juego por ganar (además de las de cada oleada)
TD.LIMIT = {Basico = 8, Criatura = 6, Trampa = 4, Legendario = 2} -- tropas de cada tipo por jugador (o troop.limit)
TD.TARGETS = {"First", "Last", "Strong", "Close"}
TD.TIERS = {"Spooky", "Creepy", "Terrifying", "Nightmare"} -- nombre de cada nivel
TD.SLOTS = 6 -- tropas en el equipo (loadout)
TD.MAX_UNITS = 30 -- tropas colocadas a la vez por jugador, de cualquier tipo (como en TDS)
TD.CLEAR_BONUS = 0.25 -- despejar la oleada antes de que se acabe su tiempo paga este extra ("Wave Clear Bonus")

-- Mapas. Viven en ServerStorage.MapasTD (modelo + su terreno) y solo se cargan en el servidor privado de cada partida
-- (TDMaps). roster: qué cazafantasmas salen (TD.wave). diffs: dificultades en las que puede salir en los lobbies
-- (índices de TD.DIFF_ORDER, de-a). Lo demás es para las pantallas: image (miniatura), length (camino), hunters
-- (tipos), color, new. hp: vida de sus cazafantasmas (TD.diffHp), para que todos cuesten lo mismo. Para añadir un mapa: un modelo con ese id (atributos Origin, Bounds, Spawn, PathWidth y las
-- carpetas Camino, MapaTDS y ReturnPortal) guardado con TDMaps.store, y una entrada aquí.
TD.MAPS = {
	{
		id = "ZombieHollow", name = Config.TD_MAP_NAME, hp = 1.75, roster = "classic", image = "rbxassetid://76157362522642",
		diffs = {1, 4}, length = "Medium", hunters = 6, color = Color3.fromRGB(255, 150, 40),
		info = "Pumpkin paths and zombie crypts. The classic ghost hunters.",
		light = {ClockTime = 16.9, Brightness = 3.2, Ambient = Color3.fromRGB(128, 118, 116), OutdoorAmbient = Color3.fromRGB(172, 154, 142), ExposureCompensation = 0.5,
			atmos = {Color = Color3.fromRGB(214, 150, 112), Decay = Color3.fromRGB(110, 64, 56), Density = 0.26, Haze = 1.4, Glare = 0.5}, grade = {Saturation = 0.12, Contrast = 0.12, TintColor = Color3.fromRGB(255, 242, 230)}},
	},
	{
		id = "CursedCarnival", name = "Cursed Carnival", hp = 1.45, roster = "carnival", image = "rbxassetid://117051126901478",
		diffs = {2, 5}, length = "Long", hunters = 14, color = Color3.fromRGB(255, 72, 150),
		info = "A haunted fair: healers, shields, jetpacks, splitters and the Ringmaster.",
		light = {ClockTime = 17.9, Brightness = 2.6, Ambient = Color3.fromRGB(138, 112, 150), OutdoorAmbient = Color3.fromRGB(180, 146, 186), ExposureCompensation = 0.45,
			atmos = {Color = Color3.fromRGB(200, 130, 170), Decay = Color3.fromRGB(110, 56, 110), Density = 0.24, Haze = 1.2, Glare = 0.3}, grade = {Saturation = 0.2, Contrast = 0.12, TintColor = Color3.fromRGB(255, 240, 248)}},
	},
	{
		id = "CursedCastle", name = "Cursed Castle", hp = 0.6, roster = "castle", image = "rbxassetid://114161917563536",
		diffs = {1, 5}, length = "Long", hunters = 11, color = Color3.fromRGB(120, 150, 255),
		info = "Peasants with pitchforks, knights, paladins and King Aldric storm the castle.",
		light = {ClockTime = 16.6, Brightness = 3, Ambient = Color3.fromRGB(128, 126, 140), OutdoorAmbient = Color3.fromRGB(160, 158, 176), ExposureCompensation = 0.4,
			atmos = {Color = Color3.fromRGB(176, 168, 196), Decay = Color3.fromRGB(96, 86, 130), Density = 0.24, Haze = 1.1, Glare = 0.3}, grade = {Saturation = 0.12, Contrast = 0.12, TintColor = Color3.fromRGB(246, 242, 255)}},
	},
	{
		id = "WitchBayou", name = "Witch Bayou", hp = 0.75, roster = "hunters", image = "rbxassetid://94574438656968",
		diffs = {2, 5}, length = "Long", hunters = 9, color = Color3.fromRGB(110, 230, 120),
		info = "Monster hunters wade through the swamp. Beware hidden rangers and lantern trackers!",
		light = {ClockTime = 16.8, Brightness = 2.8, Ambient = Color3.fromRGB(122, 140, 120), OutdoorAmbient = Color3.fromRGB(156, 178, 150), ExposureCompensation = 0.45,
			atmos = {Color = Color3.fromRGB(150, 176, 140), Decay = Color3.fromRGB(70, 96, 70), Density = 0.24, Haze = 1.2, Glare = 0.2}, grade = {Saturation = 0.14, Contrast = 0.12, TintColor = Color3.fromRGB(244, 255, 240)}},
	},
	{
		id = "FrozenPeak", name = "Frozen Peak", hp = 0.6, roster = "adventurers", image = "rbxassetid://122926275069292",
		diffs = {3, 6}, length = "Medium", hunters = 8, color = Color3.fromRGB(130, 220, 255),
		info = "An icy expedition: rogues, dwarves, wizards and the Archmage climb the mountain.",
		light = {ClockTime = 17.2, Brightness = 2.4, Ambient = Color3.fromRGB(150, 168, 204), OutdoorAmbient = Color3.fromRGB(176, 194, 230), ExposureCompensation = 0.3,
			atmos = {Color = Color3.fromRGB(170, 196, 230), Decay = Color3.fromRGB(110, 130, 190), Density = 0.36, Haze = 1.6, Glare = 0.2}, grade = {Saturation = -0.05, Contrast = 0.08, TintColor = Color3.fromRGB(232, 244, 255)}},
	},
	{
		id = "FallenCathedral", name = "Fallen Cathedral", hp = 0.6, roster = "heroes", image = "rbxassetid://125274230259132",
		diffs = {3, 6}, length = "Long", hunters = 9, color = Color3.fromRGB(255, 205, 90),
		info = "The legendary heroes have come: clerics, bards, valkyries and the Chosen One.",
		light = {ClockTime = 17.9, Brightness = 2.2, Ambient = Color3.fromRGB(150, 120, 150), OutdoorAmbient = Color3.fromRGB(190, 150, 170), ExposureCompensation = 0.45,
			atmos = {Color = Color3.fromRGB(170, 120, 140), Decay = Color3.fromRGB(110, 60, 90), Density = 0.3, Haze = 1.3, Glare = 0.4}, grade = {Saturation = 0.12, Contrast = 0.1, TintColor = Color3.fromRGB(255, 240, 230)}},
	},
	---------- Nuevos ----------
	{
		id = "ScarecrowFields", name = "Scarecrow Fields", hp = 1.4, roster = "farm", image = "rbxassetid://135678000996214",
		diffs = {1, 3}, length = "Medium", hunters = 8, color = Color3.fromRGB(255, 176, 60), new = true,
		info = "A haunted harvest: farmers with torches, trappers and the Exorcist cross the pumpkin fields.",
		light = {ClockTime = 17.5, Brightness = 2.5, Ambient = Color3.fromRGB(150, 118, 104), OutdoorAmbient = Color3.fromRGB(190, 146, 120), ExposureCompensation = 0.4,
			atmos = {Color = Color3.fromRGB(190, 130, 90), Decay = Color3.fromRGB(110, 60, 50), Density = 0.3, Haze = 1.6, Glare = 0.3}, grade = {Saturation = 0.18, Contrast = 0.1, TintColor = Color3.fromRGB(255, 236, 214)}},
	},
	{
		id = "GhostHarbor", name = "Ghost Harbor", hp = 0.75, roster = "harbor", image = "rbxassetid://85724627000105",
		diffs = {1, 4}, length = "Long", hunters = 10, color = Color3.fromRGB(70, 210, 200), new = true,
		info = "Smugglers, jetpack raiders and monster slayers land at the foggy docks of the lighthouse.",
		light = {ClockTime = 18.5, Brightness = 2.2, Ambient = Color3.fromRGB(110, 140, 152), OutdoorAmbient = Color3.fromRGB(132, 168, 180), ExposureCompensation = 0.55,
			atmos = {Color = Color3.fromRGB(130, 160, 170), Decay = Color3.fromRGB(60, 86, 104), Density = 0.27, Haze = 1.3, Glare = 0}, grade = {Saturation = 0.05, Contrast = 0.12, TintColor = Color3.fromRGB(226, 246, 255)}},
	},
	{
		id = "BloodMoonCemetery", name = "Blood Moon Cemetery", hp = 0.85, roster = "graveyard", image = "rbxassetid://86699290511829",
		diffs = {2, 5}, length = "Long", hunters = 10, color = Color3.fromRGB(255, 60, 70), new = true,
		info = "Under the blood moon, priests, witch hunters and the Grand Inquisitor raid the mausoleum.",
		light = {ClockTime = 17.6, Brightness = 2.6, Ambient = Color3.fromRGB(140, 112, 120), OutdoorAmbient = Color3.fromRGB(176, 136, 140), ExposureCompensation = 0.5,
			atmos = {Color = Color3.fromRGB(196, 120, 126), Decay = Color3.fromRGB(110, 46, 64), Density = 0.22, Haze = 1, Glare = 0.3}, grade = {Saturation = 0.12, Contrast = 0.14, TintColor = Color3.fromRGB(255, 234, 234)}},
	},
	{
		id = "VoidcoreRift", name = "Voidcore Rift", hp = 0.37, roster = "void", image = "rbxassetid://134895993254780",
		diffs = {4, 6}, length = "Long", hunters = 12, color = Color3.fromRGB(190, 90, 255), new = true,
		info = "The elite of every hunter guild storms the Void Heart. Only for the bravest.",
		light = {ClockTime = 0, Brightness = 1.5, Ambient = Color3.fromRGB(170, 128, 186), OutdoorAmbient = Color3.fromRGB(192, 140, 208), ExposureCompensation = 0.8,
			atmos = {Color = Color3.fromRGB(96, 40, 112), Decay = Color3.fromRGB(44, 12, 56), Density = 0.34, Haze = 0.8, Glare = 0}, grade = {Saturation = 0.2, Contrast = 0.14, TintColor = Color3.fromRGB(240, 226, 255)}},
	},
}
function TD.mapInfo(id)
	for _, m in TD.MAPS do
		if m.id == id then
			return m
		end
	end
	return nil
end
-- El mapa en el que está jugando (atributo TDMap)
function TD.mapOf(plr)
	local id = plr:GetAttribute("TDMap")
	return id and workspace:FindFirstChild(id) or nil
end

-- Las 6 dificultades (se suman a la de los jugadores): vida y velocidad de los cazafantasmas, dinero de partida y
-- monedas del juego al acabar. Cada lobby muestra un mapa en una de sus dificultades (TD.MAPS[i].diffs).
TD.DIFF_ORDER = {"Easy", "Normal", "Hard", "Insane", "Nightmare", "Apocalypse"}
TD.DIFFS = {
	Easy = {hp = 0.35, speed = 0.9, cash = 1.3, coins = 0.75, color = Color3.fromRGB(96, 230, 120), desc = "Much weaker, slower hunters · +30% cash · x0.75 coins"},
	Normal = {hp = 0.7, speed = 1, cash = 1, coins = 1, color = Color3.fromRGB(70, 176, 255), desc = "The intended challenge · x1 coins"},
	Hard = {hp = 1.12, speed = 1.05, cash = 0.95, coins = 1.4, color = Color3.fromRGB(255, 200, 50), desc = "Tougher, faster hunters · x1.4 coins"},
	Insane = {hp = 1.35, speed = 1.1, cash = 0.9, coins = 2, color = Color3.fromRGB(255, 120, 40), desc = "Relentless hunters · x2 coins"},
	Nightmare = {hp = 1.55, speed = 1.15, cash = 0.85, coins = 2.8, color = Color3.fromRGB(180, 70, 255), desc = "Only for the bravest · x2.8 coins"},
	Apocalypse = {hp = 1.85, speed = 1.22, cash = 0.8, coins = 4, color = Color3.fromRGB(235, 30, 50), desc = "The end of all haunts · x4 coins"},
}
for i, d in TD.DIFF_ORDER do
	TD.DIFFS[d].tier = i
end
-- Vida de los cazafantasmas por la dificultad y el mapa en la oleada e (equivalente de 20). Lo que la dificultad suma
-- por encima de x1 entra poco a poco (40% en la 1, entero desde la 11): las difíciles aprietan al final, no en el
-- arranque, cuando aún no hay dinero. Cada mapa iguala lo duro que es su camino y sus cazafantasmas (TD.MAPS[i].hp):
-- así una dificultad cuesta lo mismo en cualquier mapa. Las partidas cortas llegan a su jefe con mucho menos dinero:
-- sus cazafantasmas aguantan menos (SHORT_HP) para que 5 o 10 oleadas cuesten lo mismo que 20.
TD.SHORT_HP = {[5] = 0.4, [10] = 0.55}
function TD.diffHp(name, e, mapId, waves)
	local hp = (TD.DIFFS[name] or TD.DIFFS.Normal).hp
	if hp > 1 then
		hp = 1 + (hp - 1) * math.min(1, 0.4 + 0.06 * (e - 1))
	end
	local info = TD.mapInfo(mapId)
	return hp * (info and info.hp or 1) * (TD.SHORT_HP[waves] or 1)
end
TD.ROTATE = 60 -- segundos que un lobby vacío enseña el mismo mapa antes de cambiar

-- Dificultades en las que puede salir un mapa
function TD.mapDiffs(info)
	local list = {}
	for i = info.diffs[1], info.diffs[2] do
		table.insert(list, TD.DIFF_ORDER[i])
	end
	return list
end
-- Si la oleada no se ha despejado cuando se acaba su tiempo (segundos a x1), empieza la siguiente igualmente (como en
-- TDS: los que quedan siguen en el camino). La última oleada no tiene tiempo: hay que asustarlos a todos.
function TD.waveTime(e)
	return 55 + 2.5 * e
end
-- Oleadas a elegir. Las partidas cortas comprimen la curva: la oleada w equivale a la TD.effWave(w) de una de 20
-- (5 oleadas llegan hasta la 10, 10 hasta la 15) y pagan más por oleada (TD.cashScale) y más dinero inicial.
-- TD.ENDLESS (0): Modo Infinito. Oleadas sin fin: la oleada w es la w (sin comprimir), desde la 20 salen más y más
-- fuertes (TD.endlessHp), cada 10 llega el jefe final del mapa y la partida acaba cuando cae la casa: cuenta la
-- oleada a la que llegas (récord por mapa: atributo EB_<mapa> del jugador; el del mes, el tablero Endless Legends).
TD.ENDLESS = 0
TD.WAVE_OPTIONS = {5, 10, 20, TD.ENDLESS}
local TOP = {[5] = 10, [10] = 15, [20] = 20}
TD.SHORT_BONUS = {[5] = 400, [10] = 200}
function TD.isEndless(waves)
	return waves == TD.ENDLESS
end
-- "20", "∞": cómo se escribe el número de oleadas
function TD.wavesText(waves)
	return waves == TD.ENDLESS and "∞" or tostring(waves)
end
-- vida extra de los cazafantasmas del Modo Infinito a partir de la 20 (x1.055 por oleada; antes x1.045 y se llegaba
-- sin problemas a la 40-50). Con los que salen de más (TD.ENDLESS_MORE): en la 40, ~x1.25 que antes; en la 50, ~x1.4.
TD.ENDLESS_HP = 1.055
TD.ENDLESS_MORE = 0.065 -- (antes 0.06)
function TD.endlessHp(w)
	return TD.ENDLESS_HP ^ math.max(0, w - 20)
end
function TD.effWave(w, waves)
	if waves == TD.ENDLESS then
		return w
	end
	local top = TOP[waves] or waves
	if waves <= 1 then
		return top
	end
	return math.floor(1 + (w - 1) * (top - 1) / (waves - 1) + 0.5)
end
function TD.cashScale(waves)
	if waves == TD.ENDLESS then
		return 1
	end
	return math.max(1, ((TOP[waves] or waves) - 1) / math.max(1, waves - 1))
end

-- kind: single (un objetivo) | aoe (todos en rango) | splash (objetivo y alrededor) | trap (sobre el camino)
--   | farm (no ataca: paga income al acabar cada oleada) | support (no ataca: mejora a las tropas de su alrededor)
-- dmg: miedo por golpe. cd: segundos entre ataques. range: alcance. sound: plantilla de Assets.Sounds.
-- Extras: detect (ve a los ocultos), burn {dps, time} (miedo por segundo), chain (salta a N), flee (segundos huyendo
-- hacia atrás), frenzy (cada ataque seguido -12% de espera, hasta 5), drain (vida que recupera la casa por baja),
-- buff {dmg, range} (support), income (farm, $ por oleada en el nivel 1), limit (máximo propio), fx (efecto del
-- cliente: bolt, lob, bats, chain, breath, wail, claw, drain, fire) e idle (animación en reposo: float, orbit, sway).
TD.Troops = {
	Armario = {cost = 200, dmg = 16, cd = 1.2, range = 15, kind = "single", sound = "Slam", info = "Bursts open on one ghost hunter at a time."},
	Luz = {cost = 150, dmg = 5, cd = 1, range = 12, kind = "aoe", slow = 0.35, slowTime = 1.2, detect = true, sound = "Flicker", info = "Flickers over everyone in range: -35% speed. Its light reveals hidden hunters."},
	Gramofono = {cost = 300, dmg = 12, cd = 1.1, range = 13, kind = "aoe", sound = "MusicBox", info = "Its creepy lullaby scares everyone in range."},
	Fantasma = {cost = 350, dmg = 11, cd = 0.6, range = 15, kind = "single", sound = "Wail", info = "Fast and relentless: almost two scares per second."},
	Muneca = {cost = 500, dmg = 60, cd = 2.5, range = 24, kind = "single", target = "Strong", sound = "DollScream", info = "Long range. Screams at the bravest hunter."},
	Sombra = {cost = 450, dmg = 12, cd = 1.2, range = 14, kind = "aoe", terrify = 0.35, terrifyTime = 2.5, detect = true, sound = "Deep", info = "Terrifies everyone in range: +35% fear taken. Sees hidden hunters."},
	Arana = {cost = 550, dmg = 30, cd = 1.6, range = 14, kind = "single", stun = 0.9, sound = "Hop", info = "Drops on a hunter and freezes them in place."},
	Trampilla = {cost = 400, dmg = 45, cd = 3.5, range = 3.5, kind = "trap", knock = 22, sound = "WoodBreak", info = "Goes ON the path: drops a hunter 22 studs back."},
	Ataud = {cost = 650, dmg = 55, cd = 2, range = 16, kind = "splash", splash = 7, sound = "Slam", info = "A skeleton bursts out: splash fear around the target."},
	Payaso = {cost = 1200, dmg = 45, cd = 1, range = 20, kind = "splash", splash = 6, sound = "Laugh", info = "Its laugh splashes fear on whole groups."},
	Zombie = {cost = 1500, dmg = 130, cd = 1.8, range = 15, kind = "single", stun = 0.4, sound = "ZombieGroan", info = "Huge bites that stun the target."},
	Parca = {cost = 2200, dmg = 110, cd = 1.4, range = 24, kind = "single", execute = 0.12, detect = true, sound = "Whoosh", info = "12% chance to scare a hunter away instantly (not bosses). Sees hidden hunters."},
	---------- Nuevas ----------
	Murcielagos = {cost = 275, dmg = 6, cd = 0.38, range = 13, kind = "single", fx = "bats", idle = "orbit", sound = "Swoosh", info = "A swarm of bats that nibbles hunters: super fast attacks."},
	Calabaza = {cost = 350, dmg = 22, cd = 2, range = 19, kind = "splash", splash = 6, fx = "lob", color = Color3.fromRGB(255, 140, 30), sound = "Boom", info = "Lobs exploding jack-o'-lanterns over walls: splash fear."},
	Cuervo = {cost = 325, dmg = 26, cd = 2.2, range = 30, kind = "single", detect = true, fx = "bolt", idle = "sway", sound = "Whoosh", info = "Huge range. Its sharp eyes spot hidden hunters."},
	Velas = {cost = 300, dmg = 4, cd = 1.4, range = 11, kind = "aoe", burn = {dps = 4, time = 3}, fx = "fire", color = Color3.fromRGB(255, 170, 60), sound = "Flicker", info = "Cursed fire for everyone in range: burns over time."},
	Espantapajaros = {cost = 600, dmg = 10, cd = 1.3, range = 16, kind = "aoe", slow = 0.25, slowTime = 1.5, detect = true, idle = "sway", sound = "Growl", info = "Its crows spot hidden hunters. Slows everyone around: -25% speed."},
	Bruja = {cost = 800, dmg = 20, cd = 1.7, range = 18, kind = "splash", splash = 7, burn = {dps = 10, time = 3}, fx = "lob", color = Color3.fromRGB(120, 255, 90), sound = "Laugh", info = "Hurls bubbling potions: splash fear and poison."},
	Banshee = {cost = 950, dmg = 14, cd = 2.6, range = 15, kind = "aoe", flee = 1.3, fx = "wail", idle = "float", sound = "Wail", info = "Her wail sends everyone in range running back in terror."},
	Momia = {cost = 700, dmg = 40, cd = 1.8, range = 15, kind = "single", stun = 1.2, slow = 0.4, slowTime = 2, fx = "wrap", sound = "Growl", info = "Wraps a hunter in bandages: long stun, then slowed."},
	Poltergeist = {cost = 900, dmg = 24, cd = 1.2, range = 17, kind = "single", chain = 4, fx = "chain", color = Color3.fromRGB(190, 110, 255), idle = "float", sound = "Swoosh", info = "Flings haunted objects that bounce between 4 hunters."},
	Manos = {cost = 450, dmg = 30, cd = 3, range = 3.5, kind = "trap", stun = 2, fx = "hands", sound = "DirtBurst", info = "Goes ON the path: hands burst out and hold hunters in place."},
	Pozo = {cost = 600, dmg = 0, cd = 999, range = 0, kind = "farm", income = 100, limit = 3, idle = "souls", sound = "Sparkle", info = "Earns cash for you after every wave. Upgrade it to earn more!"},
	Espejo = {cost = 700, dmg = 0, cd = 999, range = 14, kind = "support", buff = {dmg = 0.2, range = 0.1}, limit = 2, sound = "Sparkle", info = "Troops in range: +20% fear, +10% range, and they see hidden hunters."},
	HombreLobo = {cost = 2800, dmg = 85, cd = 1.1, range = 14, kind = "single", frenzy = true, fx = "claw", sound = "Growl", info = "Every bite makes it faster: up to +60% attack speed."},
	Vampiro = {cost = 3200, dmg = 120, cd = 1.5, range = 20, kind = "single", drain = 1, detect = true, fx = "drain", idle = "float", sound = "Deep", info = "Each hunter it scares away heals the house +1 HP. Sees hidden hunters."},
	Jinete = {cost = 3600, dmg = 70, cd = 1.6, range = 26, kind = "splash", splash = 9, burn = {dps = 20, time = 3}, fx = "lob", color = Color3.fromRGB(255, 110, 20), sound = "Laugh", info = "Hurls flaming pumpkin heads: huge splash that sets hunters on fire."},
	Dragon = {cost = 5000, dmg = 60, cd = 0.9, range = 22, kind = "splash", splash = 10, burn = {dps = 30, time = 3}, detect = true, fx = "breath", color = Color3.fromRGB(110, 255, 140), idle = "float", sound = "Growl", info = "Breathes ghost fire: massive splash and burn. Sees hidden hunters."},
	---------- Personajes ----------
	HombreCalabaza = {cost = 375, dmg = 18, cd = 1.5, range = 14, kind = "single", stun = 0.5, fx = "wrap", idle = "sway", sound = "Laugh", info = "Lashes its vines at a hunter: short stun."},
	Esqueleto = {cost = 650, dmg = 26, cd = 1.4, range = 18, kind = "splash", splash = 5, burn = {dps = 6, time = 2}, fx = "lob", color = Color3.fromRGB(120, 255, 140), sound = "Laugh", info = "Throws its own flaming skull: splash fear and ghost fire."},
	Frankenstein = {cost = 3000, dmg = 60, cd = 1.5, range = 17, kind = "single", chain = 3, stun = 0.5, fx = "chain", color = Color3.fromRGB(150, 200, 255), sound = "Flicker", info = "Tesla coils zap a hunter and arc to 3 more, stunning them."},
	Demonio = {cost = 4400, dmg = 95, cd = 1.6, range = 22, kind = "splash", splash = 9, burn = {dps = 26, time = 3}, detect = true, fx = "lob", color = Color3.fromRGB(255, 110, 30), sound = "Growl", info = "Hurls hellfire orbs: huge splash and burn. Sees hidden hunters."},
}
-- Las que no nacen viendo a los ocultos aprenden a verlos al mejorarlas hasta este nivel (las baratas, más tarde)
TD.DETECT_AT = {
	Armario = 3, Gramofono = 3, Velas = 3, Murcielagos = 2, Calabaza = 3, HombreCalabaza = 3,
	Fantasma = 2, Muneca = 2, Esqueleto = 3, Momia = 3, Arana = 3, Bruja = 3, Poltergeist = 2, Banshee = 2,
	Trampilla = 4, Manos = 4, Ataud = 3,
	Payaso = 2, Zombie = 2, HombreLobo = 2, Frankenstein = 2, Jinete = 2,
}
for t, lv in TD.DETECT_AT do
	TD.Troops[t].detectAt = lv
end

-- Los cazafantasmas (bots visitantes con sus animaciones de miedo). hp = valor: miedo que aguantan.
-- cash: dinero de partida para cada jugador al asustarlo. leak: vida que quitan a la casa si llegan.
TD.Enemies = {
	visitor = {name = "Ghost Hunter", hp = 40, speed = 10, cash = 8, leak = 5, scale = 1, shirt = Color3.fromRGB(60, 120, 200)},
	kid = {name = "Brave Kid", hp = 24, speed = 15, cash = 6, leak = 4, scale = 0.82, shirt = Color3.fromRGB(240, 130, 40)},
	brave = {name = "Skeptic", hp = 150, speed = 8, cash = 16, leak = 10, scale = 1.15, shirt = Color3.fromRGB(70, 160, 80)},
	golden = {name = "Golden Visitor", hp = 90, speed = 13, cash = 75, leak = 8, scale = 1, shirt = Color3.fromRGB(255, 196, 50), golden = true},
	hunter = {name = "Paranormal Expert", hp = 450, speed = 7, cash = 120, leak = 15, scale = 1.3, shirt = Color3.fromRGB(196, 150, 80), pants = Color3.fromRGB(150, 110, 54), boss = true, gear = {"Paranormal"}}, -- (modelo: Blender)
	boss = {name = "The Exorcist", hp = 1600, speed = 5.5, cash = 500, leak = 50, scale = 1.7, shirt = Color3.fromRGB(24, 22, 28), pants = Color3.fromRGB(24, 22, 28), boss = true, gear = {"Exorcist"}}, -- (modelo: Blender)
	-- Cursed Carnival. Habilidades: armor (parte del miedo que no les afecta), shield (escudo extra, en fracción de la
	-- vida), heal (cura a los de alrededor), regen (vida por segundo), split (al huir salen otros), steady (inmunes a
	-- ralentizar, aturdir y trampillas), burst (acelera al asustarse), fly (vuelan: las trampillas no les afectan),
	-- summon (llama a más). gear: complementos que llevan puestos (Outfits).
	vlogger = {name = "Vlogger", icon = "⚡", hp = 30, speed = 17, cash = 7, leak = 4, scale = 0.9, shirt = Color3.fromRGB(230, 60, 150), gear = {"cap", "camera"}},
	juggler = {name = "Juggler", icon = "💨", hp = 60, speed = 11, cash = 10, leak = 5, scale = 0.95, shirt = Color3.fromRGB(250, 200, 40), pants = Color3.fromRGB(150, 40, 200), gear = {"jester"}, burst = {mult = 1.9, time = 1.4, cd = 4}},
	dad = {name = "Tourist Dad", icon = "👪", hp = 120, speed = 9, cash = 14, leak = 8, scale = 1.1, shirt = Color3.fromRGB(40, 190, 170), gear = {"sunhat", "camera"}, split = {kind = "kid", n = 2}},
	medium = {name = "Psychic Medium", icon = "💚", hp = 110, speed = 8.5, cash = 22, leak = 8, scale = 1, shirt = Color3.fromRGB(110, 50, 160), gear = {"scarf", "robe"}, heal = {radius = 13, amount = 0.12, cd = 3}},
	jetpack = {name = "Jetpack Hunter", icon = "🚀", hp = 90, speed = 12, cash = 16, leak = 7, scale = 1, shirt = Color3.fromRGB(80, 90, 110), gear = {"helmet", "jetpack"}, fly = true},
	priest = {name = "Exorcist Priest", icon = "✝", hp = 160, speed = 7.5, cash = 24, leak = 10, scale = 1.1, shirt = Color3.fromRGB(28, 26, 32), pants = Color3.fromRGB(28, 26, 32), gear = {"collar", "halo"}, armor = 0.4},
	riot = {name = "Riot Skeptic", icon = "🛡", hp = 140, speed = 8, cash = 26, leak = 10, scale = 1.15, shirt = Color3.fromRGB(40, 60, 90), gear = {"helmet", "riotshield"}, shield = 0.6},
	monk = {name = "Fearless Monk", icon = "🧘", hp = 210, speed = 7, cash = 28, leak = 12, scale = 1.1, shirt = Color3.fromRGB(230, 120, 30), pants = Color3.fromRGB(230, 120, 30), gear = {"robe", "beads"}, steady = true},
	strongman = {name = "Strongman", icon = "💪", hp = 380, speed = 6.5, cash = 45, leak = 18, scale = 1.4, shirt = Color3.fromRGB(200, 40, 50), gear = {"mustache", "dumbbell"}, regen = 0.03},
	clownhunter = {name = "Clown Hunter", icon = "🛡", hp = 560, speed = 6.5, cash = 160, leak = 20, scale = 1.45, shirt = Color3.fromRGB(70, 30, 40), boss = true, torch = true, gear = {"helmet"}, shield = 0.4, steady = true},
	ringmaster = {name = "The Ringmaster", icon = "🎩", hp = 1700, speed = 5, cash = 600, leak = 60, scale = 1.8, shirt = Color3.fromRGB(170, 20, 30), pants = Color3.fromRGB(240, 240, 240), boss = true, gear = {"tophat", "cane"}, armor = 0.2, summon = {kind = "juggler", n = 2, cd = 12}},
	-- Nuevas habilidades: hidden (solo los ven las tropas con detect o junto a un Espejo), cleanse {radius, cd} (quita
	-- ralentizar, aturdir, fuego y terror a los de alrededor), barrier {radius, amount, cd} (escudo a los de alrededor,
	-- en fracción de su vida), blink {dist, cd} (salta hacia delante por el camino), inspire {radius, mult, time, cd}
	-- (los de alrededor corren más), dash {mult, time, cd} (carga cada cierto tiempo), disable {radius, time, cd}
	-- (aturde a las tropas de alrededor). cape, hood, tabard: colores de esas prendas.
	---------- Cursed Castle: el pueblo y los caballeros ----------
	villager = {name = "Villager", icon = "🔱", hp = 45, speed = 10, cash = 8, leak = 5, scale = 1, shirt = Color3.fromRGB(176, 136, 92), pants = Color3.fromRGB(92, 70, 50), gear = {"strawhat", "pitchfork"}},
	torch = {name = "Torchbearer", icon = "🔥", hp = 55, speed = 12, cash = 9, leak = 5, scale = 1, shirt = Color3.fromRGB(128, 70, 48), pants = Color3.fromRGB(60, 44, 36), hood = Color3.fromRGB(96, 52, 36), gear = {"hood", "torch"}, burst = {mult = 1.7, time = 1.2, cd = 5}},
	squire = {name = "Squire", icon = "🗡", hp = 80, speed = 13, cash = 11, leak = 6, scale = 0.9, shirt = Color3.fromRGB(60, 100, 176), pants = Color3.fromRGB(80, 80, 90), gear = {"leathercap", "shortsword"}},
	knight = {name = "Knight", icon = "⚔", hp = 220, speed = 8, cash = 22, leak = 10, scale = 1.1, shirt = Color3.fromRGB(172, 178, 190), pants = Color3.fromRGB(120, 124, 136), tabard = Color3.fromRGB(40, 70, 170), gear = {"knighthelm", "tabard", "sword", "kiteshield"}, armor = 0.3},
	shieldknight = {name = "Shield Bearer", icon = "🛡", hp = 180, speed = 7.5, cash = 26, leak = 10, scale = 1.15, shirt = Color3.fromRGB(150, 156, 168), pants = Color3.fromRGB(100, 104, 116), tabard = Color3.fromRGB(150, 30, 40), gear = {"knighthelm", "tabard", "towershield"}, shield = 0.8},
	lancer = {name = "Lancer", icon = "🏇", hp = 150, speed = 9, cash = 20, leak = 8, scale = 1.1, shirt = Color3.fromRGB(160, 166, 178), pants = Color3.fromRGB(110, 90, 60), tabard = Color3.fromRGB(200, 160, 40), gear = {"knighthelm", "tabard", "lance"}, dash = {mult = 2.4, time = 1.2, cd = 6}},
	crossbow = {name = "Crossbowman", icon = "🏹", hp = 110, speed = 9, cash = 16, leak = 7, scale = 1, shirt = Color3.fromRGB(140, 44, 44), pants = Color3.fromRGB(70, 56, 46), gear = {"kettlehat", "crossbow"}, armor = 0.15},
	paladin = {name = "Paladin", icon = "✨", hp = 260, speed = 7.5, cash = 30, leak = 12, scale = 1.15, shirt = Color3.fromRGB(235, 235, 240), pants = Color3.fromRGB(200, 170, 80), cape = Color3.fromRGB(250, 250, 255), gear = {"wingedhelm", "cape", "warhammer"}, armor = 0.2, heal = {radius = 14, amount = 0.1, cd = 3.5}},
	blackknight = {name = "The Black Knight", icon = "🖤", hp = 900, speed = 6.5, cash = 220, leak = 25, scale = 1.6, shirt = Color3.fromRGB(34, 32, 40), pants = Color3.fromRGB(24, 22, 28), cape = Color3.fromRGB(120, 14, 24), gear = {"blackhelm", "cape", "greatsword"}, boss = true, armor = 0.35, shield = 0.3, steady = true},
	king = {name = "King Aldric the Bold", icon = "👑", hp = 2200, speed = 5, cash = 700, leak = 70, scale = 1.9, shirt = Color3.fromRGB(140, 28, 44), pants = Color3.fromRGB(60, 30, 70), cape = Color3.fromRGB(170, 20, 40), gear = {"crown", "beard", "royalcape", "scepter"}, boss = true, armor = 0.25, regen = 0.008, summon = {kind = "knight", n = 2, cd = 10}},
	---------- Witch Bayou: los cazadores de monstruos ----------
	trapper = {name = "Trapper", icon = "🪤", hp = 70, speed = 11, cash = 10, leak = 5, scale = 1, shirt = Color3.fromRGB(110, 84, 54), pants = Color3.fromRGB(66, 74, 50), gear = {"furhat", "backpack", "axe"}},
	ranger = {name = "Ranger", icon = "🏹", hp = 90, speed = 12, cash = 14, leak = 6, scale = 1, shirt = Color3.fromRGB(56, 100, 56), pants = Color3.fromRGB(70, 60, 44), hood = Color3.fromRGB(40, 84, 44), gear = {"hood", "quiver", "longbow"}, hidden = true},
	vhunter = {name = "Vampire Hunter", icon = "✝", hp = 200, speed = 9, cash = 24, leak = 10, scale = 1.1, shirt = Color3.fromRGB(60, 40, 36), pants = Color3.fromRGB(40, 34, 30), gear = {"tricorn", "coat", "crossbow"}, steady = true},
	witchhunter = {name = "Witch Hunter", icon = "📖", hp = 180, speed = 8.5, cash = 26, leak = 10, scale = 1.05, shirt = Color3.fromRGB(36, 34, 40), pants = Color3.fromRGB(30, 28, 34), gear = {"pilgrimhat", "coat", "holybook"}, cleanse = {radius = 15, cd = 4}},
	tracker = {name = "Lantern Tracker", icon = "🏮", hp = 140, speed = 9, cash = 18, leak = 8, scale = 1.05, shirt = Color3.fromRGB(90, 70, 44), pants = Color3.fromRGB(50, 44, 40), gear = {"widehat", "coat", "lantern"}, disable = {radius = 14, time = 2, cd = 8}},
	slayer = {name = "Van Gloom the Slayer", icon = "🗡", hp = 1000, speed = 7, cash = 250, leak = 30, scale = 1.6, shirt = Color3.fromRGB(70, 30, 30), pants = Color3.fromRGB(30, 28, 30), cape = Color3.fromRGB(40, 20, 24), gear = {"slayerhat", "coat", "cape", "silversword"}, boss = true, steady = true, armor = 0.25, burst = {mult = 2, time = 1.5, cd = 5}},
	inquisitor = {name = "The Grand Inquisitor", icon = "⚖", hp = 2300, speed = 5, cash = 700, leak = 70, scale = 1.85, shirt = Color3.fromRGB(150, 20, 30), pants = Color3.fromRGB(110, 14, 24), cape = Color3.fromRGB(230, 220, 200), gear = {"inquisitorhat", "royalcape", "holystaff"}, boss = true, armor = 0.2, cleanse = {radius = 20, cd = 3}, disable = {radius = 22, time = 3, cd = 9}, summon = {kind = "witchhunter", n = 2, cd = 14}},
	---------- Frozen Peak: los aventureros ----------
	explorer = {name = "Explorer", icon = "🧭", hp = 60, speed = 13, cash = 9, leak = 5, scale = 1, shirt = Color3.fromRGB(196, 170, 120), pants = Color3.fromRGB(110, 86, 60), gear = {"fedora", "backpack", "whip"}},
	climber = {name = "Mountaineer", icon = "⛰", hp = 150, speed = 8.5, cash = 18, leak = 8, scale = 1.05, shirt = Color3.fromRGB(220, 70, 50), pants = Color3.fromRGB(50, 56, 76), gear = {"beanie", "goggles", "backpack", "iceaxe"}, steady = true},
	dwarf = {name = "Dwarf Miner", icon = "⛏", hp = 260, speed = 7, cash = 26, leak = 12, scale = 0.8, shirt = Color3.fromRGB(110, 60, 40), pants = Color3.fromRGB(70, 60, 50), gear = {"minerhelm", "beard", "pickaxe"}, armor = 0.3, regen = 0.02},
	rogue = {name = "Rogue", icon = "🗡", hp = 85, speed = 14, cash = 15, leak = 7, scale = 0.95, shirt = Color3.fromRGB(56, 44, 70), pants = Color3.fromRGB(36, 30, 44), hood = Color3.fromRGB(44, 34, 56), gear = {"hood", "mask", "daggers"}, hidden = true},
	wizard = {name = "Wizard", icon = "🔮", hp = 130, speed = 8, cash = 28, leak = 9, scale = 1, shirt = Color3.fromRGB(60, 70, 170), pants = Color3.fromRGB(50, 56, 140), gear = {"wizardhat", "beard", "robe", "staff"}, barrier = {radius = 14, amount = 0.35, cd = 6}},
	treasure = {name = "Treasure Hunter", icon = "💰", hp = 100, speed = 14, cash = 90, leak = 6, scale = 1, shirt = Color3.fromRGB(255, 196, 50), pants = Color3.fromRGB(200, 140, 30), gear = {"fedora", "goldsack"}, golden = true},
	archmage = {name = "Archmage Solenne", icon = "🌀", hp = 1000, speed = 6, cash = 260, leak = 30, scale = 1.55, shirt = Color3.fromRGB(90, 40, 170), pants = Color3.fromRGB(60, 30, 120), cape = Color3.fromRGB(40, 120, 220), gear = {"archmagehat", "robe", "cape", "archstaff"}, boss = true, blink = {dist = 18, cd = 7}, barrier = {radius = 18, amount = 0.4, cd = 8}},
	legend = {name = "Sir Reginald the Legendary", icon = "🚩", hp = 2200, speed = 5.5, cash = 700, leak = 70, scale = 1.85, shirt = Color3.fromRGB(200, 176, 120), pants = Color3.fromRGB(120, 90, 60), cape = Color3.fromRGB(200, 40, 40), gear = {"pithhelmet", "mustache", "cape", "backpack", "flag"}, boss = true, steady = true, armor = 0.2, burst = {mult = 1.8, time = 1.5, cd = 6}, summon = {kind = "climber", n = 3, cd = 12}},
	---------- Fallen Cathedral: los héroes ----------
	acolyte = {name = "Acolyte", icon = "📿", hp = 70, speed = 11, cash = 10, leak = 5, scale = 0.95, shirt = Color3.fromRGB(200, 190, 170), pants = Color3.fromRGB(170, 160, 140), hood = Color3.fromRGB(180, 170, 150), gear = {"hood", "robe"}},
	cleric = {name = "Cleric", icon = "💚", hp = 140, speed = 8.5, cash = 22, leak = 8, scale = 1, shirt = Color3.fromRGB(240, 240, 235), pants = Color3.fromRGB(220, 200, 120), gear = {"mitre", "robe", "holybook"}, heal = {radius = 14, amount = 0.12, cd = 3}},
	bard = {name = "Bard", icon = "🎵", hp = 120, speed = 9.5, cash = 20, leak = 8, scale = 0.95, shirt = Color3.fromRGB(60, 150, 90), pants = Color3.fromRGB(180, 60, 60), gear = {"featherhat", "lute"}, inspire = {radius = 15, mult = 1.45, time = 2.5, cd = 6}},
	hero = {name = "Young Hero", icon = "⚔", hp = 260, speed = 9, cash = 30, leak = 10, scale = 1.05, shirt = Color3.fromRGB(40, 110, 60), pants = Color3.fromRGB(90, 70, 50), cape = Color3.fromRGB(190, 40, 40), gear = {"herohair", "cape", "herosword", "heroshield"}, regen = 0.02},
	valkyrie = {name = "Valkyrie", icon = "🪽", hp = 220, speed = 10, cash = 30, leak = 10, scale = 1.05, shirt = Color3.fromRGB(190, 196, 210), pants = Color3.fromRGB(70, 90, 140), gear = {"valkyriehelm", "wings", "spear"}, fly = true},
	sorceress = {name = "Sorceress", icon = "✦", hp = 160, speed = 9, cash = 26, leak = 9, scale = 1, shirt = Color3.fromRGB(120, 30, 120), pants = Color3.fromRGB(70, 20, 80), gear = {"sorceresshat", "robe", "orb"}, blink = {dist = 12, cd = 6}},
	champion = {name = "The Champion", icon = "🏆", hp = 1100, speed = 6.5, cash = 280, leak = 30, scale = 1.6, shirt = Color3.fromRGB(200, 170, 70), pants = Color3.fromRGB(120, 100, 50), cape = Color3.fromRGB(30, 60, 160), gear = {"championhelm", "cape", "greatsword", "heroshield"}, boss = true, armor = 0.3, shield = 0.3, steady = true},
	chosen = {name = "The Chosen One", icon = "🌟", hp = 2600, speed = 5.2, cash = 800, leak = 80, scale = 1.9, shirt = Color3.fromRGB(240, 236, 220), pants = Color3.fromRGB(200, 170, 80), cape = Color3.fromRGB(240, 200, 70), gear = {"halo", "herohair", "royalcape", "wings", "holysword"}, boss = true, armor = 0.2, regen = 0.006, summon = {kind = "hero", n = 2, cd = 12}, inspire = {radius = 22, mult = 1.3, time = 3, cd = 8}, disable = {radius = 20, time = 2.5, cd = 10}},
}

-- Cuánto pesa el grupo en la oleada w: de 0.3 al principio a 1 desde la oleada 10 (que el arranque sea igual para todos)
function TD.ramp(w)
	return math.min(1, 0.25 + 0.075 * w)
end

-- Cuántos más cazafantasmas normales salen por los jugadores extra
function TD.crowd(w, players)
	return 1 + TD.PER_PLAYER_COUNT * (math.max(1, players or 1) - 1) * TD.ramp(w)
end

-- Oleadas del carnaval (e = oleada equivalente de una partida de 20)
local function carnival(e, final, add)
	if final then
		add("vlogger", 10, 0.4)
		add("riot", 3, 1.2)
		add("strongman", 2, 2)
		add("ringmaster", 1, 0)
		return
	end
	add("visitor", math.min(2 + e, 14), math.max(0.5, 1.1 - e * 0.03))
	add("vlogger", e >= 2 and math.min(e - 1, 10) or 0, 0.5)
	add("juggler", e >= 3 and math.min(e - 2, 8) or 0, 0.8)
	add("dad", e >= 4 and math.ceil(e / 3) or 0, 1.4)
	add("jetpack", e >= 5 and math.ceil(e / 2.5) or 0, 0.9)
	add("medium", e >= 6 and math.ceil(e / 5) or 0, 2)
	add("priest", e >= 7 and math.ceil(e / 3) or 0, 1.4)
	add("riot", e >= 9 and math.ceil(e / 4) or 0, 1.6)
	add("monk", e >= 11 and math.ceil(e / 4) or 0, 1.6)
	add("strongman", e >= 13 and math.ceil((e - 10) / 3) or 0, 2.4)
	add("clownhunter", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas del castillo: primero el pueblo con horcas y antorchas, luego escuderos, caballeros y paladines; el Caballero
-- Negro cada 5 oleadas y el rey Aldric al final
local function castle(e, final, add)
	if final then
		add("knight", 6, 0.9)
		add("shieldknight", 2, 1.5)
		add("paladin", 2, 2)
		add("blackknight", 1, 3)
		add("king", 1, 0)
		return
	end
	add("villager", math.min(3 + e, 16), math.max(0.45, 1.1 - e * 0.03))
	add("torch", e >= 2 and math.min(e, 10) or 0, 0.6)
	add("squire", e >= 3 and math.min(e - 1, 10) or 0, 0.7)
	add("knight", e >= 5 and math.ceil(e / 3) or 0, 1.4)
	add("lancer", e >= 6 and math.ceil(e / 4) or 0, 1.6)
	add("crossbow", e >= 7 and math.ceil(e / 3.5) or 0, 1.2)
	add("shieldknight", e >= 9 and math.ceil(e / 5) or 0, 1.8)
	add("paladin", e >= 11 and math.ceil((e - 8) / 4) or 0, 2.5)
	add("blackknight", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas del pantano: tramperos y cazafantasmas clásicos; luego exploradores ocultos (hace falta detectar),
-- cazavampiros, rastreadores que aturden tropas y cazabrujas que limpian estados. Van Gloom cada 5 y el Inquisidor
local function hunters(e, final, add)
	if final then
		add("ranger", 6, 0.7)
		add("vhunter", 3, 1.2)
		add("tracker", 2, 2)
		add("slayer", 1, 3)
		add("inquisitor", 1, 0)
		return
	end
	add("visitor", math.min(2 + e, 12), math.max(0.5, 1.1 - e * 0.03))
	add("trapper", math.min(1 + e, 12), 0.8)
	add("ranger", e >= 4 and math.ceil(e / 2.5) or 0, 1)
	add("vhunter", e >= 6 and math.ceil(e / 3.5) or 0, 1.5)
	add("tracker", e >= 8 and math.ceil(e / 6) or 0, 2.5)
	add("witchhunter", e >= 10 and math.ceil(e / 5) or 0, 2)
	add("hunter", e >= 12 and e % 3 == 0 and 1 or 0, 2)
	add("slayer", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas de la montaña: exploradores, pícaros ocultos, alpinistas, enanos y magos con barreras; la Archimaga cada 5
-- y sir Reginald al final. A veces, un cazatesoros dorado
local function adventurers(e, final, add)
	if final then
		add("explorer", 8, 0.5)
		add("climber", 3, 1.3)
		add("wizard", 2, 2)
		add("archmage", 1, 3)
		add("legend", 1, 0)
		return
	end
	add("explorer", math.min(3 + e, 16), math.max(0.45, 1.05 - e * 0.03))
	add("rogue", e >= 3 and math.ceil(e / 2.5) or 0, 0.9)
	add("climber", e >= 5 and math.ceil(e / 3) or 0, 1.4)
	add("dwarf", e >= 7 and math.ceil(e / 4) or 0, 1.8)
	add("wizard", e >= 9 and math.ceil(e / 5) or 0, 2.2)
	add("treasure", e % 3 == 0 and 1 or 0, 0)
	add("archmage", e % 5 == 0 and e // 5 or 0, 3)
end

-- Oleadas de la catedral: acólitos, bardos que inspiran, clérigos que curan, héroes, valquirias que vuelan y
-- hechiceras que saltan; el Campeón cada 5 y el Elegido al final
local function heroes(e, final, add)
	if final then
		add("hero", 4, 1.2)
		add("valkyrie", 3, 1.2)
		add("cleric", 2, 2)
		add("champion", 2, 3)
		add("chosen", 1, 0)
		return
	end
	add("acolyte", math.min(3 + e, 16), math.max(0.45, 1.05 - e * 0.03))
	add("bard", e >= 3 and math.ceil(e / 4) or 0, 1.6)
	add("cleric", e >= 4 and math.ceil(e / 4) or 0, 1.8)
	add("hero", e >= 6 and math.ceil(e / 3) or 0, 1.4)
	add("valkyrie", e >= 8 and math.ceil(e / 3) or 0, 1.2)
	add("sorceress", e >= 10 and math.ceil(e / 4) or 0, 1.6)
	add("champion", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas de la granja (el mapa más fácil): granjeros con horcas, niños, antorchas y tramperos; el Experto
-- Paranormal cada 5 y el Exorcista al final
local function farm(e, final, add)
	if final then
		add("villager", 10, 0.4)
		add("dad", 3, 1.2)
		add("strongman", 2, 2)
		add("boss", 1, 0)
		return
	end
	add("villager", math.min(3 + e, 16), math.max(0.45, 1.1 - e * 0.03))
	add("kid", e >= 2 and math.min(e, 10) or 0, 0.5)
	add("torch", e >= 3 and math.ceil(e / 2) or 0, 0.8)
	add("trapper", e >= 5 and math.ceil(e / 3) or 0, 1.2)
	add("dad", e >= 7 and math.ceil(e / 4) or 0, 1.6)
	add("strongman", e >= 12 and math.ceil((e - 10) / 3) or 0, 2.4)
	add("hunter", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas del puerto: contrabandistas, piratas con jetpack, ballesteros y lanceros que cargan; Van Gloom cada 5 y
-- sir Reginald desembarca al final. A veces, un cazatesoros dorado
local function harbor(e, final, add)
	if final then
		add("trapper", 8, 0.5)
		add("crossbow", 4, 1)
		add("vhunter", 3, 1.2)
		add("slayer", 1, 3)
		add("legend", 1, 0)
		return
	end
	add("visitor", math.min(2 + e, 12), math.max(0.5, 1.1 - e * 0.03))
	add("trapper", math.min(1 + e, 12), 0.8)
	add("jetpack", e >= 4 and math.ceil(e / 3) or 0, 1)
	add("crossbow", e >= 6 and math.ceil(e / 3.5) or 0, 1.2)
	add("lancer", e >= 8 and math.ceil(e / 4) or 0, 1.6)
	add("vhunter", e >= 10 and math.ceil(e / 4) or 0, 1.5)
	add("tracker", e >= 12 and math.ceil(e / 6) or 0, 2.5)
	add("slayer", e % 5 == 0 and e // 5 or 0, 3)
	add("treasure", e % 3 == 0 and 1 or 0, 0)
end

-- Oleadas del cementerio: acólitos, médiums que curan, sacerdotes con armadura, cazabrujas que limpian estados y
-- paladines; el Experto Paranormal cada 5 y el Gran Inquisidor bajo la luna de sangre al final
local function graveyard(e, final, add)
	if final then
		add("priest", 6, 0.8)
		add("witchhunter", 3, 1.4)
		add("paladin", 2, 2)
		add("hunter", 2, 2)
		add("inquisitor", 1, 0)
		return
	end
	add("visitor", math.min(3 + e, 14), math.max(0.45, 1.1 - e * 0.03))
	add("acolyte", e >= 2 and math.min(e, 10) or 0, 0.6)
	add("medium", e >= 4 and math.ceil(e / 5) or 0, 2)
	add("priest", e >= 5 and math.ceil(e / 3) or 0, 1.4)
	add("witchhunter", e >= 8 and math.ceil(e / 5) or 0, 2)
	add("paladin", e >= 11 and math.ceil((e - 8) / 4) or 0, 2.5)
	add("hunter", e % 5 == 0 and e // 5 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

-- Oleadas del vacío (el mapa más difícil): lo mejor de cada gremio. Vloggers rapidísimos, pícaros ocultos, escudos
-- antidisturbios, hechiceras que saltan, valquirias que vuelan, magos con barreras y monjes impasibles; la Archimaga y el
-- Campeón se turnan cada 5 y el Elegido cierra la brecha
local function void(e, final, add)
	if final then
		add("rogue", 6, 0.6)
		add("valkyrie", 3, 1.2)
		add("wizard", 2, 1.6)
		add("champion", 1, 3)
		add("chosen", 1, 0)
		return
	end
	add("vlogger", math.min(2 + e, 12), math.max(0.4, 0.9 - e * 0.025))
	add("rogue", e >= 2 and math.ceil(e / 2.5) or 0, 0.9)
	add("riot", e >= 4 and math.ceil(e / 4) or 0, 1.6)
	add("sorceress", e >= 6 and math.ceil(e / 4) or 0, 1.6)
	add("valkyrie", e >= 8 and math.ceil(e / 3.5) or 0, 1.2)
	add("wizard", e >= 9 and math.ceil(e / 5) or 0, 2.2)
	add("monk", e >= 11 and math.ceil(e / 4) or 0, 1.6)
	add("archmage", e % 10 == 5 and 1 or 0, 3)
	add("champion", e % 10 == 0 and e // 10 or 0, 3)
	add("golden", e % 4 == 2 and 1 or 0, 0)
end

local ROSTERS = {
	carnival = carnival, castle = castle, hunters = hunters, adventurers = adventurers, heroes = heroes,
	farm = farm, harbor = harbor, graveyard = graveyard, void = void,
}

-- Oleada w (de waves) con estos jugadores: lista de grupos {tipo, cuántos, segundos entre uno y otro}
local CROWD = {
	visitor = true, kid = true, brave = true, vlogger = true, juggler = true, villager = true, torch = true, squire = true,
	trapper = true, explorer = true, acolyte = true,
}
function TD.wave(w, players, waves, roster)
	waves = waves or TD.WAVES
	local list = {}
	local endless = waves == TD.ENDLESS
	local last = not endless and w >= waves
	w = TD.effWave(w, waves)
	local k = TD.crowd(w, players)
	-- Modo Infinito: desde la 20, cada oleada un 6.5% más de cazafantasmas (los jefes, uno)
	local more = endless and 1 + TD.ENDLESS_MORE * math.max(0, w - 20) or 1
	local function add(kind, n, gap)
		if CROWD[kind] then
			n, gap = math.floor(n * k * more + 0.5), gap / (k * more)
		elseif n > 1 then
			n = math.floor(n * more + 0.5)
		end
		if n > 0 then
			table.insert(list, {kind, n, gap})
		end
	end
	if ROSTERS[roster] then
		ROSTERS[roster](w, last, add)
		-- cada 10 oleadas del Modo Infinito, además, la oleada final del mapa con su jefe
		if endless and w % 10 == 0 then
			ROSTERS[roster](w, true, add)
		end
		return list
	end
	if endless and w % 10 == 0 then
		add("brave", 8, 0.8)
		add("hunter", 2, 2)
		add("boss", 1, 0)
	end
	if last then
		add("brave", 8, 0.8)
		add("hunter", 2, 2)
		add("boss", 1, 0)
		return list
	end
	add("visitor", math.min(4 + w * 2, 26), math.max(0.45, 1.2 - w * 0.04))
	add("kid", w >= 3 and w + 1 or 0, 0.5)
	add("brave", w >= 5 and w // 2 or 0, 1.1)
	add("hunter", w % 5 == 0 and w // 5 or 0, 2.5)
	add("golden", w % 4 == 2 and 1 or 0, 0)
	return list
end

function TD.hpScale(w, players)
	return (1 + 0.11 * (w - 1)) * (TD.SOLO_HP + TD.PER_PLAYER_HP * (math.max(1, players) - 1) * TD.ramp(w))
end
function TD.waveCash(w) -- dinero de partida para cada jugador al superar la oleada
	return 100 + 25 * w
end
function TD.waveCoins(w) -- monedas del juego (las de comprar sustos) al superar la oleada
	return 10 + 4 * w
end

---------- Mejoras ----------
-- Mejorar rinde más o menos lo mismo por moneda que poner otra tropa igual (x1.80, x2.96, x4.71 de miedo por segundo
-- por 1.85, 3.25 y 5.45 veces su precio), pero además da alcance y área, y no gasta hueco (hay un límite de cada tropa).
-- Antes costaba mucho menos (1.6, 2.6 y 4.1 veces) y con las tropas del principio mejoradas se ganaba en Hard.
-- (y lo demás crece con ellas: fuego, rebotes, mejora del Espejo, lo que paga el Pozo)
TD.LEVEL_DMG = {1, 1.55, 2.25, 3.2}
TD.LEVEL_CD = {1, 0.86, 0.76, 0.68}
TD.LEVEL_RANGE = {1, 1.1, 1.2, 1.32}
TD.LEVEL_CHAIN = {0, 1, 1, 2} -- rebotes extra
TD.UPGRADE = {0.85, 1.4, 2.2} -- precio de pasar de nivel n a n + 1 (por el de la tropa)
TD.INCOME = {1, 1.9, 3.1, 4.8}
-- mastery: el nivel de la tropa (Config.levelOf de su experiencia): cada nivel, +Config.LEVEL_FEAR de miedo (y de fuego
-- y de lo que paga el Pozo)
function TD.stats(t, level, mastery)
	local s = table.clone(TD.Troops[t])
	local lv = math.clamp(level or 1, 1, TD.MAX_LEVEL)
	local k = lv - 1
	local mk = 1 + Config.LEVEL_FEAR * ((mastery or 1) - 1)
	s.mastery = mastery or 1
	s.dmg = s.dmg * TD.LEVEL_DMG[lv] * mk
	s.cd = s.cd * TD.LEVEL_CD[lv]
	s.range = s.range * TD.LEVEL_RANGE[lv]
	if s.splash then
		s.splash *= TD.LEVEL_RANGE[lv]
	end
	if s.burn then
		s.burn = {dps = s.burn.dps * TD.LEVEL_DMG[lv] * mk, time = s.burn.time}
	end
	if s.chain then
		s.chain += TD.LEVEL_CHAIN[lv]
	end
	if s.buff then
		s.buff = {dmg = s.buff.dmg + 0.08 * k, range = s.buff.range + 0.03 * k}
	end
	if s.income then
		s.income = math.floor(s.income * TD.INCOME[k + 1] * mk + 0.5)
	end
	if s.flee then
		s.flee *= 1 + 0.15 * k
	end
	if s.detectAt and lv >= s.detectAt then
		s.detect = true
	end
	return s
end
function TD.upgradeCost(t, level) -- de level a level + 1
	return math.floor(TD.Troops[t].cost * (TD.UPGRADE[level] or 2.2) / 5 + 0.5) * 5
end
function TD.sellValue(spent)
	return math.floor(spent * TD.SELL)
end
function TD.limit(t)
	return TD.Troops[t].limit or TD.LIMIT[Config.Scares[t].cat] or 4
end

-- ¿Ataca? (el Pozo y el Espejo no)
function TD.attacks(t)
	local k = TD.Troops[t].kind
	return k ~= "farm" and k ~= "support"
end

-- ¿Tiene este susto? (en la mochila o colocado en su casa). Los colocados, por el atributo PlacedTypes que pone
-- Juego, no buscando la casa: en los mapas el cliente quita la calle y las casas (ZombieHollowFX) y el equipo se
-- quedaba solo con los de la mochila.
function TD.owns(plr, t)
	if (plr:GetAttribute("Inv_" .. t) or 0) > 0 then
		return true
	end
	return table.find(string.split(plr:GetAttribute("PlacedTypes") or "", ","), t) ~= nil
end

-- Su equipo: los sustos que ha elegido (atributo Loadout, "Armario,Luz,...") y sigue teniendo. Sin elegir: los
-- primeros que tenga, en el orden de la tienda.
function TD.loadout(plr)
	local list = {}
	for t in string.gmatch(plr:GetAttribute("Loadout") or "", "[^,]+") do
		if TD.Troops[t] and not table.find(list, t) and #list < TD.SLOTS and TD.owns(plr, t) then
			table.insert(list, t)
		end
	end
	if (plr:GetAttribute("Loadout") or "") == "" then
		for _, t in Config.ScareOrder do
			if TD.Troops[t] and #list < TD.SLOTS and TD.owns(plr, t) then
				table.insert(list, t)
			end
		end
	end
	return list
end

-- Estrellas al ganar: 1, +1 si la casa sigue a más de la mitad, +1 si está intacta
function TD.stars(won, hp)
	if not won then
		return 0
	end
	return 1 + (hp >= TD.BASE_HP / 2 and 1 or 0) + (hp >= TD.BASE_HP and 1 or 0)
end

---------- Camino (<mapa>.Camino: puntos 1..N de la salida de los enemigos a la casa) ----------
local function flat(v)
	return Vector2.new(v.X, v.Z).Magnitude
end
TD.flat = flat

-- map: el modelo del mapa
local paths = {}
function TD.path(map)
	local path = paths[map]
	if not path then
		local pts = {}
		for _, p in map:WaitForChild("Camino"):GetChildren() do
			pts[tonumber(p.Name)] = p.Position
		end
		local cum, total = {0}, 0
		for i = 2, #pts do
			total += flat(pts[i] - pts[i - 1])
			cum[i] = total
		end
		path = {pts = pts, cum = cum, total = total}
		paths[map] = path
	end
	return path
end

-- Punto a d studs del principio del camino, y el índice del siguiente punto
function TD.pointAt(d, map)
	local p = TD.path(map)
	d = math.clamp(d, 0, p.total)
	for i = 2, #p.pts do
		if p.cum[i] >= d then
			local seg = p.cum[i] - p.cum[i - 1]
			return p.pts[i - 1]:Lerp(p.pts[i], seg > 0 and (d - p.cum[i - 1]) / seg or 1), i
		end
	end
	return p.pts[#p.pts], #p.pts
end

function TD.distToPath(pos, map)
	local pts = TD.path(map).pts
	local best = math.huge
	local q = Vector2.new(pos.X, pos.Z)
	for i = 2, #pts do
		local a, b = Vector2.new(pts[i - 1].X, pts[i - 1].Z), Vector2.new(pts[i].X, pts[i].Z)
		local ab = b - a
		local k = math.clamp((q - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (a + ab * k - q).Magnitude)
	end
	return best
end

---------- ¿Se puede colocar aquí? (cliente: vista previa verde/roja; servidor: validación) ----------
-- Devuelve ok, motivo, posición en el suelo. ignore: más cosas que no cuentan (la vista previa del cliente).
-- Suelo válido: el terreno (sin agua) y las piezas de MapaTDS.Camino / MapaTDS.Suelo del mapa.
local function isGround(map, inst)
	if inst == workspace.Terrain then
		return true
	end
	local tds = map:FindFirstChild("MapaTDS")
	for _, n in {"Camino", "Suelo"} do
		local f = tds and tds:FindFirstChild(n)
		if f and inst:IsDescendantOf(f) then
			return true
		end
	end
	return false
end

function TD.canPlace(t, pos, ignore, map)
	local troop = TD.Troops[t]
	if not (troop and map) or typeof(pos) ~= "Vector3" or pos ~= pos then
		return false, "You can't place it there"
	end
	local o, b = map:GetAttribute("Origin"), map:GetAttribute("Bounds")
	local lp = o:PointToObjectSpace(pos)
	if lp.X < b.Min.X + 4 or lp.X > b.Max.X - 4 or lp.Z < b.Min.Y + 4 or lp.Z > b.Max.Y - 4 then
		return false, "Outside the map"
	end
	local td = map:FindFirstChild("TD")
	local skip = {workspace.Terrain}
	for _, x in {td, ignore} do
		table.insert(skip, x)
	end
	for _, p in Players:GetPlayers() do
		table.insert(skip, p.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {table.unpack(skip, 2)} -- el rayo sí tiene que dar en el terreno
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 25, pos.Z), Vector3.new(0, -60, 0), params)
	if not hit or hit.Normal.Y < 0.85 then
		return false, "You can't place it there"
	end
	if not isGround(map, hit.Instance) or hit.Material == Enum.Material.Water then
		return false, "Something is in the way"
	end
	local at = hit.Position
	local half = (map:GetAttribute("PathWidth") or 7) / 2
	local d = TD.distToPath(at, map)
	if troop.kind == "trap" then
		if d > half - 0.5 then
			return false, "Traps go on the path"
		end
	elseif d < half + 1.8 then
		return false, "Keep the path clear"
	end
	for _, m in td and td.Towers:GetChildren() or {} do
		if flat(m:GetPivot().Position - at) < TD.SPACING then
			return false, "Too close to another troop"
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = skip
	op.RespectCanCollide = true
	if #workspace:GetPartBoundsInRadius(at + Vector3.new(0, 2.6, 0), 1.6, op) > 0 then
		return false, "Something is in the way"
	end
	return true, nil, at
end

return TD
