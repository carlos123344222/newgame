-- Mapa del Tower Defense "Witch Bayou" (roster hunters: tramperos, exploradores ocultos, cazavampiros, rastreadores
-- con farol, cazabrujas, Van Gloom y el Gran Inquisidor). Un pantano de noche: una pasarela de tablones serpentea
-- entre charcas con nenúfares, juncos y cipreses con musgo, desde el campamento de los cazadores (suroeste) hasta la
-- cabaña de la bruja sobre pilotes en su laguna (noreste), la casa a defender.
-- Uso: require(game.ServerStorage.MapaWitchBayou).build()
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WATER = rgb(36, 70, 58)
local PLANK = rgb(120, 88, 60)
local POST = rgb(66, 48, 34)
local TOXIC = rgb(120, 255, 110)
local WARM = rgb(255, 180, 90)

local M_ = {}

function M_.build()
	local B = L.new("WitchBayou", CFrame.new(2300, 2, 800), {seed = 23, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Grass, 24)
	for _ = 1, 30 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-120, 120), rng:NextNumber(10, 22), M.Grass, rng:NextNumber() < 0.6 and M.Mud or M.LeafyGrass)
	end
	task.wait()
	-- charcas (tres las cruza la pasarela)
	local ponds = {
		{-50, 12, 17}, {-132, -24, 15}, {98, 22, 13}, {62, -12, 16}, {128, -98, 27}, {-152, 48, 12}, {-14, 82, 16}, {104, 98, 11}, {-40, -102, 14},
	}
	for _, p in ponds do
		B:pond(p[1], p[2], p[3], WATER)
	end
	task.wait()
	-- lomas alrededor y montañas bajas a lo lejos
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), -152 + rng:NextNumber(-10, 6), rng:NextNumber(24, 34), rng:NextNumber(14, 26), M.Ground, M.LeafyGrass)
		B:hill(x + rng:NextNumber(-8, 8), 156 + rng:NextNumber(-6, 10), rng:NextNumber(24, 34), rng:NextNumber(14, 26), M.Ground, M.LeafyGrass)
	end
	for i = 0, 9 do
		local z = -130 + i * 29
		B:hill(-206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(16, 28), M.Ground, M.LeafyGrass)
		B:hill(206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(16, 28), M.Ground, M.LeafyGrass)
	end
	task.wait()
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), -250 + rng:NextNumber(-20, 10), rng:NextNumber(55, 70), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(55, 70), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		B:hill(330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		task.wait()
	end

	---------- Pasarela (el camino) ----------
	local ctrl = {
		{-168, 92}, {-132, 90}, {-110, 70}, {-114, 40}, {-136, 14}, {-140, -22}, {-120, -52}, {-86, -62}, {-62, -38}, {-56, -4},
		{-32, 24}, {0, 32}, {26, 12}, {32, -24}, {56, -46}, {86, -32}, {100, 4}, {96, 40}, {112, 72}, {142, 66}, {156, 34},
		{150, -2}, {136, -32}, {130, -64},
	}
	B:path(ctrl, {flat = true, mat = M.WoodPlanks, color = PLANK, edgeMat = M.Wood, edgeColor = POST, edge = 1.6})
	B:decks(PLANK, POST)
	B:arrows(7, rgb(150, 255, 120))
	B:flush()
	-- postes de la pasarela en tierra, cada pocos tramos, con faroles
	local pts = B.pathPts
	for i = 3, #pts - 2, 3 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local nrm = Vector2.new(-dir.Y, dir.X)
		if not B:inPond(p.X, p.Y, 4) then
			for s = -1, 1, 2 do
				local at = p + nrm * s * (B.width / 2 + 0.9)
				B:part({Name = "Poste", Size = V(0.7, 2.4, 0.7), CFrame = B:cf(at.X, 1, at.Y), Material = M.Wood, Color = POST, CanCollide = false})
			end
		end
		if i % 6 == 0 then
			local at = p + nrm * ((i // 6) % 2 == 0 and 1 or -1) * (B.width / 2 + 2.2)
			if B:inPond(at.X, at.Y, 2) then
				local pole = B:part({Name = "Farol", Size = V(0.5, 7, 0.5), CFrame = B:cf(at.X, 1.5, at.Y), Material = M.Wood, Color = POST, CanCollide = false})
				local lamp = B:deco({Name = "Luz", Size = V(0.9, 1.2, 0.9), CFrame = B:cf(at.X, 5.4, at.Y), Material = M.Neon, Color = TOXIC})
				B:light(lamp, TOXIC, 18, 1.4)
			else
				B:kit("PathLantern", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)))
			end
		end
	end
	B:flush()

	---------- Llegada ----------
	B:arrival(40, 102, 0, "Witch Bayou")
	B:bounds(-172, -122, 172, 122)

	---------- La cabaña de la bruja (la casa a defender) ----------
	local hx, hz = 128, -94
	local hut = B:kit("WitchHut", hx, hz, 180, 1.15, B.F.Arq, -3.5)
	if hut then
		local cf, size = hut:GetBoundingBox()
		local glow = B:deco({Name = "Brillo", Size = V(4, 4, 4), CFrame = cf * CF(0, -size.Y * 0.05, 0), Transparency = 1})
		B:light(glow, TOXIC, 40, 2.5)
		B:emitter(glow, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(TOXIC), Rate = 10, Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.5, 0), LightEmission = 1,
		})
	end
	table.insert(B.avoid, {hx, hz, 34})
	-- caldero burbujeante junto a la orilla
	local function cauldron(x, z, s)
		local y = B:groundY(x, z)
		local base = B:cf(x, y, z)
		B:part({Name = "Caldero", Shape = Enum.PartType.Ball, Size = V(4.2, 3.6, 4.2) * s, CFrame = base * CF(0, 1.9 * s, 0), Material = M.Metal, Color = rgb(30, 28, 34)})
		B:part({Name = "Borde", Shape = Enum.PartType.Cylinder, Size = V(0.5, 3.8, 3.8) * s, CFrame = base * CF(0, 3.3 * s, 0) * ANG(0, 0, rad(90)), Material = M.Metal, Color = rgb(40, 38, 44)})
		local brew = B:deco({Name = "Pocion", Shape = Enum.PartType.Cylinder, Size = V(0.3, 3.3, 3.3) * s, CFrame = base * CF(0, 3.35 * s, 0) * ANG(0, 0, rad(90)), Material = M.Neon, Color = TOXIC})
		B:light(brew, TOXIC, 18, 2)
		B:emitter(brew, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(TOXIC), Rate = 14, Lifetime = NumberRange.new(0.6, 1.4),
			Speed = NumberRange.new(1.5, 3.5), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.5, 0.1), LightEmission = 1,
		})
		B:emitter(brew, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(100, 200, 100)), Rate = 3, Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(1.5, 4),
			Transparency = NumberSequence.new(0.5, 1), LightEmission = 0.5,
		})
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			B:part({Name = "Pata", Size = V(0.5, 1.4, 0.5) * s, CFrame = base * CF(math.cos(a) * 1.6 * s, 0.6 * s, math.sin(a) * 1.6 * s), Material = M.Metal, Color = rgb(30, 28, 34)})
		end
		local f = B:deco({Name = "Fuego", Size = V(1, 1, 1), CFrame = base * CF(0, 0.4, 0), Transparency = 1})
		B:fire(f, 3 * s)
	end
	cauldron(108, -70, 1.1)
	cauldron(150, -66, 0.8)
	B:flush()

	---------- Campamento de los cazadores (de donde salen) ----------
	B:tent(-150, 110, 0, 8, 10, 6, rgb(90, 110, 70), rgb(160, 140, 100))
	B:tent(-128, 112, -10, 7, 9, 5.5, rgb(120, 70, 50), rgb(170, 150, 110))
	B:tent(-160, 68, 80, 7, 9, 5.5, rgb(90, 110, 70), rgb(160, 140, 100))
	B:campfire(-142, 70)
	table.insert(B.avoid, {-142, 70, 12})
	local function prop(name, x, z, yaw, scale, gap, opts)
		if B:free(x, z, gap or 3) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale, nil, nil, opts)
		end
	end
	prop("Cart", -126, 66, 40)
	prop("NoticeBoard", -118, 104, 160)
	prop("ToxicBarrels", -164, 108, 20)
	prop("Barricade", -168, 80, 90)
	prop("Barricade", -168, 104, 90)
	-- jaulas de cazador (barrotes)
	for _, c in {{-156, 50}, {-134, 52}} do
		if B:free(c[1], c[2], 4) then
			local base = B:cf(c[1], B:groundY(c[1], c[2]), c[2], rng:NextNumber(0, 90))
			B:part({Name = "Jaula", Size = V(4.4, 0.4, 4.4), CFrame = base * CF(0, 0.2, 0), Material = M.Wood, Color = POST})
			B:part({Name = "Jaula", Size = V(4.4, 0.4, 4.4), CFrame = base * CF(0, 4.6, 0), Material = M.Wood, Color = POST})
			for k = 0, 11 do
				local side, t = k // 3, (k % 3 - 1) * 1.4
				local off = ({CF(t, 0, 2), CF(t, 0, -2), CF(2, 0, t), CF(-2, 0, t)})[side + 1]
				B:part({Name = "Barrote", Size = V(0.25, 4.2, 0.25), CFrame = base * off * CF(0, 2.4, 0), Material = M.Metal, Color = rgb(50, 48, 54)})
			end
		end
	end
	B:flush()

	---------- Chozas sobre pilotes y una barca ----------
	local function shack(x, z, yaw)
		if not B:free(x, z, 9) then
			return
		end
		local base = B:cf(x, 0, z, yaw)
		for _, c in {{-4, -3.5}, {4, -3.5}, {-4, 3.5}, {4, 3.5}} do
			B:part({Name = "Pilote", Size = V(0.8, 6, 0.8), CFrame = base * CF(c[1], 0.5, c[2]), Material = M.Wood, Color = POST})
		end
		B:part({Name = "Porche", Size = V(11, 0.5, 11), CFrame = base * CF(0, 3.2, -1), Material = M.WoodPlanks, Color = PLANK})
		B:cottage(x, z, yaw, 8, 7, 6, {y = 2.6, wall = rgb(104, 80, 58), wallMat = M.WoodPlanks, beam = POST, roof = rgb(70, 74, 60), roofMat = M.WoodPlanks, noBeams = true})
		for k = 0, 2 do
			B:part({Name = "Escalon", Size = V(3, 0.4, 1.2), CFrame = base * CF(0, 2.5 - k * 0.9, -7.2 - k * 1.1), Material = M.WoodPlanks, Color = PLANK})
		end
		table.insert(B.avoid, {x, z, 12})
	end
	shack(-92, 102, 180)
	shack(12, -96, 0)
	shack(152, 100, 200)
	shack(-150, -94, 20)
	-- barca en una charca
	local function boat(x, z, yaw)
		local base = B:cf(x, -1.3, z, yaw)
		B:part({Name = "Casco", Size = V(3, 1, 7), CFrame = base * CF(0, 0.2, 0), Material = M.WoodPlanks, Color = rgb(110, 76, 50), CanCollide = false})
		for s = -1, 1, 2 do
			B:part({Name = "Borda", Size = V(0.4, 1.2, 7.2), CFrame = base * CF(s * 1.6, 0.8, 0), Material = M.Wood, Color = POST, CanCollide = false})
		end
		B:wedge({Name = "Proa", Size = V(3.4, 1.4, 2), CFrame = base * CF(0, 0.6, -4.4) * ANG(0, math.pi, 0), Material = M.Wood, Color = POST, CanCollide = false})
		B:part({Name = "Remo", Size = V(0.25, 0.25, 6), CFrame = base * CF(1.2, 1.2, 0.5) * ANG(0, 0.5, 0.3), Material = M.Wood, Color = rgb(140, 100, 60), CanCollide = false})
		local l = B:deco({Name = "Farol", Size = V(0.7, 0.9, 0.7), CFrame = base * CF(0, 1.6, 2.6), Material = M.Neon, Color = WARM})
		B:light(l, WARM, 14, 1.2)
	end
	boat(-18, 84, 30)
	boat(64, -8, -60)
	B:flush()

	---------- Vegetación ----------
	local function tree(x, z, big)
		local name = big and "SwampTree" or ({"DeadTreeA", "DeadTreeB", "CypressA", "CypressB", "DeadTreeC"})[rng:NextInteger(1, 5)]
		B:kit(name, x, z, rng:NextNumber(0, 360), big and rng:NextNumber(0.9, 1.4) or rng:NextNumber(0.7, 1), nil, nil, {sink = 0.6})
	end
	-- borde del bosque
	for x = -180, 180, 15 do
		tree(x + rng:NextNumber(-5, 5), -130 + rng:NextNumber(-8, 4), rng:NextNumber() < 0.7)
		tree(x + rng:NextNumber(-5, 5), 132 + rng:NextNumber(-4, 8), rng:NextNumber() < 0.7)
	end
	for z = -120, 125, 14 do
		tree(-184 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5), rng:NextNumber() < 0.7)
		tree(184 + rng:NextNumber(-4, 6), z + rng:NextNumber(-5, 5), rng:NextNumber() < 0.7)
	end
	B:flush()
	-- dentro: cipreses de pantano lejos del camino (y no delante de la plataforma)
	local placed = 0
	for _ = 1, 500 do
		if placed >= 26 then
			break
		end
		local x, z = rng:NextNumber(-165, 165), rng:NextNumber(-115, 118)
		local inView = x > 0 and x < 90 and z > 45
		if not inView and not B:inPond(x, z, 2) and B:free(x, z, 15) then
			tree(x, z, rng:NextNumber() < 0.75)
			table.insert(B.avoid, {x, z, 10})
			placed += 1
		end
	end
	B:flush()
	-- juncos en las orillas, nenúfares y setas que brillan
	for _, p in ponds do
		for k = 0, math.floor(p[3] / 4) do
			local a = rng:NextNumber(0, math.pi * 2)
			local x, z = p[1] + math.cos(a) * (p[3] + 1), p[2] + math.sin(a) * (p[3] + 1)
			if B:distToPath(x, z) > B.width / 2 + 3 then
				B:reeds(x, z, 6, rng)
			end
		end
		B:lilies(p[1], p[2], p[3], math.floor(p[3] / 2), rng)
		B:flush()
	end
	local SMALL = {"Mushrooms", "BushA", "BushB", "RockA", "RockC", "Mushrooms", "BonePile", "Mound"}
	placed = 0
	for _ = 1, 600 do
		if placed >= 80 then
			break
		end
		local x, z = rng:NextNumber(-168, 168), rng:NextNumber(-118, 118)
		if not B:inPond(x, z, 1) and B:free(x, z, 3) then
			local name = SMALL[rng:NextInteger(1, #SMALL)]
			local m = B:kit(name, x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.4), nil, nil, {noCollide = true})
			-- las setas brillan
			if m and name == "Mushrooms" and rng:NextNumber() < 0.6 then
				local p = m:FindFirstChildWhichIsA("BasePart")
				if p then
					B:light(p, rgb(110, 230, 255), 8, 1)
				end
			end
			placed += 1
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 244, rgb(120, 180, 130), rgb(210, 255, 140), 8, 9)
	return B:finish()
end

return M_
