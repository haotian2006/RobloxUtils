local WorkerManager = {}
local Worker = {}
WorkerManager.__index = WorkerManager

local Runservice = game:GetService("RunService")

local DeafultActor =  if Runservice:IsServer() then script.ActorServer else script.ActorClient

local workersFolder = Instance.new("Folder") 
workersFolder.Name = "Workers"
workersFolder.Parent = if Runservice:IsServer() then game:GetService("ServerScriptService") else game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")

function Worker.new(index,actor)
    local clone = (actor or DeafultActor):Clone()
    clone.Name = index
    clone.Parent = workersFolder
    clone.Main.Enabled = true 
    return clone
end

function WorkerManager:GetNextWorker()
    local Workers = self.Workers
    if #Workers == 0 then error("TABLE IS EMPTY") end 
    self.WorkerIndex +=1
    local Index = self.WorkerIndex
    if Workers[Index] then
        return Workers[Index],Index
    else
        self.WorkerIndex = 0
        return self:GetNextWorker()
    end
end

local INT32 = 2^31-1 --Increase this if you want
function WorkerManager:GetId()
    self.id += 1
    local id = self.id
    if self.threads[id] ~= nil then 
        return self:GetId()
    elseif id >= INT32 then
        self.id = 0
        return self:GetId()
    end
    return id 
end

function WorkerManager:RunTaskALl(...)
    for i,actor:Actor in self.Workers do
        actor:SendMessage("Run",...)
    end
end

function WorkerManager:DoWork(taskToDo,...)
    local c = self:GetId()
    local worker:Actor,_ = self:GetNextWorker()
    worker:SendMessage("M",c,taskToDo,...)
    self.threads[c] = coroutine.running() 
    local data =  {coroutine.yield()} 
    self.threads[c] = nil 
    return unpack(data)
end

function WorkerManager.create(name,amt,toRequire,actor,...)
    local Bindable = Instance.new("BindableEvent")
    Bindable.Name = name
    Bindable.Parent = script
    local self = setmetatable({id =0,WorkerIndex=0,threads = {},Workers = {}},WorkerManager)
    Bindable.Event:connect(function(id,...)
        coroutine.resume(self.threads[id],...)
   end)
   for i =1,amt do
        local worker = Worker.new(i,actor)
        table.insert(self.Workers,worker)
        worker:SendMessage("Init",Bindable,toRequire,...)
   end
   return self
end
return WorkerManager