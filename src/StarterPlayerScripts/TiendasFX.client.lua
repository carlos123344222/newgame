-- El puesto de la ruleta (cliente): da vida a la Wheel of Fright de workspace.Mapa.Tiendas (la construye
-- TiendasMapaBuilder). Bombillas de feria en cadena, la ruleta gigante (gira cuando alguien tira, para todos) y el
-- cartel flotante con su aviso (tirada gratis). El mostrador abre la ruleta con su ProximityPrompt (eso está en Tiendas).
-- También el Caldero de Fusión del cementerio (FusionBuilder): las tres almas que giran sobre el caldero, los cristales
-- que flotan y su cartel ("★ 3 READY TO FUSE!"). Su aviso lo abre FusionUI.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(RS:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sfx = require(RS:WaitForChild("Sfx"))
local player = Players.LocalPlayer

local folder = workspace:WaitForChild("Mapa"):WaitForChild("Tiendas", 60)
if not folder then
	return
end
-- (con StreamingEnabled los puestos, persistentes, pueden llegar después de que arranque este script)
folder:WaitForChild("Ruleta", 60)
folder:WaitForChild("Fusion", 60)
local booths = {}
for _, m in folder:GetChildren() do
	booths[m:GetAttribute("Kind")] = m
end

local function sound3D(name, parent, gain, pitch)
	local s = parent and Sfx.play(name, parent, gain, pitch)
	if s then
		s.RollOffMinDistance, s.RollOffMaxDistance = 12, 90
	end
end

local function catColor(t)
	return Config.Categories[Config.Scares[t].cat].color
end

---------- Bombillas en cadena ----------
local bulbs = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Marquee") then
		table.insert(bulbs, d)
	end
end
local ON, OFF = Color3.fromRGB(255, 236, 170), Color3.fromRGB(90, 60, 40)
local step = -1

---------- Ruleta gigante ----------
local wheel = booths.wheel
local rotor = wheel and wheel:FindFirstChild("Rotor")
local pointer = wheel and wheel:FindFirstChild("Flecha")
local angle, spinning, lastSlot = 0, false, 0
local rotorBase = rotor and rotor:GetAttribute("Base")
local rotorParts = {}
if rotor then
	for _, p in rotor:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(rotorParts, {p, rotorBase:ToObjectSpace(p.CFrame)})
		end
	end
end
local pointerBase = pointer and pointer.CFrame

-- Nombres y colores de los premios de la ruleta que se enseña (la última que alguien giró; al principio, la mejor)
local labels = {}
local function paintWheel(tier, period)
	if not rotor then
		return
	end
	local prizes = Config.wheelPrizes(tier, period)
	for _, p in rotor:GetChildren() do
		local k = p:GetAttribute("Seg")
		if k then
			p.Color = catColor(prizes[k].scare)
		end
	end
	local sg = rotor:FindFirstChild("Caras") and rotor.Caras:FindFirstChild("Premios")
	if not sg then
		return
	end
	local R = sg.AbsoluteSize.X / 2
	for k, p in prizes do
		local l = labels[k]
		if not l then
			l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			local s = Instance.new("UIStroke")
			s.Thickness = 3
			s.Color = Color3.fromRGB(20, 10, 25)
			s.Parent = l
			l.Parent = sg
			labels[k] = l
		end
		local a = (k - 1) * 45
		local r = math.rad(a)
		l.Size = UDim2.fromOffset(R * 0.62, R * 0.2)
		l.Position = UDim2.fromOffset(R + math.sin(r) * R * 0.6, R - math.cos(r) * R * 0.6)
		l.Rotation = a - 90 -- a lo largo del radio, como en las ruletas de feria
		l.Text = Config.Scares[p.scare].name
	end
end

local function setRotor(a)
	local cf = rotorBase * CFrame.Angles(0, 0, math.rad(a))
	for _, e in rotorParts do
		e[1].CFrame = cf * e[2]
	end
end

local function spinBig()
	local tier, period, slot = wheel:GetAttribute("SpinTier"), wheel:GetAttribute("SpinPeriod"), wheel:GetAttribute("SpinSlot")
	if not (tier and period and slot) or not rotor then
		return
	end
	paintWheel(tier, period)
	spinning = true
	local from = angle
	local target = from - from % 360 + 360 * 5 + (-(slot - 1) * 45 + math.random(-15, 15)) % 360
	local v = Instance.new("NumberValue")
	v.Value = from
	local tw = TweenService:Create(v, TweenInfo.new(Config.WHEEL_SPIN_TIME - 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Value = target})
	local conn = v.Changed:Connect(function(x)
		angle = x
	end)
	tw:Play()
	tw.Completed:Wait()
	conn:Disconnect()
	v:Destroy()
	angle = target
	spinning = false
	-- premio: confeti y fanfarria en el puesto
	if pointer then
		sound3D("Win", pointer, 1.4)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 255))})
		pe.Size = NumberSequence.new(0.35)
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Speed = NumberRange.new(14, 26)
		pe.SpreadAngle = Vector2.new(70, 70)
		pe.Acceleration = Vector3.new(0, -25, 0)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-300, 300)
		pe.LightEmission = 0.4
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Rate = 0
		pe.Parent = pointer
		pe:Emit(90)
		task.delay(3, pe.Destroy, pe)
	end
end

if wheel then
	paintWheel(#Config.Wheels, Config.wheelPeriod(workspace:GetServerTimeNow()))
	wheel:GetAttributeChangedSignal("SpinSeq"):Connect(function()
		task.spawn(spinBig)
	end)
end

---------- Carteles flotantes ----------
local BILL = {
	wheel = {icon = "wheel", title = "WHEEL OF FRIGHT", color = Color3.fromRGB(255, 120, 200)},
	-- (el caldero no tiene cartel de neón: su nombre va en el flotante)
	fuse = {icon = "cauldron", title = "FUSION WITCH", color = Color3.fromRGB(140, 240, 100), named = true},
}
local bills = {}
local BB_W, BB_H = 12, 5.5
local IDLE = Color3.fromRGB(46, 26, 66)
for kind, m in booths do
	local anchor = m:FindFirstChild("BadgeAnchor")
	local def = BILL[kind]
	if anchor and def then
		-- el puesto ya lleva su nombre en el cartel de neón: aquí solo el icono y el aviso, flotando justo encima
		local cy = anchor.Position.Y
		for _, c in m:GetChildren() do
			if c.Name == "Cartel" and c:IsA("BasePart") then
				cy = math.max(cy - BB_H / 2, c.Position.Y + c.Size.Y / 2 + 1.2) + BB_H / 2
			end
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(BB_W, 0, BB_H, 0)
		if def.named then
			-- el nombre, grande y con degradado, entre el icono y el aviso
			local name = Instance.new("TextLabel")
			name.AnchorPoint = Vector2.new(0.5, 1)
			name.Position = UDim2.fromScale(0.5, 0.6)
			name.Size = UDim2.fromScale(1.3, 0.34)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.LuckiestGuy
			name.TextScaled = true
			name.Text = def.title
			name.TextColor3 = Color3.new(1, 1, 1)
			name.ZIndex = 3
			UI.new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(205, 255, 140), Color3.fromRGB(170, 110, 255))}, name)
			UI.new("UIStroke", {Thickness = 4, Color = UI.INK, LineJoinMode = Enum.LineJoinMode.Round}, name)
			name.Parent = bb
		end
		bb.LightInfluence = 0
		bb.MaxDistance = 260
		bb.Adornee = anchor
		bb.Parent = player:WaitForChild("PlayerGui")
		-- el icono del kit encima del título, con un brillo de su color detrás
		UI.piece("glow2", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, -0.12), Size = UDim2.fromScale(0.5, 0.8), ImageColor3 = def.color, ImageTransparency = 0.45}, bb)
		local icon = UI.icon(def.icon, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, def.named and -0.42 or -0.06), Size = UDim2.fromScale(0.36, 0.62)}, bb)
		UI.new("UIAspectRatioConstraint", {AspectRatio = 1}, icon)
		local pill = Instance.new("TextLabel")
		pill.AnchorPoint = Vector2.new(0.5, 1)
		pill.Position = UDim2.fromScale(0.5, 1)
		pill.Size = UDim2.fromScale(0.9, 0.4)
		pill.BackgroundColor3 = IDLE
		pill.BackgroundTransparency = 0.05
		pill.Font = Enum.Font.FredokaOne
		pill.TextScaled = true
		pill.TextColor3 = Color3.new(1, 1, 1)
		pill.Text = ""
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = pill
		local ps = Instance.new("UIStroke")
		ps.Thickness = 2.5
		ps.Color = def.color -- borde del color del puesto: sobre el cielo de noche la píldora oscura no se leía
		ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ps.Parent = pill
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
		pad.Parent = pill
		pill.Parent = bb
		bills[kind] = {bb = bb, pill = pill, stroke = ps, color = def.color, lift = cy - anchor.Position.Y}
	end
end

-- aviso: lo que te espera en la ruleta (una vez por segundo basta)
local hot = {}
local function refreshBills()
	local now = workspace:GetServerTimeNow()
	local free = now >= (player:GetAttribute("FreeSpinAt") or math.huge)
	local function set(kind, text, isHot)
		local b = bills[kind]
		if b then
			b.pill.Text = text
			b.pill.BackgroundColor3 = isHot and b.color or IDLE
			b.stroke.Color = isHot and Color3.new(1, 1, 1) or b.color
			b.pill.TextColor3 = isHot and Color3.fromRGB(20, 10, 25) or Color3.new(1, 1, 1)
			hot[kind] = isHot
		end
	end
	-- caldero: cuántos sustos puedes fusionar ya (copias de la mochila)
	local ready = 0
	for t, def in Config.Scares do
		local star = Config.starOf(player, t)
		if not def.skin and star < Config.STAR_MAX and (player:GetAttribute("Inv_" .. t) or 0) >= Config.STAR_COST[star + 1] then
			ready += 1
		end
	end
	set("fuse", ready > 0 and ("★ %d READY TO FUSE!"):format(ready) or "Fuse your duplicates", ready > 0)
	if free then
		set("wheel", "FREE SPIN!", true)
	else
		local left = math.max(0, math.floor((Config.wheelPeriod(now) + 1) * Config.WHEEL_ROTATE - now))
		set("wheel", ("New prizes in %d:%02d:%02d"):format(left // 3600, left % 3600 // 60, left % 60), false)
	end
end
task.spawn(function()
	while true do
		refreshBills()
		task.wait(1)
	end
end)

---------- Caldero de Fusión: almas y cristales ----------
local fuse = booths.fuse
local souls, crystals, potCenter = {}, {}, nil
if fuse then
	local brew = fuse:FindFirstChild("Pocion")
	potCenter = brew and brew.Position
	for _, p in fuse:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Alma" and potCenter then
			local off = p.Position - potCenter
			table.insert(souls, {p = p, a = math.atan2(off.Z, off.X), r = Vector2.new(off.X, off.Z).Magnitude, y = off.Y})
		elseif p:IsA("BasePart") and p.Name:match("^Cristal") then
			table.insert(crystals, {p = p, cf = p.CFrame, k = #crystals})
		end
	end
end

---------- Cada frame ----------
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	-- bombillas: 2 de cada 4 encendidas, corriendo (más rápido mientras gira la ruleta)
	local s = math.floor(t * (spinning and 16 or 6))
	if s ~= step then
		step = s
		for _, b in bulbs do
			b.Color = (b:GetAttribute("Marquee") + s) % 4 < 2 and ON or OFF
		end
	end
	-- ruleta gigante: quieta va girando despacito; cuando alguien tira, la anima spinBig
	if rotor then
		if not spinning then
			angle += 0.15
		end
		setRotor(angle)
		local slot = math.floor((angle + 22.5) / 45)
		if slot ~= lastSlot then
			lastSlot = slot
			if spinning and pointer then
				sound3D("Click", pointer, 1.2, 1.15)
				pointer.CFrame = pointerBase * CFrame.Angles(0, 0, math.rad(slot % 2 == 0 and -20 or 20))
				TweenService:Create(pointer, TweenInfo.new(0.12), {CFrame = pointerBase}):Play()
			end
		end
	end
	-- almas que dan vueltas sobre el caldero (subiendo y bajando) y cristales que giran y flotan
	for i, s in souls do
		local a = s.a + t * 1.1
		s.p.CFrame = CFrame.new(potCenter + Vector3.new(math.cos(a) * s.r, s.y + math.sin(t * 2 + i * 2) * 0.5, math.sin(a) * s.r))
	end
	for _, c in crystals do
		c.p.CFrame = CFrame.new(0, math.sin(t * 1.6 + c.k) * 0.3, 0) * c.cf * CFrame.Angles(0, t * 0.9, 0)
	end
	-- carteles: suben y bajan; los que tienen algo para ti, laten
	for kind, b in bills do
		b.bb.StudsOffset = Vector3.new(0, b.lift + math.sin(t * 2 + #kind) * 0.35, 0)
		local pulse = hot[kind] and 1 + math.sin(t * 6) * 0.08 or 1
		b.bb.Size = UDim2.new(BB_W * pulse, 0, BB_H * pulse, 0)
	end
end)
