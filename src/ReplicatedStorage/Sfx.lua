-- Sonidos de una vez (cliente y servidor), desde las plantillas de Assets.Sounds: volumen, tono, recorte y grupo de
-- mezcla ya ajustados (volumen normalizado por categoría). Cada plantilla puede tener hijos Sound: variantes que suenan
-- en su lugar (al azar, sin repetir la última), cada una con su propio volumen y recorte. Atributos de la plantilla:
--   Var    variación de tono (±) en cada uso, para que lo que se repite no suene a máquina
--   Notes  semitonos ("0,2,4,7"): si no se pide tono, una de esas notas al azar (las monedas, como un carillón)
--   Voices cuántos a la vez como mucho (si ya suenan tantos, el nuevo no suena: nada se corta ni se amontona)
--   Steal  con Voices llenas, el nuevo corta al más viejo en vez de no sonar (lo rápido y corto: ticks, notas)
--   Gap    segundos mínimos entre dos (evita el "flanger" de dos iguales en el mismo instante)
local SoundService = game:GetService("SoundService")
local Templates = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Sounds")

local Sfx = {}

local playing = {} -- nombre -> lista de los que suenan ahora (el más viejo primero)
local lastAt = {} -- nombre -> os.clock() del último
local lastVariant = {} -- nombre -> índice de la última variante
local notes = {} -- caché de Notes ya leídas

local function pick(t)
	local options = {t}
	for _, c in t:GetChildren() do
		if c:IsA("Sound") then
			table.insert(options, c)
		end
	end
	local i = math.random(#options)
	if #options > 1 and i == lastVariant[t.Name] then
		i = i % #options + 1
	end
	lastVariant[t.Name] = i
	return options[i], i == 1
end

local function noteOf(t)
	local list = t:GetAttribute("Notes")
	if not list then
		return 1
	end
	if not notes[list] then
		notes[list] = {}
		for n in list:gmatch("-?%d+") do
			table.insert(notes[list], tonumber(n))
		end
	end
	return 2 ^ (notes[list][math.random(#notes[list])] / 12)
end

-- parent: dónde suena (una pieza o Attachment para 3D; nada = en la cabeza). gain multiplica el volumen y pitch el tono.
-- Devuelve el Sound (o nil si no ha sonado).
function Sfx.play(name, parent, gain, pitch)
	local t = Templates:FindFirstChild(name)
	if not t then
		return nil
	end
	local now = os.clock()
	local active = playing[name] or {}
	playing[name] = active
	if now - (lastAt[name] or -1) < (t:GetAttribute("Gap") or 0.02) then
		return nil
	end
	if #active >= (t:GetAttribute("Voices") or 8) then
		if not t:GetAttribute("Steal") then
			return nil
		end
		active[1]:Destroy() -- (su Destroying lo saca de la lista)
	end
	lastAt[name] = now
	local src, isTemplate = pick(t)
	local s = src:Clone()
	if isTemplate then
		for _, c in s:GetChildren() do
			if c:IsA("Sound") then
				c:Destroy()
			end
		end
	else
		-- la variante hereda de la plantilla cómo suena en el mundo
		s.SoundGroup = t.SoundGroup
		s.RollOffMode, s.RollOffMinDistance, s.RollOffMaxDistance = t.RollOffMode, t.RollOffMinDistance, t.RollOffMaxDistance
	end
	s.Looped = false
	s.Volume *= gain or 1
	s.PlaybackSpeed *= (pitch or noteOf(t)) * (1 + (math.random() * 2 - 1) * (t:GetAttribute("Var") or 0))
	s.Parent = parent or SoundService
	table.insert(active, s)
	local done = false
	local function finish()
		if not done then
			done = true
			local i = table.find(active, s)
			if i then
				table.remove(active, i)
			end
			s:Destroy()
		end
	end
	s.Ended:Once(finish)
	s.Destroying:Once(finish)
	-- red de seguridad (si el padre desaparece o el audio no carga); como mucho 40 s
	local region = s.PlaybackRegionsEnabled and (s.PlaybackRegion.Max - s.PlaybackRegion.Min) or nil
	task.delay(math.min(((region and region < 1000 and region) or (s.TimeLength > 0 and s.TimeLength) or 20) / s.PlaybackSpeed + 1, 40), finish)
	s:Play()
	return s
end

return Sfx
