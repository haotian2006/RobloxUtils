BitArray is an array with random access that utilizes a buffer to store integers efficiently. BitArray can store unsigned integers between the size of [1,32] and can be useful when you are trying to save memory and you know the entry size. The BitArray works by using uint32s and bitwise magic to find the index and store values. Using uint32 to store data means that even if the length is 1 the buffer part will take up 4 Bytes. Also, FYI BitArray starts at index 0.

# Documentation
### new(bitsPerEntry : `number`,length : `number`,defaultBuf : `buffer?`): `BitArray`

Creates a new BitArray with the given entry size and length. If `defaultBuf` is present it would use the buffer provided rather than creating a new buffer.

### get(b : `BitArray`,index: `number`): `number`

Returns the value at the given index

### set(b : `BitArray`,index : `number`,value : `number`)

Sets the value at the given index

### getAndSet(b : `BitArray`,index : `number`, value : `number`): `number`

Sets the value and returns the old value at the given index

### copy(b: `BitArray`): `BitArray`

Returns a copy of the BitArray

###  copyAndResize(b : `BitArray`,newEntrySize : `number`): `BitArray`

Returns a copy of the BitArray with each entry having the size of the new Size

### reallocate(b : `BitArray`, newLength : `number`): `BitArray`

Changes the length of the BitArray

### toBuffer(b:  `BitArray`,bufferSize : `("8"|"16"|"32")?`): `Buffer`

Converts the BitArray to a buffer. `bufferSize` determines if the BitArray uses `buffer.writeu8`,  `buffer.writeu16` or  `buffer.writeu32` for each entry, If nothing is given then use `buffer.writeu32`. If `bufferSize` is too small for the entry size then an error would be thrown.

### forEach(b : `BitArray`,callback : `(index: number,value: number) -> ()`)

Iterates the BitArray, invoking the callback for each entry

### size(b : `BitArray`): `number`

Returns how many bytes the BitArray takes

### len(b : `BitArray`): `number`

Returns the length of the BitArray

### serialize(b : `BitArray`,buf : `buffer`,cursor : `number?`): `number`

Writes the BitArray to a `buffer` at the given cursor or 0 if not given. Returns the new cursor location.

### serializeSize(b : `BitArray`): `number`

Returns how many bytes the `BitArray` would take up when writing to a `buffer`

### deserialize(buf : `buffer`,cursor : `number`): (`number`,`BitArray`)

Creates a BitArray from the given `buffer` at the given cursor or 0 if not provided. Returns the new cursor location and the BitArray

# Example

If we want to create a BitArray with the entry size of 2 bits [0,3] and a length of 4 we can do it like this.
```lua
local array = BitArray.new(2,4)
```

To set a value or get a value we can do it like this.

```lua
BitArray.set(array,0,3)
BitArray.set(array,1,2)
BitArray.set(array,2,1)
BitArray.set(array,3,1)

print(BitArray.getAndSet(array,0,1)) --> 3
print(BitArray.get(array,0)) --> 1
print(BitArray.get(array,1)) --> 2 
```

If we wanted to increase the length to 5 we can use the `reallocate` function.

```lua
BitArray.reallocate(array,5)

print(BitArray.len(array)) --> 5
print(BitArray.size(array)) --> 4 bytes
BitArray.set(array,4,3)
print(BitArray.get(array,4)) --> 3 
```

If we wanted to change the entry size from 2 bits [0,3] to 4 bits [0,15] we can use `copyAndResize`. 

```lua
local newArray = BitArray.copyAndResize(array,4)

print(BitArray.get(newArray,0)) --> 1
BitArray.set(newArray,1,15)
print(BitArray.get(newArray,1)) --> 15
```

And to iterate over the BitArray we can use the `forEach` function.

```lua
BitArray.forEach(newArray,function(i,v)
    print(i,v)
end)
--[[
0 1
1 15
2 1
3 1 
4 3
]]
```

For Basic serialization and deserialization, we can do it like this.

```lua
local tempBuffer = buffer.create(1000)

local cursor = BitArray.serialize(array,tempBuffer,0)
cursor = BitArray.serialize(newArray,tempBuffer,cursor)

--deserialize
local cursor = 0
local newCursor,arr1 = BitArray.deserialize(tempBuffer,cursor)
local newCursor,arr2 = BitArray.deserialize(tempBuffer,newCursor)

print(BitArray.get(arr1,1)) --> 2
print(BitArray.get(arr2,1)) --> 15
```

Full Script
```
local BitArray = require(Path.To.Module)

local array = BitArray.new(2,4)
BitArray.set(array,0,3)
BitArray.set(array,1,2)
BitArray.set(array,2,1)
BitArray.set(array,3,1)

print(BitArray.getAndSet(array,0,1)) --> 3
print(BitArray.get(array,0)) --> 1
print(BitArray.get(array,1)) --> 2 

BitArray.reallocate(array,5)

print(BitArray.len(array)) --> 5
print(BitArray.size(array)) --> 4 bytes
BitArray.set(array,4,3)
print(BitArray.get(array,4)) --> 3

local newArray = BitArray.copyAndResize(array,4)
print(BitArray.get(newArray,0)) --> 1

BitArray.set(newArray,1,15)
print(BitArray.get(newArray,1)) --> 15

BitArray.forEach(newArray,function(i,v)
    print(i,v)
end)

--[[
0 1
1 15
2 1
3 1 
4 3
]]

local tempBuffer = buffer.create(1000)

local cursor = BitArray.serialize(array,tempBuffer,0)
cursor = BitArray.serialize(newArray,tempBuffer,cursor)

--deserialize
local cursor = 0
local newCursor,arr1 = BitArray.deserialize(tempBuffer,cursor)
local newCursor,arr2 = BitArray.deserialize(tempBuffer,newCursor)

print(BitArray.get(arr1,1)) --> 2
print(BitArray.get(arr2,1)) --> 15
```

