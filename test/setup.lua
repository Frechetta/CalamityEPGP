local spy, stub, mock = ...

Util = require('test.util')

-- MOCK --
SlashCmdList = {}
NUM_CHAT_WINDOWS = 0

LibStub = function(_, _)
    local Lib = {}
    function Lib:NewAddon(...)
        return mock({
            Print = spy.new(function(_) end)
        })
    end
    return Lib
end

tinsert = table.insert

time = function()
    return 1
end

UnitGUID = function(_)
    return '0'
end

C_Timer = {}
function C_Timer.After(_, func)
    func()
end
