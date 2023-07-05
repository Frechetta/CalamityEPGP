local _, ns = ...  -- Namespace

local List = {}
ns.List = List

local Dict = {}
ns.Dict = Dict

local Set = {}
ns.Set = Set

---------------
function List:new(items)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._list = {}
    o._len = 0

    items = items or {}
    for _, item in ipairs(items) do
        table.insert(o._list, item)
        o._len = o._len + 1
    end

    return o
end

function List:iter()
    local i = 1
    return function()
        if i <= self._len then
            local item = self:get(i)
            i = i + 1
            return item
        end
    end
end

function List:append(item)
    table.insert(self._list, item)
    self._len = self._len + 1
end

function List:get(index)
    return self._list[index]
end

function List:set(index, value)
    assert(self._list[index] ~= nil, 'no item at index ' .. index)

    self._list[index] = value
end

function List:len()
    return self._len
end

function List:sort(func)
    table.sort(self._list, func)
end

function List:toTable()
    return ns.Lib:deepcopy(self._list)
end


---------------
function Dict:new(table)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._dict = table or {}
    o._keys = Set:new()
    o._values = List:new()
    o._keyToValueIndex = {}

    for k, v in pairs(o._dict) do
        o._keys:add(k)
        o._values:append(v)
        o._keyToValueIndex[k] = #o._values
    end

    return o
end

function Dict:iter()
    local i = 1
    local len = self:len()
    return function()
        if i <= len then
            local key = self._keys:_get(i)
            local value = self:get(key)
            i = i + 1
            return key, value
        end
    end
end

function Dict:get(key)
    return self._dict[key]
end

function Dict:set(key, value)
    self._dict[key] = value
    self._keys:add(key)

    local index = self._keyToValueIndex[key]
    if index ~= nil then
        self._values[index] = value
    else
        self._values:append(value)
        self._keyToValueIndex[key] = #self._values
    end
end

function Dict:len()
    return self._keys:len()
end

function Dict:clear()
    self._dict = {}
    self._keys = {}
    self._values = {}
    self._keyToValueIndex = {}
end

function Dict:keys()
    return self._keys
end

function Dict:values()
    return self._values
end

function Dict:isEmpty()
    return self:len() == 0
end


---------------
function Set:new(items)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._values = {}
    o._set = {}

    items = items or {}
    for _, item in ipairs(items) do
        table.insert(o._values, item)
        o._set[item] = #o._values
    end

    return o
end

function Set:iter()
    local i = 1
    local len = self:len()
    return function()
        if i <= len then
            local item = self:_get(i)
            i = i + 1
            return item
        end
    end
end

function Set:_get(index)
    return self._values[index]
end

function Set:add(item)
    if self._set[item] ~= nil then
        return
    end

    table.insert(self._values, item)
    self._set[item] = #self._values
end

function Set:remove(item)
    local index = self._set[item]
    if index ~= nil then
        self._set[item] = nil
        table.remove(self._values, index)
    end
end

function Set:contains(item)
    return self._set[item] ~= nil
end

function Set:len()
    return #self._values
end

function Set:clear()
    self._values = {}
    self._set = {}
end

function Set:toTable()
    return ns.Lib:deepcopy(self._values)
end

function Set:difference(...)
    local newSet = ns.Lib:deepcopy(self)
    for _, other in ... do
        for item in other:iter() do
            newSet:remove(item)
        end
    end
    return newSet
end
