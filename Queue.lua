--A fast queue implementation in lua using tables 
local Queue = {}

function Queue.new(preAllocated)
    local self = table.create(preAllocated or 0)
    self.Start = 1
    self.End = 0
    return self
end

function Queue.enqueue(self,value)
    local last = self.End + 1
    self.End = last
    self[last] = value
end

function Queue.dequeue(self)
    local first = self.Start
    if first > self.End then
        return nil
    end
    local value =self[first]
    self[first] = nil
    self.Start = first + 1
    return value
end

return Queue
