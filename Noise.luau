--!native
--!optimize 2

local Noise = {}
local BasicNoise = {}

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
 
function BasicNoise.new(seed,salt)
    if salt then
        seed = jenkins_hash(`{seed}_{salt}`)
    end
    local RandomObject = Random.new(seed)
    return Vector3.new(RandomObject:NextNumber(-10000,10000),RandomObject:NextNumber(-10000,10000),RandomObject:NextNumber(-10000,10000))
end

local function basic_sample(self:Vector3,x,y,z)
   return math.noise(x+self.X,y+self.Y,z+self.Z)
end

Noise.newBasic = BasicNoise.new
Noise.basicSample = basic_sample

export type Noise = {
    
}

function Noise.new(seed,firstOctave,amplitudes,persistance,lacunarity,salt)
    local inputFactor = 2^firstOctave
    local valueFactor = 2^ (#amplitudes - 1) / ((2^ #amplitudes) - 1)
    local self = {amplitudes,inputFactor,valueFactor,table.create(#amplitudes,false),persistance or .5,lacunarity or 2}
    for i = 1, #amplitudes do
        if amplitudes[i] == 0.0 then 
            self[4][i] = false
            continue 
        end 
        local octave = firstOctave + i 
        self[4][i] = BasicNoise.new(jenkins_hash(`Octave_{octave}_{seed}`),salt)
    end
    return self
end

function Noise.parse(seed,setting)
    if setting.type == "basic" then
        return {true,BasicNoise.new(seed)}
    end
    return Noise.new(seed, setting.firstOctave, setting.amplitudes, setting.persistance, setting.lacunarity,setting.salt)
end

function Noise.sample(self,x,y,z)
    if self[1] == true then
        return basic_sample(self, x, y, z)
    end
    local inputFactor = self[2]
    local valueFactor = self[3]
    local value = 0
    local persistance = self[5]
    local lacunarity  = self[6]
    x,y,z = x or 0, y or 0, z or 0
    for i,basicNoise in self[4] do
        if basicNoise then 
            local amplitude = self[1][i] or 1
            value += amplitude*valueFactor*basic_sample(basicNoise, x*inputFactor, y*inputFactor, z*inputFactor)
        end 
        valueFactor*=persistance
        inputFactor*=lacunarity
    end

    return value
end

--[[Example
local settings = {
    firstOctave = 4,
    amplitudes = {0.5,0.25,0.125,0.0625},
}

local noise = Noise.parse(1234, settings)

local value = Noise.sample(noise, 1, 2, 3)
print(value)
]]


return table.freeze(Noise)