-- Trazados rectos de los mapas del Tower Defense (los aplica MapasRectos sobre los mapas de siempre). Cada mapa:
-- path (esquinas {x, z} locales, de la entrada a la casa: empieza y acaba donde empezaba y acababa el camino viejo),
-- width, style (firme, borde y franja del camino), ground (material del terreno con el que se tapa el camino viejo),
-- keepNames / keepBoxes (lo que no se toca aunque esté en medio) y decor (faroles y adornos a lo largo del camino).
local C = Color3.fromRGB
local M = Enum.Material

local Defs = {}

---------- Adornos ----------
-- Un modelo del kit en el exterior de cada esquina del camino (faroles, braseros...)
local function corners(B, R, pts, name, scale, opts)
	opts = opts or {}
	local half = B.width / 2 + 2.6 + (opts.off or 0)
	-- (cada esquina son dos vértices del chaflán: i, i + 1; el exterior de la curva es d1 - d2)
	for i = 2, #pts - 2, 2 do
		local d1 = (pts[i] - pts[i - 1]).Unit
		local d2 = (pts[i + 2] - pts[i + 1]).Unit
		local mid = (pts[i] + pts[i + 1]) / 2
		local spot = mid + (d1 - d2).Unit * (half + 1.5)
		B:kit(name, spot.X, spot.Y, opts.yaw or 0, scale, B.F.Deco, nil, {noCollide = false})
	end
end

-- Modelos a lo largo del camino, a los dos lados, cada 'every' studs
local function along(B, R, pts, names, every, scale, opts)
	opts = opts or {}
	local half = B.width / 2 + 2.4 + (opts.off or 0)
	local rng = B.rng
	local k = 0
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		if len > every then
			local d = (b - a).Unit
			local n = Vector2.new(-d.Y, d.X)
			for t = every / 2, len - every / 2, every do
				k += 1
				local s = (opts.alternate and (k % 2 == 0 and 1 or -1)) or (rng:NextNumber() < 0.5 and 1 or -1)
				local sides = opts.both and {-1, 1} or {s}
				for _, sd in sides do
					local p = a + d * t + n * sd * half
					if R.polyDist(pts, p) > B.width / 2 + 1.5 and (not opts.chance or rng:NextNumber() < opts.chance) then
						local name = names[rng:NextInteger(1, #names)]
						local yaw = opts.align and math.deg(math.atan2(d.X, d.Y)) or rng:NextNumber(0, 360)
						B:kit(name, p.X, p.Y, yaw, scale * rng:NextNumber(0.9, 1.1), B.F.Deco, nil, {noCollide = false})
					end
				end
			end
		end
	end
end
Defs.corners, Defs.along = corners, along

---------- Cursed Castle ----------
Defs.CursedCastle = {
	path = {{-168, -62}, {-112, -62}, {-112, 10}, {12, 10}, {12, -96}, {84, -96}, {84, 47}, {110, 47}},
	width = 9, chamfer = 7,
	style = {mat = M.Cobblestone, color = C(150, 144, 136), edgeMat = M.Slate, edgeColor = C(92, 88, 100), edge = 1.8},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	keepNames = {"Arco", "Pila", "Pretil", "Remate", "Puente", "Farol", "Luz", "Poste", "NieblaRio", "Travesaño"},
	keepBoxes = {{106, -60, 180, 130}}, -- el castillo
	decor = function(B, R, pts)
		corners(B, R, pts, "LampPost", 1)
		along(B, R, pts, {"JackOLantern", "Pumpkin"}, 26, 1.4, {chance = 0.6})
	end,
	fill = {
		{names = {"PineA", "PineB", "CypressA", "DeadTreeA", "DeadTreeB"}, n = 22, smin = 0.5, smax = 0.8, gap = 14, space = 7},
		{names = {"RockA", "RockB", "RockC", "BushA", "BushB", "Mushrooms"}, n = 30, smin = 0.8, smax = 1.3, gap = 7, space = 3},
		{names = {"GraveCross", "GraveRound", "HayBale", "Cart", "Signpost", "Bench", "Brazier", "Statue", "Pumpkin", "JackOLantern", "WoodFence", "Coffin"}, n = 34, smin = 1, smax = 1.4, gap = 6, space = 3},
	},
}

---------- Zombie Hollow ----------
Defs.ZombieHollow = {
	path = {{-118, -82}, {-70, -82}, {-70, -20}, {-105, -20}, {-105, 60}, {-15, 60}, {-15, -70}, {55, -70}, {55, 40}, {115, 40}, {115, 80}},
	width = 9, chamfer = 6,
	keepNames = {"CasaEmbrujada", "ArcoEntrada", "PortalCueva", "Estanque"},
	keepBoxes = {{-170, -130, -114, -55}}, -- la cueva de la entrada
	style = {mat = M.Ground, color = C(138, 96, 64), edgeMat = M.Ground, edgeColor = C(76, 54, 40), edge = 1.8, band = C(112, 80, 56)},
	ground = M.Grass,
	-- rocas del borde menos moradas (más grises, como las de las fotos)
	recolor = {rock = C(118, 112, 124)},
	decor = function(B, R, pts)
		corners(B, R, pts, "PathLantern", 1.7)
		along(B, R, pts, {"JackOLantern", "Pumpkin", "PumpkinRound", "JackClassic"}, 20, 1.6, {chance = 0.75})
		R.regrass(B, pts, 7)
	end,
	fill = {
		{names = {"Pumpkin", "PumpkinRound", "PumpkinSquat", "JackOLantern", "JackAngry", "Mushrooms", "BushA", "BushB", "RockA", "RockC"}, n = 40, smin = 1, smax = 1.6, gap = 6, space = 3},
		{names = {"ZombieGrave", "GraveCross", "GraveRound", "BonePile", "ZombieHand", "Brazier", "HayBale"}, n = 24, smin = 1, smax = 1.5, gap = 6, space = 3},
	},
}

---------- Cursed Carnival ----------
Defs.CursedCarnival = {
	path = {{-170, -96}, {-115, -96}, {-115, 60}, {-40, 60}, {-40, -80}, {20, -80}, {20, 65}, {115, 65}, {115, 10}, {148, 10}, {148, 28}},
	width = 9, chamfer = 6,
	style = {mat = M.SmoothPlastic, color = C(96, 70, 92), edgeMat = M.SmoothPlastic, edgeColor = C(220, 40, 60), edgeColor2 = C(245, 236, 226), edge = 1.6, band = C(120, 90, 112)},
	ground = M.Grass, oldMats = {M.Ground, M.Mud, M.Pavement},
	removeNames = {"CarnivalPath"},
	recolor = {Cesped = C(80, 116, 64), CespedFuera = C(62, 92, 52), Tierra = C(112, 86, 70)},
	keepNames = {"ClownGate", "FunHouse", "Coaster", "FerrisWheel", "DropTower", "Carousel", "Lagoon", "BigTop", "SwingRide", "FortuneTent"},
	decor = function(B, R, pts)
		corners(B, R, pts, "CarnivalLamp", 1.3)
		along(B, R, pts, {"Balloons", "JackOLantern", "Pumpkin", "PrizeTeddy"}, 22, 1.2, {chance = 0.7})
	end,
	fill = {
		{names = {"StallA", "StallB", "PopcornCart", "TicketBooth", "HammerGame", "CrateStack", "ClownStatue", "Balloons"}, n = 16, smin = 0.9, smax = 1.1, gap = 9, space = 7},
		{names = {"Pumpkin", "JackOLantern", "PrizeTeddy", "Balloons", "Mushrooms"}, n = 30, smin = 1, smax = 1.5, gap = 6, space = 3},
	},
}

---------- Witch Bayou ----------
Defs.WitchBayou = {
	path = {{-168, 92}, {-104, 92}, {-104, -60}, {-8, -60}, {-8, 48}, {150, 48}, {150, -48}, {124, -48}, {124, -74}},
	width = 9, chamfer = 6,
	style = {mat = M.WoodPlanks, color = C(118, 88, 60), edgeMat = M.Wood, edgeColor = C(72, 52, 38), edge = 1.5, deck = C(110, 82, 56), post = C(62, 46, 34)},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	keepNames = {"WitchHut", "Porche"},
	recolor = {Agua = C(52, 108, 92)},
	decor = function(B, R, pts)
		corners(B, R, pts, "PathLantern", 1.7)
		-- los estanques brillan un poco (luciérnagas sobre el agua)
		for _, d in B.model.MapaTDS:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Agua" then
				d.Reflectance, d.Material = 0.15, M.SmoothPlastic
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness = C(120, 255, 170), 18, 0.8
				l.Parent = d
				-- juncos en la orilla
				local o = B.O:PointToObjectSpace(d.Position)
				local r = d.Size.Y / 2
				for k = 0, 9 do
					local a = k / 10 * math.pi * 2 + B.rng:NextNumber(-0.2, 0.2)
					local x, z = o.X + math.cos(a) * (r + 0.5), o.Z + math.sin(a) * (r + 0.5)
					if R.polyDist(pts, Vector2.new(x, z)) > B.width / 2 + 3 then
						B:reeds(x, z, B.rng:NextInteger(2, 5), B.rng)
					end
				end
			end
		end
		along(B, R, pts, {"Candles", "Mushrooms", "Candles2", "Pumpkin"}, 20, 1.5, {chance = 0.7})
	end,
	fill = {
		{names = {"Mushrooms", "Candles", "BonePile", "Coffin", "RockA", "RockC", "BushA", "BushB", "Pumpkin"}, n = 40, smin = 1, smax = 1.6, gap = 6, space = 3},
		{names = {"SwampTree", "SwampTree", "DeadTreeB", "CypressB"}, n = 16, smin = 0.55, smax = 0.85, gap = 13, space = 9, box = {-90, -100, 140, 80}},
	},
}

---------- Frozen Peak ----------
Defs.FrozenPeak = {
	path = {{-162, 62}, {-115, 62}, {-115, -70}, {-55, -70}, {-55, 40}, {5, 40}, {5, -70}, {65, -70}, {65, 62}, {110, 62}},
	width = 9, chamfer = 6,
	style = {mat = M.Ground, color = C(134, 118, 108), edgeMat = M.Glacier, edgeColor = C(176, 200, 224), edge = 1.8, band = C(112, 98, 92)},
	ground = M.Snow, oldMats = {M.Ground, M.Mud},
	keepNames = {"Espiritus", "Torre", "Escalon", "Base", "Tejado", "Banda"},
	keepBoxes = {{126, 46, 170, 96}}, -- la Aguja de Escarcha
	decor = function(B, R, pts)
		corners(B, R, pts, "PathLantern", 1.7)
		along(B, R, pts, {"IceCrystals", "RockC", "IceCrystals"}, 24, 0.7, {chance = 0.6})
	end,
	fill = {
		{names = {"SnowPine"}, n = 20, smin = 0.55, smax = 0.85, gap = 12, space = 7},
		{names = {"IceCrystals", "RockA", "RockC", "BushA"}, n = 30, smin = 0.8, smax = 1.3, gap = 6, space = 3},
	},
}

---------- Fallen Cathedral (la grieta del abismo solo se cruza por su puente, en z = 55) ----------
Defs.FallenCathedral = {
	path = {{-168, -10}, {-120, -10}, {-120, -80}, {-50, -80}, {-50, 55}, {55, 55}, {55, -80}, {88, -80}, {88, 30}, {104, 30}},
	width = 9, chamfer = 6,
	style = {mat = M.Pavement, color = C(200, 192, 204), edgeMat = M.Slate, edgeColor = C(82, 74, 98), edge = 1.8, band = C(176, 168, 184)},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	keepNames = {"Arch", "Fountain", "Cathedral", "Almas", "Escalon", "Frontis", "Dintel", "VeloDorado", "Pretil", "Remate", "Puente", "Abismo", "Pilono", "Arco"},
	decor = function(B, R, pts)
		corners(B, R, pts, "LampDouble", 1)
		along(B, R, pts, {"Candles", "Candles2", "AngelStatue"}, 24, 1.3, {chance = 0.6})
	end,
	fill = {
		{names = {"AngelStatue", "Statue", "GraveCross", "GraveRound", "GraveObelisk", "Candles", "Brazier", "GraveTomb"}, n = 34, smin = 1, smax = 1.5, gap = 6, space = 3},
		{names = {"CypressA", "DeadTreeC", "DeadTreeA", "CypressB"}, n = 14, smin = 0.5, smax = 0.8, gap = 12, space = 7},
	},
}

---------- Scarecrow Fields (el camino rodea los campos de maíz y calabazas) ----------
Defs.ScarecrowFields = {
	path = {{-176, -82}, {-107, -82}, {-107, 48}, {-52, 48}, {-52, -96}, {46, -96}, {46, -36}, {140, -36}, {140, -60}},
	width = 9, chamfer = 6,
	style = {mat = M.Ground, color = C(138, 98, 64), edgeMat = M.Ground, edgeColor = C(96, 66, 46), edge = 1.6, band = C(116, 82, 56)},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	keepNames = {"Barn", "Torre", "Base", "Banda", "Tejado", "Aspa", "Eje", "Casa", "Zocalo", "Viga", "Hastial", "Caballete", "Chimenea"},
	decor = function(B, R, pts)
		along(B, R, pts, {"WoodFence"}, 9, 1.05, {both = true, align = true, chance = 0.75, off = 0.6})
		corners(B, R, pts, "PathLantern", 1.7, {off = 1})
		along(B, R, pts, {"JackOLantern", "Pumpkin", "HayBale"}, 22, 1.4, {chance = 0.6, off = 3})
	end,
	fill = {
		{names = {"Scarecrow", "HayBale", "Cart", "CrateStack", "Brazier", "Signpost"}, n = 14, smin = 1, smax = 1.3, gap = 8, space = 5},
		{names = {"Pumpkin", "JackOLantern", "Mushrooms", "BushA", "BushB", "RockA"}, n = 30, smin = 1, smax = 1.6, gap = 6, space = 3},
	},
}

---------- Ghost Harbor (entre las casetas del puerto y, al final, un muelle hasta el faro) ----------
Defs.GhostHarbor = {
	path = {{-178, -46}, {-110, -46}, {-110, 78}, {-45, 78}, {-45, -40}, {35, -40}, {35, 70}, {110, 70}, {110, -60}, {140, -60}, {140, -88}},
	width = 9, chamfer = 6,
	style = {mat = M.Cobblestone, color = C(126, 120, 116), edgeMat = M.Slate, edgeColor = C(72, 74, 84), edge = 1.8, deck = C(104, 82, 60), post = C(64, 50, 40)},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	removeNames = {"Muelle"},
	keepNames = {"Lighthouse", "GhostShip", "DockShack", "Haz", "Brillo", "Casa", "Zocalo", "Viga", "Tejado", "Caballete"},
	decor = function(B, R, pts)
		corners(B, R, pts, "LampPost", 1)
		along(B, R, pts, {"CrateStack", "ToxicBarrels", "JackOLantern"}, 26, 1, {chance = 0.5, off = 2})
	end,
	fill = {
		{names = {"CrateStack", "Bench", "NoticeBoard", "Cart", "Brazier", "ToxicBarrels"}, n = 16, smin = 1, smax = 1.2, gap = 7, space = 5, maxY = 6},
		{names = {"RockA", "RockC", "BushA", "BushB", "Mushrooms", "Pumpkin"}, n = 26, smin = 1, smax = 1.5, gap = 6, space = 3, maxY = 6},
		{names = {"DeadTreeA", "PineA", "CypressA"}, n = 8, smin = 0.5, smax = 0.8, gap = 12, space = 8, maxY = 6},
	},
}

---------- Blood Moon Cemetery (de la verja al mausoleo, entre las criptas) ----------
Defs.BloodMoonCemetery = {
	path = {{178, 80}, {120, 80}, {120, -50}, {60, -50}, {60, 55}, {0, 55}, {0, -62}, {-65, -62}, {-65, 40}, {-140, 40}, {-140, -80}},
	width = 9, chamfer = 6,
	style = {mat = M.Cobblestone, color = C(118, 108, 112), edgeMat = M.Concrete, edgeColor = C(60, 54, 60), edge = 1.8, band = C(84, 76, 82), bandMat = M.Cobblestone},
	ground = M.Grass, oldMats = {M.Ground, M.Mud},
	keepNames = {"Mausoleum", "CemeteryGate", "ZombieCrypt", "Crypt", "Chapel", "LunaDeSangre", "Halo"},
	decor = function(B, R, pts)
		corners(B, R, pts, "Brazier", 1.4)
		along(B, R, pts, {"GraveCross", "GraveRound", "Candles", "JackOLantern"}, 22, 1.3, {chance = 0.6, off = 1})
	end,
	fill = {
		{names = {"GraveCross", "GraveRound", "GraveObelisk", "GraveSlab", "GraveTomb", "Coffin", "AngelStatue", "Candles", "BonePile", "ZombieHand"}, n = 40, smin = 1, smax = 1.5, gap = 6, space = 3},
		{names = {"DeadTreeA", "DeadTreeB", "DeadTreeC"}, n = 12, smin = 0.5, smax = 0.8, gap = 12, space = 7},
	},
}

---------- Voidcore Rift (espiral cuadrada hasta el Corazón del Vacío, con bordes de neón) ----------
Defs.VoidcoreRift = {
	path = {{-178, -96}, {150, -96}, {150, 82}, {-142, 82}, {-142, -58}, {112, -58}, {112, 46}, {-104, 46}, {-104, -14}, {-10, -14}},
	width = 9, chamfer = 6, arrowEvery = 26,
	style = {mat = M.Basalt, color = C(72, 60, 96), edgeMat = M.Neon, edgeColor = C(126, 52, 214), edge = 1.2, band = C(58, 46, 80), bandMat = M.Basalt},
	ground = M.Basalt, oldMats = {M.Slate, M.Ground}, under = M.Basalt,
	keepNames = {"VoidHeart", "Nucleo", "Remolino", "Aro", "Base", "Pilar", "Capitel", "Circulo"},
	decor = function(B, R, pts)
		corners(B, R, pts, "VoidCrystals", 0.5)
		along(B, R, pts, {"VoidCrystals", "BonePile", "RockC"}, 26, 0.5, {chance = 0.45, off = 1.5})
	end,
	fill = {
		{names = {"VoidCrystals"}, n = 14, smin = 0.5, smax = 0.8, gap = 9, space = 6},
		{names = {"RockA", "RockC", "BonePile", "Mushrooms"}, n = 24, smin = 1, smax = 1.5, gap = 6, space = 3},
	},
}

return Defs
