-- Hexa, la bruja del Caldero de Fusión (cliente): le da vida a la figura de piezas que monta FusionBuilder en
-- workspace.Mapa.Tiendas.Fusion. Un esqueleto ligero sobre las piezas (cadera, cuello, mandíbula, cejas, sombrero de
-- punta blanda, capa y dos brazos con IK de dos huesos que siguen al remo) y una coreografía por fotogramas clave:
--  * Remover: el remo da vueltas dentro del caldero y el cuerpo acompaña (balanceo, respiración; la capa y la punta
--    del sombrero van con retraso de muelle). Parpadea, mira alrededor y, si te acercas, te sigue con la mirada.
--  * De vez en cuando: GIRA EL CALDERO (saca el remo, coge impulso y le da un golpe: el caldero da dos vueltas
--    bamboleándose, con chispas y un destello, y ella se ríe), se ASOMA a oler el brebaje y asiente, o se RÍE.
--  * Cuando fusionas un susto, lo celebra girando el caldero.
-- Las gotas de los chorreones se hinchan, caen y salpican el suelo; las burbujas crecen y revientan.
-- Todo local, como las almas de TiendasFX: las piezas son ancladas del servidor y aquí solo se mueven para ti. Solo
-- se dibuja si estás cerca. Pruebas: BrujaDebug:Fire("spin" | "cackle" | "peek") desde la barra de comandos.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sfx = require(RS:WaitForChild("Sfx"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer

local tiendas = workspace:WaitForChild("Mapa"):WaitForChild("Tiendas", 60)
local station = tiendas and tiendas:WaitForChild("Fusion", 60)
if not (station and station:WaitForChild("BrujaCabeza", 30) and station:WaitForChild("Remo", 30) and station:WaitForChild("Panza", 30)) then
	return
end

local Y = Vector3.yAxis
local rad = math.rad
local TAU = math.pi * 2
local DRAW_DISTANCE = 170
local STIR_SPEED = TAU / 2.8 -- una vuelta del remo cada 2.8 s
local SPIN_TIME = 3.2 -- lo que tarda el caldero en dar sus dos vueltas

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function rotAbout(p, r)
	return CFrame.new(p) * r * CFrame.new(-p)
end
local axis = CFrame.fromAxisAngle

---------- Piezas ----------
local rest = {} -- [pieza] = CFrame de reposo
local function named(name)
	local list = {}
	for _, c in station:GetChildren() do
		if c:IsA("BasePart") and c.Name == name then
			table.insert(list, c)
			rest[c] = c.CFrame
		end
	end
	return list
end
local function one(name)
	return named(name)[1]
end
local function group(names)
	local list = {}
	for _, n in names do
		for _, p in named("Bruja" .. n) do
			table.insert(list, p)
		end
	end
	return list
end

local SKIRT = group({"Falda", "Dobladillo", "DobladilloTela", "Vuelo"})
local TORSO = group({"Torso", "Corse", "Cordon", "Cinturon", "Hebilla", "HebillaHueco", "Cuellito", "Hombro"})
local CAPE = group({"Capa", "CapaPico"})
local HEAD = group({"Cabeza", "Nariz", "NarizPunta", "Verruga", "Flequillo", "Pelo", "PeloAtras", "PeloPunta", "Ojo", "Pupila"})
local JAW = group({"Barbilla", "Boca", "Diente"})
local BROWS = group({"Ceja"})
local EYES = group({"Ojo", "Pupila"})
local HAT = group({"Ala", "AlaBorde", "Cinta", "HebillaSombrero"})
local copas = group({"Copa"})
table.sort(copas, function(a, b)
	return a.Position.Y < b.Position.Y
end)
local dije = one("BrujaDije")
table.insert(HAT, copas[1])
table.insert(HAT, copas[2])
local TIP1 = {copas[3]}
local TIP2 = {copas[4], copas[5], dije}
local eyeSize = {}
for _, e in EYES do
	eyeSize[e] = e.Size
end

-- El caldero: todo lo que está pegado a él (gira con él)
local panza, pocion = one("Panza"), one("Pocion")
local POT = panza.Position
local POT_NAMES = {Panza = true, Cuello = true, Pocion = true, AroCaldero = true, Remache = true, Chorreon = true, Cinto = true, Emblema = true, Garra = true, Medallon = true, Pata = true}
local POT_PARTS = {}
for name in POT_NAMES do
	for _, p in named(name) do
		if flat(p.Position - POT).Magnitude < 4.8 then
			table.insert(POT_PARTS, p)
		end
	end
end
local bubbles, drops = named("Burbuja"), named("Gota")
local baseSize = {}
for _, p in bubbles do
	baseSize[p] = p.Size
end
for _, p in drops do
	baseSize[p] = p.Size
end
local centro = station:FindFirstChild("Centro")
local GROUND = centro and centro.Position.Y + centro.Size.X / 2 or POT.Y - 2.6
local PIVOT = Vector3.new(POT.X, GROUND, POT.Z) -- (gira y se bambolea sobre sus patas)
local BREW = pocion.Position

-- Ejes de la bruja: mira al caldero
local torso = one("BrujaTorso")
local FWD = flat(POT - torso.Position).Unit
local RIGHT = FWD:Cross(Y).Unit
local WAIST = Vector3.new(torso.Position.X, one("BrujaCinturon").Position.Y, torso.Position.Z)
local NECK = one("BrujaCuellito").Position + Vector3.new(0, 0.2, 0)
local HAT_BASE = one("BrujaCinta").Position
local J1 = (copas[2].Position + copas[3].Position) / 2
local J2 = (copas[3].Position + copas[4].Position) / 2
local capa = one("BrujaCapa")
local CAPE_TOP = (capa.CFrame * CFrame.new(0, capa.Size.Y / 2, 0)).Position
local CAPE_AXIS = capa.CFrame.RightVector

-- Brazos: hombro, codo y mano sacados de las piezas; el polo (hacia dónde dobla el codo) del reposo
local arms = {}
do
	local fores, cuffs, hands = named("BrujaAntebrazo"), named("BrujaManga"), named("BrujaMano")
	local taken = {}
	local function nearest(list, p)
		local best, bd
		for _, q in list do
			local d = (q.Position - p).Magnitude
			if not taken[q] and (not bd or d < bd) then
				best, bd = q, d
			end
		end
		taken[best] = true
		return best
	end
	for _, upper in named("BrujaBrazo") do
		local fore = nearest(fores, upper.Position)
		local cuff = nearest(cuffs, fore.Position)
		local hand = nearest(hands, fore.Position)
		local half = upper.CFrame.LookVector * upper.Size.Z / 2
		local e1, e2 = upper.Position + half, upper.Position - half
		local elbow = (e1 - fore.Position).Magnitude < (e2 - fore.Position).Magnitude and e1 or e2
		local shoulder = elbow == e1 and e2 or e1
		local wrist = hand.Position
		local across = (wrist - shoulder).Unit
		local bend = elbow - (shoulder + wrist) / 2
		local pole = bend - across * bend:Dot(across)
		pole = pole.Magnitude > 1e-3 and pole.Unit or -Y
		local U0, F0 = CFrame.lookAt(shoulder, elbow, pole), CFrame.lookAt(elbow, wrist, pole)
		table.insert(arms, {
			shoulder = shoulder, pole = pole, lu = (elbow - shoulder).Magnitude, lf = (wrist - elbow).Magnitude, hand = hand,
			upper = {{upper, U0:ToObjectSpace(upper.CFrame)}},
			fore = {{fore, F0:ToObjectSpace(fore.CFrame)}, {cuff, F0:ToObjectSpace(cuff.CFrame)}},
		})
	end
end

-- El remo: la pala dentro del caldero y el agarre entre las dos manos (las manos van pegadas a él)
local remo, pala = one("Remo"), one("RemoPala")
local BLADE0 = pala.Position
local GRIP0 = Vector3.zero
for _, a in arms do
	GRIP0 += a.hand.Position / #arms
end
local R0 = CFrame.lookAt(BLADE0, GRIP0)
local OAR = {{remo, R0:ToObjectSpace(remo.CFrame)}, {pala, R0:ToObjectSpace(pala.CFrame)}}
for _, a in arms do
	a.grip = R0:ToObjectSpace(a.hand.CFrame)
end
local bladeOff = flat(BLADE0 - BREW)
local STIR_R = math.max(0.6, bladeOff.Magnitude)
local theta = math.atan2(bladeOff:Dot(RIGHT), bladeOff:Dot(FWD))

---------- Efectos ----------
local chispas, vapor = pocion:FindFirstChild("Chispas"), pocion:FindFirstChild("Vapor")
local brewLight = pocion:FindFirstChildOfClass("PointLight")
local BREW_BRIGHT = brewLight and brewLight.Brightness or 1
local head = one("BrujaCabeza")
local function sound(name, parent, gain, pitch)
	local s = Sfx.play(name, parent, gain, pitch)
	if s then
		s.RollOffMinDistance, s.RollOffMaxDistance = 12, 80
	end
end

local spinAt, flashAt = nil, -10
local EVENTS = {
	hit = function(now)
		spinAt, flashAt = now, now
		if chispas then
			chispas:Emit(55)
		end
		if vapor then
			vapor:Emit(12)
		end
		sound("Swoosh", pocion, 1.3, 0.9)
		sound("Sparkle", pocion, 1, 1.1)
	end,
	cackle = function()
		sound("Laugh", head, 1.1)
	end,
	giggle = function()
		sound("Giggle", head, 0.9)
	end,
}

---------- Coreografía ----------
-- Cada movimiento: fotogramas clave por canal ({segundo, valor}, interpolados suave) y avisos en su segundo.
-- Canales (grados): yaw/lean/roll del cuerpo, hy/hp/hr de la cabeza. Remo: stir (velocidad de remover), lift y back
-- (sacarlo y echarlo hacia ella, studs), swing (giro extra de la pala, radianes), radius (lo lejos del centro).
-- Cara: jaw, brow. laugh (risa: tiembla), sniff (olfatea), look (cuánto te mira).
local MOVES = {
	spin = {
		len = 5.4,
		keys = {
			stir = {{0, 1}, {0.45, 0}, {3.9, 0}, {4.9, 1}},
			lift = {{0, 0}, {0.7, 2.4}, {1.0, 2.6}, {1.18, 1.4}, {1.45, 2.2}, {3.6, 2.2}, {4.6, 0}},
			back = {{0, 0}, {0.7, 0.5}, {1.1, 0.1}, {1.5, 0.5}, {3.6, 0.5}, {4.6, 0}},
			swing = {{0, 0}, {0.7, 0}, {1.0, -0.7}, {1.25, 0.9}, {1.6, 0.6}, {3.6, 0.6}, {4.6, 0}},
			radius = {{0, STIR_R}, {0.9, 1.5}, {1.15, 2.3}, {1.45, 1.5}, {4.6, STIR_R}},
			yaw = {{0, 0}, {0.7, 10}, {1.0, 14}, {1.22, -12}, {1.6, -6}, {3.6, -4}, {4.8, 0}},
			lean = {{0, 0}, {0.7, -6}, {1.0, -8}, {1.22, 10}, {1.6, 4}, {2.0, -4}, {3.6, -3}, {4.8, 0}},
			hp = {{0, 0}, {0.6, 10}, {1.2, 8}, {1.75, -14}, {3.4, -12}, {4.6, 0}},
			laugh = {{0, 0}, {1.55, 0}, {1.85, 1}, {3.3, 1}, {3.7, 0}},
			brow = {{0, 0}, {0.5, 1}, {1.6, 1}, {1.9, 0.6}, {3.6, 0.6}, {4.4, 0}},
			look = {{0, 1}, {0.3, 0}, {3.8, 0}, {4.8, 1}},
		},
		events = {{1.15, "hit"}, {1.7, "cackle"}},
	},
	cackle = {
		len = 3.4,
		keys = {
			stir = {{0, 1}, {0.4, 0.25}, {2.8, 0.25}, {3.4, 1}},
			laugh = {{0, 0}, {0.35, 1}, {2.6, 1}, {3.1, 0}},
			hp = {{0, 0}, {0.4, -16}, {2.6, -12}, {3.2, 0}},
			lean = {{0, 0}, {0.4, -5}, {2.6, -4}, {3.2, 0}},
			brow = {{0, 0}, {0.3, 1}, {2.8, 1}, {3.3, 0}},
			look = {{0, 1}, {0.3, 0.3}, {2.8, 0.3}, {3.3, 1}},
		},
		events = {{0.25, "cackle"}},
	},
	peek = {
		len = 4.4,
		keys = {
			stir = {{0, 1}, {0.5, 0}, {3.6, 0}, {4.4, 1}},
			lift = {{0, 0}, {0.6, 0.7}, {3.6, 0.7}, {4.4, 0}},
			lean = {{0, 0}, {0.8, 12}, {2.4, 12}, {2.8, 3}, {3.8, 3}, {4.4, 0}},
			hp = {{0, 0}, {0.8, 24}, {2.4, 22}, {2.75, 4}, {2.95, -3}, {3.15, 9}, {3.35, -3}, {3.55, 8}, {4.2, 0}},
			sniff = {{0, 0}, {0.9, 0}, {1.1, 1}, {2.2, 1}, {2.4, 0}},
			brow = {{0, 0}, {2.5, 0}, {2.8, 1}, {3.7, 1}, {4.2, 0}},
			jaw = {{0, 0}, {2.8, 0}, {3.0, 0.35}, {3.8, 0.35}, {4.1, 0}},
			look = {{0, 1}, {0.4, 0}, {3.7, 0}, {4.4, 1}},
		},
		events = {{2.8, "giggle"}},
	},
}

local function curve(keys, u)
	if u <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local k0, k1 = keys[i - 1], keys[i]
		if u <= k1[1] then
			local a = (u - k0[1]) / (k1[1] - k0[1])
			a = a * a * (3 - 2 * a)
			return k0[2] + (k1[2] - k0[2]) * a
		end
	end
	return keys[#keys][2]
end

-- Cuándo toca el siguiente: cada 7-12 s uno al azar (sin repetir), y girar el caldero como mucho cada tres
local move, moveName, moveAt, nextEvent
local queued
local nextAt = os.clock() + 5
local sinceSpin = 0
local function start(name, now)
	move, moveName, moveAt, nextEvent = MOVES[name], name, now, 1
	sinceSpin = name == "spin" and 0 or sinceSpin + 1
	nextAt = now + move.len + 7 + math.random() * 5
end
local function schedule(now)
	if move then
		return
	end
	if queued then
		start(queued, now)
		queued = nil
	elseif now >= nextAt then
		local name = sinceSpin >= 2 and "spin" or ({"spin", "cackle", "peek"})[math.random(3)]
		if name == moveName then
			name = name == "spin" and "peek" or "spin"
		end
		start(name, now)
	end
end

-- ¡Has fusionado! Lo celebra (en cuanto acabe lo que esté haciendo)
Remote.OnClientEvent:Connect(function(kind)
	if kind == "Fused" then
		queued = "spin"
	end
end)
local dbg = Instance.new("BindableEvent")
dbg.Name = "BrujaDebug"
dbg.Parent = script
dbg.Event:Connect(function(name)
	if MOVES[name] then
		queued = name
	end
end)

---------- Muelles (lo que va con retraso: la punta del sombrero y la capa) ----------
local function spring(s, target, k, c, dt)
	s.v += (k * (target - s.x) - c * s.v) * dt
	s.x += s.v * dt
	return s.x
end
local tipPitch, tipRoll, capeLag = {x = 0, v = 0}, {x = 0, v = 0}, {x = 0, v = 0}

-- La mirada: te sigue si estás cerca; si no, de vez en cuando echa un vistazo alrededor
local lookYaw, lookPitch = 0, 0
local glanceYaw, glanceUntil, nextGlance = 0, 0, os.clock() + 4
local nextBlink, blinkAt = os.clock() + 2, -1

local P = {}
local function resetPose()
	P.yaw, P.lean, P.roll, P.hy, P.hp, P.hr = 0, 0, 0, 0, 0, 0
	P.stir, P.lift, P.back, P.swing, P.radius = 1, 0, 0, 0, STIR_R
	P.jaw, P.brow, P.laugh, P.sniff, P.look = 0, 0, 0, 0, 1
end

local parts, cfs = {}, {}
local function put(list, xf)
	for _, p in list do
		table.insert(parts, p)
		table.insert(cfs, xf * rest[p])
	end
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local now = os.clock()
	schedule(now)
	resetPose()
	if move then
		local u = now - moveAt
		if u >= move.len then
			move = nil
		else
			for field, keys in move.keys do
				P[field] = curve(keys, u)
			end
			local ev = move.events[nextEvent]
			if ev and u >= ev[1] then
				nextEvent += 1
				EVENTS[ev[2]](now)
			end
		end
	end

	-- remover: el cuerpo acompaña al remo (empuja, tira y se balancea con cada vuelta)
	theta += dt * STIR_SPEED * P.stir
	local s = math.min(P.stir, 1)
	local st, ct = math.sin(theta), math.cos(theta)
	P.yaw += 5 * st * s
	P.lean += 3 * ct * s
	P.roll += 1.5 * st * s
	P.hy -= 2.5 * st * s
	P.hr += 2 * math.sin(theta + 1) * s
	-- respiración, risa (tiembla entera) y olfateo
	local breath = math.sin(now * 1.7)
	P.lean += 0.8 * breath
	local bob = 0.035 * breath + P.laugh * 0.05 * math.sin(now * 29)
	P.roll += P.laugh * 1.6 * math.sin(now * 23)
	P.hr += P.laugh * 3 * math.sin(now * 17)
	P.jaw = math.max(P.jaw, P.laugh * (0.55 + 0.45 * math.sin(now * 21)))
	P.hp += P.sniff * 3 * math.sin(now * 17)

	-- mirada
	local ty, tp = 0, 0
	local char = player.Character
	local ph = char and char:FindFirstChild("Head")
	local d = ph and ph.Position - NECK
	if d and flat(d).Magnitude < 26 then
		ty = -math.deg(math.atan2(d:Dot(RIGHT), d:Dot(FWD)))
		tp = -math.deg(math.atan2(d.Y, flat(d).Magnitude))
		ty, tp = math.clamp(ty, -60, 60), math.clamp(tp, -22, 22)
	else
		if now >= nextGlance then
			glanceYaw = (math.random() < 0.5 and -1 or 1) * (20 + math.random() * 20)
			glanceUntil = now + 1.4 + math.random()
			nextGlance = glanceUntil + 5 + math.random() * 5
		end
		ty = now < glanceUntil and glanceYaw or 0
	end
	local k = 1 - math.exp(-5 * dt)
	lookYaw += (ty - lookYaw) * k
	lookPitch += (tp - lookPitch) * k
	P.hy += lookYaw * P.look
	P.hp += lookPitch * P.look

	-- muelles
	local tp2 = spring(tipPitch, P.hp + P.lean, 70, 6, dt)
	local tr2 = spring(tipRoll, P.hr + P.roll, 70, 6, dt)
	local cl = spring(capeLag, P.lean, 40, 7, dt)

	-- parpadeo
	if now >= nextBlink then
		blinkAt = now
		nextBlink = now + 2.2 + math.random() * 3.5
		if math.random() < 0.2 then
			nextBlink = now + 0.3 -- (a veces dos seguidos)
		end
	end
	local blink = math.clamp(1 - math.abs(now - blinkAt - 0.07) / 0.07, 0, 1)

	-- caldero: gira dos vueltas tras el golpe (rápido al principio, frenando) bamboleándose; quieto, casi nada
	local phi, tilt = 0, rad(0.4) * math.sin(now * 2.3)
	local spinK
	if spinAt then
		spinK = (now - spinAt) / SPIN_TIME
		if spinK >= 1 then
			spinAt, spinK = nil, nil
		else
			phi = 2 * TAU * (1 - (1 - spinK) ^ 3)
			tilt += rad(4.5) * (1 - spinK) ^ 2
		end
	end
	local flash = math.exp(-(now - flashAt) * 2.5)
	if brewLight then
		brewLight.Brightness = BREW_BRIGHT + 3 * flash + (spinK and 0.8 * (1 - spinK) or 0)
	end

	-- ¿se ve? (lejos no se mueve nada: solo pasa el tiempo)
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - POT).Magnitude > DRAW_DISTANCE then
		return
	end

	table.clear(parts)
	table.clear(cfs)
	-- cuerpo
	local hip = CFrame.new(0, bob, 0) * rotAbout(WAIST, axis(Y, rad(P.yaw)) * axis(RIGHT, -rad(P.lean)) * axis(FWD, rad(P.roll)))
	put(TORSO, hip)
	put(SKIRT, rotAbout(WAIST, axis(Y, rad(P.yaw * 0.35)) * axis(RIGHT, -rad(P.lean * 0.2)) * axis(FWD, rad(P.roll * 0.4))))
	put(CAPE, hip * rotAbout(CAPE_TOP, axis(CAPE_AXIS, rad((cl - P.lean) * 1.2 + 2.5 * math.sin(now * 1.3)))))
	local headXf = hip * rotAbout(NECK, axis(Y, rad(P.hy)) * axis(RIGHT, -rad(P.hp)) * axis(FWD, rad(P.hr)))
	put(HEAD, headXf)
	put(JAW, headXf * CFrame.new(0, -0.14 * P.jaw, 0))
	put(BROWS, headXf * CFrame.new(0, 0.09 * P.brow, 0))
	local pitchLag, rollLag = rad((tp2 - P.hp - P.lean) * 1.3 + 2 * math.sin(now * 0.9)), rad((tr2 - P.hr - P.roll) * 1.3 + 3 * math.sin(now * 1.1))
	local hatXf = headXf * rotAbout(HAT_BASE, axis(FWD, rollLag * 0.15) * axis(RIGHT, pitchLag * 0.15))
	put(HAT, hatXf)
	local tip1 = hatXf * rotAbout(J1, axis(FWD, rollLag) * axis(RIGHT, pitchLag))
	put(TIP1, tip1)
	put(TIP2, tip1 * rotAbout(J2, axis(FWD, rollLag * 0.8) * axis(RIGHT, pitchLag * 0.8)))
	for e, size in eyeSize do
		e.Size = Vector3.new(size.X, size.Y * (1 - 0.85 * blink), size.Z)
	end

	-- remo: la pala da vueltas en el brebaje y el agarre hace un círculo pequeño con ella
	local ang = theta + P.swing
	local dir = FWD * math.cos(ang) + RIGHT * math.sin(ang)
	local blade = Vector3.new(BREW.X, BLADE0.Y, BREW.Z) + dir * P.radius + Y * P.lift
	local grip = GRIP0 + dir * 0.33 - FWD * P.back + Y * P.lift * 0.75
	local R = CFrame.lookAt(blade, grip)
	for _, e in OAR do
		table.insert(parts, e[1])
		table.insert(cfs, R * e[2])
	end
	-- brazos: IK de dos huesos desde el hombro (que va con el cuerpo) hasta la mano (que va con el remo)
	for _, a in arms do
		local handCF = R * a.grip
		local target = handCF.Position
		local sh = hip * a.shoulder
		local pole = hip:VectorToWorldSpace(a.pole)
		local to = target - sh
		local dist = math.clamp(to.Magnitude, math.abs(a.lu - a.lf) + 0.01, a.lu + a.lf - 0.01)
		local along = to.Unit
		local x = (a.lu ^ 2 - a.lf ^ 2 + dist ^ 2) / (2 * dist)
		local h = math.sqrt(math.max(0, a.lu ^ 2 - x ^ 2))
		local side = pole - along * pole:Dot(along)
		side = side.Magnitude > 1e-4 and side.Unit or pole
		local elbow = sh + along * x + side * h
		local U, F = CFrame.lookAt(sh, elbow, side), CFrame.lookAt(elbow, target, side)
		for _, e in a.upper do
			table.insert(parts, e[1])
			table.insert(cfs, U * e[2])
		end
		for _, e in a.fore do
			table.insert(parts, e[1])
			table.insert(cfs, F * e[2])
		end
		table.insert(parts, a.hand)
		table.insert(cfs, handCF)
	end

	-- caldero
	local wob = FWD * math.cos(phi * 1.5) + RIGHT * math.sin(phi * 1.5)
	local potXf = rotAbout(PIVOT, axis(wob, tilt) * axis(Y, phi))
	put(POT_PARTS, potXf)
	-- burbujas: crecen y revientan (hierven más mientras gira)
	local boil = spinK and 1.8 or 0.55
	for i, b in bubbles do
		local p = (now * boil + i * 0.37) % 1
		local grow = p < 0.88 and 0.35 + 0.95 * p / 0.88 or 1.3 * (1 - (p - 0.88) / 0.12)
		b.Size = baseSize[b] * math.max(grow, 0.05)
		table.insert(parts, b)
		table.insert(cfs, potXf * CFrame.new(0, 0.12 * p, 0) * rest[b])
	end
	-- gotas: se hinchan colgando del chorreón, caen y salpican
	for i, g in drops do
		local len = 2.6 + (i % 3) * 0.7
		local p = ((now + i * 0.83) % len) / len
		local base = potXf * rest[g]
		local fall = base.Position.Y - GROUND - 0.15
		local size, yoff, alpha = baseSize[g], 0, 0
		if p < 0.72 then
			local q = p / 0.72
			size = Vector3.new(size.X * (0.55 + 0.5 * q), size.Y * (0.55 + 0.9 * q), size.Z * (0.55 + 0.5 * q))
			yoff = -0.2 * q
		elseif p < 0.86 then
			local q = (p - 0.72) / 0.14
			size = Vector3.new(size.X * 0.85, size.Y * 1.5, size.Z * 0.85)
			yoff = -0.2 - (fall - 0.2) * q * q
		else
			local q = (p - 0.86) / 0.14
			size = Vector3.new(size.X * (1 + 1.6 * q), size.Y * 0.18, size.Z * (1 + 1.6 * q))
			yoff = -fall
			alpha = q
		end
		g.Size = size
		g.Transparency = alpha
		table.insert(parts, g)
		table.insert(cfs, CFrame.new(0, yoff, 0) * (alpha > 0 and CFrame.new(base.Position) or base))
	end

	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
