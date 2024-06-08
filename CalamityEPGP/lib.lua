local _, ns = ...  -- Namespace

local Lib = {
    playerNameToGuid = {},
    epgpAllowedCharacters = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '-'}
}

ns.Lib = Lib


---@param o1 any|table First object to compare
---@param o2 any|table Second object to compare
---@param ignore_mt boolean True to ignore metatables (a recursive function to tests tables inside tables)
---@return boolean
function Lib.equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or Lib.equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end


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
            if Lib.equals(v, value, false) then
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
            if Lib.equals(k, value, false) then
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

        if i == -1 then
            break
        end

        table.remove(container, i)

        if not all then
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
        guid = ns.unitGuid(playerName)
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
---@param classFilename string?
---@param spec string?
---@param callback function
function Lib.getGp(itemLink, classFilename, spec, callback)
    if ns.cfg == nil then
        return
    end

    Lib.getItemInfo(itemLink, function(itemInfo)
        local gp = Lib.getGpWithInfo(itemInfo, classFilename, spec)
        callback(gp)
    end)
end


---@param itemInfo table
---@param classFilename string?
---@param spec string?
function Lib.getGpWithInfo(itemInfo, classFilename, spec)
    local rarity = itemInfo.quality

    if rarity == nil then
        return 0
    end

    local ilvl = itemInfo.level
    local slot = itemInfo.slot

    if slot == 'INVTYPE_ROBE' then slot = 'INVTYPE_CHEST' end

    local modifier

    local slotMod = ns.cfg.gpSlotMods[slot]
    if slotMod == nil then
        ilvl = ns.values.tokenGp[itemInfo.id]
        modifier = 0.75
    else
        modifier = slotMod.base
        if classFilename ~= nil and slotMod.overrides ~= nil then
            local classOverride = slotMod.overrides[classFilename]
            if classOverride ~= nil then
                if type(classOverride) == 'number' then
                    modifier = classOverride
                elseif spec ~= nil then  -- it's a table with specs (spec can't be nil)
                    local specOverride = classOverride[spec]
                    if specOverride ~= nil then
                        modifier = specOverride
                    end
                end
            end
        end
    end

    if ilvl == nil then
        return 0
    end

    local gp = 4.83 * (2 ^ ((ilvl / 26) + (rarity - 4)) * modifier) * 0.1

    if ilvl >= 300 then
        gp = gp * 0.1
    end

    return math.floor(gp)
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
    local serialized = ns.addon:Serialize(data)

    local hasher = ns.addon.libc:fcs32init()
    hasher = ns.addon.libc:fcs32update(hasher, serialized)
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
    local playerData = ns.db.knownPlayers[playerGuid]

    return RAID_CLASS_COLORS[playerData.classFilename]
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


---@param item string | number
---@param callback? function
function Lib.getItemInfo(item, callback)
    callback = callback or function(_) end

    local itemId
    if type(item) == 'number' then
        itemId = item
    elseif type(item) == 'string' then
        itemId = Lib.getItemIdFromLink(item)
        if itemId == nil then
            error('Invalid item link "' .. item .. '"')
        end
    end

    local theItem = Item:CreateFromItemID(itemId)
    if theItem:IsItemEmpty() then
        error('No item found with ID "' .. itemId .. '"')
    end

    if theItem:IsItemDataCached() then
        local itemInfo = Lib.getCachedItemInfo(itemId)

        if itemInfo then
            callback(itemInfo)
            return
        end
    end

    theItem:ContinueOnItemLoad(function()
        local itemInfo = Lib.getCachedItemInfo(itemId)

        -- if itemInfo == nil then
        --     return
        -- end

        callback(itemInfo)
    end)
end


---@param player? string
---@return boolean
function Lib.isOfficer(player)
    if player == nil then
        player = ns.unitName('player')
    end

    local playerGuid = Lib.getPlayerGuid(player)
    if playerGuid == nil then
        return false
    end

    local playerData = ns.db.knownPlayers[playerGuid]
    if playerData == nil then
        return false
    end

    local rankIndex = playerData.rankIndex
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
        part = bit.band(x, 63)  -- 63 == 0b111111 (first six bits)
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


function Lib.strStartsWith(s, pattern)
    return s:sub(1, #pattern) == pattern
end


function Lib.strEndsWith(s, pattern)
    local sLen = #s
    return s:sub(sLen - #pattern + 1, sLen) == pattern
end


---@param reason number
---@return string
function Lib.getEventReason(reason, ...)
    local args = {...}

    if reason == ns.values.epgpReasons.MANUAL_SINGLE then
        assert(type(args[1]) == 'string')  -- details
        return ('%d:%s'):format(ns.values.epgpReasons.MANUAL_SINGLE, args[1])
    end

    if reason == ns.values.epgpReasons.MANUAL_MULTIPLE then
        assert(type(args[1]) == 'string')  -- details
        local reasonStr = ('%d:%s'):format(ns.values.epgpReasons.MANUAL_MULTIPLE, args[1])

        if args[2] then
            assert(type(args[2]) == 'boolean')
            reasonStr = reasonStr .. ':1'
        end

        return reasonStr
    end

    if reason == ns.values.epgpReasons.DECAY then
        assert(type(args[1]) == 'string')  -- details
        return ('%d:%s'):format(ns.values.epgpReasons.DECAY, args[1])
    end

    if reason == ns.values.epgpReasons.AWARD then
        assert(args[1] and (strlower(args[1]) == 'ms' or strlower(args[1]) == 'os'))  -- roll type
        assert(args[2] and (type(args[2]) == 'number' or type(args[2]) == 'string'))  -- item ID or name
        return ('%d:%s:%s'):format(ns.values.epgpReasons.AWARD, strlower(args[1]), args[2])
    end

    if reason == ns.values.epgpReasons.BOSS_KILL then
        assert(args[1] and type(args[1] == 'number'))  -- boss ID
        local reasonStr = ('%d:%d'):format(ns.values.epgpReasons.BOSS_KILL, args[1])

        if args[2] then
            assert(type(args[2]) == 'boolean')
            reasonStr = reasonStr .. ':1'
        end

        return reasonStr
    end

    error(('Unknown event reason: %s'):format(reason))
end


Lib.specTable = {
    DEATHKNIGHT = {ns.consts.SPEC_DK_BLOOD, ns.consts.SPEC_DK_FROST, ns.consts.SPEC_DK_UNHOLY},
    DRUID = {ns.consts.SPEC_DRUID_BALANCE, ns.consts.SPEC_DRUID_FERAL, ns.consts.SPEC_DRUID_RESTO},
    HUNTER = {ns.consts.SPEC_HUNTER_BM, ns.consts.SPEC_HUNTER_MM, ns.consts.SPEC_HUNTER_SV},
    MAGE = {ns.consts.SPEC_MAGE_ARCANE, ns.consts.SPEC_MAGE_FIRE, ns.consts.SPEC_MAGE_FROST},
    PALADIN = {ns.consts.SPEC_PALADIN_HOLY, ns.consts.SPEC_PALADIN_PROT, ns.consts.SPEC_PALADIN_RET},
    PRIEST = {ns.consts.SPEC_PRIEST_DISC, ns.consts.SPEC_PRIEST_HOLY, ns.consts.SPEC_PRIEST_SHADOW},
    ROGUE = {ns.consts.SPEC_ROGUE_ASS, ns.consts.SPEC_ROGUE_COMBAT, ns.consts.SPEC_ROGUE_SUB},
    SHAMAN = {ns.consts.SPEC_SHAMAN_ELE, ns.consts.SPEC_SHAMAN_ENH, ns.consts.SPEC_SHAMAN_RESTO},
    WARLOCK = {ns.consts.SPEC_WARLOCK_AFF, ns.consts.SPEC_WARLOCK_DEMO, ns.consts.SPEC_WARLOCK_DESTRO},
    WARRIOR = {ns.consts.SPEC_WARRIOR_ARMS, ns.consts.SPEC_WARRIOR_FURY, ns.consts.SPEC_WARRIOR_PROT},
}

---@return number
function Lib.getActiveTalentGroup()
    return GetActiveTalentGroup(false, false)
end

---@param group number?
---@return number?
function Lib.getActiveSpecIndex(group)
    if group == nil then
        group = Lib.getActiveTalentGroup()
    end

    assert(group == 1 or group == 2, "group is not a valid number (1-2)")

    local mostPoints = 0
    local specIndex = nil

    for i = 1, 3 do  -- GetNumTalentTabs
        local points = 0

        for j = 1, GetNumTalents(i, false, false) do
            points = points + select(5, GetTalentInfo(i, j, group))
        end

        if (points > mostPoints) then
            mostPoints = points
            specIndex = i
        end
    end

    return specIndex
end

---@param class string
---@param specIndex number
---@return string
function Lib.getSpecName(class, specIndex)
    local specs = Lib.specTable[class]
    assert(specs ~= nil, 'invalid class')

    assert(type(specIndex) == 'number' and specIndex > 0 and specIndex < 4, 'specIndex is not a valid number (1-3)')

    return specs[specIndex]
end


---@param guid string
---@param callback function?
function Lib.getPlayerInfo(guid, callback)
    callback = callback or function(_) end

    local playerData = ns.db.knownPlayers[guid]
    if playerData ~= nil then
        callback(playerData)
        return
    end

    local _, classFilename, _, _, _, name, _ = GetPlayerInfoByGUID(guid)
    if name ~= nil and #name > 0 then
        playerData = Lib.createKnownPlayer(guid, name, classFilename, false, nil)
        callback(playerData)
        return
    elseif name == nil then
        C_Timer.After(0.2, function() Lib.getPlayerInfo(guid, callback) end)
        return
    end

    callback(nil)
end


---@param guid string
---@param name string
---@param classFilename string
---@param inGuild boolean
---@param rankIndex integer?
---@return table
function Lib.createKnownPlayer(guid, name, classFilename, inGuild, rankIndex)
    local playerData = {
        guid = guid,
        name = name,
        classFilename = classFilename,
        inGuild = inGuild,
        rankIndex = rankIndex,
    }

    ns.db.knownPlayers[guid] = playerData

    Lib.playerNameToGuid[name] = guid

    return playerData
end


---@param eventAndHash table
---@return string
function Lib.getEventAndHashId(eventAndHash)
    return ('%s:%s'):format(eventAndHash[1][1], eventAndHash[2])
end
