-- Importa las piezas exportadas desde Blender (td_map.py -> to_luau.py) a workspace.ZombieHollow.MapaTDS
local GROUPS = {"Suelo", "Acantilados", "Cueva", "Flechas", "Base", "Estanque", "Arboles", "Rocas", "Arbustos", "Flores"}
local PALS = {{98,178,72,"Grass"},{148,144,136,"Slate"},{122,118,112,"Slate"},{84,160,62,"Grass"},{18,16,20,"SmoothPlastic"},{160,158,150,"Rock"},{120,255,130,"Neon"},{168,162,150,"Cobblestone"},{196,190,176,"Brick"},{52,96,182,"SmoothPlastic"},{240,196,60,"Metal"},{140,98,60,"WoodPlanks"},{230,64,52,"Fabric"},{214,196,148,"Sand"},{70,160,220,"Glass"},{110,178,70,"Grass"},{110,76,48,"Wood"},{52,124,50,"Grass"},{70,150,58,"Grass"},{44,108,56,"Grass"},{250,230,90,"SmoothPlastic"},{240,120,160,"SmoothPlastic"}}
local NOCOLLIDE = {Flechas = true, Flores = true, Arbustos = true}

local function nums(s)
	local t = {}
	for v in s:gmatch("[^,]+") do table.insert(t, tonumber(v)) end
	return t
end

return function(data)
	local root = workspace.ZombieHollow.MapaTDS
	local n = 0
	local batch = {}
	for line in data:gmatch("[^\n]+") do
		local g, s, p, r, z, pal = line:match("^(%d+);(%a);([^;]+);([^;]+);([^;]+);(%d+)$")
		local group = GROUPS[tonumber(g) + 1]
		local P, R, Z = nums(p), nums(r), nums(z)
		local c = PALS[tonumber(pal) + 1]
		local part = Instance.new("Part")
		part.Anchored = true
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		local cf = CFrame.new(P[1], P[2], P[3]) * CFrame.Angles(math.rad(R[1]), math.rad(R[2]), math.rad(R[3]))
		local size = Vector3.new(Z[1], Z[2], Z[3])
		if s == "C" then -- Blender: eje Z (Y en Roblox); Roblox: eje X
			part.Shape = Enum.PartType.Cylinder
			cf = cf * CFrame.Angles(0, 0, math.pi / 2)
			size = Vector3.new(Z[2], Z[1], Z[3])
		elseif s == "S" then
			part.Shape = Enum.PartType.Ball
			size = Vector3.one * (Z[1] + Z[2] + Z[3]) / 3
		end
		part.Size = size
		part.CFrame = cf
		part.Color = Color3.fromRGB(c[1], c[2], c[3])
		part.Material = Enum.Material[c[4]]
		if c[4] == "Glass" then part.Transparency = 0.35 part.Reflectance = 0.15 part.CanCollide = false end
		if c[4] == "Neon" then part.Transparency = 0.15 part.CastShadow = false end
		if NOCOLLIDE[group] then part.CanCollide = false part.CanQuery = false part.CanTouch = false end
		part.Name = group
		batch[group] = batch[group] or {}
		table.insert(batch[group], part)
		n += 1
	end
	for group, list in batch do
		local f = root:FindFirstChild(group)
		if not f then f = Instance.new("Folder") f.Name = group f.Parent = root end
		local tmp = Instance.new("Folder")
		for _, part in list do part.Parent = tmp end
		for _, part in list do part.Parent = f end
		tmp:Destroy()
	end
	return n
end
