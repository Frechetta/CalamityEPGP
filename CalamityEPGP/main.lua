SLASH_RELOADUI1 = '/rl'
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = '/fs'
SlashCmdList.FRAMESTK = function()
    LoadAddOn('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end

-- for i = 1, NUM_CHAT_WINDOWS do
--     _G['ChatFrame' .. i .. 'EditBox']:SetAltArrowKeyMode(false)
-- end
---------------------------------------------------------------

local addonName, ns = ...  -- Namespace

function ns.unitName(unit)
    return UnitName(unit)
end

function ns.unitGuid(unit)
    return UnitGUID(unit)
end

local List = ns.List
local Dict = ns.Dict
local Set = ns.Set

---@class AceAddon
local addon = LibStub('AceAddon-3.0'):NewAddon(
    addonName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceSerializer-3.0', 'AceTimer-3.0'
)
ns.addon = addon

local dbDefaults = {
    profile = {
        history = {},
        cfg = {},
        altData = {
            mainAltMapping = {},
            altMainMapping = {},
        },
        loot = {
            toTrade = {},
            awarded = {},
        },
        lmSettingsLastChange = -1,
        benchedPlayers = {},
    }
}


function addon:OnInitialize()
    self.version = C_AddOns.GetAddOnMetadata(addonName, 'Version')
    self.author = C_AddOns.GetAddOnMetadata(addonName, 'Author')

    self.versionNum = ns.Lib.getVersionNum(self.version)

    self.initializing = false
    self.preinitialized = false
    self.initialized = false
    self.minimapButtonInitialized = false
    self.useForRaidPrompted = false
    self.useForRaid = false
    self.raidRoster = Dict:new()
    self.whisperCommands = {
        INFO = '!ceinfo',
    }

    ns.minSyncVersion = ns.Lib.getVersionNum('0.19.0')

    self:RegisterEvent('GUILD_ROSTER_UPDATE', 'handleGuildRosterUpdate')

    if IsInGuild() then
        -- Request guild roster info from server; will receive an event (GUILD_ROSTER_UPDATE)
        GuildRoster()
    else
        self:init()
    end
end


-- function addon:OnEnable()
--     -- Called when the addon is enabled
-- end


-- function addon:OnDisable()
--     -- Called when the addon is disabled
-- end


function ns.print(msg)
    addon:Print(msg)
end

function ns.debug(msg)
    if not ns.cfg.debugMode then
        return
    end

    ns.print('DEBUG: ' .. tostring(msg))
end

function ns.printPublic(msg, rw)
    local channel

    if IsInRaid() then
        if rw and (UnitIsGroupLeader('player') or UnitIsGroupAssistant('player')) then
            channel = 'RAID_WARNING'
        else
            channel = 'RAID'
        end
    elseif IsInGroup() then
        channel = 'PARTY'
    end

    msg = tostring(msg)

    if channel ~= nil then
        SendChatMessage(('%s: %s'):format(addonName, msg), channel)
    else
        ns.print(msg)
    end
end

-------------------------
-- HANDLERS
-------------------------
function addon:handleSlashCommand(input)
    if input == 'show' then
        self.showMainWindow()
    elseif input == 'history' then
        ns.HistoryWindow:createWindow()
        ns.HistoryWindow:show()
    elseif input == 'cfg' then
        self.openOptions()
    else
        ns.print('Usage:')
        ns.print('show - Opens the main window')
        ns.print('history - Opens the history window')
        ns.print('cfg - Opens the configuration menu')
    end
end

function addon:handleGuildRosterUpdate()
    C_Timer.After(0.1, function()
        self:init()

        if self.initialized then
            self:computeStandings()
        end
    end)
end

function addon.showMainWindow()
    ns.MainWindow:createWindow()
    ns.MainWindow:show()
end

function addon.openOptions()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function addon:handleItemClick(itemLink, mouseButton)
    if not itemLink
            or type(itemLink) ~= "string"
            or (mouseButton and mouseButton ~= "LeftButton")
            or not ns.Lib.getItemIdFromLink(itemLink) then
        return;
    end

    local keyPressIdentifier = ns.Lib.getClickCombination(mouseButton);

    if not ((ns.cfg.lmMode and IsMasterLooter()) or ns.cfg.debugMode) then
        return
    end

    if keyPressIdentifier == 'ALT_CLICK' then
        self.showLootDistWindow(itemLink)
    elseif keyPressIdentifier == 'ALT_SHIFT_CLICK' then
        self.showManualAwardWindow(itemLink)
    end
end

function addon.showLootDistWindow(itemLink)
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:show(itemLink)
end

function addon.showManualAwardWindow(itemLink)
    if not ns.cfg.lmMode then
        return
    end

    ns.ManualAwardWindow:show(itemLink)
end

function addon:init()
    if self == nil then
        C_Timer.After(0.25, function() addon:init() end)
        return
    end

    if not self.initializing and not self.initialized then
        -- Get guild name
        local guildName = GetGuildInfo('player')

        -- haven't actually received guild data yet. wait 1 second and run this function again
        if guildName == nil then
            -- TODO: handle guildless players
            if IsInGuild() then
                C_Timer.After(0.5, function() addon:init() end)
            end

            return
        end

        self.initializing = true

        local realmName = GetRealmName()
        local guildFullName = guildName .. '-' .. realmName

        -- DB
        local db = LibStub('AceDB-3.0'):New(addonName, dbDefaults)
        db:SetProfile(guildFullName)

        ns.db = db.profile
        ns.cfg = ns.db.cfg

        ns.db.realmId = GetRealmID()

        ns.guild = guildFullName
        ns.peers = Dict:new()
        ns.knownPlayers = Dict:new()
        ns.standings = Dict:new()
        ns.playersLastUpdated = Dict:new()

        self.ldb = LibStub('LibDataBroker-1.1', true)
        self.ldbi = LibStub('LibDBIcon-1.0', true)

        self.candy = LibStub('LibCandyBar-3.0')

        self.libc = LibStub('LibCompress')
        self.libcEncodeTable = self.libc:GetAddonEncodeTable()

        self.migrateData()

        table.sort(ns.db.history, function(left, right)
            return left[1][1] < right[1][1]
        end)

        -- TODO: prune history

        ns.Comm:init()
        ns.Sync:init()

        self.clearAwarded()
        self.clearAwardedTimer = self:ScheduleRepeatingTimer(function() self.clearAwarded() end, 60)

        self:RegisterChatCommand('ce', 'handleSlashCommand')
        self:RegisterEvent('CHAT_MSG_SYSTEM', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_PARTY', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_PARTY_LEADER', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_RAID', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_RAID_LEADER', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_RAID_WARNING', 'handleChatMsg')
        self:RegisterEvent('CHAT_MSG_LOOT', 'handleChatMsgLoot')
        self:RegisterEvent('CHAT_MSG_WHISPER', 'handleChatMsgWhisper')
        self:RegisterEvent('TRADE_REQUEST', 'handleTradeRequest')
        self:RegisterEvent('TRADE_SHOW', 'handleTradeShow')
        self:RegisterEvent('TRADE_PLAYER_ITEM_CHANGED', 'handleTradePlayerItemChanged')
        self:RegisterEvent('RAID_INSTANCE_WELCOME', 'handleEnteredRaid')
        self:RegisterEvent('RAID_ROSTER_UPDATE', 'handleEnteredRaid')
        self:RegisterEvent('GROUP_LEFT', 'loadRaidRoster')
        self:RegisterEvent('LOOT_READY', 'handleLootReady')
        self:RegisterEvent('LOOT_CLOSED', 'handleLootClosed')
        self:RegisterEvent('UI_INFO_MESSAGE', 'handleUiInfoMessage')
        self:RegisterEvent('ENCOUNTER_END', 'handleEncounterEnd')
        self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', 'handlePartyLootMethodChanged')

        hooksecurefunc("HandleModifiedItemClick", function(itemLink)
            self:handleItemClick(itemLink, GetMouseButtonClicked())
        end);

        hooksecurefunc("GameTooltip_UpdateStyle", function(frame)
            self:handleTooltipUpdate(frame)
        end)

        self.preinitialized = true
    end

    if self.preinitialized then
        -- Load guild data
        self:loadGuildRoster()

        -- load raid data
        if IsInRaid() then
            self:handleEnteredRaid()
        end
    end

    if self.initializing and self.preinitialized and not self.initialized then
        -- Load config module
        ns.Config:init()

        self:computeStandings(function()
            self:initMinimapButton()

            ns.Comm:registerHandler(ns.Comm.msgTypes.HEARTBEAT, self.handleHeartbeat)
            ns.Comm:registerHandler(ns.Comm.msgTypes.ROLL_PASS, self.handleRollPass)

            self.housekeepPeersTimer = self:ScheduleRepeatingTimer(function() self:housekeepPeers() end, 25)

            self.initialized = true
            self.initializing = false

            ns.print(string.format('v%s by %s loaded. Type /ce to get started!', addon.version, addon.author))

            self:sendHeartbeat()
            self.heartbeatTimer = self:ScheduleRepeatingTimer(function() self:sendHeartbeat() end, 60)

            ns.Sync:computeIndices()
            ns.Sync:syncInit()
        end)
    end
end


function addon.migrateData()
    ns.debug('migrating data...')

    -- STANDINGS
    if ns.db.standingsVersion ~= nil then
        ns.debug('removing standings')
        ns.db.standings = nil
        ns.db.standingsVersion = nil
    end

    -- HISTORY
    if not ns.db.historyVersion then
        ns.debug('migrating history to v1')

        ns.HistoryWindow.fixHistory()

        local newHistory = {}

        for _, eventAndHash in ipairs(ns.db.history) do
            local event = eventAndHash[1]

            local ts = event[1]
            local issuer = event[3]
            local players = event[4]
            local type = event[5]
            local value = event[6]
            local reason = event[7]
            local perc = event[8]

            -- issuer
            issuer = ns.Lib.getShortPlayerGuid(issuer)

            -- players
            local newPlayers = {}
            for _, guid in ipairs(players) do
                tinsert(newPlayers, ns.Lib.getShortPlayerGuid(guid))
            end

            -- reason
            local bench = false
            if ns.Lib.strEndsWith(reason, ' BENCH') then
                bench = true
                reason = reason:sub(0, #reason - 6)
            end

            if ns.Lib.strStartsWith(reason, 'manual_single:') then
                local details = string.match(reason, '^manual_single: (.*)$')
                if not details then
                    details = ''
                end
                reason = ns.Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE, details)
            elseif ns.Lib.strStartsWith(reason, 'manual_multiple:') then
                local details = string.match(reason, '^manual_multiple: (.*)$')
                if not details then
                    details = ''
                end
                reason = ns.Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, details, bench)
            elseif ns.Lib.strStartsWith(reason, 'decay:') then
                local details = string.match(reason, '^decay: (.*)$')
                if not details then
                    details = ''
                end
                reason = ns.Lib.getEventReason(ns.values.epgpReasons.DECAY, details)
            elseif ns.Lib.strStartsWith(reason, 'award:') then
                local itemName, rollType = string.match(reason, '^award: (.+) %- (%u%u) %- .+$')
                reason = ns.Lib.getEventReason(ns.values.epgpReasons.AWARD, rollType, itemName)
            elseif ns.Lib.strStartsWith(reason, 'boss_kill:') then
                local bossId = string.match(reason, '^boss_kill: ".+" %((%d+)%)')
                reason = ns.Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, bossId, bench)
            else
                error('unknown reason: ' .. reason)
            end

            -- create and insert event
            local newEvent = {ts, issuer, newPlayers, type, value, reason, perc}
            local newHash = ns.Lib.hash(newEvent)
            local newEventAndHash = {newEvent, newHash}

            tinsert(newHistory, newEventAndHash)
        end

        ns.db.history = newHistory

        ns.db.historyVersion = 1
    end

    if ns.db.historyVersion == 1 then
        ns.debug('migrating history to v2')

        for _, eventAndHash in ipairs(ns.db.history) do
            local newHash = ns.Lib.hash(eventAndHash[1])
            eventAndHash[2] = newHash
        end

        ns.db.historyVersion = 2
    end

    if ns.db.historyVersion == 2 then
        ns.debug('migrating history to v3')

        for _, eventAndHash in ipairs(ns.db.history) do
            local event = eventAndHash[1]
            if event[7] == nil then
                event[7] = false
            end

            event[8] = ns.cfg.gpBase

            local newHash = ns.Lib.hash(eventAndHash[1])
            eventAndHash[2] = newHash
        end

        ns.db.historyVersion = 3
    end

    if ns.db.historyVersion == 3 then
        ns.debug('migrating history to v4 (removing history)')
        ns.db.history = {}
        ns.db.historyVersion = 4
    end

    -- GP SLOT MODIFIERS
    if not ns.db.slotModifiersVersion then
        ns.debug('migrating slot modifiers to v1')
        ns.db.cfg.gpSlotMods = nil
        ns.db.slotModifiersVersion = 1
    end

    ns.debug('done migrating data')

    ns.debug('testing b64 encoding...')
    for _, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]
        local hash = eventAndHash[2]

        local ts = event[1]

        local encodedTs = ns.Lib.b64Encode(ts)
        assert(ts == ns.Lib.b64Decode(encodedTs))

        local encodedHash = ns.Lib.b64Encode(hash)
        assert(hash == ns.Lib.b64Decode(encodedHash))
    end
    ns.debug('done')
end


function addon:loadGuildRoster()
    local guildMembers = Set:new()

    for i = 1, GetNumGuildMembers() do
        local fullName, _, rankIndex, _, _, _, _, _, _, _, classFilename, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if fullName ~= nil then
            local name = self.getCharName(fullName)

            ns.Lib.createKnownPlayer(guid, name, classFilename, true, rankIndex)
            guildMembers:add(guid)
        end
    end

    for guid, playerData in ns.knownPlayers:iter() do
        if playerData.inGuild and not guildMembers:contains(guid) then
            playerData.inGuild = false
            playerData.rankIndex = nil
        end
    end
end


function addon:loadRaidRoster()
    self.raidRoster:clear()

    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            local name, _, _, _, _, classFilename, _, online, _, _, isMl, _ = GetRaidRosterInfo(i)

            if name ~= nil then
                self.raidRoster:set(name, {
                    online = online,
                    ml = isMl,
                })

                local guid = ns.Lib.getPlayerGuid(name)

                if not ns.knownPlayers:contains(guid) then
                    ns.Lib.createKnownPlayer(guid, name, classFilename, false, nil)
                end
            end
        end
    end

    ns.MainWindow:refresh()
end


---@param events table
---@param callback function
function addon.loadPlayersFromEvents(events, callback)
    callback = callback or function() end

    local shortToFullGuids = Dict:new()

    local uniquePlayersSeen = 0
    local uniquePlayersLoaded = 0

    local seenAll = false
    local callbackCalled = false

    for _, eventAndHash in ipairs(events) do
        local event = eventAndHash[1]
        local players = event[3]

        for _, guidShort in ipairs(players) do
            local guid = shortToFullGuids:get(guidShort)
            if guid == nil then
                guid = ns.Lib.getFullPlayerGuid(guidShort)
                shortToFullGuids:set(guidShort, guid)

                uniquePlayersSeen = uniquePlayersSeen + 1

                ns.Lib.getPlayerInfo(guid, function()
                    uniquePlayersLoaded = uniquePlayersLoaded + 1
                    if seenAll and uniquePlayersLoaded == uniquePlayersSeen then
                        callback()
                        callbackCalled = true
                    end
                end)
            end
        end
    end

    seenAll = true

    if not callbackCalled and uniquePlayersLoaded == uniquePlayersSeen then
        callback()
    end
end


---@param callback function?
function addon:computeStandings(callback)
    ns.standings:clear()
    ns.playersLastUpdated:clear()
    self:computeStandingsWithEvents(ns.db.history, callback)
end


---@param events table
---@param callback function?
function addon:computeStandingsWithEvents(events, callback)
    callback = callback or function(_) end

    local shortToFullGuids = Dict:new()

    self.loadPlayersFromEvents(events, function()
        local playerDiffs = Dict:new()

        for _, eventAndHash in ipairs(events) do
            local event = eventAndHash[1]
            local ts = event[1]
            local players = event[3]
            local mode = event[4]
            local value = event[5]
            local percent = event[7]
            local minGp = event[8]

            local mains = Set:new()

            for _, guidShort in ipairs(players) do
                local guid = shortToFullGuids:get(guidShort)
                if guid == nil then
                    guid = ns.Lib.getFullPlayerGuid(guidShort)
                    shortToFullGuids:set(guidShort, guid)
                end

                local lastUpdated = ns.playersLastUpdated:get(guid)
                if lastUpdated == nil or ts > lastUpdated then
                    ns.playersLastUpdated:set(guid, ts)
                end

                if not playerDiffs:contains(guid) then
                    playerDiffs:set(guid, {ep = 0, gp = 0})
                end

                local playerStandings = ns.standings:get(guid)
                if playerStandings == nil then
                    playerStandings = self.createStandingsEntry(guid)
                    ns.standings:set(guid, playerStandings)
                end

                local oldValue = playerStandings[mode]
                local newValue

                if percent then
                    -- value is expected to be something like -10, meaning decrease by 10%
                    local multiplier = (100 + value) / 100
                    newValue = oldValue * multiplier
                else
                    newValue = oldValue + value
                end

                if mode == ns.consts.MODE_GP and newValue < minGp then
                    newValue = minGp
                end

                playerStandings[mode] = newValue

                local diff = newValue - oldValue
                local playerDiff = playerDiffs:get(guid)
                playerDiff[mode] = playerDiff[mode] + diff

                local playerData = ns.knownPlayers:get(guid)
                local playerName = playerData.name
                local main = ns.db.altData.altMainMapping[playerName]
                if main ~= nil then
                    mains:add(main)
                end
            end

            -- sync alts
            if ns.cfg.syncAltEp or ns.cfg.syncAltGp then
                for main in mains:iter() do
                    local alts = ns.db.altData.mainAltMapping[main]
                    if alts ~= nil then
                        local mainGuid = ns.Lib.getPlayerGuid(main)

                        local lastUpdatedGuid = self.getLastUpdatedToon(mainGuid)
                        local lastUpdatedStandings = ns.standings:get(lastUpdatedGuid)
                        if lastUpdatedStandings == nil then
                            lastUpdatedStandings = self.createStandingsEntry(lastUpdatedGuid)
                            ns.standings:set(lastUpdatedGuid, lastUpdatedStandings)
                        end

                        for _, alt in ipairs(alts) do
                            local altGuid = ns.Lib.getPlayerGuid(alt)
                            local altStandings = ns.standings:get(altGuid)
                            if altStandings == nil then
                                altStandings = self.createStandingsEntry(altGuid)
                                ns.standings:set(altGuid, altStandings)
                            end

                            if ns.cfg.syncAltEp then
                                altStandings.ep = lastUpdatedStandings.ep
                            end

                            if ns.cfg.syncAltGp then
                                altStandings.gp = lastUpdatedStandings.gp
                            end
                        end
                    end
                end
            end
        end

        for guid, playerData in ns.knownPlayers:iter() do
            if not ns.standings:contains(guid) and playerData.inGuild then
                playerData = self.createStandingsEntry(guid)
                ns.standings:set(guid, playerData)
            end
        end

        local function finalize()
            if not ns.cfg.syncAltEp and not ns.cfg.syncAltGp then
                return
            end

            for playerName in pairs(ns.db.altData.mainAltMapping) do
                local playerGuid = ns.Lib.playerNameToGuid[playerName]

                local mostRecentGuid = self.getLastUpdatedToon(playerGuid)

                for _, toon in ipairs(ns.db.altData.mainAltMapping[playerName]) do
                    local toonGuid = ns.Lib.playerNameToGuid[toon]

                    if toonGuid ~= mostRecentGuid and ns.standings:contains(toonGuid) and ns.standings:contains(mostRecentGuid) then
                        local toonStandings = ns.standings:get(toonGuid)
                        local mostRecentStandings = ns.standings:get(mostRecentGuid)

                        if ns.cfg.syncAltEp then
                            toonStandings.ep = mostRecentStandings.ep
                        end

                        if ns.cfg.syncAltGp then
                            toonStandings.gp = mostRecentStandings.gp
                        end
                    end
                end
            end
        end

        local i = 0
        for guid in ns.standings:iter() do
            i = i + 1
            ns.Lib.getPlayerInfo(guid, function(_)
                if i >= ns.standings:len() then
                    finalize()
                    ns.MainWindow:refresh()
                    callback(playerDiffs)
                end
            end)
        end
    end)
end


---@param guid string
---@return table
function addon.createStandingsEntry(guid)
    return {
        guid = guid,
        [ns.consts.MODE_EP] = 0,
        [ns.consts.MODE_GP] = ns.cfg.gpBase,
    }
end


function addon.fixGp()
    for _, playerData in pairs(ns.standings) do
        local min = ns.cfg.gpBase
        if playerData.gp == nil or playerData.gp < min then
            playerData.gp = min
        end
    end
end


function addon.clearAwarded()
    local now = time()

    local newAwarded = {}

    for itemLink, itemData in pairs(ns.db.loot.awarded) do
        for awardee, awardeeData in pairs(itemData) do
            local awardTime = awardeeData.awardTime

            if awardTime ~= nil then
                if now - awardTime < 7200 then  -- 2 hours
                    if newAwarded[itemLink] == nil then
                        newAwarded[itemLink] = {}
                    end

                    if newAwarded[itemLink][awardee] == nil then
                        newAwarded[itemLink][awardee] = {}
                    end

                    newAwarded[itemLink][awardee] = awardeeData
                end
            end
        end
    end

    ns.db.loot.awarded = newAwarded

    local newToTrade = {}

    for player, items in pairs(ns.db.loot.toTrade) do
        for _, itemData in ipairs(items) do
            if type(itemData) == 'table' then
                local ts = itemData[2]

                if now - ts < 7200 then
                    if newToTrade[player] == nil then
                        newToTrade[player] = {}
                    end

                    tinsert(newToTrade[player], itemData)
                end
            end
        end
    end

    ns.db.loot.toTrade = newToTrade
end


function addon.getCharName(fullName)
    local nameDash = string.find(fullName, '-')

    if nameDash == nil then
        return fullName
    end

    local name = string.sub(fullName, 0, nameDash - 1)
    return name
end


function addon.handleHeartbeat(message, sender)
    if ns.peers == nil then
        return
    end

    local ts = time()
    local senderVersion = message.v
    local senderGuid = ns.Lib.getPlayerGuid(sender)

    ns.peers:set(senderGuid, {ts = ts, version = senderVersion})

    if not addon.outOfDateMessageSent then
        if ns.addon.versionNum < senderVersion then
            ns.print('addon is out of date! Please download the latest version from CurseForge or WoWInterface.')
            addon.outOfDateMessageSent = true
        end
    end
end


function addon.sendHeartbeat()
    ns.Comm:send(ns.Comm.msgTypes.HEARTBEAT, nil, 'GUILD')
end


function addon.handleRollPass(_, sender)
    ns.LootDistWindow:handlePass(sender)
end


function addon.sendRollPass()
    local ml = ns.Lib.getMl()
    if ml ~= nil then
        ns.Comm:send(ns.Comm.msgTypes.ROLL_PASS, nil, 'WHISPER', ml)
    end
end


function addon:housekeepPeers()
    local now = time()

    local toRemove = Set:new()

    for guid, peerData in ns.peers:iter() do
        if now - peerData.ts >= 180 then
            toRemove:add(guid)
        end
    end

    for guid in toRemove:iter() do
        ns.peers:remove(guid)
    end
end


---@param players table
---@param mode 'ep' | 'gp'
---@param value number
---@param reason string
---@param percent boolean?
---@return table
function addon.createHistoryEvent(players, mode, value, reason, percent)
    percent = percent or false

    local ts = time()

    local issuer = ns.Lib.getShortPlayerGuid(ns.unitGuid('player'))

    local newPlayers = {}
    for _, guid in ipairs(players) do
        tinsert(newPlayers, ns.Lib.getShortPlayerGuid(guid))
    end

    local minGp = ns.cfg.gpBase

    local event = {ts, issuer, newPlayers, mode, value, reason, percent, minGp}
    local hash = ns.Lib.hash(event)
    local eventAndHash = {event, hash}

    return eventAndHash
end


---@param players table
---@param mode 'ep' | 'gp'
---@param value number
---@param reason string
---@param percent boolean?
function addon:modifyEpgp(players, mode, value, reason, percent)
    if not ns.cfg.lmMode then
        error('Cannot modify EPGP when loot master mode is off')
        return
    end

    if mode ~= ns.consts.MODE_EP and mode ~= ns.consts.MODE_GP then
        error(string.format('Mode (%s) is not one of allowed modes', mode))
        return
    end

    if #players == 0 then
        ns.print('Won\'t modify EP/GP for 0 players')
        return
    end

    local event = self.createHistoryEvent(players, mode, value, reason, percent)
    tinsert(ns.db.history, event)

    self:computeStandingsWithEvents({event}, function(playerDiffs)
        for guid, diffData in playerDiffs:iter() do
            for theMode, diff in pairs(diffData) do
                if diff ~= 0 then
                    local verb = 'gained'
                    local amount = diff

                    if diff < 0 then
                        verb = 'lost'
                        amount = -diff
                    end

                    local baseReason = tonumber(ns.Lib.split(reason, ':')[1])
                    local baseReasonPretty = ns.HistoryWindow.epgpReasonsPretty[baseReason]

                    local playerData = ns.knownPlayers:get(guid)

                    ns.debug(string.format('%s %s %.2f %s (%s)', playerData.name, verb, amount, string.upper(theMode), baseReasonPretty))
                end
            end
        end
    end)

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    ns.Sync:sendEventsToGuild({event})
end


---@param playerGuid string
---@return string
function addon.getLastUpdatedToon(playerGuid)
    local mostRecentGuid = playerGuid

    local playerData = ns.knownPlayers:get(playerGuid)
    local player = playerData.name

    local main = ns.db.altData.altMainMapping[player]

    if main ~= nil then
        local alts = ns.db.altData.mainAltMapping[main]

        if alts ~= nil then
            local playerLastUpdated = ns.playersLastUpdated:get(playerGuid)

            local mostRecentTs = playerLastUpdated
            for _, alt in ipairs(alts) do
                if alt ~= player then
                    local altGuid = ns.Lib.getPlayerGuid(alt)

                    local altLastUpdated = ns.playersLastUpdated:get(altGuid)
                    if altLastUpdated ~= nil and (mostRecentTs == nil or altLastUpdated > mostRecentTs) then
                        mostRecentTs = altLastUpdated
                        mostRecentGuid = altGuid
                    end
                end
            end
        end
    end

    return mostRecentGuid
end


function addon:initMinimapButton()
    local minimapButton = self.ldb:NewDataObject(addonName, {
        type = 'launcher',
        text = addonName,
        icon = 'Interface\\AddOns\\' ..  addonName .. '\\Assets\\icon',
        OnClick = function(_, button)
            if button == 'LeftButton' then
                addon.showMainWindow()
            elseif button == 'RightButton' then
                addon.openOptions();
            elseif button == 'MiddleButton' then
                ns.HistoryWindow:createWindow()
                ns.HistoryWindow:show()
            end
        end,
        OnEnter = function(buttonFrame)
            local inRaidText = ''
            if IsInRaid() and IsMasterLooter() then
                inRaidText = string.format(
                    '\n%s is %s for this raid\n',
                    addonName,
                    addon.useForRaid and "|cFF00FF00active|r|c00FFC100" or "|cFFFF0000inactive|r|c00FFC100"
                )
            end
            local text = string.format(
                '%s\n' ..
                'Version: %s\n' ..
                '%s\n' ..
                'Left Click: Open the main window\n' ..
                'Middle Click: Open the history window\n' ..
                'Right Click: Open the configuration menu',
                addonName, addon.version, inRaidText
            )
            GameTooltip:SetOwner(buttonFrame, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText(text)
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end
    })

    self.ldbi:Register(addonName, minimapButton, ns.cfg.minimap)

    self.minimapButtonInitialized = true
end


function addon:showUseForRaidWindow()
    ns.ConfirmWindow:show(('Use %s for this raid?'):format(addonName),
                          function()   -- callback for "Yes"
                              self.useForRaid = true
                              self.useForRaidPrompted = true
                              self:loadRaidRoster()
                          end,
                          function()  -- callback for "No"
                              self.useForRaid = false
                              self.useForRaidPrompted = true
                          end)
end


function addon:clearData()
    ns.db.history = {}

    self:computeStandings()

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    if IsInGuild() then
        self:handleGuildRosterUpdate()
    end
end


function addon.modifiedLmSettings()
    ns.db.lmSettingsLastChange = time()
    ns.Sync:sendLmSettingsToGuild()
end


-----------------
-- EVENT HANDLERS
-----------------
function addon:handleChatMsg(_, message)
    local duration, itemLink = string.match(message, addonName .. ': You have (%d-) seconds to roll on (.+)')
    if duration then
        duration = tonumber(duration)
        ns.RollWindow:show(itemLink, duration)
        return
    end

    if message == addonName .. ': Stop your rolls!' then
        ns.RollWindow:hide()
        return
    end

    local playerName = string.match(message, '(%S+) has gone offline.')
    if playerName then
        playerName = self.getCharName(playerName)
        local guid = ns.Lib.getPlayerGuid(playerName)
        ns.peers:remove(guid)
        return
    end

    if not ns.cfg or not ns.cfg.lmMode then
        return
    end

    local roller, roll, low, high = string.match(message, ns.LootDistWindow.rollPattern)
    if roller and (self.raidRoster:contains(roller) or roller == ns.unitName('player')) then
        roll = tonumber(roll) or 0
        low = tonumber(low) or 0
        high = tonumber(high) or 0

        local rollType
        if low == 1 then
            if high == 100 then
                rollType = 'MS'
            elseif high == 99 then
                rollType = 'OS'
            end
        end

        if rollType ~= nil then
            ns.debug('got roll')
            ns.LootDistWindow:handleRoll(roller, roll, rollType)
            return
        end
    end
end


function addon:handleChatMsgWhisper(_, message, playerFullName)
    local parts = ns.Lib.split(message, ' ')
    local command = parts[1]

    if command == self.whisperCommands.INFO then
        local name
        if parts[2] ~= nil then
            name = parts[2]
        else
            name = self.getCharName(playerFullName)
        end

        local guid = ns.Lib.getPlayerGuid(name)

        if guid == nil or not ns.standings:contains(guid) then
            local msgName = 'You'
            local msgWord = 'aren\'t'
            if parts[2] ~= nil then
                msgName = parts[2]
                msgWord = 'isn\'t'
            end

            SendChatMessage(string.format('%s %s in the standings!', msgName, msgWord), 'WHISPER', nil, playerFullName)
            return
        end

        local playerStandings = ns.standings:get(guid)
        local playerEp = playerStandings.ep
        local playerGp = playerStandings.gp
        local playerPr = playerEp / playerGp

        local sortedStandings = List:new()
        for g, standings in ns.standings:iter() do
            local playerData = ns.knownPlayers:get(g)

            local combined = ns.Lib.deepcopy(standings)
            combined.name = playerData.name
            combined.inGuild = playerData.inGuild

            sortedStandings:bininsert(combined, function(left, right)
                local prLeft = left.ep / left.gp
                local prRight = right.ep / right.gp

                return prLeft > prRight
            end)
        end

        local overallRank
        local guildRank
        local raidRank

        local j = 1  -- guild index
        local k = 1  -- raid index
        for i, playerData in sortedStandings:iter() do
            if playerData.name == name then
                overallRank = i
                guildRank = j
                raidRank = k
                break
            end

            if playerData.inGuild then
                j  = j + 1
            end

            if self.raidRoster:contains(playerData.name) then
                k = k + 1
            end
        end

        local reply = string.format(
            'Standings for %s - EP: %.2f / GP: %.2f / PR: %.3f - Rank: Overall: #%d / Guild: #%d',
            name, playerEp, playerGp, playerPr, overallRank, guildRank
        )

        if self.raidRoster:contains(name) then
            reply = string.format('%s / Raid: #%d', reply, raidRank)
        end

        SendChatMessage(reply, 'WHISPER', nil, playerFullName)
    else
        return
    end
end


function addon:handleTradeRequest(player)
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow.handleTradeRequest(player)
end


function addon:handleTradeShow()
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow:handleTradeShow()
end


function addon:handleTradePlayerItemChanged()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:handleTradePlayerItemChanged()
end


function addon:handleEnteredRaid()
    self:loadRaidRoster()

    if ns.cfg and ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() and not self.useForRaidPrompted then
        self:showUseForRaidWindow()
    end
end


function addon:handlePartyLootMethodChanged()
    if ns.cfg and ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() then
        if not self.useForRaid then
            self:showUseForRaidWindow()
        end
    else
        self.useForRaid = false
        self.useForRaidPrompted = false
    end
end


function addon:handleLootReady()
    if not ns.cfg or not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:getLoot()
end


function addon:handleLootClosed()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:clearLoot()
end


function addon:handleChatMsgLoot(_, msg)
    if ns.cfg == nil or not ns.cfg.lmMode then
        return
    end

    local player, itemLink = msg:match('(%a+) receives? loot: (.+)%.')

    if player == nil or itemLink == nil then
        return
    end

    ns.LootDistWindow:handleLootReceived(itemLink, player)
end


function addon:handleUiInfoMessage(_, _, msg)
    if not ns.cfg.lmMode then
        return
    end

    if msg == ERR_TRADE_COMPLETE then
        ns.LootDistWindow:handleTradeComplete()
    end
end


---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@param encounterId number
---@param encounterName string
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@param success number
function addon:handleEncounterEnd(_, encounterId, encounterName, _, _, success)
    if not self.useForRaid or
            success ~= 1 then
        return
    end

    local ep = ns.cfg.encounterEp[encounterId]

    if ep == nil then
        ns.print(string.format('Encounter %d (%s) not in encounters table!', encounterId, encounterName))
        return
    end

    local proceedFunc = function()
        local reason = ns.Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, encounterId)
        local players = {}

        for player in self.raidRoster:iter() do
            local guid = ns.Lib.getPlayerGuid(player)
            tinsert(players, guid)
        end

        self:modifyEpgp(players, ns.consts.MODE_EP, ep, reason)

        if #ns.db.benchedPlayers > 0 then
            local benchedPlayers = {}
            for _, player in ipairs(ns.db.benchedPlayers) do
                local guid = ns.Lib.getPlayerGuid(player)
                tinsert(benchedPlayers, guid)
            end

            local benchedReason = ns.Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, encounterId, true)
            self:modifyEpgp(benchedPlayers, ns.consts.MODE_EP, ep, benchedReason)
        end

        ns.printPublic(string.format('Awarded %d EP to raid for killing %s', ep, encounterName))
    end

    C_Timer.After(2, function()
        ns.ConfirmWindow:show(string.format('Award %s EP to raid for killing %s?', ep, encounterName), proceedFunc)
    end)
end


function addon:handleTooltipUpdate(frame)
    if frame == nil or not self.initialized then
        return
    end

    local _, itemLink = frame:GetItem()

    if not itemLink or itemLink == nil or itemLink == '' then
        return
    end

    local itemId = ns.Lib.getItemIdFromLink(itemLink)
    if not ns.Lib.itemExists(itemId) then
        return
    end

    -- add GP to tooltip
    local classFilename = UnitClassBase('player')
    local spec = ns.Lib.getSpecName(classFilename, ns.Lib.getActiveSpecIndex())

    ns.Lib.getItemInfo(itemLink, function(itemInfo)
        local gpBase = itemInfo.gp
        local gpYours = ns.Lib.getGpWithInfo(itemInfo, classFilename, spec)

        if gpBase == nil then
            gpBase = '?'
        end

        if gpYours == nil then
            gpYours = '?'
        end

        frame:AddLine('GP: ' .. gpBase, 0.5, 0.6, 1)

        if gpYours ~= gpBase then
            frame:AddLine('Your GP: ' .. gpYours, 0.5, 0.6, 1)
        end

        -- add awarded list to tooltip
        local awardedList = List:new()

        local itemAwardedData = ns.db.loot.awarded[itemLink]
        if itemAwardedData ~= nil then
            for player, items in pairs(itemAwardedData) do
                for _, item in ipairs(items) do
                    local given = item.given

                    awardedList:bininsert({player, given}, function(left, right)
                        return left[1] < right[1]
                    end)
                end
            end
        end

        if awardedList:len() > 0 then
            frame:AddLine('Awarded To')

            for awardedItem in awardedList:iter() do
                local player = awardedItem[1]
                local given = awardedItem[2] and 'yes' or 'no'

                local _, playerClassFilename = UnitClass(player)
                local classColor = RAID_CLASS_COLORS[playerClassFilename]

                if classColor ~= nil then
                    local playerColored = classColor:WrapTextInColorCode(player)
                    frame:AddLine(string.format('  %s | Given: %s', playerColored, given))
                end
            end
        end
    end)
end
