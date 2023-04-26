-- CHIP-8 emulator

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GradientCanvas = require(game:GetService("ReplicatedStorage").Packages.GradientCanvas)
local gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local Fusion = require(game:GetService("ReplicatedStorage").Packages.Fusion)
local New = Fusion.New

local tweenIn = TweenInfo.new(0.075, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local tweenOut = TweenInfo.new(0.075, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

local KEY_MAP = {
	[Enum.KeyCode.One] = 0x1,
	[Enum.KeyCode.Two] = 0x2,
	[Enum.KeyCode.Three] = 0x3,
	[Enum.KeyCode.Four] = 0xC,
	[Enum.KeyCode.Q] = 0x4,
	[Enum.KeyCode.W] = 0x5,
	[Enum.KeyCode.E] = 0x6,
	[Enum.KeyCode.R] = 0xD,
	[Enum.KeyCode.A] = 0x7,
	[Enum.KeyCode.S] = 0x8,
	[Enum.KeyCode.D] = 0x9,
	[Enum.KeyCode.F] = 0xE,
	[Enum.KeyCode.Z] = 0xA,
	[Enum.KeyCode.X] = 0x0,
	[Enum.KeyCode.C] = 0xB,
	[Enum.KeyCode.V] = 0xF
}

local chip8 = {}
chip8.__index = chip8

function chip8.new()
	local self = setmetatable({}, chip8)
	
	self.clockSpeed = 1 / 500 -- 500Hz
	
	self.memory = table.create(4096, 0) -- 4KB memory
	self.memory[0] = 0
	self.v = table.create(16, 0) -- 16 8-bit registers (V0 - VF)
	self.i = 0 -- 16-bit register
	self.pc = 0x200 -- 16-bit program counter (program starts at 0x200)
	self.stack = {} -- 16 16-bit values
	self.delayTimer = 0 -- 8-bit timer
	self.soundTimer = 0 -- 8-bit timer
	self.video = table.create(64 * 32, 0) -- 64x32 pixels
	self.video[0] = 0
	self.video[64 * 32 + 1] = 0
	self.keys = table.create(15, 0) -- 16 keys
	self.keys[0] = 0
	self.beep = New "Sound" {
		Parent = game:GetService("SoundService"),
		SoundId = "rbxassetid://13227670986",
		Volume = 0,
		Looped = true,
		Name = "Beep"
	}
	
	self.display = GradientCanvas.new(64, 32)
	self.display:SetParent(gui)
	
	-- font (0x50 - 0x9F)
	local fontset = {
		0xF0, 0x90, 0x90, 0x90, 0xF0, 	-- 0
		0x20, 0x60, 0x20, 0x20, 0x70, 	-- 1
		0xF0, 0x10, 0xF0, 0x80, 0xF0, 	-- 2
		0xF0, 0x10, 0xF0, 0x10, 0xF0, 	-- 3
		0x90, 0x90, 0xF0, 0x10, 0x10, 	-- 4
		0xF0, 0x80, 0xF0, 0x10, 0xF0, 	-- 5
		0xF0, 0x80, 0xF0, 0x90, 0xF0, 	-- 6
		0xF0, 0x10, 0x20, 0x40, 0x40, 	-- 7
		0xF0, 0x90, 0xF0, 0x90, 0xF0, 	-- 8
		0xF0, 0x90, 0xF0, 0x10, 0xF0, 	-- 9
		0xF0, 0x90, 0xF0, 0x90, 0x90, 	-- A
		0xE0, 0x90, 0xE0, 0x90, 0xE0, 	-- B
		0xF0, 0x80, 0x80, 0x80, 0xF0, 	-- C
		0xE0, 0x90, 0x90, 0x90, 0xE0, 	-- D
		0xF0, 0x80, 0xF0, 0x80, 0xF0, 	-- E
		0xF0, 0x80, 0xF0, 0x80, 0x80 	-- F
	}
	
	for i = 0, #fontset - 1 do -- Load fontset into memory
		self.memory[i] = fontset[i + 1]
	end
	
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = KEY_MAP[input.KeyCode]
			if key then
				self.keys[key] = 1
			end
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = KEY_MAP[input.KeyCode]
			if key then
				self.keys[key] = 0
			end
		end
	end)
	
	print("Initialized CHIP-8!")
	return self
end

function chip8:loadROM(rom: string)
	print("Loading rom...")
	for i = 0, #rom - 1 do -- Load rom into memory
		self.memory[i + 0x200] = string.byte(rom, i + 1)
	end
	print("Loaded rom!")
end

function chip8:reset()
	-- clear program memory
	for i = 0, #self.memory do
		if i >= 0x200 then
			self.memory[i] = 0x00
		end
	end
	
	-- clear registers
	for i = 0, #self.v do
		self.v[i] = 0x00
	end
	
	-- clear stack
	for i = 1, #self.stack do
		self.stack[i] = nil
	end
	
	-- clear video
	for i = 0, #self.video do
		self.video[i] = 0x00
	end
	
	-- clear keys
	for i = 0, #self.keys do
		self.keys[i] = 0x00
	end
	
	-- reset timers
	self.delayTimer = 0
	self.soundTimer = 0
	
	-- reset program counter
	self.pc = 0x200
	
	-- reset index register
	self.i = 0
	
	-- reset stack pointer
	self.sp = 0
	
	-- reset beep
	self.beep.Volume = 0
	
	print("Reset!")
end

function chip8:cycle()
	local instructionCycles = (1 / 60) / self.clockSpeed -- determine how many instructions to execute per cycle (emulator runs at 60Hz)
	for i = 1, instructionCycles do
		local instruction = bit32.bor(bit32.lshift(self.memory[self.pc], 8), self.memory[self.pc + 1])
		self.pc += 2
		
		local opcode = bit32.rshift(bit32.band(instruction, 0xF000), 12)
		if opcode == 0x0 then
			local nnn = bit32.band(instruction, 0x0FFF)
			if nnn == 0x000 then -- NOP
				self.pc -= 2
			elseif nnn == 0x0E0 then -- Clear the display.
				self.video = table.create(64 * 32, 0)
			elseif nnn == 0x0EE then -- Return from a subroutine.
				self.pc = self.stack[#self.stack]
				self.stack[#self.stack] = nil
			end
		elseif opcode == 0x1 then -- Jump to address nnn.
			local addr = bit32.band(instruction, 0x0FFF)
			self.pc = addr
		elseif opcode == 0x2 then -- Call subroutine at nnn.
			local addr = bit32.band(instruction, 0x0FFF)
			self.stack[#self.stack + 1] = self.pc
			self.pc = addr
		elseif opcode == 0x3 then -- Skip next instruction if Vx = kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			if self.v[vx] == kk then
				self.pc = self.pc + 2
			end
		elseif opcode == 0x4 then -- Skip next instruction if Vx != kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			if self.v[vx] ~= kk then
				self.pc = self.pc + 2
			end
		elseif opcode == 0x5 then -- Skip next instruction if Vx = Vy.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			if self.v[vx] == self.v[vy] then
				self.pc = self.pc + 2
			end
		elseif opcode == 0x6 then -- Set Vx = kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			self.v[vx] = kk
		elseif opcode == 0x7 then -- Set Vx = Vx + kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			self.v[vx] += kk
			-- make sure we don't overflow
			if self.v[vx] > 255 then
				self.v[vx] -= 256
			end
		elseif opcode == 0x8 then
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			local n = bit32.band(instruction, 0x000F)
			if n == 0x0 then -- Set Vx = Vy.
				self.v[vx] = self.v[vy]
			elseif n == 0x1 then -- Set Vx = Vx OR Vy.
				self.v[vx] = bit32.bor(self.v[vx], self.v[vy])
			elseif n == 0x2 then -- Set Vx = Vx AND Vy.
				self.v[vx] = bit32.band(self.v[vx], self.v[vy])
			elseif n == 0x3 then -- Set Vx = Vx XOR Vy.
				self.v[vx] = bit32.bxor(self.v[vx], self.v[vy])
			elseif n == 0x4 then -- Set Vx = Vx + Vy, set VF = carry.
				local sum = self.v[vx] + self.v[vy]
				if sum > 0xFF then
					self.v[0xF] = 1
				else
					self.v[0xF] = 0
				end
				-- make sure we don't overflow
				if sum > 255 then
					sum -= 256
				end
				self.v[vx] = sum
			elseif n == 0x5 then -- Set Vx = Vx - Vy, set VF = NOT borrow.
				local diff = self.v[vx] - self.v[vy]
				if diff < 0 then
					self.v[0xF] = 0
				else
					self.v[0xF] = 1
				end
				self.v[vx] = diff
				-- make sure we don't underflow
				if self.v[vx] < 0 then
					self.v[vx] += 256
				end
			elseif n == 0x6 then -- Set Vx = Vx SHR 1.
				self.v[0xF] = bit32.band(self.v[vx], 0x1)
				self.v[vx] = bit32.rshift(self.v[vx], 1)
			elseif n == 0x7 then -- Set Vx = Vy - Vx, set VF = NOT borrow.
				local diff = self.v[vy] - self.v[vx]
				if diff < 0 then
					self.v[0xF] = 0
				else
					self.v[0xF] = 1
				end
				self.v[vx] = diff
				-- make sure we don't underflow
				if self.v[vx] < 0 then
					self.v[vx] += 256
				end
			elseif n == 0xE then -- Set Vx = Vx SHL 1.
				self.v[0xF] = bit32.rshift(self.v[vx], 7)
				self.v[vx] = bit32.lshift(self.v[vx], 1)
				-- make sure we don't overflow
				if self.v[vx] > 255 then
					self.v[vx] -= 256
				end
			end
		elseif opcode == 0x9 then -- Skip next instruction if Vx != Vy.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			if self.v[vx] ~= self.v[vy] then
				self.pc = self.pc + 2
			end
		elseif opcode == 0xA then -- Set I = nnn.
			local nnn = bit32.band(instruction, 0x0FFF)
			self.i = nnn
		elseif opcode == 0xB then -- Jump to location nnn + V0.
			local nnn = bit32.band(instruction, 0x0FFF)
			self.pc = nnn + self.v[0]
		elseif opcode == 0xC then -- Set Vx = random byte AND kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			self.v[vx] = bit32.band(math.random(0, 255), kk)
		elseif opcode == 0xD then -- Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			local n = bit32.band(instruction, 0x000F)
			local x = self.v[vx] % 64
			local y = self.v[vy] % 32
			self.v[0xF] = 0
			for i = 0, n - 1 do
				local sprite = self.memory[self.i + i]
				for j = 0, 7 do
					local pixel = bit32.rshift(bit32.band(sprite, 0x80), 7)
					if pixel == 1 then
						local index = (x + j) + ((y + i) * 64)
						if self.video[index] == 1 then
							self.v[0xF] = 1
						end
						self.video[index] = bit32.bxor((self.video[index] or 0), 1)
					end
					sprite = bit32.lshift(sprite, 1)
				end
			end
			self.drawFlag = true
		elseif opcode == 0xE then
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local n = bit32.band(instruction, 0x00FF)
			if n == 0x9E then -- Skip next instruction if key with the value of Vx is pressed.
				if self.keys[self.v[vx]] == 1 then
					self.pc += 2
				end
			elseif n == 0xA1 then -- Skip next instruction if key with the value of Vx is not pressed.
				if self.keys[self.v[vx]] == 0 then
					self.pc += 2
				end
			end
		elseif opcode == 0xF then
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local n = bit32.band(instruction, 0x00FF)
			if n == 0x07 then -- Set Vx = delay timer value.
				self.v[vx] = self.delayTimer
			elseif n == 0x0A then -- Wait for a key press, store the value of the key in Vx.
				local keyPress = false
				for i = 0, 15 do
					if self.keys[i] == 1 then
						self.v[vx] = i
						keyPress = true
					end
				end
				if not keyPress then
					self.pc -= 2
				end
			elseif n == 0x15 then -- Set delay timer = Vx.
				self.delayTimer = self.v[vx]
			elseif n == 0x18 then -- Set sound timer = Vx.
				self.soundTimer = self.v[vx]
			elseif n == 0x1E then -- Set I = I + Vx.
				self.i = self.i + self.v[vx]
			elseif n == 0x29 then -- Set I = location of sprite for digit Vx.
				self.i = self.v[vx] * 5
			elseif n == 0x33 then -- Store BCD representation of Vx in memory locations I, I+1, and I+2.
				local value = self.v[vx]
				self.memory[self.i] = math.floor(value / 100)
				self.memory[self.i + 1] = math.floor((value % 100) / 10)
				self.memory[self.i + 2] = value % 10
			elseif n == 0x55 then -- Store registers V0 through Vx in memory starting at location I.
				for i = 0, vx do
					self.memory[self.i + i] = self.v[i]
				end
			elseif n == 0x65 then -- Read registers V0 through Vx from memory starting at location I.
				for i = 0, vx do
					self.v[i] = self.memory[self.i + i]
				end
			end
		end
	end
	
	-- update timers (60hz)
	if self.delayTimer > 0 then
		self.delayTimer -= 1
	end
	
	if self.soundTimer > 0 then
		if not self.beep.IsPlaying then
			self.beep:Play()
			local tween = TweenService:Create(self.beep, tweenIn, { Volume = 0.5 })
			tween:Play()
		end
		self.soundTimer -= 1
	else
		if self.beep.IsPlaying then
			coroutine.wrap(function()
				local sound = self.beep
				local tween = TweenService:Create(sound, tweenOut, { Volume = 0 })
				tween:Play()
				tween.Completed:Wait()
				sound:Destroy()
			end)()
			local clone = self.beep:Clone()
			clone.Volume = 0
			clone:Stop()
			clone.Parent = self.beep.Parent
			self.beep = clone
		end
	end
end

function chip8:render()
	for i = 0, 64 * 32 - 1 do
		if self.video[i] == 1 then
			self.display:SetPixel(i % 64 + 1, math.floor(i / 64) + 1, Color3.new(1, 1, 1))
		else
			self.display:SetPixel(i % 64 + 1, math.floor(i / 64) + 1, Color3.new())
		end
	end
	
	self.display:Render()
end

return chip8