-- Animación en reposo de los sustos de las casas (solo en este cliente): respiran, miran alrededor, los murciélagos se
-- mecen colgados, la bruja remueve el caldero, las llamas titilan... Se para mientras el susto salta (el servidor pone
-- el atributo Busy y anima él) y vuelve después. Solo se animan los que están cerca de la cámara.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rig = require(RS:WaitForChild("Rig"))
local Config = require(RS:WaitForChild("Config"))
local Houses = workspace:WaitForChild("Casas")

local V = Vector3.new
local sin, cos, noise = math.sin, math.cos, math.noise
local NEAR = 90 -- studs
local RATE = 1 / 30

-- criaturas escondidas hasta el susto: no se animan en reposo
local HIDDEN = {Spirit = true, Ghost = true, Reflection = true, Soul = true, Lurker = true}

local entries = {} -- [modelo del susto] = {type, rigs = {nombre = rig}, bats = {}, parts = {[parte] = CFrame}, seed}

local function rigsOf(m)
	local rigs, bats = {}, {}
	for _, c in m:GetChildren() do
		if c:IsA("Model") and c.PrimaryPart and c.PrimaryPart.Name == "Root" and not HIDDEN[c.Name] then
			if c.Name == "Bat" then
				if not c.PrimaryPart or (c:FindFirstChild("Body") and c.Body.Transparency < 1) then
					table.insert(bats, {rig = c, home = c:GetPivot()})
				end
			else
				rigs[c.Name] = c
			end
		end
	end
	return rigs, bats
end

local function add(m)
	if entries[m] or not m:IsA("Model") then
		return
	end
	task.defer(function()
		if not m.Parent then
			return
		end
		local rigs, bats = rigsOf(m)
		local parts = {}
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Float" or p.Name == "Bubble" or p.Name == "Flame" or p.Name == "Drawer") then
				parts[p] = {cf = p.CFrame, size = p.Size}
			end
		end
		-- (las skins se mueven como su susto base)
		local def = Config.Scares[m.Name]
		entries[m] = {type = def and def.base or m.Name, rigs = rigs, bats = bats, parts = parts, seed = math.random() * 100, busy = m:GetAttribute("Busy") == true}
		m:GetAttributeChangedSignal("Busy"):Connect(function()
			local e = entries[m]
			if not e then
				return
			end
			e.busy = m:GetAttribute("Busy") == true
			if e.busy then
				-- deja todo como lo tiene el servidor (en reposo) para que su animación empiece limpia
				for _, c in e.rigs do
					if e.type == "Manos" then
						Rig.setPose(c, Rig.full(c, {Root = V(0, -3.15, 0)}))
					else
						Rig.setPose(c, Rig.idlePose(c))
					end
				end
				for _, b in e.bats do
					b.rig:PivotTo(b.home)
					Rig.setPose(b.rig, Rig.idlePose(b.rig))
				end
				for p, base in e.parts do
					if p.Name ~= "Flame" then
						p.CFrame = base.cf
					end
				end
			else
				-- los murciélagos y lo que flota vuelve a su sitio de reposo
				task.delay(0.3, function()
					for _, b in e.bats do
						b.home = b.rig:GetPivot()
					end
				end)
			end
		end)
	end)
end

local function watch(house)
	local scares = house:WaitForChild("Scares", 10)
	if not scares then
		return
	end
	for _, m in scares:GetChildren() do
		add(m)
	end
	scares.ChildAdded:Connect(add)
	scares.ChildRemoved:Connect(function(m)
		entries[m] = nil
	end)
end
for _, h in Houses:GetChildren() do
	task.spawn(watch, h)
end
Houses.ChildAdded:Connect(watch)

---------- Poses de reposo ----------
-- Cada función recibe la entrada y el tiempo y pone las poses de sus criaturas. Sin función propia: respira y mira.
local function breathe(c, t, s, amount)
	local p = Rig.idlePose(c)
	amount = amount or 1
	if p.Torso then
		p.Torso += V(2.5 * sin(t * 1.7 + s) * amount, 0, 0)
	end
	if p.Head then
		p.Head += V(3 * sin(t * 0.9 + s), 14 * noise(t * 0.25, s) * amount, 4 * sin(t * 0.6 + s))
	end
	if p.ArmL then
		p.ArmL += V(4 * sin(t * 1.7 + s + 0.6) * amount, 0, 0)
	end
	if p.ArmR then
		p.ArmR += V(4 * sin(t * 1.7 + s + 1.1) * amount, 0, 0)
	end
	return p
end

local function generic(e, t)
	for _, c in e.rigs do
		Rig.setPose(c, breathe(c, t, e.seed))
	end
end

local IDLE = {}

function IDLE.Espantapajaros(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = breathe(c, t, s, 0.4)
	local wind = noise(t * 0.4, s)
	p.Torso += V(0, 0, 4 * wind)
	p.ArmL += V(0, 0, 8 * wind + 3 * sin(t * 2.3))
	p.ArmR += V(0, 0, 8 * wind + 3 * sin(t * 2.1 + 1))
	p.LegL += V(6 * sin(t * 1.3 + s), 0, 0)
	p.LegR += V(6 * sin(t * 1.1 + s + 2), 0, 0)
	p.Head += V(0, 0, 6 * wind)
	-- el cuervo picotea y mira a todos lados
	local peck = math.max(0, sin(t * 3 + s)) ^ 8
	p.CrowHead = V(-40 * peck, 40 * math.round(noise(t * 0.5, s + 9) * 2) / 2, 0)
	p.CrowTail = V(10 * sin(t * 4), 0, 0)
	Rig.setPose(c, p)
end

function IDLE.Cuervo(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	-- gira la cabeza a tirones, ahueca las alas de vez en cuando y mueve la cola
	p.Head += V(4 * sin(t * 1.3), 50 * math.round(noise(t * 0.35, s) * 3) / 3, 8 * math.round(noise(t * 0.35, s + 4) * 2) / 2)
	p.Body += V(2 * sin(t * 1.8), 0, 0)
	local ruffle = math.max(0, sin(t * 0.7 + s)) ^ 12
	p.WingL += V(0, 0, -30 * ruffle)
	p.WingR += V(0, 0, 30 * ruffle)
	p.Tail += V(12 * sin(t * 2.6) * ruffle + 4 * sin(t * 1.5), 0, 0)
	p.Beak = V(-20 * math.max(0, sin(t * 0.9 + s + 2)) ^ 20, 0, 0)
	Rig.setPose(c, p)
end

function IDLE.Bruja(e, t)
	local c = e.rigs.Creature
	if c then
		local p = breathe(c, t, e.seed, 0.6)
		-- remueve el caldero en círculos
		p.ArmR += V(9 * sin(t * 2.4), 0, 9 * cos(t * 2.4))
		p.Torso += V(0, 4 * sin(t * 2.4), 0)
		p.Head += V(0, 0, 5 * sin(t * 1.2))
		Rig.setPose(c, p)
	end
	-- las burbujas suben y bajan
	for part, base in e.parts do
		if part.Name == "Bubble" then
			local k = (t * 0.8 + base.cf.X * 3) % 1
			part.CFrame = base.cf + V(0, k * 0.25, 0)
			part.Size = base.size * (1 + 0.4 * sin(k * math.pi))
		end
	end
end

function IDLE.Momia(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local p = breathe(c, t, e.seed, 0.8)
	local twitch = math.max(0, sin(t * 0.9 + e.seed)) ^ 30
	p.Head += V(-10 * twitch, 0, 12 * twitch)
	p.ArmL += V(6 * sin(t * 0.8), 0, 0)
	p.ArmR += V(6 * sin(t * 0.7 + 1), 0, 0)
	Rig.setPose(c, p)
end

function IDLE.Banshee(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = breathe(c, t, s, 0.6)
	p.Root = V(0, 0.3 * sin(t * 1.4 + s), 0)
	p.Hair += V(8 * sin(t * 1.1), 0, 5 * sin(t * 0.8))
	p.Tail1 += V(8 * sin(t * 1.4 + 0.5), 0, 4 * sin(t * 0.9))
	p.Tail2 += V(12 * sin(t * 1.4 + 1.2), 0, 6 * sin(t * 0.9 + 1))
	p.ArmL += V(6 * sin(t * 1.2), 0, -4 * sin(t * 0.7))
	p.ArmR += V(6 * sin(t * 1.2 + 1), 0, 4 * sin(t * 0.7 + 1))
	Rig.setPose(c, p)
end

function IDLE.Manos(e, t)
	local c = e.rigs.Hands
	if not c then
		return
	end
	local p = Rig.full(c, {Root = V(0, -3.15, 0)})
	for i = 1, 4 do
		local k = "F" .. i
		p[k] += V(25 * noise(t * 1.5, e.seed + i), 0, 0)
		p["A" .. i] += V(4 * sin(t * 0.8 + i), 0, 3 * cos(t * 0.6 + i))
	end
	Rig.setPose(c, p)
end

function IDLE.Pozo(e, t)
	local c = e.rigs.Bucket
	if c then
		Rig.setPose(c, {Rope = V(6 * sin(t * 0.9 + e.seed), 0, 4 * sin(t * 0.7))})
	end
end

function IDLE.HombreLobo(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	-- respira fuerte, jadea, mueve la cola y aprieta las garras
	local b = sin(t * 2.6 + s)
	p.Torso += V(4 * b, 0, 0)
	p.Head += V(-3 * b, 18 * noise(t * 0.3, s), 0)
	p.Jaw = V(-6 - 6 * math.max(0, b), 0, 0)
	p.ArmL += V(5 * sin(t * 2.6 + 0.4), 0, -4 * math.abs(sin(t * 0.8)))
	p.ArmR += V(5 * sin(t * 2.6 + 0.9), 0, 4 * math.abs(sin(t * 0.7)))
	p.Tail += V(0, 25 * sin(t * 1.8), 0)
	Rig.setPose(c, p)
end

function IDLE.Vampiro(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local p = breathe(c, t, e.seed, 0.5)
	p.CapeL += V(3 * sin(t * 1.3), 0, -3 * math.abs(sin(t * 0.9)))
	p.CapeR += V(3 * sin(t * 1.3 + 0.5), 0, 3 * math.abs(sin(t * 0.8)))
	Rig.setPose(c, p)
end

function IDLE.Jinete(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	local b = sin(t * 1.6 + s)
	p.Body += V(1.2 * b, 0, 0)
	p.Neck += V(4 * sin(t * 1.1 + s), 6 * noise(t * 0.3, s), 0)
	p.HHead += V(8 * math.max(0, sin(t * 0.8 + s)) ^ 6, 0, 0)
	p.Tail += V(6 * sin(t * 2), 20 * sin(t * 1.3), 0)
	p.FL += V(-35 * math.max(0, sin(t * 0.6 + s + 1)) ^ 16, 0, 0) -- piafa de vez en cuando
	p.RTorso += V(-2 * b, 6 * noise(t * 0.2, s + 3), 0)
	p.RArmR += V(5 * sin(t * 1.4), 0, 3 * sin(t * 0.9))
	p.RCape += V(6 * sin(t * 1.7), 0, 3 * sin(t * 1.1))
	Rig.setPose(c, p)
end

function IDLE.Dragon(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	local b = sin(t * 1.2 + s)
	p.Body += V(1.5 * b, 0, 0)
	p.Neck1 += V(-2 * b, 10 * sin(t * 0.45 + s), 0)
	p.Neck2 += V(3 * sin(t * 0.9), 8 * sin(t * 0.45 + s + 0.6), 0)
	p.Head += V(4 * sin(t * 0.9 + 1), 8 * noise(t * 0.3, s), 0)
	p.Jaw += V(-6 * math.max(0, sin(t * 0.5 + s)) ^ 4, 0, 0)
	p.WingL += V(0, 0, -4 * b)
	p.WingR += V(0, 0, 4 * b)
	p.Tail1 += V(0, 10 * sin(t * 0.8), 0)
	p.Tail2 += V(0, 14 * sin(t * 0.8 - 0.6), 0)
	p.Tail3 += V(0, 18 * sin(t * 0.8 - 1.2), 0)
	Rig.setPose(c, p)
end

-- desplomado: se mece con el viento como un espantapájaros y de vez en cuando da un respingo
function IDLE.HombreCalabaza(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = breathe(c, t, s, 0.5)
	local wind = noise(t * 0.35, s)
	local twitch = math.max(0, sin(t * 0.7 + s)) ^ 30
	p.Torso += V(0, 0, 3 * wind)
	p.Head += V(-8 * twitch, 0, 8 * wind)
	p.ArmL += V(0, 0, -5 * wind + 3 * sin(t * 1.9))
	p.ArmR += V(0, 0, -5 * wind + 3 * sin(t * 1.7 + 1))
	Rig.setPose(c, p)
end

-- apoyado en la lápida: la calavera cabecea, la mandíbula castañetea a ratos y un dedo tamborilea
function IDLE.Esqueleto(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	local clack = math.max(0, sin(t * 0.8 + s)) ^ 16
	p.Jaw += V(-14 * clack * math.abs(sin(t * 18)), 0, 0)
	p.Head += V(4 * sin(t * 0.9 + s), 10 * noise(t * 0.3, s), 0)
	p.ArmR += V(6 * math.max(0, sin(t * 6)) * math.max(0, sin(t * 0.5 + s)), 0, 0)
	p.Torso += V(1.5 * sin(t * 1.2), 0, 0)
	Rig.setPose(c, p)
end

-- dormido en la mesa: respira hondo y de vez en cuando le da un calambre
function IDLE.Frankenstein(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = breathe(c, t, s, 0.6)
	local jolt = math.max(0, sin(t * 0.6 + s)) ^ 40
	p.Torso += V(3 * sin(t * 0.9), 0, 0)
	p.Head += V(-6 * jolt, 0, 0)
	p.ArmL += V(10 * jolt, 0, 0)
	p.ArmR += V(8 * jolt * sin(t * 30), 0, 0)
	Rig.setPose(c, p)
end

-- agazapado: respira fuerte, mueve la cola y las alas plegadas y abre la boca humeando
function IDLE.Demonio(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = Rig.idlePose(c)
	local b = sin(t * 1.8 + s)
	p.Torso += V(3 * b, 0, 0)
	p.Head += V(-2 * b, 12 * noise(t * 0.25, s), 0)
	p.Jaw += V(-6 * math.max(0, b), 0, 0)
	p.ArmL += V(4 * sin(t * 1.8 + 0.4), 0, -3 * math.abs(sin(t * 0.7)))
	p.ArmR += V(4 * sin(t * 1.8 + 0.9), 0, 3 * math.abs(sin(t * 0.6)))
	p.WingL += V(0, 0, -4 * b)
	p.WingR += V(0, 0, 4 * b)
	p.Tail += V(0, 20 * sin(t * 1.4), 0)
	Rig.setPose(c, p)
end

-- el rey: respira con calma, mira a su alrededor, la capa ondea y golpea el suelo con el cetro de vez en cuando
function IDLE.ReyCalabaza(e, t)
	local c = e.rigs.Creature
	if not c then
		return
	end
	local s = e.seed
	local p = breathe(c, t, s, 0.5)
	p.Head += V(0, 18 * noise(t * 0.2, s), 0)
	p.Cape += V(4 * sin(t * 1.3), 0, 2 * sin(t * 0.9))
	p.ArmR += V(-8 * math.max(0, sin(t * 0.5 + s)) ^ 12, 0, 0)
	Rig.setPose(c, p)
end

function IDLE.Calabaza(e, t)
	local c = e.rigs.Creature
	if c then
		Rig.setPose(c, Rig.full(c, {Arm = Rig.idlePose(c).Arm + V(1.5 * sin(t * 1.3 + e.seed), 0, 0)}))
	end
end

function IDLE.Murcielagos(e, t)
	for i, b in e.bats do
		local s = e.seed + i * 3
		local p = Rig.idlePose(b.rig)
		-- colgados se mecen; de vez en cuando uno estira las alas o gira la cabeza
		p.RootR = V(5 * sin(t * 1.3 + s), 0, 6 * sin(t * 1.1 + s))
		local stretch = math.max(0, sin(t * 0.45 + s)) ^ 14
		p.WingL += V(0, 0, -95 * stretch + 6 * sin(t * 9 + s) * stretch)
		p.WingR += V(0, 0, 95 * stretch - 6 * sin(t * 9 + s) * stretch)
		p.Head = V(0, 40 * noise(t * 0.4, s), 0)
		Rig.setPose(b.rig, p)
	end
end

function IDLE.Poltergeist(e, t)
	for part, base in e.parts do
		if part.Name == "Float" then
			local o = part:GetAttribute("Orbit") or 1
			part.CFrame = base.cf * CFrame.new(0, 0.25 * sin(t * 1.6 + o), 0) * CFrame.Angles(0.15 * sin(t * 1.1 + o), t * 0.4, 0.1 * cos(t * 0.9 + o))
		end
	end
end

function IDLE.Velas(e, t)
	for part, base in e.parts do
		if part.Name == "Flame" then
			local k = 1 + 0.25 * noise(t * 6, base.cf.X * 10)
			part.Size = base.size * V(1, k, 1)
			part.CFrame = base.cf * CFrame.new(0, base.size.Y * (k - 1) / 2, 0) * CFrame.Angles(0, 0, 0.12 * noise(t * 3, base.cf.X))
		end
	end
end

---------- Bucle ----------
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < RATE then
		return
	end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	local t = os.clock()
	for m, e in entries do
		if not m.Parent then
			entries[m] = nil
			continue
		end
		if e.busy then
			continue
		end
		local ok, pos = pcall(m.GetPivot, m)
		if not ok or (pos.Position - eye).Magnitude > NEAR then
			continue
		end
		local f = IDLE[e.type] or generic
		local fine, err = pcall(f, e, t)
		if not fine then
			warn("ScareIdle " .. e.type .. ": " .. tostring(err))
			entries[m] = nil
		end
	end
end)
