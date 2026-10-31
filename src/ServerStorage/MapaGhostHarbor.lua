-- Mapa del Tower Defense "Ghost Harbor" (roster harbor: contrabandistas, piratas con jetpack, ballesteros, lanceros,
-- Van Gloom y sir Reginald). Un puerto con niebla de noche: el camino sale de la playa (oeste), cruza el pueblo de
-- pescadores, se mete en el mar por un muelle de tablones y acaba en el faro, sobre su roca (noreste): la casa a
-- defender. Al norte, el mar con un barco fantasma encallado.
-- Uso: require(game.ServerStorage.MapaGhostHarbor).build() y luego MapasNuevosLib.store("GhostHarbor")
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local SEA = rgb(28, 64, 72)
local PLANK = rgb(112, 86, 62)
local POST = rgb(58, 44, 34)
local STONE = rgb(96, 100, 108)
local GHOST = rgb(90, 255, 220)
local WARM = rgb(255, 180, 90)

local SHORE = -66 -- el mar empieza aquí (z local)
local ISLAND = {148, -100, 20} -- roca del faro (x, z, radio)

local M_ = {}

function M_.build()
	local B = L.new("GhostHarbor", CFrame.new(3200, 2, 800), {seed = 71, width = 8})
	local rng = B.rng
	local function onIsland(x, z, margin)
		return (Vector2.new(x - ISLAND[1], z - ISLAND[2])).Magnitude < ISLAND[3] + (margin or 0)
	end
	local function isSea(x, z, margin)
		return z < SHORE + (margin or 0) and not onIsland(x, z, -(margin or 0))
	end

	---------- Terreno: tierra al sur, mar al norte ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Grass, 24)
	-- el mar: hueco con fondo de arena y una lámina de agua
	B:fillBlock(0, -5, SHORE - 220, 1000, 10, 440, M.Air)
	B:fillBlock(0, -11, SHORE - 220, 1000, 4, 440, M.Sand)
	task.wait()
	-- playa y rocas en la orilla
	for x = -260, 260, 12 do
		B:paint(x, SHORE + 8, 10, M.Grass, M.Sand)
		B:paint(x, SHORE + 8, 10, M.LeafyGrass, M.Sand)
	end
	for _ = 1, 26 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-40, 120), rng:NextNumber(8, 16), M.Grass, rng:NextNumber() < 0.5 and M.LeafyGrass or M.Ground)
	end
	task.wait()
	-- la roca del faro
	-- (como el suelo base, la cima acaba en y = -2: el terreno se dibuja 2 studs más arriba)
	B:fillCyl(ISLAND[1], -8, ISLAND[2], 12, ISLAND[3], M.Rock)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		B:fillBall(ISLAND[1] + math.cos(a) * (ISLAND[3] + 2), -7, ISLAND[2] + math.sin(a) * (ISLAND[3] + 2), 5, M.Rock)
	end
	B:fillCyl(ISLAND[1] + 14, 2, ISLAND[2] - 14, 8, 8, M.Rock)
	-- acantilados y montañas alrededor (por tierra)
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), 156 + rng:NextNumber(-6, 10), rng:NextNumber(24, 34), rng:NextNumber(14, 26), M.Rock, M.Grass)
	end
	for i = 0, 7 do
		local z = -40 + i * 26
		B:hill(-206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(16, 28), M.Rock, M.Grass)
		B:hill(206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(16, 28), M.Rock, M.Grass)
	end
	task.wait()
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(55, 70), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		task.wait()
	end
	for i = 0, 6 do
		local z = -40 + i * 50
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		B:hill(330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(40, 65), M.Rock, M.LeafyGrass)
		task.wait()
	end
	-- islotes rocosos en el mar
	for _, r in {{-150, -140, 10}, {-60, -170, 14}, {60, -150, 9}, {200, -170, 16}, {-230, -110, 12}, {250, -60, 14}} do
		B:hill(r[1], r[2], r[3], r[3] * 1.2, M.Rock, M.Slate)
	end
	local sea = B:part({Name = "Mar", Size = V(1000, 0.4, 440), CFrame = B:cf(0, -1.4, SHORE - 220), Material = M.SmoothPlastic, Color = SEA, Transparency = 0.12, Reflectance = 0.12, CanCollide = false, CastShadow = false}, B.F.TDS)
	B:flush()

	---------- Camino: playa, pueblo, muelle y la roca del faro ----------
	local ctrl = {
		{-178, -46}, {-140, -50}, {-112, -34}, {-104, 0}, {-126, 32}, {-120, 66}, {-84, 86}, {-46, 72}, {-38, 34}, {-58, 0},
		{-46, -40}, {-24, -84}, {8, -100}, {34, -82}, {32, -44}, {46, -6}, {32, 30}, {48, 64}, {86, 78}, {116, 58}, {112, 18},
		{98, -20}, {110, -58}, {140, -88},
	}
	B:path(ctrl, {flat = true, mat = M.Cobblestone, color = rgb(118, 112, 110), edgeMat = M.Slate, edgeColor = rgb(70, 72, 80), edge = 1.6, under = M.Ground})
	B:arrows(7, GHOST)
	B:flush()
	-- muelle de tablones donde el camino pasa por el mar (con postes y barandilla)
	local pts = B.pathPts
	local W = B.width
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local m = (p + q) / 2
		if isSea(m.X, m.Y, 4) then
			local a, b = B:w(p.X, 0, p.Y), B:w(q.X, 0, q.Y)
			local look = CFrame.lookAt((a + b) / 2, b)
			local len = (b - a).Magnitude
			B:part({Name = "Muelle", Size = V(W + 3, 0.8, len + 1.5), CFrame = look * CF(0, -0.15, 0), Material = M.WoodPlanks, Color = PLANK}, B.F.Suelo)
			for s = -1, 1, 2 do
				B:part({Name = "Pilote", Size = V(1, 9, 1), CFrame = look * CF(s * (W / 2 + 1.4), -3.5, 0), Material = M.Wood, Color = POST})
				B:part({Name = "Barandilla", Size = V(0.4, 0.4, len + 1), CFrame = look * CF(s * (W / 2 + 1.4), 2, 0), Material = M.Wood, Color = POST, CanCollide = false})
				B:part({Name = "Pilar", Size = V(0.6, 3, 0.6), CFrame = look * CF(s * (W / 2 + 1.4), 0.9, 0), Material = M.Wood, Color = POST, CanCollide = false})
			end
		end
	end
	B:flush()
	-- faroles fantasma a lo largo del camino
	for i = 4, #pts - 2, 6 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local nrm = Vector2.new(-dir.Y, dir.X)
		local at = p + nrm * ((i // 6) % 2 == 0 and 1 or -1) * (W / 2 + 2.4)
		if isSea(at.X, at.Y, 2) then
			local pole = B:part({Name = "Farol", Size = V(0.5, 8, 0.5), CFrame = B:cf(at.X, 2.5, at.Y), Material = M.Wood, Color = POST, CanCollide = false})
			local lamp = B:deco({Name = "Luz", Size = V(1, 1.3, 1), CFrame = B:cf(at.X, 7, at.Y), Material = M.Neon, Color = GHOST})
			B:light(lamp, GHOST, 18, 1.5)
		else
			B:kit("LampPost", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)), 0.9, nil, nil, {lightColor = GHOST})
		end
	end
	B:flush()

	---------- Llegada ----------
	B:arrival(40, 104, 0, "Ghost Harbor")
	B:bounds(-172, -122, 172, 122)

	---------- El faro (la casa a defender) ----------
	local lh = B:kit("Lighthouse", ISLAND[1] + 6, ISLAND[2] - 8, 210, 1.55, B.F.Arq, 0)
	if lh then
		local cf, size = lh:GetBoundingBox()
		local top = B:deco({Name = "Linterna", Size = V(4, 4, 4), CFrame = cf * CF(0, size.Y * 0.32, 0), Transparency = 1})
		B:light(top, GHOST, 60, 3)
		B:emitter(top, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GHOST), Rate = 8, Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.7, 0), LightEmission = 1,
		})
		-- el haz del faro, hacia el mar
		local beam = B:deco({Name = "Haz", Size = V(6, 6, 120), CFrame = cf * CF(0, size.Y * 0.32, 0) * ANG(rad(-6), rad(140), 0) * CF(0, 0, -62), Material = M.Neon, Color = GHOST, Transparency = 0.9, CastShadow = false})
		local spot = Instance.new("SpotLight")
		spot.Face, spot.Range, spot.Angle, spot.Brightness, spot.Color = Enum.NormalId.Front, 60, 30, 2, GHOST
		spot.Parent = beam
		local glow = B:deco({Name = "Brillo", Size = V(4, 4, 4), CFrame = B:cf(ISLAND[1] - 6, 5, ISLAND[2] + 8), Transparency = 1})
		B:light(glow, WARM, 30, 1.6)
	end
	table.insert(B.avoid, {ISLAND[1], ISLAND[2], ISLAND[3] + 6})
	B:flush()

	---------- El barco fantasma, barcas y la playa de los contrabandistas ----------
	local ship = B:kit("GhostShip", -112, -158, 64, 1.7, nil, -6)
	if ship then
		-- encallado y escorado, medio transparente, con niebla fantasma alrededor
		ship:PivotTo(ship:GetPivot() * ANG(rad(6), 0, rad(16)))
		for _, d in ship:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 0.35
				d.CastShadow = false
			end
		end
		local cf, size = ship:GetBoundingBox()
		local l = B:deco({Name = "Brillo", Size = V(size.X, 4, size.Z), CFrame = cf * CF(0, 2, 0), Transparency = 1})
		B:light(l, GHOST, 60, 2.4)
		B:emitter(l, {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(GHOST), Rate = 6, Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 20), Size = NumberSequence.new(4, 10),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1)}), LightEmission = 0.6,
		})
	end
	local function boat(x, z, yaw, beached)
		local base = B:cf(x, beached and 0.2 or -1.3, z, yaw) * (beached and ANG(0, 0, rad(12)) or CF())
		B:part({Name = "Casco", Size = V(3.4, 1.1, 8), CFrame = base * CF(0, 0.2, 0), Material = M.WoodPlanks, Color = rgb(96, 70, 52), CanCollide = false})
		for s = -1, 1, 2 do
			B:part({Name = "Borda", Size = V(0.4, 1.3, 8.2), CFrame = base * CF(s * 1.8, 0.8, 0), Material = M.Wood, Color = POST, CanCollide = false})
		end
		B:wedge({Name = "Proa", Size = V(3.8, 1.5, 2.2), CFrame = base * CF(0, 0.6, -5) * ANG(0, math.pi, 0), Material = M.Wood, Color = POST, CanCollide = false})
		local l = B:deco({Name = "Farol", Size = V(0.7, 0.9, 0.7), CFrame = base * CF(0, 1.7, 3), Material = M.Neon, Color = WARM})
		B:light(l, WARM, 14, 1.2)
	end
	boat(-160, -76, 20, false)
	boat(-146, -84, -30, false)
	boat(-122, -60, 100, true)
	boat(-170, -60, 70, true)
	boat(80, -96, 40, false)
	boat(-40, -116, -70, false)
	B:campfire(-150, -28)
	table.insert(B.avoid, {-150, -28, 10})
	B:flush()

	---------- El pueblo de pescadores ----------
	local function prop(name, x, z, yaw, scale, gap, opts)
		if B:free(x, z, gap or 3) and not isSea(x, z, 2) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale, nil, nil, opts)
		end
	end
	local function house(x, z, yaw)
		if not B:free(x, z, 10) or isSea(x, z, 8) then
			return
		end
		local shack = B:kit("DockShack", x, z, yaw, 1.25, B.F.Arq)
		if not shack then
			B:cottage(x, z, yaw, 10, 8, 7, {wall = rgb(100, 90, 80), wallMat = M.WoodPlanks, beam = POST, roof = rgb(60, 70, 80), noBeams = true})
		end
		table.insert(B.avoid, {x, z, 12})
	end
	house(-150, 10, 70)
	house(-150, 52, 100)
	house(-84, 40, -90)
	house(-10, 0, 180)
	house(-12, 46, 90)
	house(76, 28, -60)
	house(70, -36, 200)
	house(150, 20, -100)
	house(-120, 106, 10)
	B:cottage(150, 90, 200, 14, 10, 9, {wall = rgb(200, 190, 170), roof = rgb(60, 70, 90)})
	table.insert(B.avoid, {150, 90, 14})
	for _, c in {{-130, -20}, {-70, -30}, {10, -40}, {70, -10}, {130, -30}, {-90, 110}, {6, 80}} do
		prop("CrateStack", c[1], c[2], nil, 1.1)
	end
	for _, c in {{-100, -50}, {-20, -56}, {60, -56}, {120, -10}, {-40, 104}} do
		prop("ToxicBarrels", c[1], c[2], nil, 0.9, 3, {lightColor = GHOST})
	end
	prop("NoticeBoard", -96, 60, 30)
	prop("Signpost", 20, 10, 200)
	prop("Cart", 100, 100, 70, 1.3)
	prop("Brazier", -60, 100, 0, 1.2)
	prop("Brazier", 120, -46, 0, 1.2)
	B:flush()
	-- rocas en la orilla
	for x = -230, 230, 9 do
		local z = SHORE + rng:NextNumber(-3, 4)
		if B:free(x, z, 4) and not onIsland(x, z, 6) then
			B:kit(rng:NextNumber() < 0.5 and "RockB" or "RockA", x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.6), nil, -1.5)
		end
	end
	B:flush()

	---------- Vegetación ----------
	local TREES = {"PineA", "PineB", "DeadTreeA", "DeadTreeC", "CypressA"}
	local function tree(x, z)
		B:kit(TREES[rng:NextInteger(1, #TREES)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1.05), nil, nil, {sink = 0.6})
	end
	for x = -180, 180, 15 do
		tree(x + rng:NextNumber(-5, 5), 134 + rng:NextNumber(-4, 8))
	end
	for z = -40, 125, 14 do
		tree(-186 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5))
		tree(186 + rng:NextNumber(-4, 6), z + rng:NextNumber(-5, 5))
	end
	B:flush()
	local SMALL = {"BushA", "BushB", "RockA", "RockC", "Mound", "Mushrooms"}
	local placed = 0
	for _ = 1, 500 do
		if placed >= 50 then
			break
		end
		local x, z = rng:NextNumber(-168, 168), rng:NextNumber(-50, 118)
		if not isSea(x, z, 3) and B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.4), nil, nil, {noCollide = true})
			placed += 1
		end
	end
	B:flush()

	---------- Ambiente: mucha niebla ----------
	B:ambience(340, 244, rgb(150, 200, 200), GHOST, 12, 6)
	return B:finish()
end

return M_
