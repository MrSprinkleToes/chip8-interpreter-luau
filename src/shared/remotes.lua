local Net = require(game:GetService("ReplicatedStorage").Packages.Net)

return Net.CreateDefinitions({
	GetROM = Net.Definitions.ServerFunction()
})