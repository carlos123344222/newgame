-- Nivel encima de la cabeza: cartel (BillboardGui) en la cabeza de cada jugador con su nivel y su nombre, que ven
-- todos. Sustituye al nombre de Roblox. El nivel sale del atributo PXP (Config.playerLevelOf).
-- Con un tag equipado (atributo Tag, Config.Tags): "[ Phantom ]" encima del nombre y el nombre con su degradado (el
-- UIGradient lleva la etiqueta "TagGradient": los clientes animan los míticos y ponen destellos, TagFX).
-- Diseño: Figma "Haunted House – HUD redesign", sección 4.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local INK = Color3.fromRGB(27, 12, 38)
local GREEN = Color3.fromRGB(110, 235, 140)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function outline(o, t)
	new("UIStroke", {Color = INK, Thickness = t, LineJoinMode = Enum.LineJoinMode.Round}, o)
end

local function build(plr, char)
	local head = char:WaitForChild("Head", 10)
	local hum = char:WaitForChild("Humanoid", 10)
	if not (head and hum) then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- (el nombre va en el cartel)
	local bb = new("BillboardGui", {
		Name = "Nameplate", Adornee = head, Size = UDim2.fromOffset(260, 84), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 90,
		LightInfluence = 0, ResetOnSpawn = false,
	}, head)
	new("UIListLayout", {HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, bb)
	-- píldora con el nivel
	local pill = new("Frame", {Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1}, bb)
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, pill)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(52, 34, 82), Color3.fromRGB(22, 13, 38))}, pill)
	new("UIStroke", {Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, pill)
	new("UIPadding", {PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10)}, pill)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, pill)
	local badge = new("Frame", {Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1}, pill)
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, badge)
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 250, 170), Color3.fromRGB(70, 180, 100))}, badge)
	new("UIStroke", {Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, badge)
	local num = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "1",
	}, badge)
	new("UIPadding", {PaddingTop = UDim.new(0, 3)}, num)
	outline(num, 1.5)
	local word = new("TextLabel", {
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 15,
		TextColor3 = GREEN, Text = "LEVEL", LayoutOrder = 2,
	}, pill)
	new("UIPadding", {PaddingTop = UDim.new(0, 3)}, word)
	outline(word, 1.5)
	-- tag ("[ Phantom ]") y nombre
	local tagLabel = new("TextLabel", {
		Name = "Tag", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 17,
		TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false, LayoutOrder = 2,
	}, bb)
	outline(tagLabel, 2)
	local name = new("TextLabel", {
		Name = "PlayerName", Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 25,
		TextColor3 = Color3.fromRGB(250, 246, 255), Text = plr.DisplayName, LayoutOrder = 3,
	}, bb)
	outline(name, 2.5)
	local grad = new("UIGradient", {Name = "TagGradient", Enabled = false}, name)
	CollectionService:AddTag(grad, "TagGradient")

	local function refresh()
		num.Text = tostring(Config.playerLevel(plr))
	end
	local function refreshTag()
		local tag = Config.TagById[plr:GetAttribute("Tag") or ""]
		tagLabel.Visible = tag ~= nil
		tagLabel.Text = tag and ("[ %s ]"):format(tag.name) or ""
		grad.Enabled = tag ~= nil
		if tag then
			grad.Color = Config.tagGradient(tag)
			grad:SetAttribute("Rarity", tag.rarity)
		end
	end
	refresh()
	refreshTag()
	local conns = {plr:GetAttributeChangedSignal("PXP"):Connect(refresh), plr:GetAttributeChangedSignal("Tag"):Connect(refreshTag)}
	bb.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
end

local function onPlayer(plr)
	plr.CharacterAdded:Connect(function(char)
		build(plr, char)
	end)
	if plr.Character then
		task.spawn(build, plr, plr.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, plr in Players:GetPlayers() do
	onPlayer(plr)
end
