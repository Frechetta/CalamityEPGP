local _, ns = ...  -- Namespace

local List = ns.List
local Set = ns.Set
local Dict = ns.Dict

local Comm = {
    prefixes = {
        SYNC = 'sync',
        UPDATE = 'update',
    },
    eventsByHash = Dict:new(),
    guildiesMessaged = Set:new(),
}

ns.Comm = Comm


function Comm:init()
    ns.addon:RegisterComm(self.prefixes.SYNC, self.handleSync)
    ns.addon:RegisterComm(self.prefixes.UPDATE, self.handleUpdate)
end


function Comm:send(prefix, message, distribution, target)
    message = self:packMessage(message)
    ns.addon:SendCommMessage(prefix, message, distribution, target)
end


function Comm:syncInit()
    ns.addon:Print('initializing sync; sending my latest event time to all guildies')
    self:getEventsByHash()

    local toSend = {
        latestEventTime = self:getLatestEventTime(),
    }
    self:send(self.prefixes.SYNC, toSend, 'GUILD')
end


function Comm:getEventsByHash()
    self.eventsByHash:clear()

    for i, eventAndHash in ipairs(ns.db.history) do
        local serializedEvent = eventAndHash[1]
        local _, event = ns.addon:Deserialize(serializedEvent)
        local hash = eventAndHash[2]

        self.eventsByHash:set(hash, {event, i})
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
    --[[
        message is either a timestamp or a table of events like
        {
            events = <events>,  -- (originally a list)
            standings = <standings>,
        }
    ]]
    self = Comm

    if sender == UnitName('player') then
        return
    end

    ns.addon:Print('got message sync from', sender)

    message = self:unpackMessage(message)

    local theirLatestEventTime = message.latestEventTime
    local update = message.update
    local lmSettings = message.lmSettings

    local toSend = Dict:new()

    if theirLatestEventTime ~= nil then
        ns.addon:Print('-- they sent me a timestamp')

        local myLatestEventTime = self:getLatestEventTime()

        if theirLatestEventTime < myLatestEventTime then
            -- they are behind me
            ns.addon:Print('---- they are behind me; sending new events and standings')

            local newEvents = List:new()
            for i = #ns.db.history, 1, -1 do
                local eventAndHash = ns.db.history[i]
                local serializedEvent = eventAndHash[1]
                local _, event = ns.addon:Deserialize(serializedEvent)
                local hash = eventAndHash[2]

                if event[1] <= theirLatestEventTime then
                    break
                end

                newEvents:append({event, hash})
            end

            toSend:set('update', {
                events = newEvents:toTable(),
                standings = ns.db.standings
            })
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.addon:Print('---- they are ahead of me; sending my latest event time')
            toSend:set('latestEventTime', myLatestEventTime)
        end
    end

    if update ~= nil then
        -- they are ahead of me
        ns.addon:Print('-- they sent me events and standings')

        local events = List:new(update.events)
        local standings = update.standings

        for eventData in events:iter() do
            local event = eventData[1]
            local hash = eventData[2]

            if not self.eventsByHash:contains(hash) then
                local serializedEvent = ns.addon:Serialize(event)
                tinsert(ns.db.history, {serializedEvent, hash})
                local i = #ns.db.history
                self.eventsByHash:set(hash, {event, i})
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

        -- TODO: refresh settings menu
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
        self:send(self.prefixes.SYNC, toSend:toTable(), 'WHISPER', sender)
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
        ns.addon:Print(string.format('could not decompress message. error: %s', error))
        return nil
    end

    local success, message = ns.addon:Deserialize(message)

    if not success then
        ns.addon:Print('could not deserialize message')
        return nil
    end

    return message
end
