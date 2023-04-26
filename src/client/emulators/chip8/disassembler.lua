-- CHIP-8 disassembler
local remotes = require(game:GetService("ReplicatedStorage").Common.remotes)
local GetROM = remotes.Client:Get("GetROM")

local disassembler = {}

function disassembler.disassemble(romName)
	local rom = GetROM:CallServer(romName)
	
	if not rom then
		error("Failed to get ROM: " .. romName)
	end
	
	local bytes = {}
	for i = 1, #rom do
		bytes[i] = string.byte(rom, i)
	end
	
	local instructions = {}
	for i = 1, #bytes, 2 do
		local str = {}
		
		local instruction = bytes[i] * 0x100 + bytes[i + 1]
		instructions[#instructions + 1] = instruction
		
		table.insert(str, string.format("%04X", instruction))
		
		local opcode = bit32.rshift(bit32.band(instruction, 0xF000), 12)
		if opcode == 0x0 then
			local nnn = bit32.band(instruction, 0x0FFF)
			if nnn == 0x0E0 then -- Clear the display.
				table.insert(str, "CLS")
			elseif nnn == 0x0EE then -- Return from a subroutine.
				table.insert(str, "RET")
			end
		elseif opcode == 0x1 then -- Jump to address nnn.
			local addr = bit32.band(instruction, 0x0FFF)
			table.insert(str, "JP " .. string.format("%03X", addr))
		elseif opcode == 0x2 then -- Call subroutine at nnn.
			local addr = bit32.band(instruction, 0x0FFF)
			table.insert(str, "CALL " .. string.format("%03X", addr))
		elseif opcode == 0x3 then -- Skip next instruction if Vx = kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			table.insert(str, "SE V" .. vx .. ", " .. string.format("%02X", kk))
		elseif opcode == 0x4 then -- Skip next instruction if Vx != kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			table.insert(str, "SNE V" .. vx .. ", " .. string.format("%02X", kk))
		elseif opcode == 0x5 then -- Skip next instruction if Vx = Vy.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			table.insert(str, "SE V" .. vx .. ", V" .. vy)
		elseif opcode == 0x6 then -- Set Vx = kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			table.insert(str, "LD V" .. vx .. ", " .. string.format("%02X", kk))
		elseif opcode == 0x7 then -- Set Vx = Vx + kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			table.insert(str, "ADD V" .. vx .. ", " .. string.format("%02X", kk))
		elseif opcode == 0x8 then
			local n = bit32.band(instruction, 0x000F)
			if n == 0x0 then -- Set Vx = Vy.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "LD V" .. vx .. ", V" .. vy)
			elseif n == 0x1 then -- Set Vx = Vx OR Vy.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "OR V" .. vx .. ", V" .. vy)
			elseif n == 0x2 then -- Set Vx = Vx AND Vy.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "AND V" .. vx .. ", V" .. vy)
			elseif n == 0x3 then -- Set Vx = Vx XOR Vy.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "XOR V" .. vx .. ", V" .. vy)
			elseif n == 0x4 then -- Set Vx = Vx + Vy, set VF = carry.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "ADD V" .. vx .. ", V" .. vy)
			elseif n == 0x5 then -- Set Vx = Vx - Vy, set VF = NOT borrow.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "SUB V" .. vx .. ", V" .. vy)
			elseif n == 0x6 then -- Set Vx = Vx SHR 1.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "SHR V" .. vx)
			elseif n == 0x7 then -- Set Vx = Vy - Vx, set VF = NOT borrow.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
				table.insert(str, "SUBN V" .. vx .. ", V" .. vy)
			elseif n == 0xE then -- Set Vx = Vx SHL 1.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "SHL V" .. vx)
			else
				table.insert(str, "UNKNOWN")
			end
		elseif opcode == 0x9 then -- Skip next instruction if Vx != Vy.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			table.insert(str, "SNE V" .. vx .. ", V" .. vy)
		elseif opcode == 0xA then -- Set I = nnn.
			local nnn = bit32.band(instruction, 0x0FFF)
			table.insert(str, "LD I, " .. string.format("%03X", nnn))
		elseif opcode == 0xB then -- Jump to location nnn + V0.
			local nnn = bit32.band(instruction, 0x0FFF)
			table.insert(str, "JP V0, " .. string.format("%03X", nnn))
		elseif opcode == 0xC then -- Set Vx = random byte AND kk.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local kk = bit32.band(instruction, 0x00FF)
			table.insert(str, "RND V" .. vx .. ", " .. string.format("%02X", kk))
		elseif opcode == 0xD then -- Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
			local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
			local vy = bit32.rshift(bit32.band(instruction, 0x00F0), 4)
			local n = bit32.band(instruction, 0x000F)
			table.insert(str, "DRW V" .. vx .. ", V" .. vy .. ", " .. n)
		elseif opcode == 0xE then
			local kk = bit32.band(instruction, 0x00FF)
			if kk == 0x9E then -- Skip next instruction if key with the value of Vx is pressed.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "SKP V" .. vx)
			elseif kk == 0xA1 then -- Skip next instruction if key with the value of Vx is not pressed.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "SKNP V" .. vx)
			else
				table.insert(str, "UNKNOWN")
			end
		elseif opcode == 0xF then
			local kk = bit32.band(instruction, 0x00FF)
			if kk == 0x07 then -- Set Vx = delay timer value.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD V" .. vx .. ", DT")
			elseif kk == 0x0A then -- Wait for a key press, store the value of the key in Vx.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD V" .. vx .. ", K")
			elseif kk == 0x15 then -- Set delay timer = Vx.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD DT, V" .. vx)
			elseif kk == 0x18 then -- Set sound timer = Vx.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD ST, V" .. vx)
			elseif kk == 0x1E then -- Set I = I + Vx.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "ADD I, V" .. vx)
			elseif kk == 0x29 then -- Set I = location of sprite for digit Vx.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD F, V" .. vx)
			elseif kk == 0x33 then -- Store BCD representation of Vx in memory locations I, I+1, I+2.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD B, V" .. vx)
			elseif kk == 0x55 then -- Store registers V0 through Vx in memory starting at location I.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD [I], V" .. vx)
			elseif kk == 0x65 then -- Read registers V0 through Vx from memory starting at location I.
				local vx = bit32.rshift(bit32.band(instruction, 0x0F00), 8)
				table.insert(str, "LD V" .. vx .. ", [I]")
			else
				table.insert(str, "UNKNOWN")
			end
		end
		
		print(unpack(str))
	end
end

return disassembler