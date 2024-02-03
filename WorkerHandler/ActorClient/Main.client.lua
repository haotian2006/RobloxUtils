local Actor:Actor = script.Parent
local DataHandler:BindableEvent
local Tasks
Actor:BindToMessage("Init", function(bindable,tasks)
    DataHandler = bindable
    Tasks = require(tasks)
end)
Actor:BindToMessage("Runb", function(task,...)
    Tasks[task](...)
end)
Actor:BindToMessageParallel("M", function(Idx,task,...)
    local func = Tasks[task]
    if not func then warn(`{task} is not a valid task`) end 
    DataHandler:Fire(Idx,func(...))
end)
