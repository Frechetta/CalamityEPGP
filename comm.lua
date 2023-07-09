local addonName, ns = ...  -- Namespace

local List = ns.List
local Set = ns.Set
local Dict = ns.Dict

local Comm = {
    prefixes = {
        SYNC_PROBE = 'CE_sync-probe',
        STANDINGS = 'CE_standings',
        HISTORY = 'CE_history',
        LM_SETTINGS = 'CE_lm-settings',
        UPDATE = 'CE_update',
    },
    eventHashes = Set:new(),
    guildiesMessaged = Set:new(),
    otherClientVersions = Dict:new(),
}

ns.Comm = Comm


function Comm:init()
    ns.addon:RegisterComm(self.prefixes.SYNC_PROBE, self.handleSyncProbe)
    ns.addon:RegisterComm(self.prefixes.STANDINGS, self.handleStandings)
    ns.addon:RegisterComm(self.prefixes.HISTORY, self.handleHistory)
    ns.addon:RegisterComm(self.prefixes.LM_SETTINGS, self.handleLmSettings)
    ns.addon:RegisterComm(self.prefixes.UPDATE, self.handleUpdate)
    ns.addon:RegisterComm('CE_sync', self.handleSyncOld)
end


function Comm:send(prefix, message, distribution, target)
    ns.debug(string.format('sending %s msg to %s via %s', prefix, tostring(target), distribution))

    message = self:packMessage(message)
    ns.addon:SendCommMessage(prefix, message, distribution, target)
end


function Comm:syncInit()
    ns.debug('initializing sync; sending my latest event time to all guildies')
    self:getEventHashes()

    self:sendSyncProbe('GUILD', nil, true, true)
end


function Comm:getEventHashes()
    self.eventHashes:clear()

    for i, eventAndHash in ipairs(ns.db.history) do
        local hash = eventAndHash[2]
        self.eventHashes:add(hash)
    end
end

function Comm:getLatestEventTime()
    local latestEventAndHash = ns.db.history[#ns.db.history]

    if latestEventAndHash == nil then
        return -1
    end

    local latestEvent = latestEventAndHash[1]

    return latestEvent[1]
end


function Comm:handleUpdate(_, _, sender)
    if sender == UnitName('player') then
        return
    end

    Comm:sendSyncProbe('WHISPER', sender, true, true)
end


function Comm:handleSyncProbe(message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug('got message sync-probe from ' .. sender)

    message = Comm:unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format('-- client version (%s) less than minimum (%s)', ns.Lib:getVersionStr(theirAddonVersion), ns.Lib:getVersionStr(ns.minSyncVersion)))
        return
    end

    local theirLatestEventTime = message.latestEventTime
    local theirLmSettingsLastChange = message.lmSettingsLastChange

    if theirLatestEventTime ~= nil then
        local myLatestEventTime = Comm:getLatestEventTime()
        if theirLatestEventTime < myLatestEventTime then
            -- they are behind me
            ns.debug(string.format('---- they are behind me; sending new events and standings (%d < %d)', theirLatestEventTime, myLatestEventTime))

            Comm:sendStandings(sender)
            Comm:sendHistory(sender, theirLatestEventTime)
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.debug(string.format('---- they are ahead of me; sending sync-probe (%d > %d)', theirLatestEventTime, myLatestEventTime))
            ns.debug('---- they are ahead of me; sending my latest event time')
            Comm:sendSyncProbe('WHISPER', sender, true, false)
        end
    end

    if theirLmSettingsLastChange ~= nil then
        if theirLmSettingsLastChange < ns.db.lmSettingsLastChange then
            -- their LM settings are behind mine
            ns.debug(string.format('---- their LM settings are behind mine; sending updated settings (%d < %d)', theirLmSettingsLastChange, ns.db.lmSettingsLastChange))
            Comm:sendLmSettings(sender)
        elseif theirLmSettingsLastChange > ns.db.lmSettingsLastChange then
            -- their LM settings are ahead of mine
            Comm:sendSyncProbe('WHISPER', sender, false, true)
        end
    end
end


function Comm:handleStandings(message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug('got message standings from ' .. sender)

    message = Comm:unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format('-- client version (%s) less than minimum (%s)', ns.Lib:getVersionStr(theirAddonVersion), ns.Lib:getVersionStr(ns.minSyncVersion)))
        return
    end

    ns.db.standings = message.standings

    ns.MainWindow:refresh()
end


function Comm:handleHistory(message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug(string.format('got message history from %s', sender))

    message = Comm:unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format('-- client version (%s) less than minimum (%s)', ns.Lib:getVersionStr(theirAddonVersion), ns.Lib:getVersionStr(ns.minSyncVersion)))
        return
    end

    local events = message.events

    ns.debug(string.format('-- len: %d', #events))

    local fcomp = function(left, right)
        return left[1][1] < right[1][1]
    end

    for _, eventAndHash in ipairs(events) do
        local hash = eventAndHash[2]

        if not Comm.eventHashes:contains(hash) then
            ns.Lib:bininsert(ns.db.history, eventAndHash, fcomp)
            -- tinsert(ns.db.history, eventAndHash)
            Comm.eventHashes:add(hash)
        end
    end

    ns.HistoryWindow:refresh()
end


function Comm:handleLmSettings(message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug('got message lm settings from ' .. sender)

    message = Comm:unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format('-- client version (%s) less than minimum (%s)', ns.Lib:getVersionStr(theirAddonVersion), ns.Lib:getVersionStr(ns.minSyncVersion)))
        return
    end

    local lmSettings = message.settings

    ns.cfg.defaultDecay = lmSettings.defaultDecay
    ns.cfg.syncAltEp = lmSettings.syncAltEp
    ns.cfg.syncAltGp = lmSettings.syncAltGp
    ns.cfg.gpBase = lmSettings.gpBase
    ns.cfg.gpSlotMods = lmSettings.gpSlotMods
    ns.cfg.encounterEp = lmSettings.encounterEp

    if lmSettings.lmSettingsLastChange ~= nil then
        ns.db.lmSettingsLastChange = lmSettings.lmSettingsLastChange
    end

    LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end


function Comm:sendSyncProbe(distribution, target, latestEventTime, lmSettingsLastChange)
    local toSend = {
        version = ns.addon.versionNum,
    }

    if latestEventTime then
        toSend.latestEventTime = self:getLatestEventTime()
    end

    if lmSettingsLastChange then
        toSend.lmSettingsLastChange = ns.db.lmSettingsLastChange
    end

    self:send(self.prefixes.SYNC_PROBE, toSend, distribution, target)
end


function Comm:sendStandings(target)
    local toSend = {
        version = ns.addon.versionNum,
        standings = ns.db.standings,
    }

    self:send(self.prefixes.STANDINGS, toSend, 'WHISPER', target)
end


function Comm:sendHistory(target, theirLatestEventTime)
    local toSend = {
        version = ns.addon.versionNum,
    }

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


function Comm:sendLmSettings(target)
    local toSend = {
        version = ns.addon.versionNum,
        settings = {
            defaultDecay = ns.cfg.defaultDecay,
            syncAltEp = ns.cfg.syncAltEp,
            syncAltGp = ns.cfg.syncAltGp,
            gpBase = ns.cfg.gpBase,
            gpSlotMods = ns.cfg.gpSlotMods,
            encounterEp = ns.cfg.encounterEp,
            lmSettingsLastChange = ns.db.lmSettingsLastChange,
        },
    }

    self:send(self.prefixes.LM_SETTINGS, toSend, 'WHISPER', target)
end


---@param message any
---@return string
function Comm:packMessage(message)
    local package = ns.addon:Serialize(message)
    package = ns.addon.libc:CompressHuffman(package)
    package = ns.addon.libcEncodeTable:Encode(package)

    return package
end


---@param package string
---@return any
function Comm:unpackMessage(package)
    local message = ns.addon.libcEncodeTable:Decode(package)
    local message, error = ns.addon.libc:Decompress(message)

    if message == nil then
        ns.debug(string.format('could not decompress message. error: %s', error))
        return nil
    end

    local success, message = ns.addon:Deserialize(message)

    if not success then
        ns.debug('could not deserialize message')
        return nil
    end

    return message
end


function Comm:handleSyncOld(message, _, sender)
    if sender == UnitName('player') then
        return
    end

    ns.debug('got OLD message sync from ' .. sender)

    message = Comm:unpackMessage(message)

    local theirAddonVersion = message.version

    Comm.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion == nil then
        ns.debug('-- client version unknown (probably out of date)')
        return
    end

    ns.debug(string.format('-- client version: %s', ns.Lib:getVersionStr(theirAddonVersion)))
end
