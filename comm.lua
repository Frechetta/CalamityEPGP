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

    local latestEventTime = self:getLatestEventTime()
    self:send(self.prefixes.SYNC, latestEventTime, 'GUILD')
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

    if sender == UnitName('player') then
        return
    end

    self = Comm

    ns.addon:Print('got message sync from', sender)

    message = self:unpackMessage(message)

    if type(message) == 'number' then
        ns.addon:Print('-- they sent me a timestamp')

        local theirLatestEventTime = message
        local myLatestEventTime = self:getLatestEventTime()

        local toSend = nil

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

            toSend = {
                events = newEvents:toTable(),
                standings = ns.db.standings,
            }
        elseif theirLatestEventTime > myLatestEventTime then
            -- they are ahead of me
            ns.addon:Print('---- they are ahead of me; sending my latest event time')
            toSend = myLatestEventTime
        end

        if toSend ~= nil then
            self:send(self.prefixes.SYNC, toSend, 'WHISPER', sender)
        end
    elseif type(message) == 'table' then
        -- they are ahead of me
        ns.addon:Print('-- they send me a table of new events and standings')

        local events = List:new(message.events)
        local standings = message.standings

        for eventData in events:iter() do
            local event = eventData[1]
            local hash = eventData[2]

            if not self.eventsByHash:contains(hash) then
                local serializedEvent = self:Serialize(event)
                tinsert(ns.db.history, {serializedEvent, hash})
                local i = #ns.db.history
                self.eventsByHash:set(hash, {event, i})
            end
        end

        ns.db.standings = standings

        ns.MainWindow:refresh()
        ns.HistoryWindow:refresh()
    end
end


function Comm:handleUpdate(message, distribution, sender)
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
