LU = require('luaunit')
Util = require('test.util')

-- MOCK --
SlashCmdList = {}
NUM_CHAT_WINDOWS = 0

local Addon = {}
function Addon:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.printed = {}

    return o
end

function Addon:Print(msg)
    table.insert(self.printed, msg)
end

LibStub = function(_)
    local Lib = {}
    function Lib:NewAddon(...)
        return Addon:new()
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

require('test.test-main')

os.exit(LU.LuaUnit.run())
