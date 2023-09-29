local _, ns = ...  -- Namespace

local Lib = {
    playerNameToGuid = {},
    epgpAllowedCharacters = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '-'}
}

ns.Lib = Lib


---@param container table | string
---@param value any
---@return number
function Lib.find(container, value)
    if container == nil then
        error('container argument must not be nil')
    end

    if value == nil then
        error('value argument must not be nil')
    end

    if type(container) == 'table' then
        for i, v in ipairs(container) do
            if v == value then
                return i
            end
        end
    elseif type(container) == 'string' then
        for i = 1, #container do
            local c = container:sub(i, i)
            if c == value then
                return i
            end
        end
    else
        error('container argument type is unsupported')
    end

    return -1
end


---@param container table | string
---@param value any
---@return boolean
function Lib.contains(container, value)
    if type(container) == 'table' and #container == 0 then
        -- dict or empty list
        for k in pairs(container) do
            if k == value then
                return true
            end
        end

        return false
    else
        return Lib.find(container, value) ~= -1
    end
end


function Lib.deepcopy(orig, copies)
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
                copy[Lib.deepcopy(orig_key, copies)] = Lib.deepcopy(orig_value, copies)
            end
            setmetatable(copy, Lib.deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


---@param container table
---@param value any
---@param all boolean
function Lib.remove(container, value, all)
    if container == nil then
        error('container argument must not be nil')
    end

    if value == nil then
        error('value argument must not be nil')
    end

    while true do
        local i = Lib.find(container, value)
        table.remove(container, i)

        if i == -1 or not all then
            break
        end
    end
end


function Lib.split(str, sep)
    if sep == nil then
        sep = "%s"
    end

    local elements = {}

    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        tinsert(elements, s)
    end

    return elements
end


function Lib.getPlayerGuid(playerName)
    local guid = Lib.playerNameToGuid[playerName]

    if guid == nil then
        guid = UnitGUID(playerName)
        Lib.playerNameToGuid[playerName] = guid
    end

    return guid
end


function Lib.getClickCombination(mouseButton)
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


---@param itemLink string
---@return number?
function Lib.getItemIdFromLink(itemLink)
    if not itemLink or type(itemLink) ~= 'string' or itemLink == '' then
        return nil
    end

    local _, itemID = strsplit(':', itemLink)
    itemID = tonumber(itemID)

    if not itemID then
        return nil
    end

    return itemID
end


function Lib.createPattern(pattern, maximize)
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


---@param itemLink string
---@param callback function
function Lib.getGp(itemLink, callback)
    if ns.cfg == nil then
        return
    end

    Lib.getItemInfo(itemLink, function(itemInfo)
        local gp = Lib.getGpWithInfo(itemInfo)
        callback(gp)
    end)
end


function Lib.getGpWithInfo(itemInfo)
    local rarity = itemInfo.quality
    local ilvl = itemInfo.level
    local slot = itemInfo.slot

    if slot == 'INVTYPE_ROBE' then slot = 'INVTYPE_CHEST' end

    local slotMod = ns.cfg.gpSlotMods[slot]
    if slotMod == nil then
        ilvl = ns.values.tokenGp[itemInfo.id]
        slotMod = 0.75
    end

    local gp
    if ilvl == nil or rarity == nil then
        gp = 0
    else
        gp = math.floor(4.83 * (2 ^ ((ilvl / 26) + (rarity - 4)) * slotMod) * 0.1)
    end

    return gp
end


function Lib.itemExists(itemId)
	if not itemId or not tonumber(itemId) then return false end

	if C_Item.DoesItemExistByID(tonumber(itemId)) then
		return true
	else
		return false
	end
end


function Lib.len(dict)
    local count = 0

    for _ in pairs(dict) do
        count = count + 1
    end

    return count
end


function Lib.validateEpgpValue(value)
    if value == nil then
        return false
    end

    for i = 1, #value do
        local c = value:sub(i, i)
        if not Lib.contains(Lib.epgpAllowedCharacters, c) then
            return false
        end
    end

    local minusIndex = Lib.find(value, '-')
    if minusIndex ~= -1 and minusIndex ~= 1 then
        return false
    end

    return true
end


function Lib.hash(data)
    local hasher = ns.addon.libc:fcs32init()
    hasher = ns.addon.libc:fcs32update(hasher, tostring(data))
    return ns.addon.libc:fcs32final(hasher)
end


function Lib.getVersionNum(version)
    --[[
        0.7.0   == --- --7 000
        0.7.1   == --- --7 001
        0.7.56  == --- --7 056
        0.8.2   == --- --8 002
        0.12.5  == --- -12 005
        1.5.0   == --1 005 000
        1.15.12 == --1 015 012
    --]]
    local parts = Lib.split(version, '.')

    local major = tostring(parts[1])
    local minor = tostring(parts[2])
    local patch = tostring(parts[3])

    for i = 1, 3 do
        if #major < i then
            major = '0' .. major
        end

        if #minor < i then
            minor = '0' .. minor
        end

        if #patch < i then
            patch = '0' .. patch
        end
    end

    local versionNum = tonumber(major .. minor .. patch)
    return versionNum
end


function Lib.getVersionStr(versionNum)
    local patch = versionNum % 1000
    versionNum = math.floor(versionNum / 1000)
    local minor = versionNum % 1000
    versionNum = math.floor(versionNum / 1000)
    local major = versionNum % 1000

    local version = major .. '.' .. minor .. '.' .. patch
    return version
end


local fcomp_default = function(a, b) return a < b end
function Lib.bininsert(t, value, fcomp)
    -- Initialise compare function
    fcomp = fcomp or fcomp_default

    --  Initialise numbers
    local iStart, iEnd, iMid, iState = 1, #t, 1, 0

    -- Get insert position
    while iStart <= iEnd do
        -- calculate middle
        iMid = math.floor((iStart + iEnd) / 2)
        -- compare
        if fcomp(value, t[iMid]) then
            iEnd, iState = iMid - 1, 0
        else
            iStart, iState = iMid + 1, 1
        end
    end

    table.insert(t, iMid + iState, value)

    return iMid + iState
 end


function Lib.getPlayerClassColor(player)
    local playerGuid = Lib.getPlayerGuid(player)
    local playerData = ns.db.standings[playerGuid]

    return RAID_CLASS_COLORS[playerData.classFileName]
end


function Lib.getColoredText(text, color)
    if color == nil then
        return text
    end

    return color:WrapTextInColorCode(text)
end


function Lib.getColoredByClass(player, text)
    local coloredText
    if text ~= nil then
        coloredText = text
    else
        coloredText = player
    end

    local classColor = Lib.getPlayerClassColor(player)
    return Lib.getColoredText(coloredText, classColor)
end


function Lib.getMl()
    for name, playerData in ns.addon.raidRoster:iter() do
        if playerData.ml then
            return name
        end
    end

    return nil
end


---@param itemLink string
---@param callback function
function Lib.canPlayerUseItem(itemLink, callback)
    Lib.getItemInfo(itemLink, function(_)
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

        callback(canUse)
    end)
end


---@param itemId number
---@return table?
function Lib.getCachedItemInfo(itemId)
    local itemName, itemLink, itemQuality, itemLevel, _, _, _, _, itemEquipLoc,
            itemTexture, _, classID, subclassID, bindType, _, _, _ = GetItemInfo(itemId)

    if itemName == nil or itemLink == nil or type(bindType) ~= 'number' then
        ns.debug('GetItemInfo data was not yet available for item with ID: ' .. itemId)
        return nil
    end

    local itemInfo = {
        id = itemId,
        link = itemLink,
        name = itemName,
        quality = itemQuality,
        level = itemLevel,
        slot = itemEquipLoc,
        icon = itemTexture,
        classID = classID,
        subclassID = subclassID,
        bindType = bindType,
    }

    local gp = Lib.getGpWithInfo(itemInfo)
    itemInfo.gp = gp

    return itemInfo
end


---@param itemLink string
---@param callback? function
function Lib.getItemInfo(itemLink, callback)
    callback = callback or function(_) end

    local itemId = Lib.getItemIdFromLink(itemLink)
    if itemId == nil then
        error('Invalid item link "' .. itemLink .. '"')
    end

    local item = Item:CreateFromItemID(itemId)
    if item:IsItemEmpty() then
        error('No item found with link "' .. itemLink .. '"')
    end

    if item:IsItemDataCached() then
        local itemInfo = Lib.getCachedItemInfo(itemId)

        if itemInfo then
            callback(itemInfo)
            return
        end
    end

    item:ContinueOnItemLoad(function()
        local itemInfo = Lib.getCachedItemInfo(itemId)

        if itemInfo == nil then
            return
        end

        callback(itemInfo)
    end)
end


---@param player? string
---@return boolean
function Lib.isOfficer(player)
    if player == nil then
        player = UnitName('player')
    end

    local playerGuid = Lib.getPlayerGuid(player)
    if playerGuid == nil then
        return false
    end

    local charData = ns.db.standings[playerGuid]
    if charData == nil then
        return false
    end

    local rankIndex = charData.rankIndex
    if rankIndex == nil then
        return false
    end

    local rankOrder = rankIndex + 1  -- the function below accepts "rankOrder", which starts at 1 instead of 0

    -- https://wowpedia.fandom.com/wiki/API_C_GuildInfo.GuildControlGetRankFlags
    local perms = C_GuildInfo.GuildControlGetRankFlags(rankOrder)
    if perms == nil then
        return false
    end

    local isOfficer = perms[12]

    return isOfficer
end


---@param rankIndex integer
---@return string?
function Lib.getRankName(rankIndex)
    return GuildControlGetRankName(rankIndex + 1)
end


local b64EncMap = {
     [0] = 'A',  [1] = 'B',  [2] = 'C',  [3] = 'D',  [4] = 'E',  [5] = 'F',  [6] = 'G',  [7] = 'H',
     [8] = 'I',  [9] = 'J', [10] = 'K', [11] = 'L', [12] = 'M', [13] = 'N', [14] = 'O', [15] = 'P',
    [16] = 'Q', [17] = 'R', [18] = 'S', [19] = 'T', [20] = 'U', [21] = 'V', [22] = 'W', [23] = 'X',
    [24] = 'Y', [25] = 'Z', [26] = 'a', [27] = 'b', [28] = 'c', [29] = 'd', [30] = 'e', [31] = 'f',
    [32] = 'g', [33] = 'h', [34] = 'i', [35] = 'j', [36] = 'k', [37] = 'l', [38] = 'm', [39] = 'n',
    [40] = 'o', [41] = 'p', [42] = 'q', [43] = 'r', [44] = 's', [45] = 't', [46] = 'u', [47] = 'v',
    [48] = 'w', [49] = 'x', [50] = 'y', [51] = 'z', [52] = '0', [53] = '1', [54] = '2', [55] = '3',
    [56] = '4', [57] = '5', [58] = '6', [59] = '7', [60] = '8', [61] = '9', [62] = '+', [63] = '/',
}

local b64DecMap = {}
for i, c in pairs(b64EncMap) do
    b64DecMap[c] = i
end

---@param x number
---@return string
function Lib.b64Encode(x)
    if x == 0 then
        return b64EncMap[x]
    end

    local s = ''
    local part
    while x ~= 0 do
        part = bit.band(x, 63)
        s = b64EncMap[part] .. s
        x = bit.rshift(x, 6)
    end

    return s
end

---@param s string
---@return number
function Lib.b64Decode(s)
    local sLen = #s
    local num = 0
    local c
    local cNum
    local shift
    for i = 1, sLen do
        c = s:sub(i, i)
        cNum = b64DecMap[c]
        shift = (sLen - i) * 6
        num = bit.bor(num, bit.lshift(cNum, shift))
    end

    return num
end


---@param guidFull string
---@return string
function Lib.getShortPlayerGuid(guidFull)
    local realmId, guidShort = string.match(guidFull, '^Player%-(%d+)%-(%x%x%x%x%x%x%x%x)$')

    if realmId == nil or guidShort == nil then
        error(('Player GUID is malformed: "%s"'):format(guidFull))
    end

    if tonumber(realmId) ~= ns.db.realmId then
        error(('Player GUID has incorrect realm ID: "%d"; ID should be %d'):format(tonumber(realmId), ns.db.realmId))
    end

    return guidShort
end

---@param guidShort string
---@return string
function Lib.getFullPlayerGuid(guidShort)
    if not Lib.isShortPlayerGuid(guidShort) then
        error(('Player short GUID is malformed: "%s"'):format(guidShort))
    end

    return ('Player-%d-%s'):format(ns.db.realmId, guidShort)
end

function Lib.isShortPlayerGuid(guidShort)
    local res = string.match(guidShort, '^%x%x%x%x%x%x%x%x$')
    return res ~= nil and #res == 8
end

function Lib.isFullPlayerGuid(guidFull)
    local res = string.match(guidFull, '^Player%-%d+%-%x%x%x%x%x%x%x%x$')
    return res ~= nil
end
