local addonName, ns = ...  -- Namespace

Lib = {
    playerNameToGuid = {}
}

ns.Lib = Lib


function Lib:find(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end

    return -1
end


function Lib:contains(array, value)
    return self:find(array, value) ~= -1
end


function Lib:deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[self:deepcopy(orig_key, copies)] = self:deepcopy(orig_value, copies)
            end
            setmetatable(copy, self:deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function Lib:remove(array, value)
    if array == nil then
        return
    end

    local i = self:find(array, value)
    table.remove(array, i)
end


function Lib:keys(table)
    local keys = {}

    for k, _ in pairs(table) do
        tinsert(keys, k)
    end

    return keys
end


function split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local elements = {}

    for s in string.gmatch(str, "([^"..sep.."]+)") do
        tinsert(elements, s)
    end

    return  elements
end


function Lib:getPlayerGuid(playerName)
    local guid = self.playerNameToGuid[playerName]

    if guid == nil then
        guid = UnitGUID(playerName)
        self.playerNameToGuid[playerName] = guid
    end

    return guid
end


function Lib:getClickCombination(mouseButton)
    local keySegments = {};

    if IsControlKeyDown() then
        tinsert(keySegments, 'CTRL');
    end

    if IsAltKeyDown() then
        tinsert(keySegments, 'ALT');
    end

    if IsShiftKeyDown() then
        tinsert(keySegments, 'SHIFT');
    end

    if not mouseButton or mouseButton == 'LeftButton' then
        tinsert(keySegments, 'CLICK');
    elseif mouseButton == 'RightButton' then
        tinsert(keySegments, 'RIGHTCLICK');
    end

    return table.concat(keySegments, '_');
end


function Lib:getItemIDFromLink(itemLink)
    if not itemLink or type(itemLink) ~= 'string' or itemLink == '' then
        return false;
    end

    local _, itemID = strsplit(':', itemLink);
    itemID = tonumber(itemID);

    if not itemID then
        return false;
    end

    return itemID;
end


function Lib:createPattern(pattern, maximize)
    pattern = string.gsub(pattern, "[%(%)%-%+%[%]]", "%%%1");

    if not maximize then
        pattern = string.gsub(pattern, "%%s", "(.-)");
    else
        pattern = string.gsub(pattern, "%%s", "(.+)");
    end

    pattern = string.gsub(pattern, "%%d", "%(%%d-%)");

    if not maximize then
        pattern = string.gsub(pattern, "%%%d%$s", "(.-)");
    else
        pattern = string.gsub(pattern, "%%%d%$s", "(.+)");
    end

    return string.gsub(pattern, "%%%d$d", "%(%%d-%)");
end


function Lib:getGp(itemLink)
    local _, _, rarity, ilvl, _, class, subClass, _, slot, _, _ = GetItemInfo(itemLink)

    if slot == 'INVTYPE_ROBE' then slot = 'INVTYPE_CHEST' end

    local slotMod = ns.cfg.gpSlotMods[slot]
    if slotMod == nil then
        local itemId = itemLink:match("item:(%d+):")
        if itemId ~= nil then
            itemId = tonumber(itemId)
        end
        ilvl = ns.values.tokenGp[itemId]
        slotMod = 0.75
    end

    if ilvl == nil then
        return 0
    end

    local gp = math.floor(4.83 * (2 ^ ((ilvl / 26) + (rarity - 4)) * slotMod) * 0.1)

    return gp
end
