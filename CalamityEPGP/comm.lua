local addonName, ns = ...  -- Namespace

local Set = ns.Set

local Comm = {
    prefix = 'calepgp',
    msgTypes = {
        HEARTBEAT = 0,
        ROLL_PASS = 1,
        LM_SETTINGS = 2,
        SYNC_PROBE = 3,

        -- DEPRECATED
        STANDINGS = 50,
        HISTORY = 51,
        UPDATE = 52,
        SYNC_OLD = 53,
    },
    msgTypeNames = {},
    funcs = {},
    eventHashes = Set:new(),
}

ns.Comm = Comm

local officerReq = Set:new({
    Comm.msgTypes.HISTORY,
    Comm.msgTypes.LM_SETTINGS,
    Comm.msgTypes.UPDATE,
    Comm.msgTypes.STANDINGS,
})

for name, num in pairs(Comm.msgTypes) do
    Comm.msgTypeNames[num] = name
end


function Comm:init()
    local msgTypes = Comm.msgTypes

    self:registerHandler(msgTypes.UPDATE, self.handleUpdate)
    self:registerHandler(msgTypes.SYNC_PROBE, self.handleSyncProbe)
    self:registerHandler(msgTypes.STANDINGS, self.handleStandings)
    self:registerHandler(msgTypes.HISTORY, self.handleHistory)
    self:registerHandler(msgTypes.LM_SETTINGS, self.handleLmSettings)
    self:registerHandler(msgTypes.ROLL_PASS, self.handleRollPass)
    self:registerHandler(msgTypes.SYNC_OLD, self.handleSyncOld)

    ns.addon:RegisterComm(self.prefix, self.handleMessage)
end


---@param msgType integer
---@param func function
function Comm:registerHandler(msgType, func)
    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    if func == nil then
        error('func cannot be nil')
    end

    if type(func) ~= 'function' then
        error('func must be a function')
    end

    if self.funcs[msgType] ~= nil then
        error(('message type %s already has a registered function'):format(self.msgTypeNames[msgType]))
    end

    self.funcs[msgType] = func
end


---@param msgType integer
function Comm:unregisterHandler(msgType)
    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    self.funcs[msgType] = nil
end


---@param msgType integer
---@param message? table
---@param distribution string
---@param target? string
function Comm:send(msgType, message, distribution, target)
    if msgType ~= self.msgTypes.HEARTBEAT then
        local dest
        if distribution == 'WHISPER' then
            dest = target
        else
            dest = distribution
        end
        ns.debug(('sending %s msg to %s'):format(self.msgTypeNames[msgType], dest))
    end

    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    if officerReq:contains(msgType) and not ns.Lib.isOfficer() then
        ns.debug('-- you are not an officer; not sending message')
        return
    end

    if message == nil then
        message = {}
    end

    message.t = msgType
    message.v = ns.addon.versionNum

    local messageStr = self.packMessage(message)
    ns.addon:SendCommMessage(self.prefix, messageStr, distribution, target)
end


function Comm.handleMessage(prefix, message, _, sender)
    if prefix ~= Comm.prefix or sender == UnitName('player') then
        return
    end

    message = Comm.unpackMessage(message)

    local msgType = message.t
    if msgType == nil or Comm.msgTypeNames[msgType] == nil then
        return
    end

    local theirVersion = message.v

    if msgType ~= Comm.msgTypes.HEARTBEAT then
        ns.debug(('got message %s from %s'):format(Comm.msgTypeNames[msgType], sender))

        if theirVersion == nil then
            ns.debug('-- client version unknown (probably out of date)')
            return
        end

        if theirVersion < ns.minSyncVersion and msgType ~= Comm.msgTypes.ROLL_PASS then
            ns.debug(string.format(
                '-- client version (%s) less than minimum (%s)',
                ns.Lib.getVersionStr(theirVersion),
                ns.Lib.getVersionStr(ns.minSyncVersion)
            ))
            return
        end
    end

    if officerReq:contains(msgType) and not ns.Lib.isOfficer(sender) then
        ns.debug('-- they are not an officer; rejecting message')
        return
    end

    local func = Comm.funcs[msgType]
    if func == nil then
        return
    end

    func(message, sender)
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


function Comm.handleUpdate(_, sender)
    Comm:sendSyncProbe('WHISPER', sender, true, true)
end


function Comm.handleSyncProbe(message, sender)
    local theirLatestEventTime = message.latestEventTime
    local theirLmSettingsLastChange = message.lmSettingsLastChange

    -- ns.debug(('got SYNC_PROBE message from %s; theirLatestEventTime: %s, theirLmSettingsLastChange: %s'):format(sender, theirLatestEventTime, theirLmSettingsLastChange))

    if theirLatestEventTime ~= nil then
        local myLatestEventTime = Comm.getLatestEventTime()
        if theirLatestEventTime < myLatestEventTime then
            -- they are behind me
            ns.debug(string.format(
                '---- they are behind me; sending new events and standings (%d < %d)',
                theirLatestEventTime,
                myLatestEventTime
            ))

            Comm:sendStandingsToTarget(sender)
            Comm:sendHistory(sender, theirLatestEventTime)
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.debug(string.format(
                '---- they are ahead of me; sending sync-probe (%d > %d)',
                theirLatestEventTime,
                myLatestEventTime
            ))

            Comm:sendSyncProbe('WHISPER', sender, true, false)
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

            Comm:sendLmSettingsToTarget(sender)
        elseif theirLmSettingsLastChange > ns.db.lmSettingsLastChange then
            -- their LM settings are ahead of mine
            Comm:sendSyncProbe('WHISPER', sender, false, true)
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
        eventAndHash = Comm.decodeEvent(eventAndHash)

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

    ns.cfg.defaultDecayEp = lmSettings.defaultDecayEp
    ns.cfg.defaultDecayGp = lmSettings.defaultDecayGp
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


function Comm.handleRollPass(_, sender)
    ns.LootDistWindow:handlePass(sender)
end


function Comm:sendUpdate()
    self:send(self.msgTypes.UPDATE, nil, 'GUILD')
end


function Comm:sendSyncProbe(distribution, target, latestEventTime, lmSettingsLastChange)
    local toSend = {}

    if latestEventTime then
        toSend.latestEventTime = self.getLatestEventTime()
    end

    if lmSettingsLastChange then
        toSend.lmSettingsLastChange = ns.db.lmSettingsLastChange
    end

    -- ns.debug(('sending SYNC_PROBE with latestEventTime %s and lmSettingsLastChange %s'):format(toSend.latestEventTime, toSend.lmSettingsLastChange))

    self:send(self.msgTypes.SYNC_PROBE, toSend, distribution, target)
end


function Comm:sendStandings(distribution, target)
    local toSend = {
        standings = ns.db.standings,
    }

    self:send(self.msgTypes.STANDINGS, toSend, distribution, target)
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

        eventAndHash = self.encodeEvent(eventAndHash)

        tinsert(newEvents, eventAndHash)

        if #newEvents == 20 then
            toSend.events = newEvents

            ns.debug(string.format('sending a batch of 20 history events to %s', target))
            self:send(self.msgTypes.HISTORY, toSend, 'WHISPER', target)
            newEvents = {}
        end
    end

    if #newEvents > 0 then
        toSend.events = newEvents

        ns.debug(string.format('sending a batch of %d history events to %s', #newEvents, target))
        self:send(self.msgTypes.HISTORY, toSend, 'WHISPER', target)
    end
end


function Comm:sendEventToGuild(eventAndHash)
    eventAndHash = self.encodeEvent(eventAndHash)

    local toSend = {
        events = {eventAndHash}
    }

    self:send(self.msgTypes.HISTORY, toSend, 'GUILD')
end


function Comm:sendLmSettings(distribution, target)
    local toSend = {
        settings = {
            defaultDecayEp = ns.cfg.defaultDecayEp,
            defaultDecayGp = ns.cfg.defaultDecayGp,
            syncAltEp = ns.cfg.syncAltEp,
            syncAltGp = ns.cfg.syncAltGp,
            gpBase = ns.cfg.gpBase,
            gpSlotMods = ns.cfg.gpSlotMods,
            encounterEp = ns.cfg.encounterEp,
            mainAltMapping = ns.db.altData.mainAltMapping,
            lmSettingsLastChange = ns.db.lmSettingsLastChange,
        },
    }

    self:send(self.msgTypes.LM_SETTINGS, toSend, distribution, target)
end


function Comm:sendLmSettingsToTarget(target)
    self:sendLmSettings('WHISPER', target)
end


function Comm:sendLmSettingsToGuild()
    self:sendLmSettings('GUILD')
end


function Comm:sendRollPass()
    local ml = ns.Lib.getMl()
    if ml ~= nil then
        self:send(self.msgTypes.ROLL_PASS, nil, 'WHISPER', ml)
    end
end


---@param eventAndHash table
---@return table
function Comm.encodeEvent(eventAndHash)
    eventAndHash = ns.Lib.deepcopy(eventAndHash)

    local event = eventAndHash[1]
    local hash = eventAndHash[2]

    event[1] = ns.Lib.b64Encode(event[1])  -- ts
    eventAndHash[2] = ns.Lib.b64Encode(hash)

    return eventAndHash
end


---@param eventAndHash table
---@return table
function Comm.decodeEvent(eventAndHash)
    eventAndHash = ns.Lib.deepcopy(eventAndHash)

    local event = eventAndHash[1]
    local hash = eventAndHash[2]

    event[1] = ns.Lib.b64Decode(event[1])  -- ts
    eventAndHash[2] = ns.Lib.b64Decode(hash)

    return eventAndHash
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
