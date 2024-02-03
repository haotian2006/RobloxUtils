-- A Random Wrapper
local RandomLib = {}
RandomLib.__index = RandomLib

--A simple hashing alg
local function jenkins_hash(key)
    local hash = 0
    for i = 1, #key do
        hash = hash + string.byte(key, i)
        hash = hash + bit32.lshift(hash, 10)
        hash = bit32.bxor(hash, bit32.rshift(hash, 6))
    end
    hash = hash + bit32.lshift(hash, 3)
    hash = bit32.bxor(hash, bit32.rshift(hash, 11))
    hash = hash + bit32.lshift(hash, 15)
    return hash
end

function RandomLib.new(seed,obj)
    local self = setmetatable({}, RandomLib)
    self.random = obj or Random.new(seed)
    self.seed = seed
    return table.freeze(self)
end

function RandomLib:GetRandom()
    return self.random
end

function RandomLib:GetSeed()
    return self.seed
end

function RandomLib:NextNumber(...)
    return self.random:NextNumber(...)
end

function RandomLib:NextInteger(...)
    return self.random:NextInteger(...)
end

--Moves x steps 
function RandomLib:Consume(x)
    local new = self:Fork()
    for i = 1,x do
        new:NextNumber()
    end
    return new
end

--Clones a random but is on the same step
function RandomLib:Clone()
    local rc = self.random:Clone()
    return RandomLib.new(self.seed,rc)
end

--Clones a new random with step at 0
function RandomLib:Fork()
    return RandomLib.new(self.seed)
end

--Creates a new Random with the seed of the current and a string
function RandomLib:FromHash(hash:string)
    return RandomLib.new(jenkins_hash(`{hash or ""}_{self.seed}`))
end

return RandomLib