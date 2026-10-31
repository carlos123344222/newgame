-- Monta Cursed Carnival a partir del FBX importado de Blender (CursedCarnival.fbx, Archivo > Importar 3D).
-- Las mallas se llaman "Asset__pieza__Material__COLOR__colisión" (P precisa, H envolvente, B caja, N sin colisión).
-- 1) kit(import): crea ServerStorage.CarnivalKit (un Model por asset, con su pivote, luces, carteles y efectos).
-- 2) place(): coloca el kit en workspace.CursedCarnival.Atracciones según CursedCarnivalData (trazado de Blender).
-- Uso desde la barra de comandos: require(game.ServerStorage.CursedCarnivalBuilder).all(<modelo importado>)
local Data = require(script.Parent.CursedCarnivalData)
local KitData = require(script.Parent.CursedCarnivalKitData)

local B = {}
local O = Vector3.new(1400, 2, 800)
local MAPCOORDS = {CarnivalPath = true, Coaster = true}
local SIGNS = {
	ClownGate = "CURSED CARNIVAL", FunHouse = "FUN HOUSE", FerrisWheel = "RIDES", BigTop = "BIG TOP", Lagoon = "TUNNEL OF LOVE",
	FortuneTent = "FORTUNES", TicketBooth = "TICKETS",
}
local STALL_SIGNS = {"RING TOSS", "DUCK SHOOT", "BALLOON POP", "PRIZES!", "KNOCK 'EM DOWN"}
local FIDELITY = {P = Enum.CollisionFidelity.PreciseConvexDecomposition, H = Enum.CollisionFidelity.Hull, B = Enum.CollisionFidelity.Box}

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function sign(model, a, text, pivot)
	local p = Instance.new("Part")
	p.Name = "Cartel"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(a[3], a[4], 0.1)
	p.CFrame = pivot * CFrame.new(v3(a[2])) * CFrame.Angles(0, a[5], 0)
	local g = Instance.new("SurfaceGui")
	g.Name = "Gui"
	g.Face = Enum.NormalId.Back -- el frente de los assets mira a +Z
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Texto"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.fromRGB(255, 214, 90)
	t.TextStrokeColor3 = Color3.fromRGB(60, 10, 40)
	t.TextStrokeTransparency = 0
	t.Parent = g
	g.Parent = p
	p.Parent = model
end

-- Busca las mallas del FBX importado (donde estén) y monta ServerStorage.CarnivalKit.
-- El importador de Studio puede escalar (scale: studs importados por stud de Blender) y girar 180° (flip); por
-- defecto se miden con la viga de la puerta-payaso (19 studs de largo) y la bandera de sus torres (a +X).
function B.kit(import, scale, flip)
	local byAsset = {}
	for _, d in import:GetDescendants() do
		if d:IsA("MeshPart") then
			local asset, pid, mat, hex, col = d.Name:match("^(%w+)__([%w_]-)__(%w+)__(%x+)__(%u)")
			if asset and KitData[asset] then
				byAsset[asset] = byAsset[asset] or {}
				byAsset[asset][pid] = {part = d, mat = mat, hex = hex, col = col}
			end
		end
	end
	local gate = byAsset.ClownGate
	scale = scale or (gate and gate.beam and gate.beam.part.Size.X / 19) or 1
	if flip == nil then
		flip = gate ~= nil and gate.flags ~= nil and gate.flags.part.Position.X < gate.poles.part.Position.X
	end
	local rot = flip and CFrame.Angles(0, math.pi, 0) or CFrame.identity
	local kit = game.ServerStorage:FindFirstChild("CarnivalKit")
	if kit then
		kit:Destroy()
	end
	kit = Instance.new("Folder")
	kit.Name = "CarnivalKit"
	local missing = {}
	for name, info in KitData do
		local got = byAsset[name]
		if not got then
			table.insert(missing, name)
			continue
		end
		local model = Instance.new("Model")
		model.Name = name
		model:SetAttribute("Asset", name)
		-- pivote: centro de la malla importada menos su centro en Blender (media de todas las piezas)
		local sum, n = Vector3.zero, 0
		for _, p in info.parts do
			local g = got[p[1]]
			if g then
				sum += g.part.Position - rot:VectorToWorldSpace(v3(p[2]) * scale)
				n += 1
			end
		end
		local pivot = CFrame.new(sum / math.max(n, 1)) * rot
		for _, p in info.parts do
			local g = got[p[1]]
			if not g then
				continue
			end
			local m = g.part:Clone()
			m.Name = p[1]
			m.Anchored = true
			m.Material = Enum.Material[g.mat] or Enum.Material.SmoothPlastic
			m.Color = Color3.fromHex(g.hex)
			m.TextureID = ""
			m.Transparency = p[3]
			m.CastShadow = p[4] and g.mat ~= "Neon"
			m.CanCollide = g.col ~= "N"
			m.CanQuery = g.col ~= "N"
			m.CanTouch = false
			if g.mat == "Glass" then
				m.Reflectance = 0.1
			end
			if FIDELITY[g.col] then
				pcall(function()
					m.CollisionFidelity = FIDELITY[g.col]
				end)
			end
			for _, c in m:GetChildren() do
				if not c:IsA("Attachment") then
					c:Destroy() -- (SurfaceAppearance/texturas del importador: aquí manda el color)
				end
			end
			m.Parent = model
		end
		model.WorldPivot = pivot
		if math.abs(scale - 1) > 1e-3 then
			model:ScaleTo(1 / scale)
		end
		pivot = model:GetPivot()
		-- luces (sin sombras: hay muchas)
		for i, l in info.lights do
			local a = Instance.new("Attachment")
			a.Name = "Luz" .. i
			local holder = model:FindFirstChildWhichIsA("BasePart")
			a.Parent = holder
			a.WorldPosition = (pivot * CFrame.new(v3(l[1]))).Position
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromHex(l[2])
			pl.Range, pl.Brightness, pl.Shadows = l[3], l[4], false
			pl.Parent = a
		end
		for _, f in info.fx do
			local holder = model:FindFirstChildWhichIsA("BasePart")
			local a = Instance.new("Attachment")
			a.Name = f[1]
			a.Parent = holder
			a.WorldPosition = (pivot * CFrame.new(v3(f[2]))).Position
			if f[1] == "Sparkles" then
				local s = Instance.new("ParticleEmitter")
				s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				s.Color = ColorSequence.new(Color3.fromRGB(190, 120, 255))
				s.LightEmission, s.Rate, s.Lifetime, s.Speed = 1, 6, NumberRange.new(0.8, 1.4), NumberRange.new(0.5, 1.5)
				s.Size = NumberSequence.new(0.4, 0)
				s.SpreadAngle = Vector2.new(180, 180)
				s.Parent = a
			else -- niebla baja
				local s = Instance.new("ParticleEmitter")
				s.Texture = "rbxasset://textures/particles/smoke_main.dds"
				s.Color = ColorSequence.new(Color3.fromRGB(150, 120, 190))
				s.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1)})
				s.Size = NumberSequence.new(6, 10)
				s.Rate, s.Lifetime, s.Speed = 3, NumberRange.new(5, 8), NumberRange.new(0.3, 0.8)
				s.SpreadAngle = Vector2.new(180, 10)
				s.Parent = a
			end
		end
		for _, a in info.anchors do
			sign(model, a, SIGNS[name] or STALL_SIGNS[1], pivot)
		end
		model.Parent = kit
	end
	kit.Parent = game.ServerStorage
	return kit, missing
end

-- Coloca el kit en el mapa según el trazado de Blender
function B.place()
	local kit = game.ServerStorage.CarnivalKit
	local map = workspace.CursedCarnival
	local old = map:FindFirstChild("Atracciones")
	if old then
		old:Destroy()
	end
	local rides = Instance.new("Folder")
	rides.Name = "Atracciones"
	rides.Parent = map
	local n, stall = 0, 0
	local batch = Instance.new("Folder")
	local function flush()
		for _, m in batch:GetChildren() do
			m.Parent = rides
		end
		task.wait()
	end
	for name in MAPCOORDS do
		local t = kit:FindFirstChild(name)
		if t then
			local m = t:Clone()
			m:PivotTo(CFrame.new(O))
			m.Parent = rides
			if name == "CarnivalPath" then
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						p.CanCollide, p.CanQuery = false, false -- la colisión la pone MapaTDS.Camino
					end
				end
			end
		end
	end
	for _, p in Data.place do
		local t = kit:FindFirstChild(p[1])
		if not t then
			continue
		end
		local m = t:Clone()
		if p[5] ~= 1 then
			m:ScaleTo(m:GetScale() * p[5]) -- (ScaleTo es absoluto y el kit ya viene reescalado del importador)
		end
		m:PivotTo(CFrame.new(O + Vector3.new(p[2], 0, p[3])) * CFrame.Angles(0, math.rad(p[4]), 0))
		if p[1] == "StallA" or p[1] == "StallB" then
			stall += 1
			local c = m:FindFirstChild("Cartel", true)
			if c then
				c.Gui.Texto.Text = STALL_SIGNS[(stall - 1) % #STALL_SIGNS + 1]
			end
		end
		-- cabinas de la noria (las cuelga CarnivalFX en el cliente)
		if p[1] == "FerrisWheel" and kit:FindFirstChild("FerrisCab") then
			local hub = m:GetPivot() * CFrame.new(0, 30, 0)
			for k = 0, 11 do
				local cab = kit.FerrisCab:Clone()
				cab.Name = "Cab" .. k
				cab:SetAttribute("Cab", k)
				cab:SetAttribute("Cabs", 12)
				local th = k / 12 * math.pi * 2
				cab:PivotTo(CFrame.new((hub * CFrame.new(math.cos(th) * 24, math.sin(th) * 24, 0)).Position) * hub.Rotation)
				cab.Parent = m
			end
		end
		m.Parent = batch
		n += 1
		if n % 40 == 0 then
			flush()
		end
	end
	flush()
	batch:Destroy()
	return n
end

function B.all(import)
	local _, missing = B.kit(import)
	task.wait()
	local n = B.place()
	return n, missing
end

return B
