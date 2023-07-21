local Util = {
    addonName = 'Addon'
}

function Util:loadModule(name, ns)
    local modulePath = string.format('CalamityEPGP/%s.lua', name)
    return loadfile(modulePath)(self.addonName, ns)
end

return Util
