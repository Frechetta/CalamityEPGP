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

    items = items or {}
    for _, item in ipairs(items) do
        tinsert(o._list, item)
    end

    return o
end

function List:contains(item)
    return ns.Lib.contains(self._list, item)
end

function List:iter(reverse)
    if not reverse then
        local i = 1
        return function()
            if i <= self:len() then
                local item = self:get(i)
                i = i + 1
                return item
            end
        end
    else
        local i = self:len()
        return function()
            if i >= 1 then
                local item = self:get(i)
                i = i - 1
                return item
            end
        end
    end
end

function List:enumerate(reverse)
    if not reverse then
        local i = 1
        return function()
            if i <= self:len() then
                local item = self:get(i)
                i = i + 1
                return i - 1, item
            end
        end
    else
        local i = self:len()
        return function()
            if i >= 1 then
                local item = self:get(i)
                i = i - 1
                return self:len() + 1 - i - 1, item
            end
        end
    end
end

function List:clear()
    self._list = {}
end

function List:append(item)
    tinsert(self._list, item)
end

function List:get(index)
    if index == -1 then
        index = self:len()
    end
    return self._list[index]
end

function List:set(index, value)
    assert(self._list[index] ~= nil, 'no item at index ' .. index)

    self._list[index] = value
end

function List:len()
    return #self._list
end

function List:sort(func)
    table.sort(self._list, func)
end

function List:toTable()
    return ns.Lib.deepcopy(self._list)
end

function List:bininsert(value, fcomp)
    ns.Lib.bininsert(self._list, value, fcomp)
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
        o._keyToValueIndex[k] = o._values:len()
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
        self._values:set(index, value)
    else
        self._values:append(value)
        self._keyToValueIndex[key] = self._values:len()
    end
end

function Dict:len()
    return self._keys:len()
end

function Dict:contains(key)
    return self._keys:contains(key)
end

function Dict:clear()
    self._dict = {}
    self._keys:clear()
    self._values:clear()
    self._keyToValueIndex = {}
end

function Dict:keys()
    return self._keys
end

function Dict:values()
    return self._values
end

function Dict:toTable()
    return ns.Lib.deepcopy(self._dict)
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
    return ns.Lib.deepcopy(self._values)
end

function Set:difference(...)
    local newSet = ns.Lib.deepcopy(self)
    for _, other in ... do
        for item in other:iter() do
            newSet:remove(item)
        end
    end
    return newSet
end
