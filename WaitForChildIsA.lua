--A custom waitforchild fundction that also checks if its the wanted type
--made for fun because someone wanted it.

local function WaitForChildIsA(instance:Instance,Name:string,Type:string,MaxTime:number?):Instance?
    local running = coroutine.running()
    for _,part in instance:GetChildren() do
        if part.Name ~= Name or not part:IsA(Type) then continue end 
        return part
    end
    local delayT
    local Child
    local thread = task.spawn(function()
        repeat
            Child = instance.ChildAdded:Wait()
        until Child.Name == Name and Child:IsA(Type)
         task.cancel(delayT)
        coroutine.resume(running,Child)
    end)
    if Child then return Child end 
    delayT = task.delay(MaxTime or 1,function()
         task.cancel(thread)
         warn(`Infinite yield possible on WaitForChildIsA({tostring(instance)},{Name},{Type})`) --Comment/Uncomment if you want warnings
        coroutine.resume(running,nil)
    end)
    return coroutine.yield()
end

return WaitForChildIsA