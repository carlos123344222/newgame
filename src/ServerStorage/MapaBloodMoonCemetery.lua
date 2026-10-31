-- Mapa del Tower Defense "Blood Moon Cemetery" (roster graveyard: acólitos, médiums, sacerdotes, cazabrujas,
-- paladines y el Gran Inquisidor). Un cementerio gótico bajo una luna de sangre: el camino entra por la verja (este) y
-- serpentea entre hileras de tumbas, criptas, ángeles de piedra y la capilla, hasta el mausoleo (noroeste), la casa
-- a defender.
-- Uso: require(game.ServerStorage.MapaBloodMoonCemetery).build() y luego MapasNuevosLib.store("BloodMoonCemetery")
local L = require(game.ServerStorage.MapasNuevosLib)
local V, CF, ANG = L.V, L.CF, L.ANG
local rad = math.rad
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local BLOOD = rgb(255, 50, 60)
local CANDLE = rgb(255, 170, 80)
local STONE = rgb(92, 88, 100)
local IRON = rgb(36, 32, 40)

local M_ = {}

function M_.build()
	local B = L.new("BloodMoonCemetery", CFrame.new(3200, 2, 1600), {seed = 83, width = 8})
	local rng = B.rng

	---------- Terreno ----------
	B:fillBlock(0, 70, 0, 1000, 220, 900, M.Air)
	task.wait()
	B:ground(980, 860, M.LeafyGrass, 24)
	for _ = 1, 34 do
		B:paint(rng:NextNumber(-170, 170), rng:NextNumber(-120, 120), rng:NextNumber(8, 18), M.LeafyGrass, rng:NextNumber() < 0.55 and M.Ground or M.Mud)
	end
	task.wait()
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
		B:hill(x + rng:NextNumber(-12, 12), -250 + rng:NextNumber(-20, 10), rng:NextNumber(55, 70), rng:NextNumber(45, 70), M.Rock, M.Slate)
		B:hill(x + rng:NextNumber(-12, 12), 250 + rng:NextNumber(-10, 20), rng:NextNumber(55, 70), rng:NextNumber(45, 70), M.Rock, M.Slate)
		task.wait()
	end
	for i = 0, 8 do
		local z = -220 + i * 55
		B:hill(-330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(45, 70), M.Rock, M.Slate)
		B:hill(330 + rng:NextNumber(-12, 12), z, rng:NextNumber(60, 75), rng:NextNumber(45, 70), M.Rock, M.Slate)
		task.wait()
	end

	---------- Camino ----------
	local ctrl = {
		{178, 80}, {142, 84}, {112, 62}, {118, 24}, {146, 0}, {140, -38}, {104, -58}, {66, -42}, {60, 0}, {72, 40}, {40, 64},
		{0, 50}, {-10, 12}, {18, -22}, {8, -62}, {-30, -82}, {-70, -62}, {-74, -22}, {-50, 14}, {-70, 52}, {-110, 68}, {-142, 42},
		{-136, 2}, {-108, -30}, {-128, -70}, {-150, -90},
	}
	B:path(ctrl, {flat = true, mat = M.Slate, color = rgb(74, 68, 78), edgeMat = M.Cobblestone, edgeColor = rgb(52, 48, 58), edge = 1.8, under = M.Ground})
	B:arrows(7, BLOOD)
	B:flush()
	local pts = B.pathPts
	-- verjas de hierro a tramos y faroles
	for i = 2, #pts - 2 do
		local p, q = pts[i], pts[i + 1]
		local dir = (q - p).Unit
		local nrm = Vector2.new(-dir.Y, dir.X)
		local mid = (p + q) / 2
		if (i // 4) % 3 ~= 2 then
			for s = -1, 1, 2 do
				local at = mid + nrm * s * (B.width / 2 + 1.4)
				if B:distToPath(at.X, at.Y) > B.width / 2 + 0.7 then
					B:kit("IronFence", at.X, at.Y, math.deg(math.atan2(-dir.Y, dir.X)), 1, nil, nil, {noCollide = true, color = IRON})
				end
			end
		end
		if i % 7 == 0 then
			local s = (i // 7) % 2 == 0 and 1 or -1
			local at = p + nrm * s * (B.width / 2 + 2.8)
			if B:distToPath(at.X, at.Y) > B.width / 2 + 1.5 then
				B:kit("LampPost", at.X, at.Y, math.deg(math.atan2(dir.X, dir.Y)), 0.9, nil, nil, {lightColor = CANDLE})
			end
		end
	end
	B:flush()

	---------- Llegada ----------
	B:arrival(40, 104, 0, "Blood Moon Cemetery")
	B:bounds(-172, -122, 172, 122)

	---------- La luna de sangre ----------
	local moon = B:deco({Name = "LunaDeSangre", Shape = Enum.PartType.Ball, Size = V(90, 90, 90), CFrame = B:cf(-80, 210, -520), Material = M.Neon, Color = rgb(200, 30, 40), CastShadow = false}, B.F.TDS)
	B:deco({Name = "Halo", Shape = Enum.PartType.Ball, Size = V(120, 120, 120), CFrame = B:cf(-80, 210, -520), Material = M.Neon, Color = rgb(255, 60, 60), Transparency = 0.85, CastShadow = false}, B.F.TDS)

	---------- La verja del cementerio (de donde salen) ----------
	B:kit("CemeteryGate", 170, 80, 90, 1.6, nil, nil, {noCollide = true})
	table.insert(B.avoid, {170, 80, 14})
	for _, s in {-1, 1} do
		B:kit("Brazier", 162, 80 + s * 14, 0, 1.4, nil, nil, {lightColor = BLOOD})
	end
	B:flush()

	---------- El mausoleo (la casa a defender) ----------
	local hx, hz = -156, -104
	local mau = B:kit("Mausoleum", hx, hz, 150, 1.35, B.F.Arq)
	if not mau then
		B:kit("Crypt", hx, hz, 150, 2.2, B.F.Arq)
	end
	local glow = B:deco({Name = "Brillo", Size = V(4, 4, 4), CFrame = B:cf(hx + 10, 8, hz + 12), Transparency = 1})
	B:light(glow, BLOOD, 44, 2.6)
	B:emitter(glow, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(BLOOD), Rate = 10, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.6, 0), LightEmission = 1,
	})
	table.insert(B.avoid, {hx, hz, 30})
	-- ángeles de piedra y velas delante del mausoleo
	for _, a in {{-128, -98, 120}, {-150, -74, 160}} do
		B:kit("AngelStatue", a[1], a[2], a[3], 1.6)
		table.insert(B.avoid, {a[1], a[2], 5})
	end
	B:flush()

	---------- La capilla ----------
	B:kit("Chapel", 10, -104, 0, 0.75, B.F.Arq)
	table.insert(B.avoid, {10, -104, 26})

	---------- Tumbas en hileras, criptas, ataúdes y velas ----------
	local GRAVES = {"GraveCross", "GraveRound", "GraveSlab", "GraveTomb", "GraveRound", "GraveCross", "GraveObelisk"}
	local function rows(x0, z0, x1, z1, yaw)
		for x = x0, x1, 6 do
			for z = z0, z1, 8 do
				local jx, jz = x + rng:NextNumber(-0.8, 0.8), z + rng:NextNumber(-0.8, 0.8)
				if rng:NextNumber() < 0.8 and B:free(jx, jz, 3) then
					B:kit(GRAVES[rng:NextInteger(1, #GRAVES)], jx, jz, yaw + rng:NextNumber(-12, 12), rng:NextNumber(1.1, 1.5), nil, nil, {sink = 0.3})
				end
			end
			B:flush()
		end
	end
	rows(84, -110, 160, -70, 0)
	rows(84, 0, 104, 40, 90)
	rows(-40, -50, -20, 30, 90)
	rows(14, 70, 60, 112, 0)
	rows(-110, -10, -86, 40, 90)
	rows(-60, 70, -20, 112, 0)
	rows(130, 30, 165, 60, 0)
	rows(-100, -110, -60, -90, 0)
	for _, c in {{100, -24}, {-36, 54}, {150, -92}, {-102, 10}, {30, 20}} do
		if B:free(c[1], c[2], 8) then
			B:kit(rng:NextNumber() < 0.5 and "Crypt" or "ZombieCrypt", c[1], c[2], rng:NextNumber(0, 360), rng:NextNumber() < 0.5 and 1.2 or 0.75, nil, nil, {lightColor = BLOOD})
			table.insert(B.avoid, {c[1], c[2], 12})
		end
	end
	local function candles(x, z)
		if B:free(x, z, 2) then
			local m = B:kit("Candles", x, z, rng:NextNumber(0, 360), 1.3, nil, nil, {noCollide = true})
			if m then
				local p = m:FindFirstChildWhichIsA("BasePart")
				if p then
					B:light(p, CANDLE, 12, 1.3):AddTag("Flicker")
				end
			end
		end
	end
	for _ = 1, 18 do
		candles(rng:NextNumber(-165, 165), rng:NextNumber(-115, 115))
	end
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-165, 165), rng:NextNumber(-115, 115)
		if B:free(x, z, 3) then
			B:kit("Coffin", x, z, rng:NextNumber(0, 360), 1.5, nil, nil, {noCollide = true})
		end
	end
	for _, s in {{-20, -30}, {120, 100}, {-160, 100}, {90, -88}} do
		if B:free(s[1], s[2], 3) then
			B:kit("Statue", s[1], s[2], rng:NextNumber(0, 360), 1.6)
		end
	end
	B:flush()

	---------- Árboles muertos y niebla ----------
	local TREES = {"DeadTreeA", "DeadTreeB", "DeadTreeC", "CypressA", "CypressB"}
	local function tree(x, z)
		B:kit(TREES[rng:NextInteger(1, #TREES)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.75, 1.1), nil, nil, {sink = 0.6})
	end
	for x = -180, 180, 15 do
		tree(x + rng:NextNumber(-5, 5), -132 + rng:NextNumber(-8, 4))
		tree(x + rng:NextNumber(-5, 5), 134 + rng:NextNumber(-4, 8))
	end
	for z = -120, 125, 14 do
		tree(-186 + rng:NextNumber(-6, 4), z + rng:NextNumber(-5, 5))
		tree(186 + rng:NextNumber(-4, 6), z + rng:NextNumber(-5, 5))
	end
	B:flush()
	local placed = 0
	for _ = 1, 400 do
		if placed >= 14 then
			break
		end
		local x, z = rng:NextNumber(-165, 165), rng:NextNumber(-115, 118)
		if not (x > 0 and x < 90 and z > 45) and B:free(x, z, 14) then
			tree(x, z)
			table.insert(B.avoid, {x, z, 10})
			placed += 1
		end
	end
	local SMALL = {"BushA", "BushB", "RockA", "RockC", "Mound", "Mushrooms", "BonePile", "ZombieHand"}
	placed = 0
	for _ = 1, 500 do
		if placed >= 60 then
			break
		end
		local x, z = rng:NextNumber(-168, 168), rng:NextNumber(-118, 118)
		if B:free(x, z, 3) then
			B:kit(SMALL[rng:NextInteger(1, #SMALL)], x, z, rng:NextNumber(0, 360), rng:NextNumber(0.8, 1.5), nil, nil, {noCollide = true})
			placed += 1
		end
	end
	B:flush()

	---------- Ambiente ----------
	B:ambience(340, 244, rgb(170, 60, 70), rgb(255, 90, 90), 9, 7)
	return B:finish()
end

return M_
