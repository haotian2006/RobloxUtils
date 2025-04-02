--!optimize 2
--!native

--//THIS IS AUTO GENERATED
local SER_TYPES = {}
SER_TYPES.u8 = 1
SER_TYPES.i8 = 2
SER_TYPES.u16 = 3
SER_TYPES.i16 = 4
SER_TYPES.u24 = 5
SER_TYPES.i24 = 6
SER_TYPES.u32 = 7
SER_TYPES.i32 = 8
SER_TYPES.f32 = 9
SER_TYPES.f64 = 10
SER_TYPES.uint = 11
SER_TYPES.vector3 = 12
SER_TYPES.vector2 = 13
SER_TYPES.string = 14
SER_TYPES.cframe = 15
SER_TYPES.buffer = 16
SER_TYPES.bool = 17
SER_TYPES.any = 18
SER_TYPES.color3 = 19

do
    local enums = {}
    for i,v in SER_TYPES do
        enums[v] = i
    end
    SER_TYPES.enums = enums
end

------------------------------------------------------------------------------------------

local Serializer = {}

Serializer.types = SER_TYPES

local Writer,Reader = {},{}
local iWriter,iReader = {},{}
local typeToEnum = {
    number = SER_TYPES.f64,
    string = SER_TYPES.string,
    Vector3 = SER_TYPES.vector3,
    Vector2 = SER_TYPES.vector2,
    CFrame = SER_TYPES.cframe,
    buffer = SER_TYPES.buffer,
    boolean = SER_TYPES.bool,
    Color3 = SER_TYPES.color3,
    ['nil'] = 255
}

local EnumOrder = SER_TYPES.enums

local NameLookUp = {}
for i,v in EnumOrder do
    NameLookUp[v] = i
end

export type serializer = {
    buffer: buffer,
    cursor: number
}

export type Schema<T> = {
    writer: (s:serializer, value:T) -> (),
    reader: (s:serializer) -> (T)
}

export type SerializerAny = number|string|buffer|Vector3|Vector2|CFrame|nil|boolean

export type option = number&Schema<any>

export type writer = serializer&typeof(Writer)

export type reader = serializer&typeof(Reader)

Writer.__index = Writer
Reader.__index = Reader

local DEFAULT_SIZE = 1024
local GROWTH_FACTOR = 1.5

local bufferCopy = buffer.copy

--https://github.com/Data-Oriented-House/Cursor/blob/152efed23b696e1e7bca1e9beed79c931c5f1ac0/src/init.luau#L7
local function realloc(self: serializer, bytes: number)
	local b = self.buffer
	local p = self.cursor
	local len = buffer.len(b)

	if len < (p + bytes) then
		if len == 0 then
			len = 1
		end
		local exponent = math.ceil(math.log((bytes + p) / len, GROWTH_FACTOR))
		local new = buffer.create(len * GROWTH_FACTOR ^ exponent)
		bufferCopy(new, 0, b, 0)
		self.buffer = new
	end
end

local function writef16(b: buffer, i: number, v: number,min:number,max:number)
	local range = max - min
	local value = (v - min) / range
	buffer.writeu16(b, i, value * 65535)
end

local function readf16(b: buffer, i: number,min:number,max:number)
	local value = buffer.readu16(b, i) / 65535
	return value * (max - min) + min
end

local function bitsNeeded(x)
	if x == 0 then
		return 0
	end
	return math.floor(math.log(x, 2) + 1)
end

--//could use VLQ here but this works
local function writeuIntHelper(len)
	local bits = bitsNeeded(len)
	local header = 0
	local metaLength = 1
	local writer = nil
	if len + 5 < 256 then
		header = len + 5
	elseif bits < 9 then
		header = 4
		metaLength = 2
		writer = buffer.writeu8
	elseif bits < 17 then
		header = 3
		metaLength = 3
		writer = buffer.writeu16
	elseif bits < 33 then
		header = 2
		metaLength = 5
		writer = buffer.writeu32
	else
		header = 1
		metaLength = 9
		writer = buffer.writef64
	end
	return header, metaLength, writer
end

local function readuIntHelper(b, index)
	local header = buffer.readu8(b, index)
	local len
	index += 1
	if header > 4 then
		len = header - 5
	elseif header == 4 then
		len = buffer.readu8(b, index)
		index += 1
	elseif header == 3 then
		len = buffer.readu16(b, index)
		index += 2
	elseif header == 2 then
		len = buffer.readu32(b, index)
		index += 4
	else
		len = buffer.readf64(b, index)
		index += 8
	end
	return len, index
end

--[=[
	Creates a new serializer
	@param input number|buffer -- The initial size of the buffer or a buffer to use
	@return Serializer
]=]
function Serializer.new(input: (number | buffer)?): serializer
	local self = {}
	if type(input) == "number" then
		self.buffer = buffer.create(input)
	else
		self.buffer = input or buffer.create(DEFAULT_SIZE)
	end
	self.cursor = 0
	return self
end

local WriterMeta = { __index = Writer }
local ReaderMeta = { __index = Reader }

--[=[
	Attaches the writer to the serializer
	@param s Serializer
	@return Serializer_Writer
]=]
function Serializer.attachWriter(s: serializer): writer
	return setmetatable(s, WriterMeta) :: any
end

--[=[
	Attaches the reader to the serializer
	@param s Serializer
	@return Serializer_Reader
]=]
function Serializer.attachReader(s: serializer): reader
	return setmetatable(s, ReaderMeta) :: any
end

--[=[
	Creates a new writer
	@param initSize number? -- The initial size of the buffer
	@return Serializer_Writer
]=]
function Serializer.newWriter(initSize: number?): writer
	local self = table.clone(Writer)
	self.buffer = buffer.create(initSize or DEFAULT_SIZE)
	self.cursor = 0
	return self
end

--[=[
	Creates a new reader
	@param buffer buffer -- The buffer to read from
	@param startCursor number? -- The starting cursor
	@return Serializer_Reader
]=]
function Serializer.newReader(buffer: buffer, startCursor: number?): reader
	local self = table.clone(Reader)
	self.buffer = buffer
	self.cursor = startCursor or 0
	return self
end

--[=[
	Get the byte string from a buffer
	@param b buffer
	@return string
]=]
function Serializer.getByteStr(b)
	local str = ""
	for i = 0, buffer.len(b) - 1 do
		str ..= "\\" .. buffer.readu8(b, i)
	end
	return str
end

--[=[
	Get the reader function from the option
	@type function
	@param option SerializerOption
	@return (s:Serializer, ...any) -> any
	@parent SerializerClass
]=]
local function getReaderFrom(option: option): ((s: serializer, ...any) -> any)?
	local func = iReader[option]
	if not func then
		if type(option) == "table" and option.reader then
			return option.reader
		end
	end
	return func
end

Serializer.getReaderFrom = getReaderFrom


local function getWriterFrom(option: option): ((s: serializer, value: any, ...any) -> ())?
	local func = iWriter[option]
	if not func then
		if type(option) == "table" and option.writer then
			return option.writer
		end
	end
	return func
end

--[=[
	Get the writer function from the option
	@type function
	@param option SerializerOption
	@return (s:Serializer, value:any, ...any) -> any
	@parent SerializerClass
]=]
Serializer.getWriterFrom = getWriterFrom

local function writeu24(b: buffer, i: number, v: number)
	buffer.writeu8(b, i, v)
	buffer.writeu16(b, i + 1, v // 256)
end

--[=[
	Writes a u24 to the buffer
	@type function
	@param b buffer
	@param index number 
	@param value number
	@parent SerializerClass
]=]
Serializer.writeu24 = writeu24


local function readu24(b: buffer, index: number): (number)
	local v = buffer.readu8(b, index)
	v += buffer.readu16(b, index + 1) * 256
	return v
end

--[=[
	Reads a u24 from the buffer
	@type function
	@param b buffer
	@param index number 
	@parent SerializerClass
	@return number
]=]
Serializer.readu24 = readu24
local function writei24(b: buffer, i: number, v: number)
	buffer.writei8(b, i, v)
	buffer.writei16(b, i + 1, v // 256)
end

--[=[
	Writes a i24 to the buffer
	@type function
	@param b buffer
	@param index number 
	@param value number
	@parent SerializerClass
]=]
Serializer.writei24 = writei24

--[=[
	Reads a i24 to the buffer
	@type function
	@param b buffer
	@param index number 
	@return number
]=]
local function readi24(b: buffer, index: number): (number, number)
	local v = buffer.readi8(b, index)
	v += buffer.readi16(b, index + 1) * 256
	return v, index + 3
end

--[=[
	Writes a f16 to the buffer
	@type function
	@param b buffer
	@param index number
	@param value number
	@param min number
	@param max number
]=]
Serializer.writef16 = writef16

--[=[
	Reads a f16 from the buffer
	@type function
	@param b buffer
	@param index number
	@param min number
	@param max number
	@return number
]=]
Serializer.readf16 = readf16

local function writeuInt(b: buffer, i: number, v: number)
	local header, metaLength, writer = writeuIntHelper(v)
	buffer.writeu8(b, i, header)
	if writer then
		writer(b, i + 1, v)
	end
	return metaLength
end

--[=[
	Writes a uInt to the buffer
	@type function
	@param b buffer
	@param index number 
	@param value number
	@return number --the length of the meta data
	@parent SerializerClass
]=]
Serializer.writeuInt = writeuInt

do

--[=[ 
	Saves the current location of the serializer
	@param self Serializer
]=]
	function Writer.saveLocation(self)
		self._buf = self.buffer
		self._cursor = self.cursor
	end

	--[=[
		Reuses the saved location of the serializer
		@param self Serializer
		@param ser Serializer? -- The serializer to reuse, use saved location if not provided
	]=]
	function Writer.reuse(self, ser: serializer?)
		if not ser then
			self.buffer = self._buf
			self.cursor = self._cursor
			return
		end
		self.buffer = ser.buffer
		self.cursor = ser.cursor
	end

	--[=[
		Clears the buffer
		@param self Serializer
	]=]
	function Writer.clear(self: serializer)
		self.cursor = 0
	end

	--[=[
		Creates a buffer from the serializer
		@param self Serializer
		@return buffer
	]=]
	function Writer.toBuffer(s: serializer): buffer
		local b = buffer.create(s.cursor)
		bufferCopy(b, 0, s.buffer, 0, s.cursor)
		return b
	end

	--[=[
		Writes a u8 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writeu8(s: serializer, value: number)
		realloc(s, 1)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 1
		buffer.writeu8(b, p, value)
	end

	--[=[
		Writes a u16 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writeu16(s: serializer, value: number)
		realloc(s, 2)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 2
		buffer.writeu16(b, p, value)
	end

	--[=[
		Writes a f16 to the buffer
		@param self Serializer
		@param value number
		@param min number
		@param max number
	]=]
	function Writer.writef16(s: serializer, value: number, min: number, max: number)
		realloc(s, 2)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 2
		writef16(b, p, value, min, max)
	end 

	--[=[
		Writes a u24 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writeu24(s: serializer, value: number)
		realloc(s, 3)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 3
		buffer.writeu8(b, p, value)
		buffer.writeu16(b, p + 1, value // 256)
	end

	--[=[
		Writes a uInt to the buffer (variable length integer)
		@param self Serializer
		@param value number
	]=]
	function Writer.writeuInt(s: serializer, value: number)
		-- local header,metaLength,writer = writeuIntHelper(value)
		-- realloc(s, metaLength)
		-- local b = s.buffer
		-- local p = s.cursor
		-- s.cursor = p + metaLength
		-- buffer.writeu8(b, p, header)
		-- if writer then
		--     writer(b, p+1, value)
		-- end

		local p = s.cursor
		local bits = bitsNeeded(value)
		if value + 5 < 256 then
			realloc(s, 1)
			local b = s.buffer
			buffer.writeu8(b, p, value + 5)
			s.cursor = p + 1
		elseif bits < 9 then
			realloc(s, 2)
			local b = s.buffer
			buffer.writeu8(b, p, 4)
			buffer.writeu8(b, p + 1, value)
			s.cursor = p + 2
		elseif bits < 17 then
			realloc(s, 3)
			local b = s.buffer
			buffer.writeu8(b, p, 3)
			buffer.writeu16(b, p + 1, value)
			s.cursor = p + 3
		elseif bits < 33 then
			realloc(s, 5)
			local b = s.buffer
			buffer.writeu8(b, p, 2)
			buffer.writeu32(b, p + 1, value)
			s.cursor = p + 5
		else
			realloc(s, 9)
			local b = s.buffer
			buffer.writeu8(b, p, 1)
			buffer.writef64(b, p + 1, value)
			s.cursor = p + 9
		end
	end

	--[=[
		Writes a i8 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writeu32(s: serializer, value: number)
		realloc(s, 4)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 4
		buffer.writeu32(b, p, value)
	end

	--[=[
		Writes a i8 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writei8(s: serializer, value: number)
		realloc(s, 1)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 1
		buffer.writei8(b, p, value)
	end

	--[=[
		Writes a i16 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writei16(s: serializer, value: number)
		realloc(s, 2)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 2
		buffer.writei16(b, p, value)
	end

	--[=[
		Writes a i24 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writei24(s: serializer, value: number)
		realloc(s, 3)--[[  ]]
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 3
		buffer.writei8(b, p, value)
		buffer.writei16(b, p + 1, value // 256)
	end

	--[=[
		Writes a i32 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writei32(s: serializer, value: number)
		realloc(s, 4)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 4
		buffer.writei32(b, p, value)
	end

	--[=[
		Writes a f32 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writef32(s: serializer, value: number)
		realloc(s, 4)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 4
		buffer.writef32(b, p, value)
	end

	--[=[
		Writes a f64 to the buffer
		@param self Serializer
		@param value number
	]=]
	function Writer.writef64(s: serializer, value: number)
		realloc(s, 8)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 8
		buffer.writef64(b, p, value)
	end

	--[=[
		Writes a Vector3 to the buffer
		@param self Serializer
		@param value Vector3
	]=]
	function Writer.writeVector3(s: serializer, value: Vector3)
		realloc(s, 12)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 12
		buffer.writef32(b, p, value.X)
		buffer.writef32(b, p + 4, value.Y)
		buffer.writef32(b, p + 8, value.Z)
	end

	--[=[
		Writes a Vector2 to the buffer
		@param self Serializer
		@param value Vector2
	]=]
	function Writer.writeVector2(s: serializer, value: Vector2)
		realloc(s, 8)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 8
		buffer.writef32(b, p, value.X)
		buffer.writef32(b, p + 4, value.Y)
	end

	--[=[
		Writes a Color3 to the buffer

		@param self Serializer
		@param value Color3
	]=]
	function Writer.writeColor3(s: serializer, value: Color3)
		realloc(s, 3)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 3
		buffer.writeu8(b, p,value.R * 255)
		buffer.writeu8(b, p + 1,value.G * 255)
		buffer.writeu8(b, p + 2,value.B * 255)
	end

	--[=[
		Writes a string to the buffer
		@param self Serializer
		@param value string
	]=]
	function Writer.writeString(s: serializer, value: string)
		local len = #value
		local header, metaLength, writer = writeuIntHelper(len)

		realloc(s, len + metaLength)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + len + metaLength
		buffer.writeu8(b, p, header)
		if writer then
			writer(b, p + 1, len)
		end
		buffer.writestring(b, p + metaLength, value)
	end

	--[=[
		Writes a CFrame to the buffer
		@param self Serializer
		@param value CFrame
	]=]
	function Writer.writeCFrame(s: serializer, value: CFrame)
		realloc(s, 18)
		local b = s.buffer
		local p = s.cursor
		local pos = value.Position
		local axis,t = value:ToAxisAngle()
        axis*=math.sin(t/2)

		s.cursor = p + 18

		buffer.writef32(b, p, pos.X)
		buffer.writef32(b, p + 4, pos.Y)
		buffer.writef32(b, p + 8, pos.Z)

		buffer.writei16(b, p + 12, (axis.X ) * 32767)
		buffer.writei16(b, p + 14, (axis.Y + 1) * 32767)
		buffer.writei16(b, p + 16, (axis.Z + 1) * 32767)
	end

	--[=[
		Writes a buffer to the buffer
		@param self Serializer
		@param value buffer
		@param start number? -- The start index of the buffer use 0 if not provided
		@param finish number? -- The end index of the buffer use len(buffer) if not provided
	]=]
	function Writer.writeBuffer(s: serializer, value: buffer, start: number?, finish: number?)
		local target = finish or buffer.len(value)
		local init = start or 0

		local len = target - init

		local header, metaLength, writer = writeuIntHelper(len)

		realloc(s, len + metaLength)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + len + metaLength
		buffer.writeu8(b, p, header)
		if writer then
			writer(b, p + 1, len)
		end
		bufferCopy(b, p + metaLength, value, init, len)
	end

	--[=[
		Writes a buffer to the buffer without any header
		@param self Serializer
		@param value buffer
		@param start number? -- The start index of the buffer use 0 if not provided
		@param finish number? -- The end index of the buffer use len(buffer) if not provided
	]=]
	function Writer.writeBufferRaw(s: serializer, value: buffer, start: number?, finish: number?)
		local target = finish or buffer.len(value)
		local init = start or 0

		local len = target - init
		realloc(s, len)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + len
		bufferCopy(b, p, value, init, len)
	end

	--[=[
		Writes an option to the buffer
		@param self Serializer
		@param option SerializerOption
		@param value any
		@param ... any -- Additional arguments for the writer 
	]=]
	function Writer.writeOption(s: serializer, option: option, value: any, ...: any)
		local writer = getWriterFrom(option)
		if not writer then
			error("Invalid option | must be a valid enum or custom type")
		end
		writer(s, value, ...)
	end

	--[=[
		Writes a boolean to the buffer
		@param self Serializer
		@param value boolean
	]=]
	function Writer.writeBool(s: serializer, value: boolean)
		realloc(s, 1)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 1
		buffer.writeu8(b, p, value and 1 or 0)
	end

	--[=[
		Writes an any to the buffer
		@param self Serializer
		@param value SerializerAny
	]=]
	function Writer.writeAny(s: serializer, value: SerializerAny)
		local idx = typeToEnum[typeof(value)]

		realloc(s, 1)
		local b = s.buffer
		local p = s.cursor
		s.cursor = p + 1
		buffer.writeu8(b, p, idx or 254)

		local writer = iWriter[idx]
		if writer then
			writer(s, value)
		elseif not idx then
			warn("Invalid type for writeAny: " .. typeof(value))
		end
	end

	--[=[
		Checks if the buffer can hold the bytes and reallocates if needed
		@type function
		@param self Serializer
		@param bytes number -- The number of bytes to check
	]=]
	Writer.tryRealloc = realloc
end

local function readVector3(b: buffer, index: number): (Vector3, number)
	local x = buffer.readf32(b, index)
	local y = buffer.readf32(b, index + 4)
	local z = buffer.readf32(b, index + 8)
	return Vector3.new(x, y, z), index + 12
end

local function readColor3(b: buffer, index: number): (Color3, number)
	local r = buffer.readu8(b, index) 
	local g = buffer.readu8(b, index + 1) 
	local blue = buffer.readu8(b, index + 2) 
	return Color3.fromRGB(r, g, blue), index + 3
end



--[=[
	Reads a Vector3 from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return Vector3 --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readVector3 = readVector3

--[=[
	Reads a Color3 from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return Color3 --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readColor3 = readColor3

local function readVector2(b: buffer, index: number): (Vector2, number)
	local x = buffer.readf32(b, index)
	local y = buffer.readf32(b, index + 4)
	return Vector2.new(x, y), index + 8
end

--[=[
	Reads a Vector2 from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return Vector2 --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readVector2 = readVector2

local function readString(b: buffer, index: number): (string, number)
	local len, newIndex = readuIntHelper(b, index)

	local str = buffer.readstring(b, newIndex, len)
	return str, newIndex + len
end

--[=[
	Reads a string from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return string --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readString = readString

local function readCFrame(b: buffer, index: number): (CFrame, number)
	local x, y, z = buffer.readf32(b, index), buffer.readf32(b, index + 4), buffer.readf32(b, index + 8)
	local axisX =buffer.readi16(b, index+12) /32767
	local axisY =buffer.readi16(b, index+14) /32767
	local axisZ =buffer.readi16(b, index+16) /32767
	local w = math.sqrt(1 - axisX^2 - axisY^2 - axisZ^2)
	
	return CFrame.new(x, y, z, axisX, axisY, axisZ, w), index + 18
end

--[=[
	Reads a CFrame from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return CFrame --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readCFrame = readCFrame

local function readBuffer(b: buffer, index: number): (buffer, number)
	local len, newIndex = readuIntHelper(b, index)

	local newBuffer = buffer.create(len)
	bufferCopy(newBuffer, 0, b, newIndex, len)
	return newBuffer, newIndex + len
end
--[=[
	Reads a buffer from the buffer 
	@type function
	@param b buffer
	@param index number 
	@return buffer --The value
	@return number --The new index
	@parent SerializerClass
]=]
Serializer.readBuffer = readBuffer


------------------------------------------------------------------------------------------
do
	--[=[
		Saves the current location of the serializer
		@param self Serializer
	]=]
	function Reader.saveLocation(self)
		self._buf = self.buffer
		self._cursor = self.cursor
	end

	--[=[
		Reuses the saved location of the serializer
		@param self Serializer
		@param ser Serializer? -- The serializer to reuse, use saved location if not provided
	]=]
	function Reader.reuse(self, ser: serializer?)
		if not ser then
			self.buffer = self._buf
			self.cursor = self._cursor
			return
		end
		self.buffer = ser.buffer
		self.cursor = ser.cursor
	end

	--[=[
		Reads a u8 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readu8(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readu8(s.buffer, cursor)
		s.cursor = cursor + 1
		return value
	end

	--[=[
		Reads a u16 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readu16(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readu16(s.buffer, cursor)
		s.cursor = cursor + 2
		
		return value
	end

	--[=[
		Reads a u24 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readu24(s: serializer): number
		local cursor = s.cursor
		local value = readu24(s.buffer, cursor)
		s.cursor = cursor + 3
		return value
	end

	--[=[
		Reads a u32 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readu32(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readu32(s.buffer, cursor)
		s.cursor = cursor + 4
		return value
	end

	--[=[
		Reads a uInt from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readuInt(s: serializer): number
		local value, index = readuIntHelper(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Reads a i8 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readi8(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readi8(s.buffer, cursor)
		s.cursor = cursor + 1
		return value
	end

	--[=[
		Reads a i16 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readi16(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readi16(s.buffer, cursor)
		s.cursor = cursor + 2
		return value
	end

	--[=[
		Reads a i24 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readi24(s: serializer): number
		local cursor = s.cursor
		local value = readi24(s.buffer, cursor)
		s.cursor = cursor + 3
		return value
	end

	--[=[
		Reads a i32 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readi32(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readi32(s.buffer, cursor)
		s.cursor = cursor + 4
		return value
	end

	--[=[
		Reads a f16 from the buffer 
		@param self Serializer
		@param min number
		@param max number
		@return number
	]=]
	function Reader.readf16(s: serializer, min: number, max: number): number
		local cursor = s.cursor
		local value = readf16(s.buffer, cursor, min, max)
		s.cursor = cursor+2
		return value
	end

	--[=[
		Reads a f32 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readf32(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readf32(s.buffer, cursor)
		s.cursor = cursor + 4
		return value
	end

	--[=[
		Reads a f64 from the buffer 
		@param self Serializer
		@return number
	]=]
	function Reader.readf64(s: serializer): number
		local cursor = s.cursor
		local value = buffer.readf64(s.buffer, cursor)
		s.cursor = cursor + 8
		return value
	end

	--[=[
		Reads a Vector3 from the buffer 
		@param self Serializer
		@return Vector3
	]=]
	function Reader.readVector3(s: serializer): Vector3
		local value, index = readVector3(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Reads a Vector2 from the buffer 
		@param self Serializer
		@return Vector2
	]=]
	function Reader.readVector2(s: serializer): Vector2
		local value, index = readVector2(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Reads a string from the buffer 
		@param self Serializer
		@return string
	]=]
	function Reader.readString(s: serializer): string
		local value, index = readString(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Reads a CFrame from the buffer 
		@param self Serializer
		@return CFrame
	]=]
	function Reader.readCFrame(s: serializer): CFrame
		local value, index = readCFrame(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Read an option from the buffer 
		@param self Serializer
		@param option SerializerOption
		@return any
	]=]
	function Reader.readOption(s: serializer, option: option, ...: any): any
		local reader = getReaderFrom(option)
		if not reader then
			error("Invalid option | must be a valid enum or custom type")
		end
		return reader(s, ...)
	end

	--[=[
		Reads a buffer from the buffer 
		@param self Serializer
		@return buffer
	]=]
	function Reader.readBuffer(s: serializer): buffer
		local value, index = readBuffer(s.buffer, s.cursor)
		s.cursor = index
		return value
	end

	--[=[
		Reads a bool
		@param self Serializer
		@return boolean
	]=]
	function Reader.readBool(s: serializer): boolean
		local c =  s.cursor
		local value = buffer.readu8(s.buffer, c) == 1
		local index = c + 1
		s.cursor = index
		return value
	end

	--[=[
		Reads an any from the buffer
		@param self Serializer
		@return SerializerAny
	]=]
	function Reader.readAny(s: serializer): SerializerAny
		local cursor = s.cursor
		local idx = buffer.readu8(s.buffer, cursor)
		s.cursor = cursor + 1
		local reader = iReader[idx]
		if reader then
			return reader(s)
		end
		return nil
	end

	--[=[
		Reads color3 from the buffer

		@param self Serializer
		@return Color3
	]=]
	function Reader.readColor3(s: serializer): Color3
		local value, index = readColor3(s.buffer, s.cursor)
		s.cursor = index
		return value
	end
	--[=[
		Check if buffer is out of bounds or next element is contains 0.
		If the next element is 0, it increments the cursor by 1
		@param self Serializer
		@return boolean -- If the buffer is out of bounds or the next element is 0
	]=]
	function Reader.isNull(s: serializer): boolean
		if s.cursor >= buffer.len(s.buffer) then
			return true
		end
		if buffer.readu8(s.buffer, s.cursor) == 0 then
			s.cursor += 1
			return true
		end
		return false
	end
end

local serWriteu8 = Writer.writeu8
local serWriteu16 = Writer.writeu16
local serWriteu24 = Writer.writeu24
local serWriteuInt = Writer.writeuInt
local serReadu24 = Reader.readu24
local serReaduInt = Reader.readuInt
local serReadu16 = Reader.readu16
local serReadu8 = Reader.readu8

do
	--//Custom Schema
	--[=[
		Creates a custom schema for the serializer
		@param keyType SerializerOption
		@param valueType SerializerOption
		@return SerializerSchema
	]=]
	function Serializer.mapSchema(keyType: option, value: option)
		local writer = getWriterFrom(keyType)
		local reader = getReaderFrom(keyType)
		local valueWriter = getWriterFrom(value)
		local valueReader = getReaderFrom(value)
		if not writer or not reader or not valueWriter or not valueReader then
			error("Invalid key or value type")
		end
		return {
			writer = function(s: serializer, t: {[any]: any })
				local size = 0
				local start = s.cursor
				realloc(s, 3)
				s.cursor += 3
				for i, v in t do
					writer(s, i)
					valueWriter(s, v)
					size += 1
				end
				writeu24(s.buffer, start, size)
			end,
			reader = function(s: serializer): {[any]: any }
				local size = readu24(s.buffer, s.cursor)
				s.cursor += 3
				local t = {}
				for i = 1, size do
					local key = reader(s)
					local value = valueReader(s)
					t[key] = value
				end
				return t
			end,
		}
	end

	--[=[
		Creates an array schema for the serializer
		@param valueType SerializerOption
		@return SerializerSchema
	]=]
	function Serializer.arraySchema<v>(valueType: option)
		local valueWriter = getWriterFrom(valueType)
		local valueReader = getReaderFrom(valueType)
		if not valueWriter or not valueReader then
			error("Invalid value type")
		end
		return {
			writer = function(s: serializer, t: { v })
				local size = #t
				serWriteuInt(s, size)
				for _, v in ipairs(t) do
					valueWriter(s, v)
				end
			end,
			reader = function(s: serializer, writeTo: {}?): { v }
				local size = serReaduInt(s)
				local t = writeTo or table.create(size)
				for i = 1, size do
					t[i] = valueReader(s)
				end
				return t
			end,
		}
	end

	--[=[
		Creates a struct schema for the serializer
		@param struct { [string]: SerializerOption }
		@return SerializerSchema
	]=]
	function Serializer.structSchema(struct: { [string]: option })
		local writers = {}
		local readers = {}

		local indexToName = {}
		for key in struct do
			table.insert(indexToName, key)
		end
		table.sort(indexToName)
		for idx, key in indexToName do
			local option = struct[key]
			local writer = getWriterFrom(option)
			local reader = getReaderFrom(option)
			if not writer or not reader then
				error("Invalid field type for key: " .. key)
			end
			writers[idx] = writer
			readers[idx] = reader
		end

		return {
			writer = function(s: serializer, t: { [string]: any })
				for idx, writer in writers do
					writer(s, t[indexToName[idx]])
				end
			end,
			reader = function(s: serializer, writeTo: {}?): { [string]: any }
				local t = writeTo or {}
				for idx, reader in readers do
					t[indexToName[idx]] = reader(s)
				end
				return t
			end,
		}
	end

	--[=[
		Creates an optional schema for the serializer.

		Used if value may be nil
		@param type SerializerOption
		@return SerializerSchema
	]=]
	function Serializer.optional(type: option)
		local writer = getWriterFrom(type)
		local reader = getReaderFrom(type)
		if not writer or not reader then
			error("Invalid type for optional")
		end
		return {
			writer = function(s: serializer, t: any)
				if t ~= nil then
					serWriteu8(s, 1)
					writer(s, t)
				else
					serWriteu8(s, 0)
				end
			end,
			reader = function(s: serializer): any
				local hasValue = serReadu8(s)
				if hasValue == 0 then
					return nil
				end
				return reader(s)
			end,
		}
	end

	--[=[
		Creates a float16 schema with a min and max value

		@param min number
		@param max number
		@return SerializerSchema
	]=]
	function Serializer.f16Schema(min: number, max: number)
		return {
			writer = function(s: serializer, t: number)
				local start = s.cursor
				realloc(s, 2)
				s.cursor += 2
				writef16(s.buffer, start, t, min, max)
			end,
			reader = function(s: serializer): number
				local value = readf16(s.buffer, s.cursor, min, max)
				s.cursor += 2
				return value
			end,
		}
	end

	--[=[
		Creates an optional struct schema for the serializer.

		Used if struct fields may be nil
		@param struct { [string]: SerializerOption }
		@return SerializerSchema
	]=]
	function Serializer.optionalStructSchema(struct: { [string]: option })
		local writers = {}
		local readers = {}
		local nameToIndex = {}

		local indexToName = {}
		for key in struct do
			table.insert(indexToName, key)
		end
		table.sort(indexToName)

		for idx, key in indexToName do
			local option = struct[key]
			local writer = getWriterFrom(option)
			local reader = getReaderFrom(option)
			if not writer or not reader then
				error("Invalid field type for key: " .. key)
			end
			writers[idx] = writer
			readers[idx] = reader
			nameToIndex[key] = idx
		end

		return {
			writer = function(s: serializer, t: { [string]: any })
				local start = s.cursor
				realloc(s, 3)
				s.cursor += 3
				for i, v in t do
					local index = nameToIndex[i]
					if index then
						serWriteuInt(s, index)
						writers[index](s, v)
					end
				end
				writeu24(s.buffer, start, s.cursor - start - 3)
			end,
			reader = function(s: serializer, writeTo: {}?): { [string]: any }
				local t = writeTo or {}
				local size = serReadu24(s)
				local endCursor = s.cursor + size
				while s.cursor < endCursor do
					local index = serReaduInt(s)
					local key = indexToName[index]
					if key then
						t[key] = readers[index](s)
					end
				end
				return t
			end,
		}
	end

	local lshift_lookup = {}
	for i = 1, 32 do
		lshift_lookup[i] = bit32.lshift(1, i - 1)
	end

	--[=[
		Creates an argument schema for the serializer.

		Used for if multiple arguments that may be nil.

		Has a limit of 32 arguments
		@param ... SerializerOption
		@return SerializerSchema 
	]=]
	function Serializer.argumentSchema(...: option)
		local writers = {}
		local readers = {}

		local arr = { ... }
		for index, option: option in arr do
			local writer = getWriterFrom(option)
			local reader = getReaderFrom(option)
			if not writer or not reader then
				error("Invalid type for argument: " .. index)
			end
			writers[index] = writer
			readers[index] = reader
		end

		local size = #arr
		assert(size < 33, "Too many arguments")
		local toAllocate = math.ceil(size / 8)
		local readerH = Reader.readu8
		local writerH = buffer.writeu8

		if size > 8 and size < 17 then
			readerH = Reader.readu16
			writerH = buffer.writeu16
		elseif size > 16 and size < 25 then
			readerH = Reader.readu24
			writerH = writeu24
		elseif size > 24 then
			readerH = Reader.readu32
			writerH = buffer.writeu32
		end

		return {
			writer = function(s: serializer, ...: any)
				local bits = 0
				local start = s.cursor
				realloc(s, toAllocate)
				s.cursor += toAllocate
				for idx, writer in writers do
					local value = select(idx, ...)
					if value then
						writer(s, value)
					else
						bits += lshift_lookup[idx]
					end
				end
				writerH(s.buffer, start, bits)
			end,
			reader = function(s: serializer, writeTo: {}?): {any }
				local t = writeTo or {}
				local bits = readerH(s)
				for idx, reader in readers do
					t[idx] = if bits % 2 == 0 then reader(s) else nil
					bits //= 2
				end
				return t
			end,
		}
	end
end

for k: string, f in Writer :: any do
	if not k:find("write") then
		continue
	end
	local name = k:gsub("write", ""):lower()
	local str = NameLookUp[name]
	if not str then
		continue
	end
	iWriter[str] = f
end
for k: string, f in Reader :: any do
	if not k:find("read") then
		continue
	end
	local name = k:gsub("read", ""):lower()
	local str = NameLookUp[name]
	if not str then
		continue
	end
	iReader[str] = f
end

table.freeze(Writer)
table.freeze(Reader)

Serializer.writer = Writer
Serializer.reader = Reader

local function example()
    do
        print("------Basic Example------")
        local writer = Serializer.newWriter(100) -- allocate 100 bytes (newWriter and newReader makes a copy of Writer/Reader with table.clone)
        writer:writeu8(255)
        writer:writeu16(65535)
        writer:writeu24(16777215)
        writer:writeString("hello world")
        writer:tryRealloc(101) -- manually reallocating buffer
        writer:writeOption(Serializer.types.f64,1.234) -- same as a number
        writer:writeAny("this is a string") -- uses 1 extra byte, currently allowed types: number|string|buffer|Vector3|Vector2|CFrame|nil|boolean
        Serializer.writer.writeBool(writer,true) -- directly using the writer
    
        local buf = writer:toBuffer() -- convert to buffer
        local reader = Serializer.newReader(buf) -- create reader from buffer
    
        print(reader:readu8()) -- 255
        print(reader:readu16()) -- 65535
        print(reader:readu24()) -- 16777215
        print(reader:readString()) -- hello world
        print(reader:readOption(Serializer.types.f64)) -- 255
        print(reader:readAny()) -- this is a string
        print(Serializer.reader.readBool(reader)) -- directly using the reader | true
    end

    --attaching things
    do
        print("------Attaching Example------")
        local ser = Serializer.new()
        local writer = Serializer.attachWriter(ser) -- metatable based 
        writer:writeu8(255)
        writer:writeu16(65535)
        
        ser.cursor = 0
        local reader = Serializer.attachReader(ser) -- metatable based 
        print(reader:readu8()) -- 255
        print(reader:readu16()) -- 65535
    end
    --Reusing
    do
        print("------Reusing Example------")
        local writer = Serializer.newWriter(0)
        print(writer.buffer) 
        writer:saveLocation() -- saves the location at the current cursor and the current buffer
        writer:writeString("hello")
        print(writer.buffer) -- serializer was resized so different buffer
        local buf = writer:toBuffer()
        print(buffer.readstring(buf, 0,6)) -- hello
        writer:reuse() -- goes back to the saved location and the original buffer
        print(writer.buffer) -- original buffer
        writer:writeString("world")
        local buf2 = writer:toBuffer()
        print(buffer.readstring(buf2, 0,6)) -- world
    
        local b = buffer.create(10)
        buffer.writestring(b,0,"example")
        buffer.writestring(b,5,"test")
        local ser = Serializer.new(b)
        ser.cursor = 9
        writer:reuse(ser) -- moves the buffer and cursor from ser to writer
        writer:writeu8(1)

        local buf3 = writer:toBuffer()
        print(buffer.readstring(buf3, 0,7)) -- example
        print(buffer.readstring(buf3, 5,4)) -- test
        print(buffer.readu8(buf3, 9)) -- 1
    end

    --//writing collections
    --// You could write your own following the format starting at line: 734
    --[[
        they just need to return a table with a writer and reader function
        {
            writer = function(s:serializer,...any)
                --//write to buffer
            end,
            reader = function(s:serializer,...any): any
                --//read from buffer
            end    
        }
    ]]
    do
        --//array
        print("------Array Example------")
        local arraySchema = Serializer.arraySchema(Serializer.types.u8) -- array of u8
        local writer = Serializer.newWriter()
        writer:writeOption(arraySchema,{1,2,3,4,5})
        --or arraySchema.writer(writer,{1,2,3,4,5})
        local buf = writer:toBuffer()
        local reader = Serializer.newReader(buf)
        local array = reader:readOption(arraySchema)
        --or arraySchema.reader(reader)
        print(table.concat(array,",")) -- 1,2,3,4,5
    end

    do 
        --//map
        print("------Map Example------")
        local mapSchema = Serializer.mapSchema(Serializer.types.string,Serializer.types.f64) -- key string with f64 values
        local writer = Serializer.newWriter()
        writer:writeOption(mapSchema,{["hello"] = 1.234,["world"] = 5.678})
        
        local buf = writer:toBuffer()
        local reader = Serializer.newReader(buf)
        local map = reader:readOption(mapSchema)
        for k,v in pairs(map) do
            print(k,'=',v)
        end
    end

    do
        --//struct
        print("------Struct Example------")
        local structSchema = Serializer.structSchema({
            x = Serializer.types.f64,
            y = Serializer.types.f64,
            z = Serializer.types.f64,
            name = Serializer.types.string
        })
        local writer = Serializer.newWriter()
        writer:writeOption(structSchema,{x = 1,y = 2,z = 3,name = "hello"})
        local buf = writer:toBuffer()
        local reader = Serializer.newReader(buf)
        local struct = reader:readOption(structSchema)
        for k,v in pairs(struct) do
            print(k,'=',v)
        end -- x=1,y=2,z=3,name=hello
    end

    do
        --//optional
        print("------Optional Example------")
        local optionalSchema = Serializer.optional(Serializer.types.f64)
        local writer = Serializer.newWriter()
        writer:writeOption(optionalSchema,1.234)
        writer:writeOption(optionalSchema,nil)
        local buf = writer:toBuffer()
        local reader = Serializer.newReader(buf)
        print(reader:readOption(optionalSchema)) -- 1.234
        print(reader:readOption(optionalSchema)) -- nil
    end

    do
        print("------Optional Struct Example------")
        local optionalStructSchema = Serializer.optionalStructSchema({
            x = Serializer.types.f64,
            y = Serializer.types.f64,
            z = Serializer.types.f64,
            name = Serializer.types.string
        })
        local writer = Serializer.newWriter()
        writer:writeOption(optionalStructSchema,{x = 1,y = 2,z = 3,name = "hello"})
        writer:writeOption(optionalStructSchema,{x = 1,y = 2,z = 3})
        local buf = writer:toBuffer()
        local reader = Serializer.newReader(buf)
        local struct = reader:readOption(optionalStructSchema)
        for k,v in pairs(struct) do
            print(k,'=',v)
        end -- x=1,y=2,z=3,name=hello
        print("------")
        local struct = reader:readOption(optionalStructSchema)
        for k,v in pairs(struct) do
            print(k,'=',v)
        end -- x=1,y=2,z=3,name=nil
    end

    do
        print("------Argument Example------")
        --//argumentSchema are useful for function arguments as they can be the given type or nil (saves memory) (has a max of 32 arguments)
        local argSchema = Serializer.argumentSchema(Serializer.types.u8,Serializer.types.u16,Serializer.types.f64)
        do
            local writer = Serializer.newWriter()
            local args1 = {1,3,3.14}
            writer:writeOption(argSchema,unpack(args1))
            local buf = writer:toBuffer()
            print("bytes: ",buffer.len(buf)) -- 12
            local reader = Serializer.newReader(buf)
            local args = reader:readOption(argSchema)
            table.foreach(args, print) -- 1,3,3.14
        end
        do
            -- if we were not to send the last argument
            local writer = Serializer.newWriter()
            local args1 = {1,3,nil}
            writer:writeOption(argSchema,unpack(args1))
            local buf = writer:toBuffer()
            print("bytes: ",buffer.len(buf)) -- 4 (save 8 bytes because were not sending a f64)
            local reader = Serializer.newReader(buf)
            local args = reader:readOption(argSchema)
            table.foreach(args, print) -- 1,3
        end
    end

    
end

example()

return table.freeze(Serializer)
