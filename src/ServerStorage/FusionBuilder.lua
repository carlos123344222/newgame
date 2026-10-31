-- Monta el Caldero de Fusión en workspace.Mapa.Tiendas.Fusion (se ejecuta a mano en Studio, en modo edición):
--   require(game.ServerStorage.FusionBuilder).build()
-- En el cruce del centro del cementerio, al final del camino norte de la plaza: desde la fuente se ve al fondo, tras
-- la puerta "CEMETERY", con la cripta detrás. El modelo viene de Blender (FusionModelData): la bruja Hexa removiendo un
-- caldero gigante dentro de un círculo ritual, bajo un arco gótico con los tres cristales de estrella (oro, diamante
-- y mítico: las tres estrellas de fusión). Aquí se le añade lo que no es geometría: luces, fuego, vapor, el aviso
-- para abrir la fusión y el ancla del cartel flotante. Lo que se mueve (almas, cristales, aro) lo anima TiendasFX.
-- Mira a la plaza (su -Z local). Atributo Kind = "fuse", como los puestos de TiendasMapaBuilder.
local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")

local B = {}

B.SPOT = CFrame.lookAt(Vector3.new(-183, 0, -82.5), Vector3.new(-183, 0, 0))
B.R = 10.5 -- radio de la plataforma (lo que se despeja alrededor)

local C = Color3.fromRGB
local M = Enum.Material
local STARS = {CristalOro = C(255, 200, 60), CristalDiamante = C(80, 230, 255), CristalMitico = C(255, 90, 220)}
local BREW, LIME, PURPLE = C(70, 215, 80), C(150, 255, 100), C(170, 90, 255)

local function nums(line)
	local t = {}
	for v in line:gmatch("%S+") do
		table.insert(t, v)
	end
	return t
end

-- Las piezas de FusionModelData, colocadas respecto a O
local function parts(O, parent)
	local names, pals = {}, {}
	local list = {}
	for line in require(SS.FusionModelData):gmatch("[^\n]+") do
		local t = nums(line)
		if t[1] == "NAMES" then
			for i = 2, #t do
				names[i - 2] = t[i]
			end
		elseif t[1] == "PALS" then
			for i = 2, #t do
				local r, g, b, mat = t[i]:match("^(%d+),(%d+),(%d+),(%a+)$")
				pals[i - 2] = {C(tonumber(r), tonumber(g), tonumber(b)), M[mat]}
			end
		elseif #t == 14 then
			local shape = t[2]
			local p = Instance.new(shape == "w" and "WedgePart" or "Part")
			if shape == "c" then
				p.Shape = Enum.PartType.Cylinder
			elseif shape == "o" then
				p.Shape = Enum.PartType.Ball
			elseif shape == "e" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
			local pal = pals[tonumber(t[12])]
			p.Name = names[tonumber(t[1])]
			p.Size = Vector3.new(tonumber(t[9]), tonumber(t[10]), tonumber(t[11]))
			p.CFrame = O * CFrame.new(tonumber(t[3]), tonumber(t[4]), tonumber(t[5]))
				* CFrame.fromEulerAnglesXYZ(math.rad(tonumber(t[6])), math.rad(tonumber(t[7])), math.rad(tonumber(t[8])))
			p.Color, p.Material = pal[1], pal[2]
			p.Transparency = tonumber(t[13])
			p.Anchored = true
			local solid = t[14] == "1"
			p.CanCollide, p.CanQuery, p.CanTouch = solid, solid, false
			p.CastShadow = pal[2] ~= M.Neon
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = parent
			table.insert(list, p)
		end
	end
	return list
end

local function light(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = p
	return l
end

local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	for k, v in props do
		e[k] = v
	end
	e.Parent = p
	return e
end

local function fire(p, color, size, heat)
	local f = Instance.new("Fire")
	f.Color, f.SecondaryColor, f.Size, f.Heat = color, color:Lerp(Color3.new(1, 1, 1), 0.5), size, heat
	f.Parent = p
end

-- Lo que no es geometría, por nombre de pieza
local EXTRAS = {
	Pocion = function(p)
		light(p, BREW, 22, 1.3)
		emitter(p, {Name = "Vapor", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(BREW, PURPLE), LightEmission = 0.5,
			Rate = 6, Lifetime = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(1.2, 2.6), Size = NumberSequence.new(1.6, 4.2),
			Transparency = NumberSequence.new(0.55, 1), Acceleration = Vector3.new(0, 1, 0), SpreadAngle = Vector2.new(10, 10), Shape = Enum.ParticleEmitterShape.Disc,
			EmissionDirection = Enum.NormalId.Right})
		emitter(p, {Name = "Chispas", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(LIME, C(255, 230, 120)),
			Rate = 12, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2.5, 5), Size = NumberSequence.new(0.4, 0), SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Right})
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "Abrir"
		pp.ActionText = "Fuse Scares"
		pp.ObjectText = "Hexa's Cauldron"
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 16
		pp.RequiresLineOfSight = false
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.Parent = p
	end,
	Brasas = function(p)
		fire(p, C(255, 120, 40), 5, 6)
		light(p, C(255, 140, 60), 12, 1)
	end,
	FarolLuz = function(p)
		light(p, C(130, 255, 120), 16, 1.1)
	end,
	Alma = function(p)
		light(p, p.Color, 8, 0.8)
		CollectionService:AddTag(p, "AlmaFusion") -- (TiendasFX las hace girar sobre el caldero)
	end,
	Vela = function(p)
		fire(p, LIME, 1, 3)
	end,
	LibroPagina = function(p)
		light(p, C(255, 230, 160), 6, 0.6)
	end,
}
for name, color in STARS do
	EXTRAS[name] = function(p)
		light(p, color, 16, 1.3)
		emitter(p, {Name = "Destellos", Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
			Rate = 5, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(0.35, 0), SpreadAngle = Vector2.new(180, 180)})
		CollectionService:AddTag(p, "CristalFusion") -- (TiendasFX los hace girar y flotar)
	end
end

-- Saca del cruce lo que estorba (tumbas, faroles de camino, setas...) a ServerStorage.DecoradoQuitado
local function clearSpot()
	local keep = SS:FindFirstChild("DecoradoQuitado") or Instance.new("Folder")
	keep.Name = "DecoradoQuitado"
	keep.Parent = SS
	local c = B.SPOT.Position
	for _, m in workspace.Mapa.Cementerio:GetChildren() do
		local p = m:IsA("Model") and m:GetPivot().Position or m:IsA("BasePart") and m.Position
		if p and Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude < B.R + 1 and m.Name ~= "IronFence" and m.Name ~= "FencePillar" then
			m.Parent = keep
		end
	end
	local r = B.R + 2
	local region = Region3.new(c - Vector3.new(r, 8, r), c + Vector3.new(r, 8, r)):ExpandToGrid(4)
	for _, mat in {M.Grass, M.LeafyGrass} do
		workspace.Terrain:ReplaceMaterial(region, 4, mat, M.Ground)
	end
end

function B.build()
	local folder = workspace.Mapa.Tiendas
	local old = folder:FindFirstChild("Fusion")
	if old then
		old:Destroy()
	end
	clearSpot()
	local m = Instance.new("Model")
	m.Name = "Fusion"
	m:SetAttribute("Kind", "fuse")
	local list = parts(B.SPOT, m)
	for _, p in list do
		local f = EXTRAS[p.Name]
		if f then
			f(p)
		end
	end
	-- luz suave delante de la cara de la bruja: de noche si no, solo se le ven los ojos
	local head = m:FindFirstChild("BrujaCabeza")
	if head then
		local f = Instance.new("Part")
		f.Name = "LuzBruja"
		f.Size = Vector3.one * 0.2
		f.Transparency = 1
		f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch = true, false, false, false
		f.CFrame = head.CFrame * CFrame.new(0, 0.6, -3.2)
		f.Parent = m
		light(f, C(205, 170, 255), 12, 1.6)
		-- y otra violeta por detrás, para recortarla contra el fondo
		local rim = f:Clone()
		rim.Name = "LuzContornoBruja"
		rim.CFrame = head.CFrame * CFrame.new(0, 1, 3)
		rim.Parent = m
		rim.PointLight.Color, rim.PointLight.Range, rim.PointLight.Brightness = C(190, 120, 255), 10, 1.4
	end
	-- reflejo verde en la panza del caldero (desde delante y abajo): si no, es una mancha negra
	local belly = Instance.new("Part")
	belly.Name = "LuzPanza"
	belly.Size = Vector3.one * 0.2
	belly.Transparency = 1
	belly.Anchored, belly.CanCollide, belly.CanQuery, belly.CanTouch = true, false, false, false
	belly.CFrame = B.SPOT * CFrame.new(-0.9, 2.2, -5.5)
	belly.Parent = m
	light(belly, C(110, 255, 110), 9, 1.6)
	local a = Instance.new("Part")
	a.Name = "BadgeAnchor"
	a.Size = Vector3.one
	a.Transparency = 1
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.CFrame = B.SPOT * CFrame.new(0, 25, 7.6)
	a.Parent = m
	m.PrimaryPart = m:FindFirstChild("Base")
	CollectionService:AddTag(m, "Tienda")
	m.Parent = folder
	return m, #list
end

return B
