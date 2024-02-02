local Debris = {}
Debris.__index = Debris

local TIME_KEY = {"__time__"}
local NAME_KEY = {"__name__"}
local DESTROY_KEY = {"__destroy__"}

local Folders = {}

local function remove(self,Key)
    local obj = self[Key]
    if not obj then return end
    if obj[3] then
        obj[2] = task.delay(self[TIME_KEY],remove,self,Key)
        obj[3] = false
        return
    end
    local func = self[DESTROY_KEY]
    if func then 
        func(Key,obj[1])
    end
    self[Key] = nil
end

function Debris:set(Key,value)
    local sub = table.create(3)
    sub[1] = value
    sub[2] = task.delay(self[TIME_KEY], remove,self,Key)
    local last
    if self[Key] then
        last = self:remove(Key)
    end
    self[Key] = sub
    return last
end

function Debris:remove(Key)
    local object = self[Key]
    if not object then return end 
    local t = object[2]
    if t then
        task.cancel(t)
    end
    object[3] = false 
    local func = self[DESTROY_KEY]
    if func then 
        func(Key,object[1])
    end
    self[Key] = nil
    return object[1]
end

function Debris:clearAll()
    local time = self[TIME_KEY]
    local name = self[NAME_KEY]
    local callback = self[DESTROY_KEY]
    table.clear(self)
    self[TIME_KEY] = time
    self[NAME_KEY] = name
    self[DESTROY_KEY] = callback
end

function Debris:getSize()
    local count = -2
    for i,v in self do
        if i == DESTROY_KEY then continue end 
        count +=1
    end
    return count
end

function Debris:has(Key)
   return if self[Key] then true else false 
end

function Debris:get(Key)
    local a = self[Key]
    if not a then return end 
    a[3] = true
    return a[1]
end

function Debris:rawGet(Key)
    local a = self[Key]
    if not a then return end 
    return  a[1]
end

function Debris:getName()
    return self[NAME_KEY]
end

function Debris.getFolder(Name:string,MaxTime:number,Destroy:()->())
    assert(Name, "[Debris]: Name is missing or nil")
    if Folders[Name] then
        return Folders[Name]
    end
    local object = setmetatable({[TIME_KEY] = MaxTime or 60,[NAME_KEY] = Name, [DESTROY_KEY] = Destroy}, Debris)
    Folders[Name] = object
    return object
end

  
return Debris