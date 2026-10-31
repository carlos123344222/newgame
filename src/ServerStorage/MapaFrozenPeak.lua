-- Mapa del Tower Defense "Frozen Peak" (roster adventurers: exploradores, pícaros ocultos, alpinistas, enanos,
-- magos con barreras, la Archimaga y sir Reginald). Un valle nevado entre montañas bajo una aurora boreal: el
-- campamento de la expedición (oeste), una vieja mina, un lago helado y, en lo alto de una loma (este), la Aguja de
-- Escarcha: la torre de hielo encantada que hay que defender. Nieva todo el rato.
-- Uso: require(game.ServerStorage.MapaFrozenPeak).build()
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local ICE = rgb(176, 222, 255)
local CYAN = rgb(120, 230, 255)
local ROCK = rgb(120, 128, 146)
local SNOW = rgb(236, 242, 252)
local WOOD = rgb(96, 66, 44)

local M_ = {}

function M_.build()
	local B = L.new("FrozenPeak", CFrame.new(2300, 2, 1600), {seed = 37, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Snow, 24)
	for _ = 1, 22 do
		B:paint(rng:NextNumber(-160, 160), rng:NextNumber(-115, 115), rng:NextNumber(8, 16), M.Snow, rng:NextNumber() < 0.5 and M.Glacier or M.Salt)
	end
	-- loma de la Aguja (este) y lomas suaves
	B:hill(138, 66, 30, 7, M.Rock, M.Snow)
	B:hill(-70, -100, 20, 6, M.Rock, M.Snow)
	B:hill(70, 105, 18, 5, M.Rock, M.Snow)
	-- lago helado (hueco poco profundo con una capa de hielo)
	B:fillCyl(-58, -1.5, 26, 4, 22, M.Air)
	B:fillCyl(-58, -3.5, 26, 1.5, 23, M.Glacier)
	local ice = B:part({Name = "Hielo", Shape = Enum.PartType.Cylinder, Size = V(0.6, 46, 46), CFrame = B:cf(-58, -1.4, 26, 0, 0, 90), Material = M.Ice, Color = rgb(170, 214, 245), Reflectance = 0.35, Transparency = 0.05}, B.F.TDS)
	B:light(ice, CYAN, 30, 0.8)
	B.ponds = {{-58, 26, 22}}
	task.wait()
	-- montañas alrededor (roca con cumbres nevadas)
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), -150 + rng:NextNumber(-10, 6), rng:NextNumber(26, 36), rng:NextNumber(22, 40), M.Rock, M.Snow)
		B:hill(x + rng:NextNumber(-8, 8), 155 + rng:NextNumber(-6, 10), rng:NextNumber(26, 36), rng:NextNumber(18, 34), M.Rock, M.Snow)
	end
	for i = 0, 9 do
		local z = -130 + i * 29
		B:hill(-200 + rng:NextNumber(-8, 8), z, rng:NextNumber(28, 38), rng:NextNumber(24, 40), M.Rock, M.Snow)
		B:hill(200 + rng:NextNumber(-8, 8), z, rng:NextNumber(28, 38), rng:NextNumber(24, 40), M.Rock, M.Snow)
	end
	task.wait()
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), -250 + rng:NextNumber(-20, 10), rng:NextNumber(60, 80), rng:NextNumber(90, 140), M.Rock, M.Snow)
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(60, 80), rng:NextNumber(80, 130), M.Rock, M.Snow)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(65, 85), rng:NextNumber(90, 140), M.Rock, M.Snow)
		B:hill(330 + rng:NextNumber(-12, 12), z, rng:NextNumber(65, 85), rng:NextNumber(90, 140), M.Rock, M.Snow)
		task.wait()
	end

	---------- Camino (tierra pisada en la nieve) ----------
	local ctrl = {
		{-162, 62}, {-122, 62}, {-96, 40}, {-100, 4}, {-126, -26}, {-112, -62}, {-72, -78}, {-40, -52}, {-30, -14}, {-6, 10},
		{26, 14}, {46, -16}, {42, -56}, {72, -82}, {106, -70}, {118, -34}, {102, 2}, {98, 36}, {118, 58}, {134, 64},
	}
	B:path(ctrl, {mat = M.Ground, color = rgb(132, 118, 108), edgeMat = M.Rock, edgeColor = ROCK, edge = 2, under = M.Ground})
	B:arrows(7, CYAN)
	B:flush()

	---------- Llegada ----------
	B:arrival(8, 102, 0, "Frozen Peak")
	B:bounds(-166, -120, 166, 122)

	---------- La Aguja de Escarcha (la casa a defender) ----------
	local sx, sz = 146, 70
	local sy = B:groundY(sx, sz)
	local spire = Instance.new("Folder")
	spire.Name = "Aguja"
	B:add(spire, B.F.Arq)
	B:flush()
	B:part({Name = "Base", Shape = Enum.PartType.Cylinder, Size = V(3, 30, 30), CFrame = B:cf(sx, sy + 1, sz, 0, 0, 90), Material = M.Slate, Color = rgb(96, 106, 128)}, spire)
	B:part({Name = "Escalon", Shape = Enum.PartType.Cylinder, Size = V(1.5, 34, 34), CFrame = B:cf(sx, sy - 0.2, sz, 0, 0, 90), Material = M.Slate, Color = rgb(80, 88, 108)}, spire)
	B:tower(sx, sz, 9, 44, {y = sy + 2.5, mat = M.Glacier, color = ICE, roof = rgb(110, 170, 240), window = CYAN, windows = 4, windowYaw = -60, flag = CYAN, parent = spire, roofH = 26, steps = 12})
	B:tower(sx - 12, sz - 10, 4.5, 24, {y = sy + 2.5, mat = M.Glacier, color = ICE, roof = rgb(110, 170, 240), window = CYAN, windows = 2, parent = spire, roofH = 12})
	B:tower(sx + 6, sz + 13, 4.5, 20, {y = sy + 2.5, mat = M.Glacier, color = ICE, roof = rgb(110, 170, 240), window = CYAN, windows = 2, parent = spire, roofH = 11})
	-- puerta de hielo que mira al camino
	local door = B:deco({Name = "Puerta", Size = V(7, 10, 1), CFrame = B:cf(sx - 9.4, sy + 7.5, sz - 2, -70), Material = M.Neon, Color = CYAN, Transparency = 0.25}, spire)
	B:light(door, CYAN, 22, 1.2)
	-- esquirlas de hielo alrededor
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.3
		local h = rng:NextNumber(10, 24)
		local r = rng:NextNumber(12, 15)
		local base = B:cf(sx + math.cos(a) * r, sy + 1, sz + math.sin(a) * r)
		local tilt = CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3)
		B:part({Name = "Esquirla", Size = V(2.6, h, 2.6), CFrame = base * tilt * CF(0, h / 2, 0) * ANG(0, rad(45), 0), Material = M.Ice, Color = ICE, Transparency = 0.15, Reflectance = 0.2}, spire)
		B:part({Name = "Punta", Size = V(1.8, 1.8, 1.8), CFrame = base * tilt * CF(0, h, 0) * ANG(rad(45), rad(45), 0), Material = M.Ice, Color = ICE, Transparency = 0.15}, spire)
		if k % 3 == 0 then
			local c = B:deco({Name = "Nucleo", Size = V(0.8, h * 0.7, 0.8), CFrame = base * tilt * CF(0, h * 0.45, 0), Material = M.Neon, Color = CYAN}, spire)
			B:light(c, CYAN, 12, 0.9)
		end
	end
	-- gran cristal flotante sobre la torre
	local crystal = B:deco({Name = "Cristal", Size = V(5, 9, 5), CFrame = B:cf(sx, sy + 2.5 + 44 + 26 + 10, sz) * ANG(0, rad(45), 0), Material = M.Neon, Color = CYAN, Transparency = 0.1}, spire)
	B:light(crystal, CYAN, 45, 1.6)
	B:emitter(crystal, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(CYAN, Color3.new(1, 1, 1)), Rate = 12, Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.7, 0), LightEmission = 1,
	})
	local ghosts = B:deco({Name = "Espiritus", Size = V(30, 30, 30), CFrame = B:cf(sx, sy + 25, sz), Transparency = 1}, spire)
	B:emitter(ghosts, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(190, 235, 255)), Rate = 3, Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1)}),
	})
	table.insert(B.avoid, {sx, sz, 26})
	B:flush()

	---------- Campamento de la expedición (de donde salen) ----------
	B:tent(-150, 84, 10, 8, 10, 6, rgb(255, 130, 40), rgb(250, 210, 80))
	B:tent(-128, 88, -15, 7, 9, 5.5, rgb(220, 60, 50), rgb(250, 230, 200))
	B:tent(-152, 38, 160, 7, 9, 5.5, rgb(60, 130, 220), rgb(250, 230, 200))
	B:campfire(-136, 40)
	table.insert(B.avoid, {-136, 40, 10})
	local function prop(name, x, z, yaw, scale, gap, opts)
		if B:free(x, z, gap or 3) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale, nil, nil, opts)
		end
	end
	-- cajas de material, trineo, esquís y la bandera de la expedición
	local function crate(x, z, s)
		if B:free(x, z, 2) then
			local y = B:groundY(x, z)
			local c = B:cf(x, y, z, rng:NextNumber(0, 90))
			B:part({Name = "Caja", Size = V(s, s, s), CFrame = c * CF(0, s / 2, 0), Material = M.WoodPlanks, Color = rgb(150, 110, 70)})
			B:part({Name = "Nieve", Size = V(s + 0.1, 0.3, s + 0.1), CFrame = c * CF(0, s + 0.1, 0), Material = M.Snow, Color = SNOW, CanCollide = false})
		end
	end
	for _, c in {{-140, 100, 3}, {-137, 102, 2.4}, {-162, 92, 3}, {-118, 76, 2.6}, {-120, 42, 3}, {-146, 24, 2.2}} do
		crate(c[1], c[2], c[3])
	end
	if B:free(-122, 98, 4) then
		local y = B:groundY(-122, 98)
		local s = B:cf(-122, y, 98, 30)
		for k = -1, 1, 2 do
			B:part({Name = "Patin", Size = V(0.3, 0.3, 7), CFrame = s * CF(k * 1.4, 0.3, 0), Material = M.Metal, Color = rgb(60, 60, 70)})
		end
		B:part({Name = "Trineo", Size = V(3.4, 0.4, 6), CFrame = s * CF(0, 1, 0), Material = M.WoodPlanks, Color = rgb(150, 50, 40)})
		B:part({Name = "Carga", Size = V(2.8, 1.6, 3.6), CFrame = s * CF(0, 2, 0.4), Material = M.Fabric, Color = rgb(70, 100, 70)})
	end
	local flagPole = B:part({Name = "Mastil", Size = V(0.4, 14, 0.4), CFrame = B:cf(-140, B:groundY(-140, 62) + 7, 70), Material = M.Metal, Color = rgb(180, 180, 190)})
	B:deco({Name = "Bandera", Size = V(0.1, 3, 5), CFrame = flagPole.CFrame * CF(0, 5.3, 2.6), Material = M.Fabric, Color = rgb(220, 50, 50)})
	for k = 0, 2 do
		B:part({Name = "Esqui", Size = V(0.4, 6, 0.15), CFrame = B:cf(-112 + k * 1.1, B:groundY(-112, 96) + 2.6, 96, 0, 0, (k - 1) * 8), Material = M.SmoothPlastic, Color = ({rgb(220, 60, 60), rgb(60, 120, 220), rgb(250, 200, 50)})[k + 1]})
	end
	-- un muñeco de nieve con bufanda
	local function snowman(x, z)
		if not B:free(x, z, 3) then
			return
		end
		local y = B:groundY(x, z)
		local c = B:cf(x, y, z, rng:NextNumber(150, 210))
		B:part({Name = "Bola", Shape = Enum.PartType.Ball, Size = V(5, 5, 5), CFrame = c * CF(0, 2.2, 0), Material = M.Snow, Color = SNOW})
		B:part({Name = "Bola", Shape = Enum.PartType.Ball, Size = V(3.8, 3.8, 3.8), CFrame = c * CF(0, 5.4, 0), Material = M.Snow, Color = SNOW})
		B:part({Name = "Cabeza", Shape = Enum.PartType.Ball, Size = V(2.8, 2.8, 2.8), CFrame = c * CF(0, 7.9, 0), Material = M.Snow, Color = SNOW})
		B:deco({Name = "Nariz", Size = V(0.35, 0.35, 1.3), CFrame = c * CF(0, 7.9, -1.6), Material = M.SmoothPlastic, Color = rgb(255, 130, 30)})
		for s = -1, 1, 2 do
			B:deco({Name = "Ojo", Shape = Enum.PartType.Ball, Size = V(0.4, 0.4, 0.4), CFrame = c * CF(s * 0.5, 8.4, -1.25), Material = M.Neon, Color = CYAN})
			B:deco({Name = "Brazo", Size = V(0.25, 3, 0.25), CFrame = c * CF(s * 2.6, 5.8, 0) * ANG(0, 0, -s * 0.9), Material = M.Wood, Color = WOOD})
		end
		B:deco({Name = "Bufanda", Shape = Enum.PartType.Cylinder, Size = V(0.7, 3.2, 3.2), CFrame = c * CF(0, 6.8, 0) * ANG(0, 0, rad(90)), Material = M.Fabric, Color = rgb(200, 40, 60)})
		B:deco({Name = "Sombrero", Shape = Enum.PartType.Cylinder, Size = V(1.6, 1.8, 1.8), CFrame = c * CF(0, 9.6, 0) * ANG(0, 0, rad(90)), Material = M.Fabric, Color = rgb(30, 28, 34)})
	end
	snowman(-108, 88)
	snowman(60, 70)
	snowman(-30, -100)
	B:flush()

	---------- La vieja mina (noroeste) ----------
	local mx, mz = -150, -98
	if B:free(mx, mz, 6) then
		local y = B:groundY(mx, mz)
		local c = B:cf(mx, y, mz, 135)
		B:fillBall(mx - 8, 6, mz - 8, 20, M.Rock)
		B:fillBall(mx - 8, 18, mz - 8, 12, M.Snow)
		for s = -1, 1, 2 do
			B:part({Name = "Pilar", Size = V(1.4, 11, 1.4), CFrame = c * CF(s * 5, 5.5, 0), Material = M.Wood, Color = WOOD})
		end
		B:part({Name = "Viga", Size = V(12.4, 1.4, 1.6), CFrame = c * CF(0, 11.4, 0), Material = M.Wood, Color = WOOD})
		B:deco({Name = "Oscuro", Size = V(8.6, 10.4, 4), CFrame = c * CF(0, 5.2, 2.2), Material = M.SmoothPlastic, Color = rgb(10, 10, 16)})
		local lamp = B:deco({Name = "Farol", Size = V(0.8, 1, 0.8), CFrame = c * CF(-5, 9.5, -1), Material = M.Neon, Color = rgb(255, 190, 90)})
		B:light(lamp, rgb(255, 190, 90), 18, 1.6)
		for k = 0, 6 do
			B:deco({Name = "Traviesa", Size = V(4.4, 0.3, 0.8), CFrame = c * CF(0, 0.15, -2 - k * 2.2), Material = M.Wood, Color = WOOD})
		end
		for s = -1, 1, 2 do
			B:deco({Name = "Rail", Size = V(0.25, 0.3, 16), CFrame = c * CF(s * 1.5, 0.4, -8.6), Material = M.Metal, Color = rgb(90, 90, 100)})
		end
		B:part({Name = "Vagoneta", Size = V(3.4, 2.4, 4.4), CFrame = c * CF(0, 1.8, -12), Material = M.Metal, Color = rgb(90, 70, 60)})
		B:deco({Name = "Mineral", Size = V(2.8, 0.8, 3.6), CFrame = c * CF(0, 3.2, -12), Material = M.Neon, Color = CYAN})
		table.insert(B.avoid, {mx, mz, 16})
	end
	B:flush()

	---------- Bosque nevado, cristales y rocas ----------
	local function pine(x, z, s)
		if L.kitModel("SnowPine") then
			B:kit("SnowPine", x, z, rng:NextNumber(0, 360), s, nil, nil, {sink = 0.6})
		else
			B:kit(rng:NextNumber() < 0.5 and "PineA" or "PineB", x, z, rng:NextNumber(0, 360), s * 0.8)
		end
	end
	for x = -180, 180, 14 do
		pine(x + rng:NextNumber(-5, 5), -130 + rng:NextNumber(-8, 4), rng:NextNumber(0.9, 1.4))
		pine(x + rng:NextNumber(-5, 5), 134 + rng:NextNumber(-4, 8), rng:NextNumber(0.9, 1.4))
	end
	for z = -120, 125, 13 do
		pine(-178 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5), rng:NextNumber(0.9, 1.4))
		pine(178 + rng:NextNumber(-4, 6), z + rng:NextNumber(-5, 5), rng:NextNumber(0.9, 1.4))
	end
	B:flush()
	local placed = 0
	for _ = 1, 500 do
		if placed >= 28 then
			break
		end
		local x, z = rng:NextNumber(-160, 160), rng:NextNumber(-115, 118)
		local inView = x > -30 and x < 50 and z > 40
		if not inView and not B:inPond(x, z, 4) and B:free(x, z, 15) then
			pine(x, z, rng:NextNumber(0.7, 1.15))
			table.insert(B.avoid, {x, z, 9})
			placed += 1
		end
	end
	B:flush()
	placed = 0
	for _ = 1, 400 do
		if placed >= 22 then
			break
		end
		local x, z = rng:NextNumber(-160, 160), rng:NextNumber(-115, 118)
		if not B:inPond(x, z, 2) and B:free(x, z, 6) then
			local m = B:kit(L.kitModel("IceCrystals") and "IceCrystals" or "RockA", x, z, rng:NextNumber(0, 360), rng:NextNumber(0.6, 1.2))
			if m then
				local p = m:FindFirstChildWhichIsA("BasePart", true)
				if p then
					B:light(p, CYAN, 12, 1.2)
				end
			end
			table.insert(B.avoid, {x, z, 6})
			placed += 1
		end
	end
	local SMALL = {"RockA", "RockC", "RockB", "BushA", "RockC"}
	placed = 0
	for _ = 1, 500 do
		if placed >= 60 then
			break
		end
		local x, z = rng:NextNumber(-162, 162), rng:NextNumber(-118, 118)
		if not B:inPond(x, z, 2) and B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.6, 1.3), nil, nil, {noCollide = true, color = rgb(150, 160, 182)})
			placed += 1
		end
	end
	B:flush()
	-- faroles azules por el camino
	local pts = B.pathPts
	for i = 4, #pts - 3, 4 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local side = Vector2.new(-dir.Y, dir.X) * ((i // 4) % 2 == 0 and 1 or -1)
		local at = p + side * (B.width / 2 + 2.2)
		B:kit(i % 3 == 0 and "LampPost" or "PathLantern", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)), nil, nil, nil, {lightColor = CYAN})
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(330, 240, rgb(200, 220, 245), rgb(190, 240, 255), 4, 4)
	B:snowfall(380, 280, 70)
	B:aurora(0, -150, 150, 520, {rgb(90, 255, 170), rgb(110, 200, 255), rgb(190, 120, 255)})
	return B:finish()
end

return M_
