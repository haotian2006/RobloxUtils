# Debris
A efficient caching Library

## Functions

#### getFolder(Name:`string`,MaxTime:`number`,Destroy:`(any)->()`): `Constructor`
Returns the folder with the name or creates a new folder with the attached params.

`Name`: Name of the folder
`MaxTime`: How long should the object should stay cached. Default 60s.
`Destroy`: a callback fired when the object is being destroyed/removed

## Methods
#### getName(): `string`
Gets the name of the folder 

#### getSize(): `number`
Returns how many objects are in the folder. Warning this method is O(n).

#### clearAll()
Clears and remove all the objects in the object.

#### has(key:`any`) `boolean`
Returns the if the key exists in the Folder 


#### get(key:`any`): `any`
Returns the object stored in key and refresh the destroy time. 

#### rawGet(key:`any`) `any`
Returns the object stored in the key and does NOT refresh the destroy time.

#### set(key:`any`,value:`any`): `any` | `nil`
Adds the object to the folder. If the key already exists override it and returns the last value, else return nil. 

#### remove(key:`any`)
Removes the folder

## Example
```lua
local Debris = require(path.to.debris)

local function onDestroy(key,child)
    print(key,"Was Removed. Data:",child)
end

local myFolder = Debris.getFolder(
    "MyFolder", -- name of Folder
    2, --each object stays for 2 seconds 
    onDestroy
    )
--the Key can be any non nil type
myFolder:set("key1",1)
myFolder:set("key2",2)
myFolder:set(Vector3.new(3,3,3),3) -- Vector3s are a native types 

task.wait(1)

print(myFolder:get("key1")) --> 1
print(myFolder:rawGet(Vector3.new(3,3,3))) --> 3

task.wait(1.5)
-- By here the vector3 and key2 should be removed. key1 hasn't been because it has be gotten 1.5 seconds ago. 
print(myFolder:has("key1")) --> true
print(myFolder:has("key2")) --> false
print(myFolder:has(Vector3.new(3,3,3))) --> false

--[[
---OUTPUT---
    1
    3
    key2 Was Removed. Data: 2
    3,3,3 Was Removed. Data: 3
    true
    false
    false
    key1 Was Removed. Data: 1
]]

```

