local _, ns = ...  -- Namespace

local Lib = {
    playerNameToGuid = {},
    epgpAllowedCharacters = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '-'}
}

ns.Lib = Lib


function Lib:find(array, value)
    if type(array) == 'table' then
        for i, v in ipairs(array) do
            if v == value then
                return i
            end
        end
    elseif type(array) == 'string' then
        for i = 1, #array do
            local c = array:sub(i, i)
            if c == value then
                return i
            end
        end
    end

    return -1
end


function Lib:contains(array, value)
    return self:find(array, value) ~= -1
end


function Lib:dictContains(array, value)
    for k in pairs(array) do
        if k == value then
            return true
        end
    end

    return false
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


function Lib:remove(array, value, all)
    if array == nil then
        return
    end

    while true do
        local i = self:find(array, value)
        table.remove(array, i)

        if i == -1 or not all then
            break
        end
    end
end


function Lib:keys(table)
    local keys = {}

    for k, _ in pairs(table) do
        tinsert(keys, k)
    end

    return keys
end


function Lib:split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local elements = {}

    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        tinsert(elements, s)
    end

    return elements
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
    if ns.cfg == nil then
        return
    end

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


function Lib:itemExists(itemId)
	if not itemId or not tonumber(itemId) then return false; end

	if C_Item.DoesItemExistByID(tonumber(itemId)) then
		return true;
	else
		return false;
	end
end


function Lib:getItemString(itemLink)
	if not itemLink then
		return nil;
	end

	local itemString = string.find(itemLink, "item[%-?%d:]+");
	if not itemString then return nil; end
	itemString = strsub(itemLink, itemString, string.len(itemLink) - (string.len(itemLink) - 2) - 6);
	return itemString;
end


function Lib:getItemID(itemString)
	if not itemString or not string.find(itemString, "item:") then
		return nil;
	end

	local itemString = string.sub(itemString, string.find(itemString, "item:") + 5, string.len(itemString) - 1)
	return string.sub(itemString, 1, string.find(itemString, ":") - 1);
end


function Lib:len(table)
    local count = 0

    for item in pairs(table) do
        count = count + 1
    end

    return count
end


function Lib:validateEpgpValue(value)
    if value == nil then
        return false
    end

    for i = 1, #value do
        local c = value:sub(i, i)
        if not self:contains(self.epgpAllowedCharacters, c) then
            return false
        end
    end

    local minusIndex = self:find(value, '-')
    if minusIndex ~= -1 and minusIndex ~= 1 then
        return false
    end

    return true
end


function Lib:canPlayerUseItem(itemLink)
    -- GameTooltip:ClearLines()
    GameTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')
    GameTooltip:SetHyperlink(itemLink)

    local isTooltipTextRed = function(text)
        if (text and text:GetText()) then
            local r, g, b = text:GetTextColor()
            return math.floor(r * 256) >= 255 and math.floor(g * 256) == 32 and math.floor(b * 256) == 32
        end

        return false
    end

    local canUse = true

    for i = 1, GameTooltip:NumLines() do
        local left = _G['GameTooltipTextLeft' .. i]
        local right = _G['GameTooltipTextRight' .. i]

        if isTooltipTextRed(left) or isTooltipTextRed(right) then
            canUse = false
            break
        end
    end

    GameTooltip:Hide()

    return canUse
end


function Lib:hash(data)
    local hasher = ns.addon.libc:fcs32init()
    hasher = ns.addon.libc:fcs32update(hasher, data)
    return ns.addon.libc:fcs32final(hasher)
end
