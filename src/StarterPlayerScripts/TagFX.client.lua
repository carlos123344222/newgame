-- Tags (cliente): los degradados de los tags míticos fluyen y a los legendarios y míticos les salen destellos que
-- parpadean alrededor del nombre. Vale para los carteles de nombre (NivelCabeza) y para la tienda (vista previa y
-- cartas): todo UIGradient con la etiqueta "TagGradient" y el atributo Rarity.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ATLAS = "rbxassetid://75175405766725" -- (UI.ATLAS: la pieza "sparkle")
local SPOTS = {Vector2.new(-0.04, 0.15), Vector2.new(1.03, 0.7), Vector2.new(0.78, -0.12)}
local live = {}

local function track(g)
	live[g] = {seed = math.random() * 10}
end
for _, g in CollectionService:GetTagged("TagGradient") do
	track(g)
end
CollectionService:GetInstanceAddedSignal("TagGradient"):Connect(track)
CollectionService:GetInstanceRemovedSignal("TagGradient"):Connect(function(g)
	local s = live[g]
	if s and s.sparks then
		for _, img in s.sparks do
			img:Destroy()
		end
	end
	live[g] = nil
end)

local function sparkles(label)
	local list = {}
	for i, p in SPOTS do
		list[i] = Instance.new("ImageLabel")
		local img = list[i]
		img.Name = "TagSparkle"
		img.BackgroundTransparency = 1
		img.Image = ATLAS
		img.ImageRectOffset = Vector2.new(640, 0)
		img.ImageRectSize = Vector2.new(64, 64)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(p.X, p.Y)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.ZIndex = label.ZIndex + 1
		img.Parent = label
	end
	return list
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for g, s in live do
		local label = g.Parent
		if not label then
			live[g] = nil
			continue
		end
		local r = g.Enabled and g:GetAttribute("Rarity")
		if r == "Mythic" then
			g.Offset = Vector2.new(math.sin(t * 1.3 + s.seed) * 0.45, 0)
		elseif g.Offset ~= Vector2.zero then
			g.Offset = Vector2.zero
		end
		local want = (r == "Legendary" or r == "Mythic") and label:IsA("GuiObject")
		if want and not s.sparks then
			s.sparks = sparkles(label)
		elseif not want and s.sparks then
			for _, img in s.sparks do
				img:Destroy()
			end
			s.sparks = nil
		end
		if s.sparks then
			for i, img in s.sparks do
				local k = math.max(0, math.sin(t * 2.6 + i * 2.1 + s.seed))
				img.ImageTransparency = 1 - k
				img.Size = UDim2.fromScale(0.35 + 0.45 * k, 0.35 + 0.45 * k)
				img.Rotation = t * 60 + i * 40
			end
		end
	end
end)
