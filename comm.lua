local addonName, ns = ...  -- Namespace

Set = ns.Set
Dict = ns.Dict

Comm = {
    prefixes = {
        UPDATE_REQUEST = 'update_request',
        UPDATE_RESPONSE = 'update_response',
        EVENTS_REQUEST = 'events_request',
        EVENTS_RESPONSE = 'events_response',
    },
    eventsByHash = Dict:new(),
}

ns.Comm = Comm


function Comm:init()
    for _, prefix in pairs(self.prefixes) do
        ns.addon:RegisterComm(prefix, self.handleCommReceived)
    end
end


function Comm:getPrefix(prefix)
    return string.format('%s_%s', addonName, prefix)
end


function Comm:send(prefix, message, distribution, target)
    prefix = self:getPrefix(prefix)
    message = self:packMessage(message)
    ns.addon:SendCommMessage(prefix, message, distribution, target)
end


function Comm:requestUpdate()
    self:getEventHashes()
    local toSend = self.eventsByHash:keys()
    self:send(self.prefixes.UPDATE_REQUEST, toSend, 'GUILD')
end


function Comm:getEventHashes()
    self.eventsByHash = Dict:new()

    for _, eventData in ipairs(ns.db.history) do
        local event = eventData[1]
        local hash = eventData[2]
        self.eventsByHash:set(hash, event)
    end
end


function Comm:handleCommReceived(self, prefix, message, distribution, sender)
    self = Comm

    ns.addon:Print(prefix, sender)

    message = self:unpackMessage(message)

    if prefix == self.prefixes.UPDATE_REQUEST then
        -- message is a Set of event hashes

        if self.eventsByHash:len() == 0 then
            self:getEventHashes()
        end

        local myEventHashes = self.eventsByHash:keys()
        local theirEventHashes = message

        local myUniqueEventHashes = myEventHashes:difference(theirEventHashes)
        local myUniqueEvents = Dict:new()
        for hash in myUniqueEventHashes:iter() do
            local event = self.eventsByHash:get(hash)
            myUniqueEvents:set(hash, event)
        end
        -- TODO: also include current standings
        self:send(self.prefixes.UPDATE_RESPONSE, myUniqueEvents, 'WHISPER', sender)

        local theirUniqueEventHashes = theirEventHashes:difference(myEventHashes)
        self:send(self.prefixes.EVENTS_REQUEST, theirUniqueEventHashes, 'WHISPER', sender)

    elseif prefix == self.prefixes.UPDATE_RESPONSE then
        -- message is a Dict of hashes to events

        for hash, event in message:iter() do
            if self.eventsByHash:get(hash) == nil then
                self.eventsByHash:set(hash, event)
                tinsert(ns.db.history, {event, hash})
            end
        end

    elseif prefix == self.prefixes.EVENTS_REQUEST then
        -- message is a Set of event hashes

        local events = Dict:new()

        for hash in message:iter() do
            local event = self.eventsByHash:get(hash)
            events:set(hash, event)
        end

        self:send(self.prefixes.EVENTS_RESPONSE, events, 'WHISPER', sender)

    elseif prefix == self.prefixes.EVENTS_RESPONSE then
        -- message is a Dict of hashes to events

        for hash, event in message:iter() do
            if self.eventsByHash:get(hash) == nil then
                self.eventsByHash:set(hash, event)
                tinsert(ns.db.history, {event, hash})
            end
        end
    end
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
