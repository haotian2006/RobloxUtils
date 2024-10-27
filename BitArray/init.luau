--!native
--!optimize 2

local BitArray = {}

export type BitArray = {}

--[[
These function are used for fast traversal of the BitArray.

<Get>
local b = bitArr[1]
local bitsPerEntry = bitArr[2]
local len = bitArr[4]
local entriesPerInt = bitArr[3]

local shifts = 2^bitsPerEntry
local bitMask = shifts - 1

local sequence,entries = buffer.readu32(b,0),1
local byteIdx = 0

for index = 0,len-1 do
    if entries > entriesPerInt then
        byteIdx+=1
        sequence,entries = buffer.readu32(b,byteIdx*4),1
    end
    entries+=1
    local value = bit32.band( sequence, bitMask)
    sequence //= shifts
    --do something with value and index
end

<Set>
local bitArrayBuff = bitArr[1]
local entriesPerInt = bitArr[3]
local bitsPerEntry = bitArr[2]
local len = bitArr[4]

local sequence, entries = 0, 1
local byteIndex, mul = 0, 1
local shift = 2^bitsPerEntry
    
for index=0,len-1 do
    local value = ...
    
    if entries > entriesPerInt then
        buffer.writeu32(bitArrayBuff, byteIndex*4, sequence)
        byteIndex+=1 
        entries,sequence,mul = 1,0,1
    end
    entries+=1
    sequence +=  value*mul 
    mul *= shift 
end
buffer.writeu32(bitArrayBuff, byteIndex*4, sequence)

]]

local readF = {
	["8"] = buffer.readu8,
	["16"] = buffer.readu16,
	["32"] = buffer.readu32,
}

local writeF = {
	["8"] = buffer.writeu8,
	["16"] = buffer.writeu16,
	["32"] = buffer.writeu32,
}

local bufferCopy = buffer.copy

local function bytesNeeded(bitsPerEntry: number, length: number)
	local entriesPerInt = 32 // bitsPerEntry
	return (length + entriesPerInt - 1) // entriesPerInt * 4
end

function BitArray.new(bitsPerEntry: number, length: number, b: buffer?): BitArray
	assert(not (bitsPerEntry > 32 or bitsPerEntry <= 0), "[BitArray] Entry size must be in the range of [1,32] bits")
	assert(length > 0, "[BitArray] Length must be greater than 0")

	local entriesPerInt = 32 // bitsPerEntry
	local bytes = (length + entriesPerInt - 1) // entriesPerInt * 4

	return {
		b or buffer.create(bytes), -- 1
		bitsPerEntry, -- 2
		entriesPerInt, -- 3
		length, -- 4
	}
end

function BitArray.get(self: BitArray, index: number): number
	local b = self[1]

	local entriesPerInt = self[3]
	local idx = index // entriesPerInt
	local bitSize = self[2]

	local value = buffer.readu32(b, idx * 4)
	local bitIndex = (index - idx * entriesPerInt) * bitSize
	return bit32.extract(value, bitIndex, bitSize)
end

function BitArray.set(self: BitArray, index: number, value: number)
	local b = self[1]

	local entriesPerInt = self[3]
	local idx = index // entriesPerInt
	local bitSize = self[2]
	local bitIndex = (index - idx * entriesPerInt) * bitSize
	local bufferIndex = idx * 4

	local oldValue = buffer.readu32(b, bufferIndex)
	local newValue = bit32.replace(oldValue, value, bitIndex, bitSize)
	buffer.writeu32(b, bufferIndex, newValue)
end

function BitArray.getAndSet(self: BitArray, index: number, value: number): number
	local b = self[1]

	local entriesPerInt = self[3]
	local idx = index // entriesPerInt
	local bitSize = self[2]
	local bitIndex = (index - idx * entriesPerInt) * bitSize
	local bufferIndex = idx * 4

	local oldValue = buffer.readu32(b, bufferIndex)
	local newValue = bit32.replace(oldValue, value, bitIndex, bitSize)
	buffer.writeu32(b, bufferIndex, newValue)
	return bit32.extract(oldValue, bitIndex, bitSize)
end

function BitArray.copy(self: BitArray): BitArray
	local copy = table.clone(self)
	copy[1] = buffer.create(buffer.len(self[1]))
	bufferCopy(copy[1], 0, self[1])
	return copy
end

function BitArray.copyAndResize(self: BitArray, bitsPerEntry: number): BitArray
	local length = self[4]

	local newArr = BitArray.new(bitsPerEntry, length)

	local oldBuffer = self[1]
	local oldEntriesPerInt = self[3]
	local oldBitsPerEntry = self[2]
	local oldShifts = 2 ^ oldBitsPerEntry
	local oldBitMask = oldShifts - 1

	local newBuffer = newArr[1]
	local newEntriesPerInt = newArr[3]
	local newBitsPerEntry = bitsPerEntry
	local newShift = 2 ^ newBitsPerEntry

	local oldSequence, oldEntries = buffer.readu32(oldBuffer, 0), 1
	local oldByteIndex = 0

	local newSequence, newEntries = 0, 1
	local newByteIndex, mul = 0, 1

	for iter = 0, length - 1 do
		if oldEntries > oldEntriesPerInt then
			oldByteIndex += 1
			oldSequence, oldEntries = buffer.readu32(oldBuffer, oldByteIndex * 4), 1
		end
		oldEntries += 1
		local value = bit32.band(oldSequence, oldBitMask)
		oldSequence = oldSequence // oldShifts

		if newEntries > newEntriesPerInt then
			buffer.writeu32(newBuffer, newByteIndex * 4, newSequence)
			newByteIndex += 1
			newEntries, newSequence, mul = 1, 0, 1
		end
		newEntries += 1
		newSequence += value * mul --bit32.lshift(value, bitsPerEntry * (newEntries-2))
		mul *= newShift
	end

	buffer.writeu32(newBuffer, newByteIndex * 4, newSequence)

	return newArr
end

function BitArray.reallocate(self: BitArray, entries: number)
	local bitsPerEntry = self[2]

	local entriesPerInt = 32 // bitsPerEntry
	local bytes = (entries + entriesPerInt - 1) // entriesPerInt * 4

	local b = buffer.create(bytes)
	bufferCopy(b, 0, self[1], 0, bytes)

	self[1] = b
	self[4] = entries
end

function BitArray.size(self: BitArray): number
	return buffer.len(self[1])
end

function BitArray.len(self: BitArray): number
	return self[4]
end

function BitArray.toBuffer(self: BitArray, bufferSize: ("8" | "16" | "32")?): buffer
	local size = tostring(bufferSize or "32")
	assert(
		size == "8" or size == "16" or size == "32",
		"[BitArray] Invalid buffer size [" .. size .. "] expected 8, 16 or 32."
	)

	local b = self[1]
	local entriesPerInt = self[3]
	local bitsPerEntry = self[2]

	assert(
		bitsPerEntry <= tonumber(size),
		"[BitArray] BitArray entry size [" .. size .. "] is too small for Buffer entry size [" .. bitsPerEntry .. "]."
	)

	local length = self[4]
	local mulB = (tonumber(size) or 32) // 8
	local newBuff = buffer.create(length * mulB)

	local write = writeF[size]

	local shifts = 2 ^ bitsPerEntry
	local bitMask = shifts - 1

	local sequence, entries = buffer.readu32(b, 0), 1
	local byteIdx = 0

	for iter = 0, self[4] - 1 do
		if entries > entriesPerInt then
			byteIdx += 1
			sequence, entries = buffer.readu32(b, byteIdx * 4), 1
		end
		entries += 1
		local value = bit32.band(sequence, bitMask)
		sequence = sequence // shifts
		write(newBuff, iter * mulB, value)
	end

	return newBuff
end

function BitArray.serialize(self: BitArray, b: buffer, start: number?): number
	local idx: number = start or 0
	buffer.writeu8(b, idx, self[2])
	idx += 1
	buffer.writeu32(b, idx, self[4])
	idx += 4
	bufferCopy(b, idx, self[1])
	idx += buffer.len(self[1])
	return idx
end

function BitArray.serializeSize(self: BitArray): number
	return 5 + buffer.len(self[1])
end

function BitArray.deserialize(b: buffer, start: number?): (number, BitArray)
	local idx: number = start or 0
	local bitsPerEntry = buffer.readu8(b, idx)
	idx += 1
	local length = buffer.readu32(b, idx)
	idx += 4
	local bytes = bytesNeeded(bitsPerEntry, length)
	local newBuff = buffer.create(bytes)
	bufferCopy(newBuff, 0, b, idx, bytes)
	return idx + bytes, BitArray.new(bitsPerEntry, length, newBuff)
end

local function ForEachV2(self: BitArray, f: (i: number, v: number) -> ())
	local b = self[1]
	local bitsPerEntry = self[2]
	local len = self[4]
	local entriesPerInt = self[3]

	local shifts = 2 ^ bitsPerEntry
	local bitMask = shifts - 1

	local sequence, entries = buffer.readu32(b, 0), 1
	local byteIdx = 0

	for iter = 0, len - 1 do
		if entries > entriesPerInt then
			byteIdx += 1
			sequence, entries = buffer.readu32(b, byteIdx * 4), 1
		end
		entries += 1
		local value = bit32.band(sequence, bitMask)
		sequence = sequence // shifts
		f(iter, value)
	end
end

function BitArray.forEach(self: BitArray, func: (i: number, v: number) -> ())
	local bitsPerEntry = self[2]
	if bitsPerEntry < 17 then
		ForEachV2(self, func)
		return
	end
	local b = self[1]
	for i = 0, buffer.len(b) // 4 - 1 do
		func(i, buffer.readu32(b, i * 4))
	end
end

return table.freeze(BitArray)
