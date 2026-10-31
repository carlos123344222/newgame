-- Portada: el logo "YOUR HAUNTED HOUSE" (imagen del kit), un fantasmita que flota y el botón PLAY, sobre un vuelo
-- lento de cámara por la calle. Portada.show(onPlay): al pulsar PLAY la cámara baja hasta tu personaje (delante de tu
-- casa) y llama a onPlay.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")

local UI = require(script.Parent:WaitForChild("UI"))
local Assets = RS:WaitForChild("Assets")
local player = Players.LocalPlayer
local new = UI.new

local Portada = {active = false}

local INK = UI.INK

function Portada.show(onPlay)
	Portada.active = true
	local camera = workspace.CurrentCamera
	UI.lockMovement(true)

	local gui = new("ScreenGui", {Name = "Portada", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
	local top = new("Frame", {Size = UDim2.fromScale(1, 0.6), BackgroundColor3 = Color3.fromRGB(16, 6, 26), BorderSizePixel = 0}, gui)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})}, top)
	local bottom = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.fromRGB(10, 4, 16), BorderSizePixel = 0}, gui)
	new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15)})}, bottom)
	local black = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20}, gui)

	-- logo: rayos suaves detrás, la imagen y un fantasma que flota a la derecha
	local logo = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(980, 490), BackgroundTransparency = 1}, gui)
	local logoScale = new("UIScale", {}, logo)
	local rays = UI.piece("rays", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(900, 900), ImageColor3 = Color3.fromRGB(255, 170, 60), ImageTransparency = 0.82, ZIndex = 2}, logo)
	new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = UI.LOGO, ScaleType = Enum.ScaleType.Fit, ZIndex = 3}, logo)
	local boo = UI.icon("ghost", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.97, 0.66), Size = UDim2.fromOffset(160, 160), Rotation = 12, ZIndex = 5}, logo)
	local sub = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(860, 40), BackgroundTransparency = 1, Font = UI.FONT,
		TextSize = 30, TextColor3 = Color3.fromRGB(255, 240, 220), Text = "Build the scariest house on the street and spook your neighbors", ZIndex = 4,
	}, logo)
	new("UIStroke", {Color = INK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round}, sub)

	-- botón PLAY (el del kit, naranja y con el icono de jugar)
	local play = UI.iconButton({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromOffset(400, 104), BackgroundColor3 = UI.ORANGE, Text = "PLAY", Font = UI.TITLE, TextSize = 64, ZIndex = 4}, gui, "play")
	play.Icon.Size = UDim2.fromOffset(70, 70)
	play.Label.UIPadding.PaddingLeft = UDim.new(0, 40)
	play.Label.UIPadding.PaddingRight = UDim.new(0, 16)
	local playScale = play:FindFirstChildOfClass("UIScale")
	local hover = false
	play.MouseEnter:Connect(function()
		hover = true
	end)
	play.MouseLeave:Connect(function()
		hover = false
	end)

	local function rescale()
		local v = camera.ViewportSize
		local s = math.clamp(math.min(v.X / 1150, v.Y / 760), 0.4, 1.15)
		logoScale.Scale = s
		play.Size = UDim2.fromOffset(400 * s, 104 * s)
		play.TextSize = 64 * s
		play.Icon.Size = UDim2.fromOffset(70 * s, 70 * s)
	end
	local vpConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- (la caja de música de la portada la pone Musica mientras Portada.active y no Portada.leaving)
	Portada.leaving = false

	-- vuelo de cámara por la calle (va y vuelve muy despacio)
	local t0 = os.clock()
	local fly -- {from, to, t0, dur} cuando baja hacia el jugador
	RunService:BindToRenderStep("Portada", Enum.RenderPriority.Camera.Value + 1, function()
		camera.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() - t0
		if fly then
			local a = math.clamp((os.clock() - fly.t0) / fly.dur, 0, 1)
			local e = a < 0.5 and 4 * a * a * a or 1 - (-2 * a + 2) ^ 3 / 2
			local cf = fly.from:Lerp(fly.to, e)
			camera.CFrame = cf + Vector3.new(0, math.sin(e * math.pi) * 14, 0)
		else
			-- sobre la calle, entre las casas (va y vuelve muy despacio)
			local u = (1 - math.cos(t * 0.07)) / 2
			local pos = Vector3.new(-84 + u * 70, 30 - u * 6, math.sin(t * 0.13) * 4)
			camera.CFrame = CFrame.lookAt(pos, Vector3.new(pos.X + 70, 3, math.sin(t * 0.1 + 1) * 5))
		end
		boo.Position = UDim2.fromScale(0.97, 0.66 + math.sin(t * 2.2) * 0.03)
		boo.Rotation = 12 + math.sin(t * 1.7) * 6
		logo.Rotation = math.sin(t * 0.9) * 1.2
		rays.Rotation = t * 8
		if playScale then
			playScale.Scale = (hover and 1.08 or 1) + math.sin(t * 4) * 0.035
		end
	end)
	TweenService:Create(black, TweenInfo.new(1.2), {BackgroundTransparency = 1}):Play()

	local pressed = false
	local function start()
		if pressed then
			return
		end
		pressed = true
		UI.sound("Click")
		UI.sound("Success")
		UI.sound("Swoosh")
		ContextActionService:UnbindAction("PortadaJugar")
		play.Text = "..."
		-- espera al personaje (aparece delante de su casa)
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 15)
		local hum = char:WaitForChild("Humanoid", 15)
		task.wait(0.15)
		for _, o in {logo, play} do
			TweenService:Create(o, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = o.Position + UDim2.fromScale(0, o == play and 0.4 or -0.7)}):Play()
		end
		TweenService:Create(top, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
		TweenService:Create(bottom, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
		Portada.leaving = true -- la música de la calle entra mientras la cámara baja
		if root then
			local look = root.CFrame.LookVector
			local goal = CFrame.lookAt(root.Position - look * 13 + Vector3.new(0, 5.5, 0), root.Position + look * 8 + Vector3.new(0, 2, 0))
			fly = {from = camera.CFrame, to = goal, t0 = os.clock(), dur = 2.2}
			task.wait(2.25)
		end
		RunService:UnbindFromRenderStep("Portada")
		vpConn:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		if hum then
			camera.CameraSubject = hum
		end
		UI.lockMovement(false)
		gui:Destroy()
		Portada.active = false
		if onPlay then
			onPlay()
		end
	end
	play.Activated:Connect(function()
		task.spawn(start)
	end)
	ContextActionService:BindActionAtPriority("PortadaJugar", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(start)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

return Portada
