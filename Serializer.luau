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

local function bitsNeeded(x)
    if x == 0 then return 0 end 
    return math.floor(math.log(x,2)+1)
end

--//could use VLQ here but this works
local function writeuIntHelper(len)
    local bits = bitsNeeded(len)
    local header = 0
    local metaLength = 1
    local writer = nil
    if bits < 7 then
        header = len+3
    elseif bits <9 then
        header = 2
        metaLength = 2
        writer = buffer.writeu8
    elseif bits < 17 then
        header = 1
        metaLength = 3
        writer = buffer.writeu16
    else
        header = 0
        metaLength = 9
        writer = buffer.writef64
    end
    return header,metaLength,writer
end

local function readuIntHelper(b,index)
    local header = buffer.readu8(b,index)
    local len 
    index += 1
    if header >2 then
        len = header - 3
    elseif header == 2 then
        len = buffer.readu8(b,index)
        index += 1
    elseif header == 1 then
        len = buffer.readu16(b,index)
        index += 2
    else
        len = buffer.readf64(b,index)
        index += 8
    end  
    return len,index
end

function Serializer.new(input:(number|buffer)?): serializer
    local self = {}
    if type(input) == "number" then
        self.buffer = buffer.create(input)
    else
        self.buffer = input or buffer.create(DEFAULT_SIZE)
    end
    self.cursor = 0
    return self
end

function Serializer.attachWriter(s:serializer): writer
    return setmetatable(s,Writer)::any
end

function Serializer.attachReader(s:serializer): reader
    return setmetatable(s,Reader)::any
end

function Serializer.newWriter(initSize: number?): writer
    local self = table.clone(Writer)
    self.buffer = buffer.create(initSize or DEFAULT_SIZE)
    self.cursor = 0
    return self
end

function Serializer.newReader(buffer: buffer,startCursor: number?): reader
    local self = table.clone(Reader)
    self.buffer = buffer
    self.cursor = startCursor or 0
    return self
end

function Serializer.getByteStr(b)
    local str = ""
    for i = 0,buffer.len(b)-1 do
        str ..= '\\'..buffer.readu8(b,i)
    end
    return str 
end

local function getReaderFrom(option:option): (((s:serializer,...any) -> (any)))?
    local func = iReader[option]
    if not func then
        if type(option) == "table" and option.reader then
            return option.reader
        end
    end
    return func
end

Serializer.getReaderFrom = getReaderFrom

local function getWriterFrom(option:option): (((s:serializer, value:any,...any) -> ()))?
    local func = iWriter[option]
    if not func then
        if type(option) == "table" and option.writer then
            return option.writer
        end
    end
    return func
end

Serializer.getWriterFrom = getWriterFrom

local function writeu24(b:buffer,i:number,v:number)
    buffer.writeu8(b,i,v)
    buffer.writeu16(b,i+1,v//256)
end

Serializer.writeu24 = writeu24

local function writei24(b:buffer,i:number,v:number)
    buffer.writei8(b,i,v)
    buffer.writei16(b,i+1,v//256)
end

Serializer.writei24 = writei24

local function writeuInt(b:buffer,i:number,v:number)
    local header,metaLength,writer = writeuIntHelper(v)
    buffer.writeu8(b,i,header)
    if writer then
        writer(b,i+1,v)
    end
    return metaLength
end

Serializer.writeuInt = writeuInt

do

function Writer.saveLocation(self)
    self._buf = self.buffer
    self._cursor = self.cursor
end

function Writer.reuse(self,ser: serializer?)
    if not ser then
        self.buffer = self._buf
        self.cursor = self._cursor
        return
    end
    self.buffer = ser.buffer    
    self.cursor = ser.cursor
end

function Writer.clear(self:serializer)
    self.cursor = 0
end

function Writer.toBuffer(s: serializer): buffer
    local b = buffer.create(s.cursor)
    bufferCopy(b, 0, s.buffer, 0, s.cursor)
    return b
end

function Writer.writeu8(s: serializer, value: number)
    realloc(s, 1)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 1
    buffer.writeu8(b, p, value)
end

function Writer.writeu16(s: serializer, value: number)
    realloc(s, 2)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 2
    buffer.writeu16(b, p, value)
end

function Writer.writeu24(s: serializer, value: number)
    realloc(s, 3)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 3
    buffer.writeu8(b, p, value)
    buffer.writeu16(b, p + 1, value // 256)
end

function Writer.writeuInt(s: serializer, value: number)
    local header,metaLength,writer = writeuIntHelper(value)
    realloc(s, metaLength)
    local b = s.buffer
    local p = s.cursor
    s.cursor = p + metaLength
    buffer.writeu8(b, p, header)
    if writer then
        writer(b, p+1, value)
    end
end

function Writer.writeu32(s: serializer, value: number)
    realloc(s, 4)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 4
    buffer.writeu32(b, p, value)
end

function Writer.writei8(s: serializer, value: number)
    realloc(s, 1)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 1
    buffer.writei8(b, p, value)
end

function Writer.writei16(s: serializer, value: number)
    realloc(s, 2)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 2
    buffer.writei16(b, p, value)
end

function Writer.writei24(s: serializer, value: number)
    realloc(s, 3)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 3
    buffer.writei8(b, p, value)
    buffer.writei16(b, p + 1, value // 256)
end

function Writer.writei32(s: serializer, value: number)
    realloc(s, 4)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 4
    buffer.writei32(b, p, value)
end

function Writer.writef32(s: serializer, value: number)
    realloc(s, 4)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 4
    buffer.writef32(b, p, value)
end

function Writer.writef64(s: serializer, value: number)
    realloc(s, 8)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 8
    buffer.writef64(b, p, value)
end

function Writer.writeVector3(s: serializer, value: Vector3)
    realloc(s, 12)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 12
    buffer.writef32(b, p, value.X)
    buffer.writef32(b, p + 4, value.Y)
    buffer.writef32(b, p + 8, value.Z)
end

function Writer.writeVector2(s: serializer, value: Vector2)
    realloc(s, 8)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 8
    buffer.writef32(b, p, value.X)
    buffer.writef32(b, p + 4, value.Y)
end

function Writer.writeString(s: serializer, value: string)
    local len = #value
    local header,metaLength,writer = writeuIntHelper(len)

    realloc(s, len + metaLength)
    local b = s.buffer
    local p = s.cursor
    s.cursor = p + len + metaLength
    buffer.writeu8(b, p, header)
    if writer then
        writer(b, p+1, len)
    end
    buffer.writestring(b, p + metaLength, value)
end

function Writer.writeCFrame(s: serializer, value: CFrame)
    local b = s.buffer
    local p = s.cursor
    local pos = value.Position
    local rx,ry,rz = value:ToEulerAnglesXYZ()

    realloc(s, 24)
    s.cursor = p + 24

    buffer.writef32(b, p, pos.X)
    buffer.writef32(b, p + 4, pos.Y)
    buffer.writef32(b, p + 8, pos.Z)
    buffer.writef32(b, p + 12, rx)
    buffer.writef32(b, p + 16, ry)
    buffer.writef32(b, p + 20, rz)
end

function Writer.writeBuffer(s: serializer, value: buffer,start:number?,finish:number?)
    local target = finish or buffer.len(value)
    local init = start or 0
    
    local len = target - init

    local header,metaLength,writer = writeuIntHelper(len)

    realloc(s, len+metaLength)
    local b = s.buffer
    local p = s.cursor
    s.cursor = p + len + metaLength
    buffer.writeu8(b, p, header)
    if writer then
        writer(b, p+1, len)
    end
    bufferCopy(b, p+metaLength , value,init, len)
end

function Writer.writeBufferRaw(s:serializer, value: buffer,start:number?,finish:number?)
    local target = finish or buffer.len(value)
    local init = start or 0
    
    local len = target - init
    realloc(s, len)
    local b = s.buffer
    local p = s.cursor
    s.cursor = p + len
    bufferCopy(b, p, value, init, len)
end

function Writer.writeOption(s: serializer, option: option, value: any,...:any)
    local writer = getWriterFrom(option)
    if not writer then
        error("Invalid option | must be a valid enum or custom type")
    end
    writer(s,value,...)
end

function Writer.writeBool(s: serializer, value: boolean)
    realloc(s, 1)
    local b = s.buffer
    local p = s.cursor 
    s.cursor = p + 1
    buffer.writeu8(b, p, value and 1 or 0)
end

function Writer.writeAny(s: serializer, value: SerializerAny)
    local idx = typeToEnum[typeof(value)]
  
    realloc(s, 1)
    local b = s.buffer
    local p = s.cursor  
    s.cursor = p + 1
    buffer.writeu8(b, p, idx or 255)
    
    local writer = iWriter[idx]
    if writer then
        writer(s, value)
    elseif not idx then
        warn( "Invalid type for writeAny: " .. typeof(value))
    end
end

Writer.tryRealloc = realloc
end

    local function readu8(b:buffer,index:number): (number,number)
        return buffer.readu8(b,index),index+1
    end
    Serializer.readu8 = readu8

    local function readu16(b:buffer,index:number): (number,number)
        return buffer.readu16(b,index),index+2
    end
    Serializer.readu16 = readu16

    local function readu24(b:buffer,index:number): (number,number)
        local low = buffer.readu8(b,index)
        local high = buffer.readu16(b,index+1)
        return low + high*256,index+3
    end

    Serializer.readu24 = readu24
    
    local function readu32(b:buffer,index:number): (number,number)
        return buffer.readu32(b,index),index+4
    end
    Serializer.readu32 = readu32

    local function readuInt(b:buffer,index:number): (number,number)
        local len,newIndex = readuIntHelper(b,index)
        return len,newIndex
    end

    Serializer.readuInt = readuInt

    local function readi8(b:buffer,index:number): (number,number)
        return buffer.readi8(b,index),index+1
    end
    Serializer.readi8 = readi8
    
    local function readi16(b:buffer,index:number): (number,number)
        return buffer.readi16(b,index),index+2
    end
    Serializer.readi16 = readi16

    local function readi24(b:buffer,index:number): (number,number)
        local low = buffer.readi8(b,index)
        local high = buffer.readi16(b,index+1)
        return low + high*256,index+3
    end

    Serializer.readi24 = readi24

    local function readi32(b:buffer,index:number): (number,number)
        return buffer.readi32(b,index),index+4
    end
    Serializer.readi32 = readi32

    local function readf32(b:buffer,index:number): (number,number)
        return buffer.readf32(b,index),index+4
    end
    Serializer.readf32 = readf32

    local function readf64(b:buffer,index:number): (number,number)
        return buffer.readf64(b,index),index+8
    end
    Serializer.readf64 = readf64

    local function readVector3(b:buffer,index:number): (Vector3,number)
        local x = buffer.readf32(b,index)
        local y = buffer.readf32(b,index+4)
        local z = buffer.readf32(b,index+8)
        return Vector3.new(x,y,z),index+12
    end
    Serializer.readVector3 = readVector3

    local function readVector2(b:buffer,index:number): (Vector2,number)
        local x = buffer.readf32(b,index)
        local y = buffer.readf32(b,index+4)
        return Vector2.new(x,y),index+8
    end
    Serializer.readVector2 = readVector2

    local function readString(b:buffer,index:number): (string,number)
        local len,newIndex = readuIntHelper(b,index)

        local str = buffer.readstring(b,newIndex,len)
        return str,newIndex + len
    end
    Serializer.readString = readString

    local function readCFrame(b: buffer, index: number): (CFrame, number)
        local x, y, z = buffer.readf32(b, index), buffer.readf32(b, index + 4), buffer.readf32(b, index + 8)
        local rx, ry, rz = buffer.readf32(b, index + 12), buffer.readf32(b, index + 16), buffer.readf32(b, index + 20)
       
        return CFrame.new(x, y, z) * CFrame.fromEulerAnglesXYZ(rx, ry, rz), index + 24
    end
    Serializer.readCFrame = readCFrame

    local function readBuffer(b: buffer, index: number): (buffer, number)
        local len,newIndex = readuIntHelper(b,index)

        local newBuffer = buffer.create(len)
        bufferCopy(newBuffer, 0, b, newIndex, len)
        return newBuffer, newIndex + len
    end
    Serializer.readBuffer = readBuffer

    local function readBool(b: buffer, index: number): (boolean, number)
        return buffer.readu8(b, index) == 1, index + 1
    end
    Serializer.readBuffer = readBuffer

------------------------------------------------------------------------------------------
do
    function Reader.saveLocation(self)
        self._buf = self.buffer
        self._cursor = self.cursor
    end

    function Reader.reuse(self,ser: serializer?)
        if not ser then
            self.buffer = self._buf
            self.cursor = self._cursor
            return
        end
        self.buffer = ser.buffer    
        self.cursor = ser.cursor
    end


    function Reader.readu8(s: serializer): number
        local value,index = readu8(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readu16(s: serializer): number
        local value,index = readu16(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readu24(s: serializer): number
        local value,index = readu24(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readu32(s: serializer): number
        local value,index = readu32(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readuInt(s: serializer): number
        local value,index = readuInt(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readi8(s: serializer): number
        local value,index = readi8(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readi16(s: serializer): number
        local value,index = readi16(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readi24(s: serializer): number
        local value,index = readi24(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readi32(s: serializer): number
        local value,index = readi32(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readf32(s: serializer): number
        local value,index = readf32(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readf64(s: serializer): number
        local value,index = readf64(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readVector3(s: serializer): Vector3
        local value,index = readVector3(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readVector2(s: serializer): Vector2
        local value,index = readVector2(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readString(s: serializer): string
        local value,index = readString(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readCFrame(s: serializer): CFrame
        local value,index = readCFrame(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readOption(s: serializer,option: option,...:any): any
        local reader = getReaderFrom(option)
        if not reader then
            error("Invalid option | must be a valid enum or custom type")
        end
        return reader(s,...)
    end


    function Reader.readBuffer(s: serializer): buffer
        local value,index = readBuffer(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readBool(s: serializer): boolean
        local value,index = readBool(s.buffer,s.cursor)
        s.cursor = index
        return value
    end

    function Reader.readAny(s: serializer): SerializerAny
        local idx,cursor = readu8(s.buffer,s.cursor)
        s.cursor = cursor
        local reader = iReader[idx]
        if reader then
            return reader(s)
        end
        return nil
    end

end

local serWriteu24 = Writer.writeu24
local serWriteuInt = Writer.writeuInt
local serReadu24 = Reader.readu24
local serReaduInt = Reader.readuInt

do
    --//Custom Schema
    function Serializer.mapSchema(keyType:option,value:option)
        local writer = getWriterFrom(keyType)
        local reader = getReaderFrom(keyType)
        local valueWriter = getWriterFrom(value)
        local valueReader = getReaderFrom(value)
        if not writer or not reader or not valueWriter or not valueReader then
            error("Invalid key or value type")
        end
        return {
            writer = function(s:serializer,t:{})
                local size = 0
                local start = s.cursor
                realloc(s,3)
                s.cursor+=3
                for i,v in t do
                    writer(s,i)
                    valueWriter(s,v)
                    size += 1
                end
                writeu24(s.buffer,start,size)
            end,
            reader = function(s:serializer): {}
                local size = readu24(s.buffer,s.cursor)
                s.cursor += 3
                local t = {}
                for i = 1,size do
                    local key = reader(s)
                    local value = valueReader(s)
                    t[key] = value
                end
                return t
            end
        }
    end

    function Serializer.arraySchema(valueType: option)
        local valueWriter = getWriterFrom(valueType)
        local valueReader = getReaderFrom(valueType)
        if not valueWriter or not valueReader then
            error("Invalid value type")
        end
        return {
            writer = function(s:serializer,t:{})
                local size = #t
                serWriteuInt(s, size)
                for i = 1,size do
                    valueWriter(s,t[i])
                end
            end,
            reader = function(s:serializer,writeTo:{}?)
                local size = serReaduInt(s)
                local t = writeTo or table.create(size)
                for i = 1,size do
                    t[i] = valueReader(s)
                end
                return t
            end
        }
    end

    function Serializer.structSchema(struct:{[string]:option})
        local writers = {}
        local readers = {}

        for key, option:option in struct do
            local writer = getWriterFrom(option)
            local reader = getReaderFrom(option)
            if not writer or not reader then
                error("Invalid field type for key: " .. key)
            end
            writers[key] = writer
            readers[key] = reader
        end

        return {
            writer = function(s: serializer, t: { [string]: any })
               for str, writer in writers do
                    writer(s, t[str])
                end
            end,
            reader = function(s: serializer,writeTo:{}?): { [string]: any }
                local t = writeTo or {}
                for str, reader in readers do
                    t[str] = reader(s)
                end
                return t
            end
        }
    end

    local lshift_lookup = {}
    for i = 1, 32 do
        lshift_lookup[i] = bit32.lshift(1,i-1)
    end
    
    function Serializer.argumentSchema(...: option)
        local writers = {}
        local readers = {}

        local arr = {...}
        for index, option:option in arr do
            local writer = getWriterFrom(option)
            local reader = getReaderFrom(option)
            if not writer or not reader then
                error("Invalid type for argument: " .. index)
            end
            writers[index] = writer
            readers[index] = reader
        end

        local size = #arr
        assert(size < 33,"Too many arguments")
        local toAllocate = math.ceil(size/8)
        local reader = Reader.readu8
        local writer = buffer.writeu8

        if size >8 and size <17 then
            reader = Reader.readu16
            writer = buffer.writeu16
        elseif size >16 and size <25 then
            reader = Reader.readu24
            writer = writeu24
        elseif size >24 then
            reader = Reader.readu32
            writer = buffer.writeu32
        end

        return {
            writer = function(s: serializer, ...:any)
                local bits = 0
                local start = s.cursor
                realloc(s,toAllocate)
                s.cursor += toAllocate
                for idx, writer in writers do
                    local value = select(idx,...)
                    if value then
                        writer(s, value)
                    else
                        bits += lshift_lookup[idx]
                    end           
                end
                writer(s.buffer, start, bits)
            end,
            reader = function(s: serializer,writeTo:{}?): { [string]: any }
                local t = writeTo or {}
                local bits = reader(s)
                for idx, reader in readers do
                    t[idx] = if bits % 2 == 0 then reader(s) else nil
                    bits //= 2
                end
                return t
            end
        }
    end
end

for k:string,f in Writer::any do
    if not k:find("write") then continue end
    local name = k:gsub("write",""):lower()
    local str = NameLookUp[name]
    if not str then continue end
    iWriter[str] = f
end
for k:string,f in Reader::any do
    if not k:find("read") then continue end
    local name = k:gsub("read",""):lower()
    local str = NameLookUp[name]
    if not str then continue end
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
        local writer = Serializer.newWriter()
        writer:saveLocation() -- saves the location at the current cursor (0)
        writer:writeString("hello")
        local buf = writer:toBuffer()
        print(buffer.readstring(buf, 0,6)) -- hello
        writer:reuse() -- goes back to the saved location (0)
        writer:writeString("world")
        local buf2 = writer:toBuffer()
        print(buffer.readstring(buf2, 0,6)) -- world
    
        local b = buffer.create(10)
        buffer.writestring(b,0,"example")
        buffer.writestring(b,5,"test")
        local ser = Serializer.new(b)
        ser.cursor = 9
        writer:reuse(ser) -- moves the data from ser to writer
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