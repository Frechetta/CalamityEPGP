local Util = {
    addonName = 'Addon'
}

function Util:loadModule(name, ns)
    local modulePath = string.format('CalamityEPGP/%s.lua', name)
    return loadfile(modulePath)(self.addonName, ns)
end

local Mock = {}

function Mock:new(newFunc)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.calls = {}

    if newFunc == nil then
        newFunc = function() end
    end

    o.func = newFunc

    return o
end

function Mock:__call(...)
    table.insert(self.calls, {...})
    return self.func(...)
end

function Util.patch(newFunc)
    return Mock:new(newFunc)
end

return Util
