local spy, stub, mock = ...

Util = require('test.util')
Json = require('test.json')

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
    return 123
end

UnitName = function(unit)
    if unit == 'player' then
        return 'p1'
    end

    error('unknown unit "' .. unit .. '"')
end

UnitGUID = function(unit)
    if unit == 'player' then
        local name = UnitName(unit)
        return name .. '_guid'
    end

    error('unknown unit "' .. unit .. '"')
end

C_Timer = mock({
    After = function(_, func)
        func()
    end
})

RANDOM_ROLL_RESULT = '%s rolls %d (%d-%d)'
