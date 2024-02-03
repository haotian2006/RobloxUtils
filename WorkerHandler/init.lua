local WorkerManager = {}
local Worker = {}
WorkerManager.__index = WorkerManager

local Runservice = game:GetService("RunService")
 
local DeafaultActor =  if Runservice:IsServer() then script.ActorServer else script.ActorClient
local DeafaultWorkers = 10

local workersFolder = Instance.new("Folder") 
workersFolder.Name = "Workers"
workersFolder.Parent = if Runservice:IsServer() then game:GetService("ServerScriptService") else game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")

function Worker.new(index,actor)
    local clone = (actor or DeafaultActor):Clone()
    clone.Name = index
    clone.Parent = workersFolder
    clone.Main.Enabled = true 
    return clone
end

function WorkerManager:GetNextWorker()
    local Workers = self.Workers
    if #Workers == 0 then error("WORKER TABLE IS EMPTY") end 
    self.WorkerIndex +=1
    local Index = self.WorkerIndex
    if Workers[Index] then
        return Workers[Index],Index
    else
        self.WorkerIndex = 0
        return self:GetNextWorker()
    end
end

local MAXID = 2^31-1 --Increase this if you want
function WorkerManager:GetId()
    self.id += 1
    local id = self.id
    if self.threads[id] ~= nil then 
        return self:GetId()
    elseif id >= MAXID then
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

  --[[
Name is the name of this worker folder
amt is how many actors to create
toRequire is the task module script to require
actor is optional, you can use a custom actor but just make sure to follow the format in ActorServer/Client script (same name and BindToMessages)
rest of the params are info being sent to BindToMessage("Init",...) in the actor
 ]]
function WorkerManager.create(name,amt,toRequire,actor,...)
    local Bindable = Instance.new("BindableEvent")
    Bindable.Name = name
    Bindable.Parent = script
    local self = setmetatable({id =0,WorkerIndex=0,threads = {},Workers = {}},WorkerManager)
    Bindable.Event:connect(function(id,...)
        coroutine.resume(self.threads[id],...)
   end)
   for i =1,amt or DeafaultWorkers do
        local worker = Worker.new(i,actor)
        table.insert(self.Workers,worker)
        worker:SendMessage("Init",Bindable,toRequire,...)
   end
   return self
end
return WorkerManager
