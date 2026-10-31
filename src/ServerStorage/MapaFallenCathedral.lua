-- Mapa del Tower Defense "Fallen Cathedral" (roster heroes: acólitos, bardos, clérigos, héroes, valquirias,
-- hechiceras, el Campeón y el Elegido). Las ruinas de una ciudad sagrada caída en la oscuridad: los héroes llegan por
-- la Puerta del Alba (oeste, dorada), cruzan plazas en ruinas con columnas rotas, un cementerio de ángeles y la grieta
-- del abismo (morada, con un puente), hasta la catedral encantada (este), la casa a defender.
-- Uso: require(game.ServerStorage.MapaFallenCathedral).build()
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local MARBLE = rgb(206, 200, 214)
local STONE = rgb(120, 112, 136)
local STONE_D = rgb(84, 78, 100)
local GOLD = rgb(255, 205, 90)
local PURPLE = rgb(190, 100, 255)
local ABYSS = rgb(150, 40, 255)

local M_ = {}

function M_.build()
	local B = L.new("FallenCathedral", CFrame.new(1400, 2, 1600), {seed = 53, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Grass, 24)
	for _ = 1, 26 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-118, 120), rng:NextNumber(8, 18), M.Grass, rng:NextNumber() < 0.5 and M.LeafyGrass or M.Ground)
	end
	-- la grieta del abismo (de norte a sur por x = 5): honda, con resplandor morado en el fondo
	local gx = 5
	B:fillBlock(gx, -12, 0, 20, 30, 600, M.Air)
	-- paredes de basalto (oscuras, para que resalte el resplandor) con bordes rotos
	for s = -1, 1, 2 do
		B:fillBlock(gx + s * 11, -14, 0, 3, 24, 600, M.Basalt)
	end
	for z = -290, 290, 10 do
		for s = -1, 1, 2 do
			B:fillBall(gx + s * (10 + rng:NextNumber(-1.5, 1.5)), -3, z, rng:NextNumber(2.5, 4), M.Basalt)
		end
	end
	local abyss = B:part({Name = "Abismo", Size = V(18, 1, 600), CFrame = B:cf(gx, -14, 0), Material = M.Neon, Color = ABYSS, CanCollide = false, CastShadow = false}, B.F.TDS)
	for z = -125, 125, 25 do
		local l = B:deco({Name = "Luz", Size = V(1, 1, 1), CFrame = B:cf(gx, -6, z), Transparency = 1}, B.F.TDS)
		B:light(l, ABYSS, 30, 3.5)
		B:emitter(l, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(rgb(230, 140, 255)), Rate = 6, Lifetime = NumberRange.new(2, 3.5),
			Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.6, 0), LightEmission = 1,
		})
		B:emitter(l, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(150, 70, 230)), Rate = 2, Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top, LightEmission = 0.8,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1)}),
		})
	end
	task.wait()
	-- colinas y montañas alrededor
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), -152 + rng:NextNumber(-10, 6), rng:NextNumber(26, 36), rng:NextNumber(18, 32), M.Rock, M.Grass)
		B:hill(x + rng:NextNumber(-8, 8), 156 + rng:NextNumber(-6, 10), rng:NextNumber(26, 36), rng:NextNumber(16, 30), M.Rock, M.Grass)
	end
	for i = 0, 9 do
		local z = -130 + i * 29
		B:hill(-206 + rng:NextNumber(-8, 8), z, rng:NextNumber(28, 38), rng:NextNumber(20, 34), M.Rock, M.Grass)
	end
	task.wait()
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), -250 + rng:NextNumber(-20, 10), rng:NextNumber(55, 75), rng:NextNumber(60, 95), M.Rock, M.Slate)
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(55, 75), rng:NextNumber(55, 90), M.Rock, M.Slate)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 80), rng:NextNumber(60, 95), M.Rock, M.Slate)
		B:hill(320 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 80), rng:NextNumber(50, 80), M.Rock, M.Slate)
		task.wait()
	end

	---------- Puente sobre la grieta (antes del camino) ----------
	local bz = 55
	B:part({Name = "Puente", Size = V(32, 1.4, 12), CFrame = B:cf(gx, -0.4, bz), Material = M.Cobblestone, Color = STONE}, B.F.Suelo)
	for s = -1, 1, 2 do
		B:part({Name = "Pretil", Size = V(32, 2.2, 1.1), CFrame = B:cf(gx, 1.1, bz + s * 6.6), Material = M.Cobblestone, Color = STONE_D})
		B:part({Name = "Remate", Size = V(32.6, 0.5, 1.5), CFrame = B:cf(gx, 2.4, bz + s * 6.6), Material = M.Marble, Color = MARBLE})
		for k = -1, 1, 2 do
			B:part({Name = "Pilono", Size = V(2.4, 6, 2.4), CFrame = B:cf(gx + k * 15, 3, bz + s * 6.6), Material = M.Marble, Color = MARBLE})
			local f = B:deco({Name = "Llama", Shape = Enum.PartType.Ball, Size = V(1.4, 1.4, 1.4), CFrame = B:cf(gx + k * 15, 6.8, bz + s * 6.6), Material = M.Neon, Color = PURPLE, Transparency = 0.2})
			B:fire(f, 3, PURPLE, rgb(255, 200, 255))
			B:light(f, PURPLE, 20, 1.6):AddTag("Flicker")
		end
	end
	B:part({Name = "Arco", Size = V(8, 14, 12), CFrame = B:cf(gx, -8, bz), Material = M.Cobblestone, Color = STONE_D})
	B:flush()

	---------- Camino (losas de mármol con borde oscuro) ----------
	local ctrl = {
		{-168, -10}, {-130, -12}, {-108, -40}, {-118, -76}, {-88, -96}, {-52, -82}, {-46, -46}, {-68, -14}, {-74, 22}, {-52, 50},
		{-24, 55}, {5, 55}, {34, 55}, {60, 30}, {52, -6}, {28, -32}, {36, -72}, {70, -92}, {104, -72}, {112, -36}, {96, -2},
		{100, 22}, {104, 30},
	}
	B:path(ctrl, {mat = M.Pavement, color = rgb(196, 188, 200), edgeMat = M.Slate, edgeColor = rgb(72, 66, 88), edge = 2})
	B:arrows(7, GOLD)
	B:flush()

	---------- Llegada ----------
	B:arrival(-22, 104, 0, "Fallen Cathedral")
	B:bounds(-172, -120, 172, 122)

	---------- La catedral encantada (la casa a defender) ----------
	local cx, cz = 142, 30
	local cath = B:kit("Cathedral", cx, cz, 90, 1.25, B.F.Arq)
	if cath then
		local cf, size = cath:GetBoundingBox()
		local glow = B:deco({Name = "Resplandor", Size = V(4, 4, 4), CFrame = CFrame.new(cf.Position), Transparency = 1})
		B:light(glow, PURPLE, 70, 2.6)
		local ghosts = B:deco({Name = "Almas", Size = V(size.X, size.Y * 0.6, size.Z), CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.15, 0)), Transparency = 1})
		B:emitter(ghosts, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(200, 150, 255)), Rate = 4, Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1)}),
		})
		B:emitter(ghosts, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PURPLE), Rate = 10, Lifetime = NumberRange.new(2, 4),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.6, 0), LightEmission = 1,
		})
	else
		-- (sin la malla: una catedral de piezas)
		B:tower(cx, cz - 16, 8, 50, {window = PURPLE, flag = PURPLE})
		B:tower(cx, cz + 16, 8, 50, {window = PURPLE, flag = PURPLE})
		B:part({Name = "Nave", Size = V(40, 30, 26), CFrame = B:cf(cx + 14, 15, cz), Material = M.Cobblestone, Color = STONE})
		B:gable(B:cf(cx + 14, 30, cz, 90), 26, 40, 14, rgb(46, 40, 82))
	end
	table.insert(B.avoid, {cx, cz, 44})
	-- escalinata y braseros a la entrada
	for k = 0, 2 do
		B:part({Name = "Escalon", Size = V(3, 0.6, 24 - k * 3), CFrame = B:cf(cx - 38 + k * 2.5, 0.3 + k * 0.6, cz), Material = M.Marble, Color = MARBLE})
	end
	for s = -1, 1, 2 do
		local p = B:part({Name = "Brasero", Size = V(2.4, 5, 2.4), CFrame = B:cf(cx - 36, 2.5, cz + s * 14), Material = M.Marble, Color = MARBLE})
		local f = B:deco({Name = "Llama", Shape = Enum.PartType.Ball, Size = V(1.6, 1.6, 1.6), CFrame = B:cf(cx - 36, 5.6, cz + s * 14), Material = M.Neon, Color = PURPLE, Transparency = 0.25})
		B:fire(f, 4, PURPLE, rgb(255, 210, 255))
		B:light(f, PURPLE, 26, 2):AddTag("Flicker")
	end
	B:flush()

	---------- La Puerta del Alba (por donde llegan los héroes) ----------
	local px, pz = -164, -10
	local gate = B:cf(px, 0, pz, -90)
	for s = -1, 1, 2 do
		B:part({Name = "Pilar", Size = V(4, 26, 4), CFrame = gate * CF(s * 9, 13, 0), Material = M.Marble, Color = MARBLE})
		B:part({Name = "Basa", Size = V(5.6, 2.4, 5.6), CFrame = gate * CF(s * 9, 1.2, 0), Material = M.Marble, Color = rgb(230, 222, 200)})
		B:part({Name = "Capitel", Size = V(5.4, 1.6, 5.4), CFrame = gate * CF(s * 9, 26.6, 0), Material = M.Marble, Color = GOLD})
		B:banner(gate * CF(s * 9, 22, -2.2), 3.2, 9, rgb(245, 240, 225), GOLD)
	end
	B:part({Name = "Dintel", Size = V(24, 3, 5), CFrame = gate * CF(0, 28.8, 0), Material = M.Marble, Color = MARBLE})
	B:part({Name = "Frontis", Size = V(14, 5, 4.6), CFrame = gate * CF(0, 32.6, 0), Material = M.Marble, Color = MARBLE})
	local sun = B:deco({Name = "Sol", Shape = Enum.PartType.Cylinder, Size = V(0.6, 5, 5), CFrame = gate * CF(0, 32.6, -2.4) * ANG(0, rad(90), 0), Material = M.Neon, Color = GOLD}, nil)
	B:light(sun, GOLD, 18, 0.8)
	local veil = B:deco({Name = "VeloDorado", Size = V(14, 26, 0.4), CFrame = gate * CF(0, 14, 0), Material = M.Neon, Color = rgb(255, 225, 140), Transparency = 0.62})
	B:light(veil, GOLD, 30, 1.1)
	B:emitter(veil, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1)), Rate = 25, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(0.6, 0), LightEmission = 1,
	})
	-- estatuas de héroes doradas a los lados
	for s = -1, 1, 2 do
		B:kit("Statue", px + 8, pz + s * 18, -90, 1.6, nil, nil, {color = rgb(230, 190, 90)})
	end
	table.insert(B.avoid, {px, pz, 16})
	B:flush()

	---------- Ruinas: columnas rotas, arcos y muros caídos ----------
	local function column(x, z, h, broken)
		if not B:free(x, z, 4) then
			return
		end
		local y = B:groundY(x, z)
		local base = B:cf(x, y, z)
		B:part({Name = "Basa", Size = V(4.4, 1.4, 4.4), CFrame = base * CF(0, 0.7, 0), Material = M.Marble, Color = MARBLE})
		B:part({Name = "Fuste", Shape = Enum.PartType.Cylinder, Size = V(h, 3, 3), CFrame = base * CF(0, 1.4 + h / 2, 0) * ANG(0, 0, rad(90)), Material = M.Marble, Color = MARBLE:Lerp(STONE, rng:NextNumber(0, 0.35))})
		if broken then
			B:part({Name = "Rotura", Size = V(2.6, 1.4, 2.6), CFrame = base * CF(0.3, 1.4 + h + 0.2, 0) * ANG(rad(25), rad(30), rad(15)), Material = M.Marble, Color = MARBLE})
			-- el trozo que cayó, tumbado al lado
			local a = rng:NextNumber(0, math.pi * 2)
			local fx, fz = x + math.cos(a) * 5, z + math.sin(a) * 5
			if B:free(fx, fz, 2) then
				B:part({Name = "Caido", Shape = Enum.PartType.Cylinder, Size = V(rng:NextNumber(4, 7), 2.9, 2.9), CFrame = B:cf(fx, B:groundY(fx, fz) + 1.3, fz, math.deg(a)), Material = M.Marble, Color = MARBLE:Lerp(STONE, 0.2)})
			end
		else
			B:part({Name = "Capitel", Size = V(4.2, 1.4, 4.2), CFrame = base * CF(0, 1.4 + h + 0.7, 0), Material = M.Marble, Color = MARBLE})
		end
		table.insert(B.avoid, {x, z, 5})
	end
	-- columnatas a lo largo del camino (a distancia) y sueltas
	local pts = B.pathPts
	for i = 3, #pts - 4, 5 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local nrm = Vector2.new(-dir.Y, dir.X)
		for _, s in {-1, 1} do
			if rng:NextNumber() < 0.4 then
				local at = p + nrm * s * rng:NextNumber(18, 24)
				column(at.X, at.Y, rng:NextNumber(7, 16), rng:NextNumber() < 0.6)
			end
		end
	end
	B:flush()
	for _, a in {{-90, 60, 30}, {-130, 50, 80}, {70, 90, 0}, {-20, -100, 90}, {140, -95, 0}} do
		if B:free(a[1], a[2], 12) then
			B:kit("Arch", a[1], a[2], a[3], 0.8)
			table.insert(B.avoid, {a[1], a[2], 18})
		end
	end
	for _, r in {{-140, -100, 20}, {-30, -10, 70}, {80, 60, 110}, {130, -60, 10}, {-100, 95, 0}, {60, -50, 45}} do
		if B:free(r[1], r[2], 8) then
			local len = rng:NextNumber(12, 18)
			local look = B:cf(r[1], B:groundY(r[1], r[2]), r[2], r[3])
			for k = 0, 4 do
				local hh = 9 * (1 - math.abs(k - 1.5) * 0.25) + rng:NextNumber(-2, 2)
				B:part({Name = "Muro", Size = V(len / 5, hh, 2.6), CFrame = look * CF(-len / 2 + (k + 0.5) * len / 5, hh / 2, 0), Material = M.Cobblestone, Color = STONE:Lerp(STONE_D, rng:NextNumber())})
			end
			-- ventana gótica rota con vidriera
			local win = B:deco({Name = "Vidriera", Size = V(2.4, 4.4, 0.3), CFrame = look * CF(0, 5, -1.4), Material = M.Neon, Color = ({PURPLE, GOLD, rgb(110, 200, 255)})[rng:NextInteger(1, 3)]})
			B:light(win, win.Color, 12, 1)
			table.insert(B.avoid, {r[1], r[2], 12})
		end
	end
	B:flush()

	---------- Plaza con fuente y cementerio de ángeles ----------
	local function prop(name, x, z, yaw, scale, gap, opts)
		if B:free(x, z, gap or 3) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale, nil, nil, opts)
		end
	end
	-- plaza enlosada alrededor de la fuente (entre los dos tramos del oeste)
	local fx, fz = -90, 0
	if B:free(fx, fz, 10) then
		B:part({Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = V(0.6, 34, 34), CFrame = B:cf(fx, -0.2, fz, 0, 0, 90), Material = M.Pavement, Color = rgb(170, 162, 178)}, B.F.Suelo)
		B:kit("Fountain", fx, fz, 0, 1)
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			prop("Bench", fx + math.cos(a) * 13, fz + math.sin(a) * 13, -math.deg(a) - 90, 1, 1)
		end
		table.insert(B.avoid, {fx, fz, 18})
	end
	-- cementerio de ángeles (dentro del lazo del este)
	local gcx, gcz = 72, -50
	local graves = {"GraveCross", "GraveRound", "GraveObelisk", "GraveSlab", "GraveTomb"}
	for k = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, 14)
		prop(graves[rng:NextInteger(1, #graves)], gcx + math.cos(a) * r, gcz + math.sin(a) * r, rng:NextNumber(-15, 15) - 90, rng:NextNumber(0.9, 1.2), 2)
	end
	for _, a in {{gcx - 8, gcz + 6}, {gcx + 8, gcz - 6}, {-120, -50}, {-60, 80}, {40, 100}, {120, 80}} do
		local m = prop(L.kitModel("AngelStatue") and "AngelStatue" or "Statue", a[1], a[2], rng:NextNumber(0, 360), 1.3, 3)
		if m then
			table.insert(B.avoid, {a[1], a[2], 5})
		end
	end
	-- velas encendidas entre las tumbas
	for k = 1, 12 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 15)
		local x, z = gcx + math.cos(a) * r, gcz + math.sin(a) * r
		if B:free(x, z, 1) then
			local y = B:groundY(x, z)
			local h = rng:NextNumber(0.6, 1.4)
			B:deco({Name = "Vela", Size = V(0.35, h, 0.35), CFrame = B:cf(x, y + h / 2, z), Material = M.SmoothPlastic, Color = rgb(240, 236, 220)})
			local f = B:deco({Name = "Llama", Size = V(0.25, 0.4, 0.25), CFrame = B:cf(x, y + h + 0.2, z), Material = M.Neon, Color = rgb(255, 190, 90)})
			if k % 3 == 0 then
				B:light(f, rgb(255, 180, 90), 8, 0.8):AddTag("Flicker")
			end
		end
	end
	B:flush()

	---------- Vegetación y detalles ----------
	local TREES = {"DeadTreeA", "DeadTreeB", "DeadTreeC", "CypressA", "CypressB", "PineA"}
	local function tree(x, z, s)
		B:kit(TREES[rng:NextInteger(1, #TREES)], x, z, rng:NextNumber(0, 360), s or rng:NextNumber(0.8, 1.2))
	end
	for x = -180, 110, 16 do
		tree(x + rng:NextNumber(-5, 5), -130 + rng:NextNumber(-8, 4))
		tree(x + rng:NextNumber(-5, 5), 134 + rng:NextNumber(-4, 8))
	end
	for z = -120, 125, 15 do
		if math.abs(z + 10) > 20 then
			tree(-184 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5))
		end
	end
	B:flush()
	local placed = 0
	for _ = 1, 500 do
		if placed >= 22 then
			break
		end
		local x, z = rng:NextNumber(-165, 110), rng:NextNumber(-115, 118)
		local inView = x > -60 and x < 20 and z > 40
		if math.abs(x - gx) > 16 and not inView and B:free(x, z, 15) then
			tree(x, z, rng:NextNumber(0.7, 1))
			table.insert(B.avoid, {x, z, 9})
			placed += 1
		end
	end
	local SMALL = {"BushA", "BushB", "RockA", "RockC", "Mushrooms", "BushA", "JackOLantern"}
	placed = 0
	for _ = 1, 600 do
		if placed >= 70 then
			break
		end
		local x, z = rng:NextNumber(-168, 110), rng:NextNumber(-118, 118)
		if math.abs(x - gx) > 13 and B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1.2), nil, nil, {noCollide = true})
			placed += 1
		end
	end
	B:flush()
	-- farolas dobles a lo largo del camino
	for i = 4, #pts - 3, 4 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local side = Vector2.new(-dir.Y, dir.X) * ((i // 4) % 2 == 0 and 1 or -1)
		local at = p + side * (B.width / 2 + 2.2)
		if math.abs(at.X - gx) > 11 then
			B:kit(i % 3 == 0 and "LampDouble" or "PathLantern", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)))
		end
	end
	-- almas que flotan (luces fantasma)
	for k = 1, 14 do
		local x, z = rng:NextNumber(-150, 100), rng:NextNumber(-100, 100)
		if B:free(x, z, 4) then
			local w = B:deco({Name = "Alma", Shape = Enum.PartType.Ball, Size = V(0.8, 0.8, 0.8), CFrame = B:cf(x, rng:NextNumber(5, 12), z), Material = M.Neon, Color = rgb(200, 170, 255), Transparency = 0.2})
			B:light(w, rgb(190, 150, 255), 12, 1)
			B:emitter(w, {
				Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(200, 170, 255)), Rate = 4, Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1, 0), LightEmission = 1,
				Transparency = NumberSequence.new(0.4, 1),
			})
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 240, rgb(180, 150, 200), rgb(255, 210, 150), 5, 6)
	return B:finish()
end

return M_
