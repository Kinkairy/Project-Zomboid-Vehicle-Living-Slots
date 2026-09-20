-- Mirrors B42.20 NetTimedAction.set/parse: constructor parameter names select
-- same-name action fields, then the server calls new() in that parameter order.
-- Character/vehicle references stand in for engine object resolution here.
return function(class, sourcePath, action)
    local file = assert(io.open(sourcePath))
    local source = file:read("*a"); file:close()
    local params = assert(source:match("function%s+"..(class.Type or "[%w_]+")..":new%(([^)]*)%)"))
    local args, count = {}, 0
    for name in params:gmatch("[%w_]+") do
        count = count + 1
        args[count] = rawget(action, name)
    end
    return class:new(unpack(args, 1, count))
end
