-- Llamas de los faroles: se mecen, giran y titilan (solo en tu pantalla). Cada llama es una pieza "flame" (y su
-- núcleo "flameCore") apoyada en su base: aquí se estira y se inclina alrededor de esa base, nunca se mueve el farol.
local RunService = game:GetService("RunService")

local Llamas = {}
local list = {} -- [pieza] = {cf = CFrame en reposo, size = tamaño en reposo, seed}
local mapa = workspace:WaitForChild("Mapa")

local function add(p)
	if p:IsA("BasePart") and (p.Name == "flame" or p.Name == "flameCore") and not list[p] then
		-- el núcleo comparte semilla con su llama para que se muevan juntos
		local seed = (p.Position.X * 0.37 + p.Position.Z * 0.91) % 100
		list[p] = {cf = p.CFrame, size = p.Size, seed = seed}
	end
end
for _, d in mapa:GetDescendants() do
	add(d)
end
mapa.DescendantAdded:Connect(add)
mapa.DescendantRemoving:Connect(function(d)
	list[d] = nil
end)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then
		return
	end
	acc = 0
	local t = os.clock()
	local cam = workspace.CurrentCamera.CFrame.Position
	local parts, cframes = {}, {}
	for p, f in list do
		if (f.cf.Position - cam).Magnitude > 140 then
			continue -- ponytail: solo las cercanas; si hay cientos de faroles, repartir por fotogramas
		end
		local n1 = math.noise(t * 2.3, f.seed)
		local n2 = math.noise(t * 3.1, f.seed + 7)
		local n3 = math.noise(t * 1.7, f.seed + 3)
		local grow = 1 + 0.16 * n1 + 0.05 * math.sin(t * 11 + f.seed)
		local thin = 1 - 0.08 * n1
		local h = f.size.Y
		local bottom = f.cf * CFrame.new(0, -h / 2, 0)
		local cf = bottom * CFrame.Angles(n2 * 0.12, t * 0.9 + f.seed, n3 * 0.12) * CFrame.new(0, h * grow / 2, 0)
		p.Size = Vector3.new(f.size.X * thin, h * grow, f.size.Z * thin)
		table.insert(parts, p)
		table.insert(cframes, cf)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

return Llamas
