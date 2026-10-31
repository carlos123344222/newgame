-- Música: una por situación (portada, calle, visita, Tower Defense y jefe), fundidas entre sí. Cada situación es una
-- plantilla de Assets.Sounds (grupo Music) y sus variantes son la lista de reproducción: antes de que acabe una pista
-- entra otra fundida (sin repetir la misma). Al volver a una situación su música sigue por donde iba.
-- Cliente decide la situación en cada momento (Musica.set); TowerDefenseUI avisa del jefe (Musica.boss) y del final.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Templates = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Sounds")

local Musica = {boss = false}

local TRACKS = {title = "Title", town = "Town", visit = "Interior", td = "TDMusic", boss = "Boss"}
local FADE_IN, FADE_OUT, CROSS = 2.5, 1.6, 4

local decks = {} -- situación -> {sound, full, last}
local current
local quietUntil = 0

local function fade(s, to, time, after)
	local tw = TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Sine), {Volume = to})
	if after then
		tw.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				after()
			end
		end)
	end
	tw:Play()
end

-- La siguiente pista de la lista (la plantilla y sus variantes), sin repetir la que acaba de sonar
local function nextTrack(state, last)
	local t = Templates:FindFirstChild(TRACKS[state])
	if not t then
		return nil
	end
	local list = {t}
	for _, c in t:GetChildren() do
		if c:IsA("Sound") then
			table.insert(list, c)
		end
	end
	local i = math.random(#list)
	if #list > 1 and i == last then
		i = i % #list + 1
	end
	local s = list[i]:Clone()
	s:ClearAllChildren()
	s.SoundGroup = t.SoundGroup
	s.Looped = false
	local full = s.Volume
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return {sound = s, full = full, last = i}
end

function Musica.set(state)
	if os.clock() < quietUntil then
		state = nil
	end
	if state == current then
		return
	end
	local old, oldState = current and decks[current], current
	current = state
	if old then
		fade(old.sound, 0, FADE_OUT, function()
			if current ~= oldState then
				old.sound:Pause()
			end
		end)
	end
	if state then
		local d = decks[state]
		if d and d.sound.Parent then
			d.sound:Resume()
		else
			d = nextTrack(state)
			decks[state] = d
		end
		if d then
			fade(d.sound, d.full, FADE_IN)
		end
	end
end

-- Silencio musical unos segundos (para que un remate, como ganar o perder, suene solo)
function Musica.quiet(seconds)
	quietUntil = os.clock() + seconds
	Musica.set(nil)
end

-- Antes de que acabe la pista, entra la siguiente fundida
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	local d = current and decks[current]
	if not d then
		return
	end
	local s = d.sound
	if s.TimeLength > CROSS * 2 and s.TimePosition > s.TimeLength - CROSS or not s.IsPlaying and s.TimeLength > 0 and s.TimePosition == 0 then
		local n = nextTrack(current, d.last)
		if n then
			decks[current] = n
			fade(n.sound, n.full, CROSS)
			fade(s, 0, CROSS, function()
				s:Destroy()
			end)
		end
	end
end)

return Musica
