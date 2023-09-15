local addonName, ns = ...  -- Namespace

local Set = ns.Set
local Dict = ns.Dict

local Comm = {
    prefixes = {
        SYNC_PROBE = 'CE_sync-probe',
        STANDINGS = 'CE_standings',
        HISTORY = 'CE_history',
        LM_SETTINGS = 'CE_lm-settings',
        UPDATE = 'CE_update',
        ROLL_PASS = 'CE_pass',
        SYNC_OLD = 'CE_sync',
    },
    eventHashes = Set:new(),
    otherClientVersions = Dict:new(),
}

ns.Comm = Comm


local officerReq = {
    [Comm.prefixes.SYNC_PROBE] = false,
    [Comm.prefixes.STANDINGS] = true,
    [Comm.prefixes.HISTORY] = true,
    [Comm.prefixes.LM_SETTINGS] = true,
    [Comm.prefixes.UPDATE] = true,
    [Comm.prefixes.ROLL_PASS] = false,
    [Comm.prefixes.SYNC_OLD] = false,
}


function Comm:init()
    for _, prefix in pairs(self.prefixes) do
        ns.addon:RegisterComm(prefix, self.handleMessage)
    end
end


---@param prefix string
---@param message? table
---@param distribution string
---@param target? string
function Comm:send(prefix, message, distribution, target)
    local debugMsg = string.format('sending %s msg to ', prefix)
    if distribution == 'WHISPER' then
        debugMsg = debugMsg .. target
    else
        debugMsg = debugMsg .. distribution
    end
    ns.debug(debugMsg)

    if officerReq[prefix] and not ns.Lib.isOfficer() then
        ns.debug('-- you are not an officer; not sending message')
        return
    end

    if message == nil then
        message = {}
    end

    message.version = ns.addon.versionNum

    local messageStr = self.packMessage(message)
    ns.addon:SendCommMessage(prefix, messageStr, distribution, target)
end


function Comm:syncInit()
    ns.debug('initializing sync; sending my latest event time to all guildies')
    self:getEventHashes()

    self:sendSyncProbe('GUILD', nil, true, true)
end


function Comm:getEventHashes()
    self.eventHashes:clear()

    for _, eventAndHash in ipairs(ns.db.history) do
        local hash = eventAndHash[2]
        self.eventHashes:add(hash)
    end
end

function Comm.getLatestEventTime()
    local latestEventAndHash = ns.db.history[#ns.db.history]

    if latestEventAndHash == nil then
        return -1
    end

    local latestEvent = latestEventAndHash[1]

    return latestEvent[1]
end


function Comm.handleMessage(prefix, message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug(string.format('got message %s from %s', prefix, sender))

    message = Comm.unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion == nil then
        ns.debug('-- client version unknown (probably out of date)')
        return
    end

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format(
            '-- client version (%s) less than minimum (%s)',
            ns.Lib.getVersionStr(theirAddonVersion),
            ns.Lib.getVersionStr(ns.minSyncVersion)
        ))
        return
    end

    if officerReq[prefix] and not ns.Lib.isOfficer(sender) then
        ns.debug('-- they are not an officer; rejecting message')
        return
    end

    local prefixes = Comm.prefixes

    if prefix == prefixes.UPDATE then
        Comm:handleUpdate(sender)
    elseif prefix == prefixes.SYNC_PROBE then
        Comm:handleSyncProbe(message, sender)
    elseif prefix == prefixes.STANDINGS then
        Comm.handleStandings(message)
    elseif prefix == prefixes.HISTORY then
        Comm.handleHistory(message)
    elseif prefix == prefixes.LM_SETTINGS then
        Comm.handleLmSettings(message)
    elseif prefix == prefixes.ROLL_PASS then
        Comm.handleRollPass(sender)
    elseif prefix == prefixes.SYNC_OLD then
        Comm.handleSyncOld(theirAddonVersion)
    end
end


function Comm:handleUpdate(sender)
    self:sendSyncProbe('WHISPER', sender, true, true)
end


function Comm:handleSyncProbe(message, sender)
    local theirLatestEventTime = message.latestEventTime
    local theirLmSettingsLastChange = message.lmSettingsLastChange

    if theirLatestEventTime ~= nil then
        local myLatestEventTime = self.getLatestEventTime()
        if theirLatestEventTime < myLatestEventTime then
            -- they are behind me
            ns.debug(string.format(
                '---- they are behind me; sending new events and standings (%d < %d)',
                theirLatestEventTime,
                myLatestEventTime
            ))

            self:sendStandingsToTarget(sender)
            self:sendHistory(sender, theirLatestEventTime)
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.debug(string.format(
                '---- they are ahead of me; sending sync-probe (%d > %d)',
                theirLatestEventTime,
                myLatestEventTime
            ))

            self:sendSyncProbe('WHISPER', sender, true, false)
        end
    end

    if theirLmSettingsLastChange ~= nil then
        if theirLmSettingsLastChange < ns.db.lmSettingsLastChange then
            -- their LM settings are behind mine
            ns.debug(string.format(
                '---- their LM settings are behind mine; sending updated settings (%d < %d)',
                theirLmSettingsLastChange,
                ns.db.lmSettingsLastChange
            ))

            self:sendLmSettingsToTarget(sender)
        elseif theirLmSettingsLastChange > ns.db.lmSettingsLastChange then
            -- their LM settings are ahead of mine
            self:sendSyncProbe('WHISPER', sender, false, true)
        end
    end
end


function Comm.handleStandings(message)
    ns.db.standings = message.standings
    ns.MainWindow:refresh()
end


function Comm.handleHistory(message)
    local events = message.events

    ns.debug(string.format('-- len: %d', #events))

    local fcomp = function(left, right)
        return left[1][1] < right[1][1]
    end

    Comm:getEventHashes()

    for _, eventAndHash in ipairs(events) do
        local hash = eventAndHash[2]

        if not Comm.eventHashes:contains(hash) then
            ns.Lib.bininsert(ns.db.history, eventAndHash, fcomp)
            Comm.eventHashes:add(hash)
        end
    end

    ns.HistoryWindow:refresh()
end


function Comm.handleLmSettings(message)
    local lmSettings = message.settings

    ns.cfg.defaultDecay = lmSettings.defaultDecay
    ns.cfg.syncAltEp = lmSettings.syncAltEp
    ns.cfg.syncAltGp = lmSettings.syncAltGp
    ns.cfg.gpBase = lmSettings.gpBase
    ns.cfg.gpSlotMods = lmSettings.gpSlotMods
    ns.cfg.encounterEp = lmSettings.encounterEp
    ns.db.altData.mainAltMapping = lmSettings.mainAltMapping

    if lmSettings.lmSettingsLastChange ~= nil then
        ns.db.lmSettingsLastChange = lmSettings.lmSettingsLastChange
    end

    LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end


function Comm.handleRollPass(sender)
    ns.LootDistWindow:handlePass(sender)
end


function Comm:sendUpdate()
    self:send(self.prefixes.UPDATE, nil, 'GUILD')
end


function Comm:sendSyncProbe(distribution, target, latestEventTime, lmSettingsLastChange)
    local toSend = {}

    if latestEventTime then
        toSend.latestEventTime = self.getLatestEventTime()
    end

    if lmSettingsLastChange then
        toSend.lmSettingsLastChange = ns.db.lmSettingsLastChange
    end

    self:send(self.prefixes.SYNC_PROBE, toSend, distribution, target)
end


function Comm:sendStandings(distribution, target)
    local toSend = {
        standings = ns.db.standings,
    }

    self:send(self.prefixes.STANDINGS, toSend, distribution, target)
end


function Comm:sendStandingsToTarget(target)
    self:sendStandings('WHISPER', target)
end


function Comm:sendStandingsToGuild()
    self:sendStandings('GUILD')
end


function Comm:sendHistory(target, theirLatestEventTime)
    local toSend = {}

    local newEvents = {}
    for i = #ns.db.history, 1, -1 do
        local eventAndHash = ns.db.history[i]
        local event = eventAndHash[1]

        if event[1] <= theirLatestEventTime then
            break
        end

        tinsert(newEvents, eventAndHash)

        if #newEvents == 100 then
            toSend.events = newEvents

            ns.debug(string.format('sending a batch of %d history events to %s', #newEvents, target))
            self:send(self.prefixes.HISTORY, toSend, 'WHISPER', target)
            newEvents = {}
        end
    end

    if #newEvents > 0 then
        toSend.events = newEvents

        ns.debug(string.format('sending a batch of %d history events to %s', #newEvents, target))
        self:send(self.prefixes.HISTORY, toSend, 'WHISPER', target)
    end
end


function Comm:sendEventToGuild(eventAndHash)
    local toSend = {
        events = {eventAndHash}
    }

    self:send(self.prefixes.HISTORY, toSend, 'GUILD')
end


function Comm:sendLmSettings(distribution, target)
    local toSend = {
        settings = {
            defaultDecay = ns.cfg.defaultDecay,
            syncAltEp = ns.cfg.syncAltEp,
            syncAltGp = ns.cfg.syncAltGp,
            gpBase = ns.cfg.gpBase,
            gpSlotMods = ns.cfg.gpSlotMods,
            encounterEp = ns.cfg.encounterEp,
            mainAltMapping = ns.db.altData.mainAltMapping,
            lmSettingsLastChange = ns.db.lmSettingsLastChange,
        },
    }

    self:send(self.prefixes.LM_SETTINGS, toSend, distribution, target)
end


function Comm:sendLmSettingsToTarget(target)
    self:sendLmSettings('WHISPER', target)
end


function Comm:sendLmSettingsToGuild()
    self:sendLmSettings('GUILD')
end


function Comm:sendRollPass()
    local ml = ns.Lib.getMl()
    self:send(self.prefixes.ROLL_PASS, nil, 'WHISPER', ml)
end


---@param message any
---@return string
function Comm.packMessage(message)
    local package = ns.addon:Serialize(message)
    package = ns.addon.libc:CompressHuffman(package)
    package = ns.addon.libcEncodeTable:Encode(package)

    return package
end


---@param package string
---@return any
function Comm.unpackMessage(package)
    local message = ns.addon.libcEncodeTable:Decode(package)

    local error
    message, error = ns.addon.libc:Decompress(message)

    if message == nil then
        ns.debug(string.format('could not decompress message. error: %s', error))
        return nil
    end

    local success
    success, message = ns.addon:Deserialize(message)

    if not success then
        ns.debug('could not deserialize message')
        return nil
    end

    return message
end


function Comm.handleSyncOld(theirAddonVersion)
    ns.debug(string.format('-- client version: %s', ns.Lib.getVersionStr(theirAddonVersion)))
end
