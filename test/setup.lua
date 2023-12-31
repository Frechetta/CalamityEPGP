local spy, stub, mock = ...

Util = require('test.util')
Json = require('test.json')
Libc = require('test.libc')

-- MOCK --
SlashCmdList = {}
NUM_CHAT_WINDOWS = 0

LibStub = function(_, _)
    local Lib = {}

    function Lib:NewAddon(...)
        local addon = mock({
            Print = spy.new(function(_) end),
            Serialize = spy.new(function(_, data) return Json.encode(data) end),
            Deserialize = spy.new(function(_, data) return true, Json.decode(data) end),
            libc = Libc,
            libcEncodeTable = mock({
                Encode = spy.new(function(_, data) return data end),
                Decode = spy.new(function(_, data) return data end),
            }),
        })

        addon.libc.CompressHuffman = spy.new(function(_, data) return data end)
        addon.libc.Decompress = spy.new(function(_, data) return data end)

        return addon
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

GetPlayerInfoByGUID = function(guid)
    return nil, 'WARRIOR', nil, nil, nil, guid, nil
end
