local _, ns = ...  -- Namespace

local List = {}
ns.List = List

local Dict = {}
ns.Dict = Dict

local Set = {}
ns.Set = Set

---------------
---@param items? table
---@return table
function List:new(items)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._list = {}

    if items ~= nil then
        for _, item in ipairs(items) do
            table.insert(o._list, item)
        end
    end

    return o
end

---@param item any
---@return boolean
function List:contains(item)
    return ns.Lib.contains(self._list, item)
end

---@return number
function List:len()
    return #self._list
end

---@param reverse? boolean
---@param enumerate? boolean
---@return function
function List:iter(reverse, enumerate)
    ---@type number
    local i
    ---@type function
    local shouldContinue
    ---@type function
    local nextI
    ---@type function
    local index

    if not reverse then
        i = 1
        shouldContinue = function() return i <= self:len() end
        nextI = function() return i + 1 end
        index = function() return i - 1 end
    else
        i = self:len()
        shouldContinue = function() return i >= 1 end
        nextI = function() return i - 1 end
        index = function() return self:len() + 1 - i - 1 end
    end

    return function()
        if shouldContinue() then
            local item = self:get(i)
            i = nextI()

            if enumerate then
                return index(), item
            else
                return item
            end
        end
    end
end

---@param reverse? boolean
---@return function
function List:enumerate(reverse)
    return self:iter(reverse, true)
end

function List:clear()
    self._list = {}
end

function List:append(item)
    table.insert(self._list, item)
end

---@param index number
---@return any
function List:get(index)
    if index < 0 then
        index = self:len() + index + 1
    end
    return self._list[index]
end

---@param index number
---@param value any
function List:set(index, value)
    if index < 0 then
        index = self:len() + index + 1
    end

    assert(self._list[index] ~= nil, 'no item at index ' .. index)

    self._list[index] = value
end

---@param func? function
function List:sort(func)
    table.sort(self._list, func)
end

---@return table
function List:toTable()
    return ns.Lib.deepcopy(self._list)
end

---@param value any
---@param fcomp? function
function List:bininsert(value, fcomp)
    ns.Lib.bininsert(self._list, value, fcomp)
end


---------------
---@param items? table
---@return table
function Set:new(items)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._set = {}
    o._len = 0

    items = items or {}
    for _, item in ipairs(items) do
        o._set[item] = true
        o._len = o._len + 1
    end

    return o
end

---@param item any
---@return boolean
function Set:contains(item)
    return self._set[item] == true
end

---@return number
function Set:len()
    return self._len
end

---@param item any
function Set:add(item)
    if self:contains(item) then
        return
    end

    self._set[item] = true
    self._len = self._len + 1
end

---@param item any
function Set:remove(item)
    if not self:contains(item) then
        return
    end

    self._set[item] = nil
    self._len = self._len - 1
end

function Set:clear()
    self._set = {}
    self._len = 0
end

function Set:iter()
    return pairs(self._set)
end

---@return table
function Set:toTable()
    local t = {}

    for item in self:iter() do
        table.insert(t, ns.Lib.deepcopy(item))
    end

    return t
end

function Set:difference(...)
    local newSet = ns.Lib.deepcopy(self)
    for _, other in ipairs({...}) do
        for item in other:iter() do
            newSet:remove(item)
        end
    end
    return newSet
end


---------------
---@param table? table
---@return table
function Dict:new(table)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._dict = {}
    o._keys = Set:new()
    o._values = List:new()
    o._keyToValueIndex = {}

    if table == nil then table = {} end
    for k, v in pairs(table) do
        o._dict[k] = v
        o._keys:add(k)
        o._values:append(v)
        o._keyToValueIndex[k] = o._values:len()
    end

    return o
end

---@param key any
---@return boolean
function Dict:contains(key)
    return self._keys:contains(key)
end

---@return number
function Dict:len()
    return self._keys:len()
end

---@return boolean
function Dict:isEmpty()
    return self:len() == 0
end

function Dict:keys()
    return self._keys
end

function Dict:values()
    return self._values
end

---@param key any
---@return any
function Dict:get(key)
    return self._dict[key]
end

---@param key any
---@param value any
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

function Dict:iter()
    return pairs(self._dict)
end

function Dict:clear()
    self._dict = {}
    self._keys:clear()
    self._values:clear()
    self._keyToValueIndex = {}
end

---@return table
function Dict:toTable()
    return ns.Lib.deepcopy(self._dict)
end
