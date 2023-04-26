local HttpService = game:GetService("HttpService")
local remotes = require(game:GetService("ReplicatedStorage").Common.remotes)

remotes.Server:OnFunction("GetROM", function(player, romName)
	print("Requesting ROM:", romName)
	local romNameUrl = HttpService:UrlEncode(romName)
	
	local success, response = pcall(function()
		return HttpService:GetAsync("https://github.com/dmatlack/chip8/raw/master/roms/games/" .. romNameUrl)
	end)
	
	if not success then
		-- try treating romName as a URL
		success, response = pcall(function()
			return HttpService:GetAsync(romName)
		end)
	end
	
	if not success then
		error("Failed to get ROM: " .. response)
	end
	
	print("Got ROM:", romName)
	return response
end)