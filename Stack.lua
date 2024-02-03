--A fast Stack implementation in lua using tables 

local Stack = {}

function Stack.new(size)
    return table.create(size)
end

function Stack.push(self,value)
    self[#self+1] = value
end

function Stack.pop(self)
    local value = self[#self]
    self[#self] = nil
    return value
end

return Stack