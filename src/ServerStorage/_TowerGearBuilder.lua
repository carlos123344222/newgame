-- (herramienta de desarrollo) Rehace ReplicatedStorage.TowerGear con los gear_<nombre>.txt que exporta Blender,
-- servidos por recv.js en localhost:8766. Uso: require(este)({"Peana", "Calabaza", ...})
return function(names)
	local Http = game:GetService("HttpService")
	local was = Http.HttpEnabled
	Http.HttpEnabled = true
	local m = game.ReplicatedStorage.TowerGear
	local src = m.Source
	local res = {}
	for _, n in names do
		local ok, body = pcall(function()
			return Http:GetAsync("http://localhost:8766/get?name=gear_" .. n)
		end)
		if ok then
			body = body:gsub("\r", ""):gsub("(%-?%d+%.%d+)", function(s)
				local r = string.format("%.3f", tonumber(s)):gsub("0+$", ""):gsub("%.$", "")
				return r == "-0" and "0" or r
			end)
			local block = n .. " = [[\n" .. body .. "\n]],"
			local a, b = src:find("\n" .. n .. " = %[%[\n.-\n%]%],")
			if a then
				src = src:sub(1, a) .. block .. src:sub(b + 1)
			else
				local i = src:find("\n}\n\nlocal cache")
				src = src:sub(1, i) .. block .. src:sub(i)
			end
			table.insert(res, n .. " " .. #body)
		else
			table.insert(res, n .. " ERROR " .. tostring(body))
		end
	end
	Http.HttpEnabled = was
	m.Source = src
	return table.concat(res, ", ") .. " | " .. #src
end
