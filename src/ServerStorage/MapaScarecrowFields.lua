-- Mapa del Tower Defense "Scarecrow Fields" (roster farm, el más fácil). Una granja encantada en noche de cosecha:
-- un camino de tierra entre vallas serpentea por campos de maíz, huertos de calabazas que brillan, espantapájaros,
-- un molino y un silo, desde la verja de la granja (oeste) hasta el granero encantado (sureste), la casa a defender.
-- Uso: require(game.ServerStorage.MapaScarecrowFields).build() y luego MapasNuevosLib.store("ScarecrowFields")
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local DIRT = rgb(140, 96, 60)
local DIRT_EDGE = rgb(92, 64, 42)
local WOOD = rgb(110, 74, 46)
local DARKWOOD = rgb(64, 42, 28)
local PUMPKIN = rgb(255, 150, 40)
local WARM = rgb(255, 170, 70)

local M_ = {}

function M_.build()
	local B = L.new("ScarecrowFields", CFrame.new(3200, 2, 0), {seed = 61, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.Grass, 24)
	for _ = 1, 26 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-120, 120), rng:NextNumber(8, 18), M.Grass, rng:NextNumber() < 0.5 and M.LeafyGrass or M.Ground)
	end
	task.wait()
	-- lomas alrededor y montañas bajas a lo lejos
	for i = 0, 15 do
		local x = -200 + i * 27
		B:hill(x + rng:NextNumber(-8, 8), -150 + rng:NextNumber(-10, 6), rng:NextNumber(24, 34), rng:NextNumber(12, 22), M.Ground, M.Grass)
		B:hill(x + rng:NextNumber(-8, 8), 154 + rng:NextNumber(-6, 10), rng:NextNumber(24, 34), rng:NextNumber(12, 22), M.Ground, M.Grass)
	end
	for i = 0, 9 do
		local z = -130 + i * 29
		B:hill(-206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(14, 24), M.Ground, M.Grass)
		B:hill(206 + rng:NextNumber(-8, 8), z, rng:NextNumber(26, 36), rng:NextNumber(14, 24), M.Ground, M.Grass)
	end
	task.wait()
	for i = 0, 13 do
		local x = -330 + i * 52
		B:hill(x + rng:NextNumber(-12, 12), -250 + rng:NextNumber(-20, 10), rng:NextNumber(55, 70), rng:NextNumber(35, 55), M.Rock, M.LeafyGrass)
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(55, 70), rng:NextNumber(35, 55), M.Rock, M.LeafyGrass)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(35, 55), M.Rock, M.LeafyGrass)
		B:hill(330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(35, 55), M.Rock, M.LeafyGrass)
		task.wait()
	end
	-- estanque de la granja
	B:pond(-64, 96, 14, rgb(40, 66, 70))

	---------- Camino de tierra ----------
	local ctrl = {
		{-176, -82}, {-136, -86}, {-104, -66}, {-100, -24}, {-128, 8}, {-130, 48}, {-98, 74}, {-58, 62}, {-46, 22}, {-60, -20},
		{-42, -64}, {0, -80}, {40, -60}, {46, -16}, {22, 18}, {28, 52}, {66, 66}, {104, 46}, {104, 4}, {116, -36}, {146, -62},
	}
	B:path(ctrl, {flat = true, mat = M.Ground, color = DIRT, edgeMat = M.Mud, edgeColor = DIRT_EDGE, edge = 1.6, under = M.Ground})
	B:arrows(7, rgb(255, 180, 70))
	B:flush()
	local pts = B.pathPts
	-- vallas de madera a los lados del camino (con huecos) y faroles
	for i = 2, #pts - 2 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local nrm = Vector2.new(-dir.Y, dir.X)
		local mid = (p + q) / 2
		if i % 5 ~= 0 then
			for s = -1, 1, 2 do
				local at = mid + nrm * s * (B.width / 2 + 1.3)
				if B:distToPath(at.X, at.Y) > B.width / 2 + 0.6 then
					B:kit("WoodFence", at.X, at.Y, math.deg(math.atan2(-dir.Y, dir.X)), 1, nil, nil, {noCollide = true, color = WOOD})
				end
			end
		end
		if i % 6 == 0 then
			local s = (i // 6) % 2 == 0 and 1 or -1
			local at = p + nrm * s * (B.width / 2 + 2.6)
			if B:distToPath(at.X, at.Y) > B.width / 2 + 1.5 then
				B:kit("PathLantern", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)), 1, nil, nil, {lightColor = WARM})
			end
		end
	end
	B:flush()

	---------- Llegada ----------
	B:arrival(40, 104, 0, "Scarecrow Fields")
	B:bounds(-172, -122, 172, 122)

	---------- La verja de la granja (de donde salen) ----------
	local function gate(x, z, yaw)
		local base = B:cf(x, 0, z, yaw)
		for s = -1, 1, 2 do
			B:part({Name = "Poste", Size = V(1.6, 13, 1.6), CFrame = base * CF(s * 7.5, 6.5, 0), Material = M.Wood, Color = DARKWOOD})
			local fl = B:deco({Name = "Llama", Shape = Enum.PartType.Ball, Size = V(1, 1, 1), CFrame = base * CF(s * 7.5, 13.6, 0), Material = M.Neon, Color = WARM, Transparency = 0.3})
			B:fire(fl, 3)
			B:light(fl, WARM, 22, 1.8):AddTag("Flicker")
		end
		B:part({Name = "Viga", Size = V(17, 1.4, 1.2), CFrame = base * CF(0, 11.4, 0), Material = M.Wood, Color = DARKWOOD})
		local sign = B:part({Name = "Letrero", Size = V(11, 3, 0.5), CFrame = base * CF(0, 9, 0.2), Material = M.WoodPlanks, Color = WOOD})
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.PixelsPerStud = 40
		g.LightInfluence = 0.4
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Creepster
		t.TextScaled = true
		t.TextColor3 = rgb(255, 196, 110)
		t.TextStrokeTransparency = 0.2
		t.Text = "OLD MILLER'S FARM"
		t.Parent = g
		g.Parent = sign
		for _, s in {-1, 1} do
			local at = base * CF(s * 10.5, 0, 1.5)
			local p = B:loc(at.Position)
			B:kit("JackOLantern", p.X, p.Z, yaw + 180, 1.4)
		end
	end
	gate(-166, -82, 90)
	table.insert(B.avoid, {-166, -82, 12})
	B:cottage(-146, -108, 10, 12, 10, 8, {wall = rgb(196, 170, 140), roof = rgb(120, 52, 40)})
	table.insert(B.avoid, {-146, -108, 12})
	B:flush()

	---------- El granero encantado (la casa a defender) ----------
	local hx, hz = 154, -94
	local barn = B:kit("Barn", hx, hz, 200, 1.45, B.F.Arq)
	if not barn then
		-- (sin el modelo, un granero de piezas)
		B:cottage(hx, hz, 200, 26, 22, 14, {wall = rgb(150, 40, 34), wallMat = M.WoodPlanks, beam = rgb(240, 230, 210), roof = rgb(60, 40, 36), chimney = false})
	end
	local glow = B:deco({Name = "Brillo", Size = V(4, 4, 4), CFrame = B:cf(hx - 6, 6, hz + 12), Transparency = 1})
	B:light(glow, PUMPKIN, 40, 2.4)
	B:emitter(glow, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PUMPKIN), Rate = 10, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.5, 0), LightEmission = 1,
	})
	table.insert(B.avoid, {hx, hz, 30})
	-- balas de heno y calabazas delante del granero
	for _, h in {{132, -76}, {136, -98}, {166, -64}, {124, -88}} do
		B:kit("HayBale", h[1], h[2], rng:NextNumber(0, 360), 2.2)
		B:kit("HayBale", h[1] + 1, h[2] + 0.5, rng:NextNumber(0, 360), 2.2, nil, B:groundY(h[1], h[2]) + 2.4)
	end
	B:flush()

	---------- Molino y silo ----------
	local function windmill(x, z, yaw)
		local base = B:tower(x, z, 5, 24, {mat = M.WoodPlanks, color = rgb(150, 112, 78), roof = rgb(70, 40, 34), crenels = false, windows = 2, window = WARM, roofH = 10, steps = 8})
		local hub = base * ANG(0, rad(yaw), 0) * CF(0, 22, -6)
		B:part({Name = "Eje", Shape = Enum.PartType.Cylinder, Size = V(3, 1.6, 1.6), CFrame = hub * ANG(0, rad(90), 0), Material = M.Wood, Color = DARKWOOD})
		for k = 0, 3 do
			local a = rad(20 + k * 90)
			local arm = hub * CF(0, 0, -1) * ANG(0, 0, a)
			B:deco({Name = "Aspa", Size = V(0.6, 15, 0.4), CFrame = arm * CF(0, 7.5, 0), Material = M.Wood, Color = DARKWOOD})
			B:deco({Name = "Lona", Size = V(3.2, 11, 0.15), CFrame = arm * CF(1.9, 8.5, 0), Material = M.Fabric, Color = k % 2 == 0 and rgb(214, 196, 160) or rgb(170, 150, 120), Transparency = 0.1})
		end
		table.insert(B.avoid, {x, z, 12})
	end
	windmill(-150, 92, 30)
	local function silo(x, z)
		B:tower(x, z, 6, 30, {mat = M.WoodPlanks, color = rgb(150, 46, 40), roof = rgb(120, 124, 132), crenels = false, windows = 1, window = WARM, roofH = 8, steps = 8})
		for _, by in {6, 16, 26} do
			B:part({Name = "Banda", Shape = Enum.PartType.Cylinder, Size = V(0.8, 12.8, 12.8), CFrame = B:cf(x, by, z) * ANG(0, 0, rad(90)), Material = M.Metal, Color = rgb(220, 214, 200)})
		end
		table.insert(B.avoid, {x, z, 10})
	end
	silo(160, 30)
	silo(174, 46)
	B:flush()

	---------- Campos de maíz y huertos de calabazas ----------
	-- names: modelos a elegir; density: probabilidad de que haya algo en cada hueco; jitter: desorden
	local function field(x0, z0, x1, z1, step, names, scale, density, jitter)
		for x = x0, x1, step do
			for z = z0, z1, step do
				local jx, jz = x + rng:NextNumber(-jitter, jitter), z + rng:NextNumber(-jitter, jitter)
				if rng:NextNumber() < density and B:free(jx, jz, 3) and not B:inPond(jx, jz, 2) then
					B:kit(names[rng:NextInteger(1, #names)], jx, jz, rng:NextNumber(0, 360), scale * rng:NextNumber(0.7, 1.3), nil, nil, {noCollide = true})
				end
			end
			B:flush()
		end
	end
	-- surcos de tierra bajo los campos
	local fields = {
		{-170, -40, -116, -4}, {-86, -40, -70, 40}, {-30, -60, 30, -14}, {64, -10, 90, 40}, {-20, 66, 10, 110}, {60, -110, 110, -70},
	}
	for _, f in fields do
		for x = f[1], f[3], 8 do
			for z = f[2], f[4], 8 do
				if B:free(x, z, 2) then
					B:paint(x, z, 4, M.Grass, M.Mud)
					B:paint(x, z, 4, M.LeafyGrass, M.Mud)
				end
			end
		end
		task.wait()
	end
	local CORN = {"CornStalks"}
	local PUMPKINS = {"Pumpkin", "Pumpkin", "Pumpkin", "BushB"}
	field(-170, -40, -116, -4, 4.5, CORN, 1.35, 0.9, 0.6)
	field(-86, -40, -70, 40, 4.5, CORN, 1.35, 0.9, 0.6)
	field(60, -110, 110, -70, 4.5, CORN, 1.35, 0.9, 0.6)
	field(-30, -60, 30, -14, 4, PUMPKINS, 1.4, 0.45, 1.8)
	field(64, -10, 90, 40, 4, PUMPKINS, 1.4, 0.45, 1.8)
	field(-20, 66, 10, 110, 4, PUMPKINS, 1.4, 0.45, 1.8)
	-- calabazas encendidas por los huertos
	local lit = 0
	for _ = 1, 300 do
		if lit >= 22 then
			break
		end
		local f = fields[rng:NextInteger(1, #fields)]
		local x, z = rng:NextNumber(f[1], f[3]), rng:NextNumber(f[2], f[4])
		if B:free(x, z, 3) then
			B:kit("JackOLantern", x, z, rng:NextNumber(0, 360), rng:NextNumber(1.4, 2.2), nil, nil, {noCollide = true})
			lit += 1
		end
	end
	-- espantapájaros vigilando los campos (con ojos que brillan)
	for _, s in {{-142, -22}, {-78, 0}, {0, -38}, {78, 14}, {-4, 88}, {86, -90}, {-112, 108}, {128, 96}} do
		if B:free(s[1], s[2], 2) then
			local m = B:kit("Scarecrow", s[1], s[2], rng:NextNumber(0, 360), 1.35)
			if m then
				local cf, size = m:GetBoundingBox()
				local eye = B:deco({Name = "Ojos", Size = V(1, 1, 1), CFrame = cf * CF(0, size.Y * 0.36, 0), Transparency = 1})
				B:light(eye, PUMPKIN, 10, 1.4)
			end
		end
	end
	B:flush()

	---------- Granja: carros, cercas, abrevadero ----------
	local function prop(name, x, z, yaw, scale, gap, opts)
		if B:free(x, z, gap or 3) then
			return B:kit(name, x, z, yaw or rng:NextNumber(0, 360), scale, nil, nil, opts)
		end
	end
	prop("Cart", -120, -102, 30, 1.4)
	prop("Cart", 120, 70, 120, 1.4)
	prop("CrateStack", 140, -40, 20, 1)
	prop("CrateStack", -40, 104, 80, 1)
	prop("Signpost", -110, 22, 60, 1.2)
	prop("NoticeBoard", 70, 100, 200, 1)
	prop("Brazier", -20, 40, 0, 1.3)
	prop("Brazier", 80, -40, 0, 1.3)
	B:campfire(-20, 30)
	table.insert(B.avoid, {-20, 30, 8})
	B:reeds(-78, 88, 6, rng)
	B:reeds(-50, 108, 6, rng)
	B:lilies(-64, 96, 14, 6, rng)
	B:flush()

	---------- Árboles ----------
	local TREES = {"DeadTreeA", "DeadTreeB", "DeadTreeC", "PineA", "PineB"}
	local function tree(x, z)
		local name = TREES[rng:NextInteger(1, #TREES)]
		B:kit(name, x, z, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1.05), nil, nil, {sink = 0.6})
	end
	for x = -180, 180, 16 do
		tree(x + rng:NextNumber(-5, 5), -132 + rng:NextNumber(-8, 4))
		tree(x + rng:NextNumber(-5, 5), 134 + rng:NextNumber(-4, 8))
	end
	for z = -120, 125, 15 do
		tree(-186 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5))
		tree(186 + rng:NextNumber(-4, 6), z + rng:NextNumber(-5, 5))
	end
	B:flush()
	local placed = 0
	for _ = 1, 400 do
		if placed >= 12 then
			break
		end
		local x, z = rng:NextNumber(-165, 165), rng:NextNumber(-115, 118)
		if not (x > 0 and x < 90 and z > 45) and not B:inPond(x, z, 3) and B:free(x, z, 14) then
			tree(x, z)
			table.insert(B.avoid, {x, z, 10})
			placed += 1
		end
	end
	local SMALL = {"BushA", "BushB", "RockA", "RockC", "Mound", "Mushrooms", "Pumpkin"}
	placed = 0
	for _ = 1, 500 do
		if placed >= 60 then
			break
		end
		local x, z = rng:NextNumber(-168, 168), rng:NextNumber(-118, 118)
		if not B:inPond(x, z, 1) and B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.4), nil, nil, {noCollide = true})
			placed += 1
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 244, rgb(200, 150, 110), rgb(255, 190, 90), 6, 10)
	return B:finish()
end

return M_
