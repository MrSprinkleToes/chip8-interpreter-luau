# CHIP8 Interpreter for Luau
### Using Roblox to provide graphics + sound

## Using
By default, the project is set up to run a Breakout game program, then shortly after reset the interpreter and load a heartbeat monitor program.

To run other programs:
Make sure you have the interpreter ready to go. Create it like this:
```
local chip8 = require(PATH_TO_CHIP8_INTERPRETER) -- by default located in src/client/emulators/chip8/chip8.lua
local device = chip8.new()
```
Fetch the program/ROM file from the internet (`.ch8` file) using the `GetROM` client to server function, like so:
```
local programFile = game:GetService("ReplicatedStorage").Common.remotes.Client:Get("GetROM"):CallServer(URL_TO_PROGRAM_HERE)
```
Make sure you have a 60 FPS loop running which calls `device:cycle()` and `device:render()`. Example using Roblox's RenderStepped function:
```
local elapsed = 0
game:GetService("RunService").RenderStepped:Connect(function(dt)
  elapsed += dt
  while elapsed >= 1 / 60 do
    elapsed -= 1 / 60
    device:cycle() -- executes a cycle of the interpreter
    device:render() -- renders the output to a 64x32 pixel display in Roblox
  end
end)
```
To load a program, simply call `device:loadROM(PROGRAM_BINARY)`:
```
device:loadROM(programFile)
```

In order to reset the interpreter and stop executing the current loaded program, call `device:reset()`.
