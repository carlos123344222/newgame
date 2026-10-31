-- Don Calabaza, el alcalde de la calle y guía del tutorial. Modelo de piezas animado por código
-- (sin física ni soldaduras): sirve en el mundo (en tu jardín) y dentro de un ViewportFrame (el retrato).
--   local c = Calabaza.new({scale = 0.85, light = true})
--   c.model.Parent = workspace; c.root = CFrame.new(...); c.talking = true; c.wave = true
--   cada frame: c:update(dt)
local Calabaza = {}
Calabaza.__index = Calabaza

local M = Enum.Material
local SMOOTH = M.SmoothPlastic

local PUMPKIN = {Color3.fromRGB(255, 136, 26), Color3.fromRGB(248, 120, 20), Color3.fromRGB(236, 104, 16)}
local GLOW = Color3.fromRGB(255, 214, 84)
local COAT = Color3.fromRGB(104, 50, 158)
local COAT_DARK = Color3.fromRGB(72, 32, 112)
local TROUSERS = Color3.fromRGB(46, 28, 64)
local SHOES = Color3.fromRGB(30, 22, 30)
local GREEN = Color3.fromRGB(70, 176, 60)
local LEAF = Color3.fromRGB(58, 140, 52)
local WHITE = Color3.fromRGB(244, 240, 230)
local HAT = Color3.fromRGB(30, 24, 40)
local GOLD = Color3.fromRGB(240, 190, 70)

-- Huesos en reposo, relativos a los pies (mira hacia -Z, como cualquier personaje)
local REST = {
	body = CFrame.new(),
	head = CFrame.new(0, 5.15, 0),
	armL = CFrame.new(-1.02, 4.45, 0),
	armR = CFrame.new(1.02, 4.45, 0),
}
local HEAD = CFrame.new(0, 6.3, 0) -- centro de la calabaza

function Calabaza.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Calabaza)
	local S = opts.scale or 1
	self.S = S
	self.model = Instance.new("Model")
	self.model.Name = "DonCalabaza"
	self.pieces = {}
	self.root = CFrame.new()
	self.talking = false
	self.wave = false
	self.t = math.random() * 10
	self.talkBlend, self.waveBlend, self.hop = 0, 0, 0
	self.land, self.lookYaw, self.lookPitch, self.blinkIn = 0, 0, 0, 2 + math.random() * 2
	self.inWorld = opts.light == true

	local function make(bone, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = size.Magnitude > 1.2
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = size * S
		p.Color = color
		p.Material = material or SMOOTH
		if shape then
			p.Shape = shape
		end
		local scaled = CFrame.new(cf.Position * S) * cf.Rotation
		p.CFrame = scaled
		p.Parent = self.model
		local rest = REST[bone]
		local restScaled = CFrame.new(rest.Position * S) * rest.Rotation
		table.insert(self.pieces, {part = p, bone = bone, offset = restScaled:Inverse() * scaled})
		return p
	end
	-- elipsoide: una pieza con malla de esfera estirada
	local function egg(bone, size, cf, color, material)
		local p = make(bone, size, cf, color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function ball(bone, d, pos, color, material)
		return make(bone, Vector3.one * d, CFrame.new(pos), color, material, Enum.PartType.Ball)
	end
	local function cyl(bone, len, d, cf, color, material) -- cilindro a lo largo del UpVector de cf
		return make(bone, Vector3.new(len, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
	end
	-- triángulo (dos cuñas). face: origen en el centro de la base, UpVector hacia el vértice, LookVector hacia fuera
	local function tri(bone, face, w, h, color, material)
		local t = 0.06
		for _, k in {1, -1} do
			local w2 = Instance.new("WedgePart")
			w2.Anchored = true
			w2.CanCollide, w2.CanQuery, w2.CanTouch = false, false, false
			w2.CastShadow = false
			w2.Size = Vector3.new(t, h, w / 2) * S
			w2.Color = color
			w2.Material = material or M.Neon
			local local_ = CFrame.fromMatrix(Vector3.new(-k * w / 4, h / 2, 0), Vector3.new(0, 0, -k), Vector3.new(0, 1, 0), Vector3.new(k, 0, 0))
			local cf = face * local_
			local scaled = CFrame.new(cf.Position * S) * cf.Rotation
			w2.CFrame = scaled
			w2.Parent = self.model
			local rest = REST[bone]
			local restScaled = CFrame.new(rest.Position * S) * rest.Rotation
			table.insert(self.pieces, {part = w2, bone = bone, offset = restScaled:Inverse() * scaled})
		end
	end
	local function facing(pos, up) -- marco de cara mirando hacia -Z (hacia quien le mira de frente)
		up = up or Vector3.yAxis
		local right = up:Cross(Vector3.zAxis).Unit
		return CFrame.fromMatrix(pos, right, up)
	end

	---------- Cuerpo ----------
	for _, s in {-1, 1} do
		make("body", Vector3.new(0.62, 0.4, 1.05), CFrame.new(s * 0.36, 0.2, -0.16), SHOES)
		egg("body", Vector3.new(0.42, 0.42, 0.55), CFrame.new(s * 0.36, 0.36, -0.7) * CFrame.Angles(math.rad(-25), 0, 0), SHOES)
		make("body", Vector3.new(0.5, 2.2, 0.5), CFrame.new(s * 0.36, 1.5, 0), TROUSERS)
		make("body", Vector3.new(0.72, 1.3, 0.12), CFrame.new(s * 0.36, 2.2, 0.55) * CFrame.Angles(math.rad(-10), 0, s * math.rad(6)), COAT_DARK) -- faldones del frac
	end
	self.chest = egg("body", Vector3.new(2.05, 2.5, 1.25), CFrame.new(0, 3.55, 0), COAT)
	egg("body", Vector3.new(0.78, 1.3, 0.3), CFrame.new(0, 3.98, -0.5), WHITE)
	for _, s in {-1, 1} do
		make("body", Vector3.new(0.2, 1.25, 0.1), CFrame.new(s * 0.42, 3.95, -0.57) * CFrame.Angles(0, 0, s * math.rad(-22)), COAT_DARK)
	end
	ball("body", 0.2, Vector3.new(0, 3.12, -0.6), GOLD, M.Metal)
	ball("body", 0.2, Vector3.new(0, 2.72, -0.53), GOLD, M.Metal)
	-- pajarita verde
	tri("body", CFrame.fromMatrix(Vector3.new(0.44, 4.55, -0.63), Vector3.yAxis, -Vector3.xAxis), 0.5, 0.42, GREEN, SMOOTH)
	tri("body", CFrame.fromMatrix(Vector3.new(-0.44, 4.55, -0.63), -Vector3.yAxis, Vector3.xAxis), 0.5, 0.42, GREEN, SMOOTH)
	ball("body", 0.22, Vector3.new(0, 4.55, -0.66), GREEN)
	-- cuello de tallo con hojas
	egg("body", Vector3.new(0.55, 0.6, 0.55), CFrame.new(0, 4.95, 0), Color3.fromRGB(96, 130, 52))
	for k = 0, 5 do
		local a = k * math.pi / 3
		egg("body", Vector3.new(0.75, 0.13, 0.36), CFrame.new(0, 4.82, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.42, 0, 0) * CFrame.Angles(0, 0, math.rad(-18)), LEAF)
	end

	---------- Brazos ----------
	for _, s in {-1, 1} do
		local bone = s == 1 and "armR" or "armL"
		local sh = REST[bone]
		ball(bone, 0.66, sh.Position, COAT)
		egg(bone, Vector3.new(0.52, 1.6, 0.52), sh * CFrame.new(0, -0.8, 0), COAT)
		egg(bone, Vector3.new(0.6, 0.26, 0.6), sh * CFrame.new(0, -1.55, 0), Color3.fromRGB(255, 150, 40))
		ball(bone, 0.64, (sh * CFrame.new(0, -1.86, 0)).Position, WHITE)
		ball(bone, 0.26, (sh * CFrame.new(-s * 0.24, -1.74, -0.22)).Position, WHITE)
	end

	---------- Cabeza de calabaza ----------
	egg("head", Vector3.new(1.65, 2.1, 2.3), HEAD, PUMPKIN[1])
	for _, s in {-1, 1} do
		egg("head", Vector3.new(1.4, 2.02, 2.15), HEAD * CFrame.new(s * 0.56, 0, 0.02), PUMPKIN[2])
		egg("head", Vector3.new(1.1, 1.78, 1.86), HEAD * CFrame.new(s * 0.96, -0.03, 0.06), PUMPKIN[3])
		egg("head", Vector3.new(1.3, 1.95, 1.8), HEAD * CFrame.new(s * 0.45, 0, 0.38), PUMPKIN[2])
	end
	-- ojos triangulares que brillan, con pupilas (inclinados hacia atrás, siguiendo la curva de la calabaza)
	local back = Vector3.new(0, math.cos(math.rad(25)), math.sin(math.rad(25)))
	for _, s in {-1, 1} do
		tri("head", facing((HEAD * CFrame.new(s * 0.43, 0.08, -1.08)).Position, back), 0.58, 0.52, GLOW)
		egg("head", Vector3.new(0.17, 0.22, 0.05), HEAD * CFrame.new(s * 0.43, 0.22, -1.07) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(40, 18, 10))
		make("head", Vector3.new(0.46, 0.1, 0.07), HEAD * CFrame.new(s * 0.45, 0.72, -0.77) * CFrame.Angles(math.rad(35), 0, s * math.rad(-12)), Color3.fromRGB(110, 52, 10))
	end
	tri("head", facing((HEAD * CFrame.new(0, -0.24, -1.15)).Position), 0.26, 0.22, GLOW)
	-- párpados para parpadear (invisibles salvo durante el parpadeo)
	self.lids = {}
	for _, s in {-1, 1} do
		local lid = egg("head", Vector3.new(0.72, 0.66, 0.16), HEAD * CFrame.new(s * 0.43, 0.3, -1.12) * CFrame.Angles(math.rad(25), 0, 0), PUMPKIN[1])
		lid.Transparency = 1
		table.insert(self.lids, lid)
	end
	-- boca: se abre al hablar (ver update)
	self.mouth = egg("head", Vector3.new(1.25, 0.3, 0.08), HEAD * CFrame.new(0, -0.58, -0.95) * CFrame.Angles(math.rad(-15), 0, 0), GLOW, M.Neon)
	self.mouthPiece = self.pieces[#self.pieces]
	for _, s in {-1, 1} do
		egg("head", Vector3.new(0.26, 0.22, 0.08), HEAD * CFrame.new(s * 0.6, -0.47, -0.95), GLOW, M.Neon)
		make("head", Vector3.new(0.2, 0.17, 0.05), HEAD * CFrame.new(s * 0.24, -0.5, -1.0) * CFrame.Angles(math.rad(-15), 0, 0), PUMPKIN[1]) -- dientes
	end
	-- chistera ladeada, con el tallo asomando por arriba
	local hat = HEAD * CFrame.Angles(0, 0, math.rad(-9)) * CFrame.new(0.08, 1.0, 0.05)
	cyl("head", 0.13, 2.3, hat, HAT)
	cyl("head", 1.3, 1.36, hat * CFrame.new(0, 0.7, 0), HAT)
	cyl("head", 0.3, 1.4, hat * CFrame.new(0, 0.22, 0), Color3.fromRGB(255, 140, 30))
	cyl("head", 0.55, 0.26, hat * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(100, 120, 44))
	egg("head", Vector3.new(0.6, 0.1, 0.32), hat * CFrame.new(0.3, 1.5, 0) * CFrame.Angles(0, 0, math.rad(20)), LEAF)

	if opts.light then
		local glow = Instance.new("PointLight")
		glow.Range = 10
		glow.Brightness = 1.3
		glow.Color = Color3.fromRGB(255, 150, 60)
		glow.Shadows = false
		glow.Parent = self.mouth
	end
	self.mouthTop = -0.43
	self.model.PrimaryPart = self.pieces[1].part
	self:update(0)
	return self
end

-- Pose de este frame
function Calabaza:update(dt)
	self.t += dt
	local t, S = self.t, self.S
	local k = math.min(1, dt * 10)
	self.talkBlend += ((self.talking and 1 or 0) - self.talkBlend) * k
	self.waveBlend += ((self.wave and 1 or 0) - self.waveBlend) * math.min(1, dt * 6)
	local wasHop = self.hop > 0
	self.hop = math.max(0, self.hop - dt * 2.4)
	if wasHop and self.hop == 0 then
		self.land = 1 -- al caer se aplasta un poco
	end
	self.land = math.max(0, self.land - dt * 5)
	local talk = self.talkBlend
	local hopUp = math.sin(self.hop * math.pi)
	local hop = hopUp * 0.9 - math.sin(self.land * math.pi) * 0.22
	-- parpadeo: 0.12 s cada 3-5 s
	self.blinkIn -= dt
	local closed = self.blinkIn < 0
	if self.blinkIn < -0.12 then
		self.blinkIn = 3 + math.random() * 2
	end
	if closed ~= self.closed then
		self.closed = closed
		for _, lid in self.lids do
			lid.Transparency = closed and 0 or 1
		end
	end
	-- mira hacia lookAt (a ti, si estás cerca) girando la cabeza, con límites y suavizado
	local yawT, pitchT = 0, 0
	if self.lookAt then
		local rel = (self.root * CFrame.new(0, 6.3 * S, 0)):PointToObjectSpace(self.lookAt)
		yawT = math.clamp(math.atan2(-rel.X, -rel.Z), -0.9, 0.9)
		pitchT = math.clamp(math.atan2(rel.Y, math.sqrt(rel.X * rel.X + rel.Z * rel.Z)), -0.35, 0.35)
	end
	local kk = math.min(1, dt * 5)
	self.lookYaw += (yawT - self.lookYaw) * kk
	self.lookPitch += (pitchT - self.lookPitch) * kk
	local bob = math.sin(t * 2.4) * 0.05 + talk * math.abs(math.sin(t * 7.5)) * 0.07 + hop
	local function sc(cf)
		return CFrame.new(cf.Position * S) * cf.Rotation
	end
	local body = self.root * CFrame.new(0, bob * S, 0) * CFrame.Angles(0, 0, math.sin(t * 1.2) * 0.025)
	local bones = {
		body = body,
		head = body * sc(REST.head) * CFrame.Angles(self.lookPitch, self.lookYaw, 0) * CFrame.Angles(math.sin(t * 1.7) * 0.04 + talk * math.sin(t * 9) * 0.07, math.sin(t * 0.9) * 0.12 * (1 - math.min(1, math.abs(self.lookYaw) * 2)), math.sin(t * 1.3) * 0.08),
		armL = body * sc(REST.armL) * CFrame.Angles(math.sin(t * 2) * 0.06 + talk * 0.25 * math.sin(t * 2.3), 0, -0.14 - talk * 0.35 * (0.5 + 0.5 * math.sin(t * 3.1)) - hopUp * 1.9),
		armR = body * sc(REST.armR) * CFrame.Angles(-math.sin(t * 2) * 0.06, 0, 0.14 + self.waveBlend * (2.45 + math.sin(t * 10) * 0.4) + (1 - self.waveBlend) * (talk * 0.3 * (0.5 + 0.5 * math.sin(t * 2.6 + 1)) + hopUp * 1.9)),
	}
	-- la boca se abre y se cierra mientras habla
	local open = 0.3 + talk * (0.18 + 0.42 * math.abs(math.noise(t * 7, 2.7)))
	local mouth = self.mouthPiece
	mouth.part.Size = Vector3.new(1.25, open, 0.08) * S
	mouth.offset = CFrame.new(0, (1.15 + self.mouthTop - open / 2) * S, -0.95 * S) * CFrame.Angles(math.rad(-15), 0, 0)
	local parts, cframes = table.create(#self.pieces), table.create(#self.pieces)
	for i, p in self.pieces do
		parts[i] = p.part
		cframes[i] = bones[p.bone] * p.offset
	end
	if self.inWorld and self.model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end
end

-- Saltito de alegría (en el jardín suena un "blup")
function Calabaza:jump()
	self.hop = 1
	local part = self.inWorld and self.model.PrimaryPart
	local t = part and game:GetService("ReplicatedStorage").Assets.Sounds:FindFirstChild("Hop")
	if t then
		local s = t:Clone()
		s.Parent = part
		s:Play()
		game:GetService("Debris"):AddItem(s, 2)
	end
end

function Calabaza:destroy()
	self.model:Destroy()
end

return Calabaza
