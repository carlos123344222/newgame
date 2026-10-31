-- Sustos (pestaña "Scares" de las pantallas de colección, entre Troops e Index), con el estilo de Catalog: el panel
-- de cartas con buscador y filtro por categoría a la izquierda y la ficha a la derecha (nombre, estadísticas, el modelo
-- 3D grande, la descripción y el botón). Los básicos se compran aquí con monedas; los demás, si aún no los tienes,
-- salen bloqueados (silueta, dónde se consiguen y el botón lleva a la ruleta o a las skins de la Shop) y, al lado,
-- el botón verde de Robux (Config.scareTier: acción RobuxBuy). Los que ya tienes, con un check.
-- Las skins no son sustos y no salen en la lista: el botón SKINS de la ficha abre las de ese susto (como las tiendas
-- de skins de los juegos de defensa): el original y sus skins en cartas del color de su rareza (candado si no la
-- tienes, check si sí, EQUIPPED la que lleva), su ficha a la derecha y BACK para volver. Se compran una vez en las
-- Daily Deals de la Shop (Config.skinOffers; la de hoy, también desde aquí) y se equipan con EQUIP (acción
-- EquipSkin): solo cambian el aspecto del susto, no sus estadísticas.
-- (Es la página Scares de la Shop anterior: la Shop nueva vende el resto.)
-- Uso: require(ScareStoreUI)(UI) desde UI. Pone UI.scareStore (la raíz) y UI.toggleScares(open, susto).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Config"))
local Remote = RS:WaitForChild("Remote")
local player = Players.LocalPlayer

return function(UI)
	local C = require(script.Parent:WaitForChild("Catalog"))(UI)
	local WHITE = Color3.new(1, 1, 1)

	local screen = C.screen("Scares", "Scares")
	local stage = screen.stage
	local lp = C.leftPanel(stage)
	local detail = C.detail(stage)
	UI.scareStore = screen.root
	C.openers.Scares = function()
		UI.toggleScares(true)
	end

	local chip = C.chip(lp.right, "", "ghost", {Size = UDim2.fromOffset(250, 48), LayoutOrder = 1})
	local action = C.button(detail.buttons, "", "green", {Size = UDim2.fromOffset(240, 58), LayoutOrder = 1}, "coin")
	local robux = C.button(detail.buttons, "", "green", {Size = UDim2.fromOffset(170, 58), LayoutOrder = 2}, "robux")
	local query = ""

	local ALL = table.clone(Config.ScareOrder)
	for _, t in Config.SpecialOrder do
		if not Config.Scares[t].base then -- (las skins, en su vista)
			table.insert(ALL, t)
		end
	end
	local skinsBtn = C.button(detail.buttons, "SKINS", "purple", {Size = UDim2.fromOffset(190, 58), LayoutOrder = 3}, "star")

	-- cuántos tienes de cada susto: en la mochila + colocados en tu casa
	local COUNTED = table.clone(Config.ScareOrder)
	table.move(Config.SpecialOrder, 1, #Config.SpecialOrder, #COUNTED + 1, COUNTED)
	local function counts()
		local c = {}
		for _, t in COUNTED do
			c[t] = player:GetAttribute("Inv_" .. t) or 0
		end
		local plot = player:GetAttribute("Plot")
		local casas = workspace:FindFirstChild("Casas")
		local house = plot and casas and casas:FindFirstChild("Casa" .. plot)
		local placed = house and house:FindFirstChild("Scares")
		for _, m in placed and placed:GetChildren() or {} do
			if c[m.Name] then
				c[m.Name] += 1
			end
		end
		return c
	end
	local function owns(t, c)
		return (c[t] or 0) > 0 or Config.starOf(player, t) > 0
	end
	local function matches(name)
		return query == "" or name:lower():find(query, 1, true) ~= nil
	end

	-- dónde se consigue lo que no se vende por monedas (las skins: con gemas en la Shop, si tienes su susto)
	local WHERE = {wheel = "the Wheel of Fright"}
	local function unlockText(t)
		local def = Config.Scares[t]
		if def.gems then
			local base = Config.Scares[def.base].name
			return ("Skin of the %s: get a %s, then grab it when it shows up in the Shop's skin offers (%s gems)."):format(base, base, UI.fmt(def.gems))
		end
		local where = {}
		for _, s in Config.sources(t) do
			if WHERE[s] then
				table.insert(where, WHERE[s])
			end
		end
		local w = #where <= 1 and (where[1] or "a stall on the street") or (table.concat(where, ", ", 1, #where - 1) .. " or " .. where[#where])
		return ("Unlock %s at %s."):format(Config.Scares[t].name, w)
	end

	local function priceButton(b, price, icon)
		local can = UI.money >= price
		b.set(can and UI.fmt(price) or ("Need %s"):format(UI.fmt(price - UI.money)), can and "green" or "grey", icon or "coin")
	end

	local CAT_ORDER = {"Basico", "Criatura", "Trampa", "Legendario", "Especial"}
	local scares = {scroll = lp.list(), cards = {}, sections = {}, filter = nil}

	function scares.build()
		scares.built = true
		local n = 0
		for ci, cat in CAT_ORDER do
			local cd = Config.Categories[cat]
			local holder, grid = C.section(scares.scroll, cd.name, cd.color:Lerp(WHITE, 0.15), ci)
			scares.sections[cat] = holder
			for i, t in ALL do
				if Config.Scares[t].cat == cat then
					local card = C.card(grid, i, {t = t, name = Config.Scares[t].name})
					card.button.Activated:Connect(function()
						UI.sound("Tab")
						scares.show(t)
					end)
					scares.cards[t] = card
					n += 1
					if n % 8 == 0 then
						task.wait() -- (no congela al abrir por primera vez)
					end
				end
			end
		end
	end

	function scares.show(t)
		scares.focus = t
		local def = Config.Scares[t]
		local cat = Config.Categories[def.cat]
		local c = counts()
		local own, buy = owns(t, c), Config.inShop(t)
		local locked = not own and not buy
		detail.name.Text = def.name
		detail.sub.Text = cat.name .. (def.mythic and "  ·  Mythic" or "") .. (def.base and "  ·  Skin" or "")
		detail.sub.TextColor3 = cat.color:Lerp(WHITE, 0.3)
		detail.setModel(t, locked)
		if locked then
			detail.setLock(unlockText(t) .. (Config.scareTier(t) and "\nOr get it now with Robux!" or ""))
		else
			detail.setLock(nil)
			local slots = Config.slots(t)
			local rows = {
				{"coins", "+" .. Config.scarePay(player, t), nil, "per scare"},
				{"skull", Config.starDef(t, Config.starOf(player, t)).fear, nil, "fear"},
				{"target", def.radius, nil, "studs"},
				{"house", slots, nil, slots == 1 and "space" or "spaces"},
			}
			if own then
				table.insert(rows, {"bag", "x" .. c[t], nil, "owned"})
			end
			detail.setStats(rows)
		end
		detail.desc.Text = def.desc or ""
		if buy then
			priceButton(action, def.price)
		elseif locked then
			action.set("LOCKED", "grey", "lock")
		else
			action.set("GET MORE", "purple", UI.sourceInfo(t).icon)
		end
		action.button.Size = UDim2.fromOffset(240, 58)
		local list = Config.SkinsOf[t]
		skinsBtn.button.Visible = list ~= nil
		if list then
			local mine = 0
			for _, s in list do
				mine += Config.ownsSkin(player, s) and 1 or 0
			end
			skinsBtn.set(("SKINS %d/%d"):format(mine, #list), "purple", "star")
		end
		local _, tier = Config.scareTier(t)
		robux.button.Visible = tier ~= nil
		if tier then
			robux.set(UI.fmt(tier.robux), "green", "robux")
		end
		for k, card in scares.cards do
			card.select(k == t)
		end
	end

	function scares.refresh()
		if not scares.built then
			return
		end
		local c = counts()
		local have, shown = 0, {}
		for t, card in scares.cards do
			local def = Config.Scares[t]
			local own = owns(t, c)
			local locked = not own and not Config.inShop(t)
			have += own and 1 or 0
			card.badge(own and "check" or locked and "lock" or nil)
			card.locked(locked)
			local vis = matches(def.name) and (scares.filter == nil or scares.filter == def.cat)
			card.button.Visible = vis
			shown[def.cat] = shown[def.cat] or vis
		end
		for cat, holder in scares.sections do
			holder.Visible = shown[cat] == true
		end
		chip.label.Text = ("Collected %d/%d"):format(have, #ALL)
		if scares.focus then
			scares.show(scares.focus)
		end
	end

	function scares.enter()
		local filters = {{"All scares", nil}}
		for _, cat in CAT_ORDER do
			table.insert(filters, {Config.Categories[cat].name, cat, Config.Categories[cat].color:Lerp(WHITE, 0.2)})
		end
		lp.setFilters(filters, scares.filter, function(v)
			scares.filter = v
			scares.refresh()
		end)
		if not scares.built then
			scares.build()
		end
		scares.focus = scares.focus or Config.ScareOrder[1]
		scares.refresh()
	end

	---------- Skins de un susto ----------
	local RAR_DEFAULT = {name = "Original", color = Color3.fromRGB(200, 205, 215)}
	local function rarityOf(t)
		local def = Config.Scares[t]
		if not def.base then
			return RAR_DEFAULT
		end
		return Config.Rarities[Config.RarityIndex[def.rarity or "Rare"] or 3]
	end
	local function unlockedSkin(t, c)
		local base = Config.Scares[t].base
		return (c[base] or 0) > 0 or Config.starOf(player, base) > 0
	end
	-- ¿Es tuya? (el original siempre) y ¿es la que lleva su susto?
	local function ownsLook(t)
		return not Config.Scares[t].base or Config.ownsSkin(player, t)
	end
	local function wearing(t)
		local def = Config.Scares[t]
		return Config.equippedSkin(player, def.base or t) == (def.base and t or nil)
	end
	local function todaysOffer(t, c)
		for _, o in Config.skinOffers(Config.skinPeriod(workspace:GetServerTimeNow()), function(x)
			return unlockedSkin(x, c) and not Config.ownsSkin(player, x)
		end) do
			if o.skin == t then
				return o
			end
		end
	end

	local skins = {scroll = lp.list(), cards = {}}
	skins.scroll.Visible = false
	skins.scroll:FindFirstChildOfClass("UIPadding").PaddingBottom = UDim.new(0, 100)
	local back = C.button(lp.panel, "BACK", "grey", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(210, 62), TextSize = 30, ZIndex = 6}, "arrowL")
	back.button.Visible = false

	function skins.show(t)
		skins.focus = t
		local def = Config.Scares[t]
		local base = def.base or t
		local r = rarityOf(t)
		local c = counts()
		detail.name.Text = def.base and def.name or "Original"
		detail.sub.Text = r.name .. (def.base and "  ·  Skin" or ("  ·  " .. def.name))
		detail.sub.TextColor3 = r.color:Lerp(WHITE, 0.15)
		detail.setModel(t, false)
		detail.setLock(nil)
		-- (una skin es el mismo susto: sus estadísticas son las del original)
		local slots = Config.slots(base)
		detail.setStats({
			{"coins", "+" .. Config.scarePay(player, base), nil, "per scare"},
			{"skull", Config.starDef(base, Config.starOf(player, base)).fear, nil, "fear"},
			{"house", slots, nil, slots == 1 and "space" or "spaces"},
		})
		detail.desc.Text = def.base and ((def.desc or "") .. " Only changes its look: same stats as your " .. Config.Scares[base].name .. ".") or (def.desc or "")
		robux.button.Visible, skinsBtn.button.Visible = false, false
		action.button.Size = UDim2.fromOffset(330, 58) -- (aquí va solo: cabe la cuenta atrás)
		if ownsLook(t) then
			if wearing(t) then
				action.set("EQUIPPED", "grey", "check")
			else
				action.set("EQUIP", "green", "check")
			end
		else
			local offer = todaysOffer(t, c)
			if not unlockedSkin(t, c) then
				action.set(("GET A %s FIRST"):format(Config.Scares[def.base].name:upper()), "grey", "lock")
			elseif offer then
				local can = (player:GetAttribute("Gems") or 0) >= offer.price
				action.set((offer.off > 0 and ("-%d%%  "):format(offer.off) or "") .. UI.fmt(offer.price), can and "green" or "grey", "gem")
			else
				local now = workspace:GetServerTimeNow()
				local left = math.max(0, (Config.skinPeriod(now) + 1) * Config.SKIN_ROTATE - now)
				action.set(("NEW DEALS IN %dh %02dm"):format(left // 3600, left % 3600 // 60), "orange", "clock")
			end
		end
		for k, card in skins.cards do
			card.select(k == t)
		end
	end

	function skins.refresh()
		if not skins.base then
			return
		end
		local have, total = 0, 0
		for t, card in skins.cards do
			local own = ownsLook(t)
			card.badge(own and "check" or "lock")
			card.equipped.Visible = own and wearing(t)
			if card.vp then
				card.vp.ImageColor3 = own and WHITE or Color3.fromRGB(105, 105, 116)
			end
			card.button.Visible = query == "" or card.name.Text:lower():find(query, 1, true) ~= nil
			if Config.Scares[t].base then
				total += 1
				have += own and 1 or 0
			end
		end
		chip.label.Text = ("Skins %d/%d"):format(have, total)
		if skins.focus then
			skins.show(skins.focus)
		end
	end

	function skins.open(base, focus)
		skins.base = base
		for _, ch in skins.scroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		table.clear(skins.cards)
		local _, grid = C.section(skins.scroll, Config.Scares[base].name .. " Skins", WHITE, 1)
		for i, t in {base, table.unpack(Config.SkinsOf[base] or {})} do
			local card = C.card(grid, i, {t = t, name = Config.Scares[t].base and Config.Scares[t].name or "Original"})
			if Config.Scares[t].base then
				card.color(rarityOf(t).color)
			end
			-- cinta verde EQUIPPED arriba: la que lleva tu susto
			local pill = Instance.new("Frame")
			pill.AnchorPoint = Vector2.new(0.5, 0)
			pill.Position = UDim2.new(0.5, 0, 0, 7)
			pill.Size = UDim2.fromOffset(92, 22)
			pill.BackgroundColor3 = WHITE
			pill.Visible = false
			pill.ZIndex = 7
			Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
			local g = Instance.new("UIGradient", pill)
			g.Rotation = 90
			g.Color = ColorSequence.new(Color3.fromRGB(110, 240, 120), Color3.fromRGB(28, 150, 56))
			local e = Instance.new("UIStroke", pill)
			e.Color, e.Thickness = Color3.fromRGB(14, 50, 20), 2
			e.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			C.text({Size = UDim2.fromScale(1, 1), TextSize = 14, Text = "EQUIPPED", ZIndex = 8}, pill, 1.5)
			pill.Parent = card.button
			card.equipped = pill
			card.button.Activated:Connect(function()
				UI.sound("Tab")
				skins.show(t)
			end)
			skins.cards[t] = card
		end
		scares.scroll.Visible, skins.scroll.Visible = false, true
		back.button.Visible = true
		lp.box.Text = ""
		lp.setFilters({}, nil, function() end)
		skins.focus = focus or (Config.SkinsOf[base] and Config.SkinsOf[base][1]) or base
		skins.refresh()
	end

	function skins.close()
		local base = skins.base
		skins.base = nil
		scares.scroll.Visible, skins.scroll.Visible = true, false
		back.button.Visible = false
		lp.box.Text = ""
		scares.focus = base
		scares.enter()
	end

	function skins.act()
		local t = skins.focus
		local def = t and Config.Scares[t]
		if not def then
			return
		end
		if ownsLook(t) then
			if not wearing(t) then
				UI.sound("Pickup")
				Remote:FireServer("EquipSkin", t)
				local card = skins.cards[t]
				if card and card.pop then
					card.pop.Scale = 1.2
					game:GetService("TweenService"):Create(card.pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Scale = 1}):Play()
				end
				UI.toast(def.base and ("%s equipped on your %s!"):format(def.name, Config.Scares[def.base].name) or ("Back to the original %s"):format(def.name),
					rarityOf(t).color, "check")
			end
			return
		end
		local c = counts()
		local offer = todaysOffer(t, c)
		if not unlockedSkin(t, c) then
			return UI.toast(("Get a %s first: then its skins show up in the Daily Deals"):format(Config.Scares[def.base].name), UI.ORANGE, "lock")
		elseif not offer then
			UI.toast("Not in today's Daily Deals. Check the Shop tomorrow!", UI.ORANGE, "clock")
			UI.toggleScares(false)
			return UI.openSkins and UI.openSkins()
		elseif (player:GetAttribute("Gems") or 0) < offer.price then
			UI.toast(("You need %s more gems"):format(UI.fmt(offer.price - (player:GetAttribute("Gems") or 0))), Color3.fromRGB(190, 140, 255), "gem")
			return UI.openCurrency and UI.openCurrency("gems")
		end
		UI.sound("Tab")
		Remote:FireServer("BuySkin", t)
	end

	back.button.Activated:Connect(function()
		UI.sound("Close")
		skins.close()
	end)
	skinsBtn.button.Activated:Connect(function()
		if scares.focus and Config.SkinsOf[scares.focus] then
			UI.sound("Open")
			skins.open(scares.focus)
		end
	end)

	function scares.act()
		local t = scares.focus
		if not t then
			return
		end
		if Config.inShop(t) then
			if UI.money < Config.Scares[t].price then
				return UI.toast(("You need %s more coins"):format(UI.fmt(Config.Scares[t].price - UI.money)), UI.RED)
			end
			Remote:FireServer("Buy", t)
		else
			UI.toggleScares(false)
			UI.openSource(t)
		end
	end

	lp.box:GetPropertyChangedSignal("Text"):Connect(function()
		query = lp.box.Text:lower()
		if skins.base then
			skins.refresh()
		else
			scares.refresh()
		end
	end)
	action.button.Activated:Connect(function()
		if skins.base then
			skins.act()
		else
			scares.act()
		end
	end)
	robux.button.Activated:Connect(function()
		if scares.focus then
			UI.sound("Tab")
			Remote:FireServer("RobuxBuy", "scare", scares.focus)
		end
	end)
	screen.onToggle = function(open)
		if open then
			task.spawn(function()
				if skins.base then
					skins.refresh()
				else
					scares.enter()
				end
			end)
		end
	end

	-- focus: un susto que enseñar (p. ej. el que se te ha acabado al construir)
	function UI.toggleScares(open, focus)
		if open == nil then
			open = not screen.root.Visible
		end
		local def = focus and Config.Scares[focus]
		if open and def and def.base then
			-- una skin: la vista de skins de su susto
			screen.open(true)
			task.defer(skins.open, def.base, focus)
			return
		end
		if open and def then
			if skins.base then
				skins.close()
			end
			scares.focus = focus
		end
		screen.open(open)
	end

	local function refresh()
		if screen.root.Visible then
			if skins.base then
				skins.refresh()
			else
				scares.refresh()
			end
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name:match("^Inv_") or name:match("^Star_") or name:match("Skin_") or name == "Gems" then
			refresh()
		end
	end)
	player:WaitForChild("leaderstats"):WaitForChild("Coins").Changed:Connect(refresh)
	Remote.OnClientEvent:Connect(function(kind, a)
		if kind == "Bought" or kind == "GotScare" or kind == "GotSkin" then
			if kind == "Bought" and scares.cards[a] and scares.cards[a].pop then
				local pop = scares.cards[a].pop
				pop.Scale = 1.25
				game:GetService("TweenService"):Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Scale = 1}):Play()
			end
			refresh()
		end
	end)
end
