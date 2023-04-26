local remotes = require(game:GetService("ReplicatedStorage").Common.remotes)
local chip8 = require(script.Parent.chip8)

local GetROM = remotes.Client:Get("GetROM")

-- disassembler.disassemble("https://github.com/corax89/chip8-test-rom/raw/master/test_opcode.ch8")

local device = chip8.new()

local landingROM = GetROM:CallServer("https://github.com/mattmikolay/chip-8/raw/master/heartmonitor/heart_monitor.ch8")
local breakoutROM = GetROM:CallServer("https://github.com/mir3z/chip8-emu/raw/master/roms/Breakout%20(Brix%20hack)%20%5BDavid%20Winter%2C%201997%5D.ch8")

-- device:loadROM(breakoutROM)

local elapsed = 0
game:GetService("RunService").RenderStepped:Connect(function(dt)
	elapsed += dt
	
	while elapsed >= 1 / 60 do
		elapsed -= 1 / 60
		device:cycle()
		device:render()
	end
end)

task.wait(5)
device:loadROM(breakoutROM)
task.wait(10)
device:reset()
task.wait(2)
device:loadROM(landingROM)

return 0