local Util = {
    addonName = 'Addon'
}

function Util:loadModule(name, ns)
    local modulePath = string.format('CalamityEPGP/%s.lua', name)
    return loadfile(modulePath)(self.addonName, ns)
end

local Mock = {}

function Mock:new(newFunc, ignoreFirstArg)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.called = false
    o.callNum = 0
    o.calls = {}

    if newFunc == nil then
        newFunc = function() end
    end

    if ignoreFirstArg == nil then
        ignoreFirstArg = false
    end

    o._func = newFunc
    o._ignoreFirstArg = ignoreFirstArg

    return o
end

function Mock:__call(...)
    self.called = true
    self.callNum = self.callNum + 1

    local rawArgs = {...}
    local args = {}
    if self._ignoreFirstArg then
        for i = 2, #rawArgs do
            local arg = rawArgs[i]
            table.insert(args, arg)
        end
    else
        args = rawArgs
    end

    table.insert(self.calls, args)

    return self._func(...)
end

function Util.patch(newFunc, ignoreFirstArg)
    return Mock:new(newFunc, ignoreFirstArg)
end

return Util
