local addonName, ns = ...  -- Namespace

local List = ns.List
local Set = ns.Set
local Dict = ns.Dict

local Comm = {
    prefixes = {
        SYNC = 'CE_sync',
        UPDATE = 'CE_update',
    },
    eventHashes = Set:new(),
    guildiesMessaged = Set:new(),
    otherClientVersions = Dict:new(),
}

ns.Comm = Comm


function Comm:init()
    ns.addon:RegisterComm(self.prefixes.SYNC, self.handleSync)
    ns.addon:RegisterComm(self.prefixes.UPDATE, self.handleUpdate)
end


function Comm:send(prefix, message, distribution, target)
    ns.debug(string.format('sending %s msg to %s via %s', prefix, tostring(target), distribution))

    message = self:packMessage(message)
    ns.addon:SendCommMessage(prefix, message, distribution, target)
end


function Comm:syncInit()
    ns.debug('initializing sync; sending my latest event time to all guildies')
    self:getEventHashes()

    local toSend = {
        version = ns.addon.versionNum,
        latestEventTime = self:getLatestEventTime(),
    }

    self:send(self.prefixes.SYNC, toSend, 'GUILD')
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

    local serializedEvent = latestEventAndHash[1]
    local _, latestEvent = ns.addon:Deserialize(serializedEvent)

    return latestEvent[1]
end


function Comm:handleSync(message, distribution, sender)
    self = Comm

    if sender == UnitName('player') then
        return
    end

    ns.debug('got message sync from ' .. sender)
    if #message < 50 then
        ns.debug('-- raw message: ' .. message)
    else
        ns.debug('-- raw message: (message too long)')
    end

    message = self:unpackMessage(message)

    if type(message) ~= 'table' then
        ns.debug('-- message is not a table. type: ' .. type(message))
        return
    end

    local theirAddonVersion = message.version

    self.otherClientVersions:set(sender, theirAddonVersion)

    if theirAddonVersion == nil then
        ns.debug('-- client version unknown (probably out of date)')
        return
    end

    if theirAddonVersion < ns.minSyncVersion then
        ns.debug(string.format('-- client version (%s) out of date', ns.Lib:getVersionStr(theirAddonVersion)))
        return
    end

    local theirLatestEventTime = message.latestEventTime
    local update = message.update
    local lmSettings = message.lmSettings

    local toSend = Dict:new()

    if theirLatestEventTime ~= nil then
        ns.debug('-- they sent me a timestamp')

        local myLatestEventTime = self:getLatestEventTime()

        if theirLatestEventTime < myLatestEventTime then
            -- they are behind me
            ns.debug(string.format('---- they are behind me; sending new events and standings (%d < %d)', theirLatestEventTime, myLatestEventTime))

            local newEvents = List:new()
            for i = #ns.db.history, 1, -1 do
                local eventAndHash = ns.db.history[i]
                local serializedEvent = eventAndHash[1]
                local _, event = ns.addon:Deserialize(serializedEvent)

                if event[1] <= theirLatestEventTime then
                    break
                end

                newEvents:append(eventAndHash)
            end

            toSend:set('update', {
                events = newEvents:toTable(),
                standings = ns.db.standings
            })
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.debug('---- they are ahead of me; sending my latest event time')
            toSend:set('latestEventTime', myLatestEventTime)
        end
    end

    if update ~= nil then
        -- they are ahead of me
        ns.debug('-- they sent me events and standings')

        local events = List:new(update.events)
        local standings = update.standings

        for eventAndHash in events:iter(true) do
            local hash = eventAndHash[2]

            if not self.eventHashes:contains(hash) then
                tinsert(ns.db.history, eventAndHash)
                self.eventHashes:add(hash)
            end
        end

        ns.db.standings = standings

        ns.HistoryWindow:refresh()
        ns.MainWindow:refresh()
    end

    if lmSettings ~= nil then
        ns.cfg.defaultDecay = lmSettings.defaultDecay
        ns.cfg.syncAltEp = lmSettings.syncAltEp
        ns.cfg.syncAltGp = lmSettings.syncAltGp
        ns.cfg.gpBase = lmSettings.gpBase
        ns.cfg.gpSlotMods = lmSettings.gpSlotMods
        ns.cfg.encounterEp = lmSettings.encounterEp

        LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
    elseif ns.cfg.lmMode then
        toSend:set('lmSettings', {
            defaultDecay = ns.cfg.defaultDecay,
            syncAltEp = ns.cfg.syncAltEp,
            syncAltGp = ns.cfg.syncAltGp,
            gpBase = ns.cfg.gpBase,
            gpSlotMods = ns.cfg.gpSlotMods,
            encounterEp = ns.cfg.encounterEp,
        })
    end

    if toSend:len() > 0 then
        toSend:set('version', ns.addon.versionNum)
        toSend = toSend._dict
        -- for k, v in pairs(toSend.update) do
        --     ns.debug(string.format('-------- %s: %s', k, tostring(v)))
        -- end
        self:send(self.prefixes.SYNC, toSend, 'WHISPER', sender)
    end
end


function Comm:handleUpdate(message, distribution, sender)
    self = Comm

    if sender == UnitName('player') then
        return
    end

    local latestEventTime = self:getLatestEventTime()
    self:send(self.prefixes.SYNC, latestEventTime, 'WHISPER', sender)
end


function Comm:packMessage(message)
    local package = ns.addon:Serialize(message)
    package = ns.addon.libc:CompressHuffman(package)
    package = ns.addon.libcEncodeTable:Encode(package)

    return package
end


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
