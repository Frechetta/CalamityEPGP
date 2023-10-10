local addonName, ns = ...  -- Namespace

local Set = ns.Set
local Dict = ns.Dict

local Sync = {
    timeframes = {
        DAILY = 0,
        WEEKLY = 1,
        EVENTS = 2,
    },
    weekTsIndex = Dict:new(),
    dayTsIndex = Dict:new(),
}

ns.Sync = Sync

local secondsDay = 86400
local secondsWeek = 604800


function Sync:init()
    local msgTypes = ns.Comm.msgTypes

    ns.Comm:registerHandler(msgTypes.DATA_REQ, self.handleDataReq)
    ns.Comm:registerHandler(msgTypes.DATA_SEND, self.handleDataSend)
    ns.Comm:registerHandler(msgTypes.SYNC_0, self.handleSync0)
    ns.Comm:registerHandler(msgTypes.SYNC_1, self.handleSync1)
    ns.Comm:registerHandler(msgTypes.SYNC_2, self.handleSync2)
end


function Sync:computeIndices()
    self.weekTsIndex:clear()
    self.dayTsIndex:clear()

    for i, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]
        local ts = event[1]

        local weekTs = math.floor(ts / secondsWeek) * secondsWeek
        if not self.weekTsIndex:contains(weekTs) then
            self.weekTsIndex:set(weekTs, i)
        end

        local dayTs = math.floor(ts / secondsDay) * secondsDay
        if not self.dayTsIndex:contains(dayTs) then
            self.dayTsIndex:set(dayTs, i)
        end
    end

    local weekTsIndexParts = {}
    for k, v in self.weekTsIndex:iter() do
        tinsert(weekTsIndexParts, k .. ': ' .. v)
    end
    ns.debug('weekTsIndex: ' .. table.concat(weekTsIndexParts, ', '))

    local dayTsIndexParts = {}
    for k, v in self.dayTsIndex:iter() do
        tinsert(dayTsIndexParts, k .. ': ' .. v)
    end
    ns.debug('dayTsIndex: ' .. table.concat(dayTsIndexParts, ', '))
end


---@return table
function Sync:getWeeklyHashes()
    local weeks = {}

    for _, eventAndHash in ipairs(ns.db.history) do
        self.processTimeframeEvent(eventAndHash[1], secondsWeek, weeks)
    end

    local weeklyHashes = {}

    for ts, weekData in pairs(weeks) do
        local hash = ns.Lib.hash(weekData)
        weeklyHashes[ns.Lib.b64Encode(ts)] = ns.Lib.b64Encode(hash)
    end

    return weeklyHashes
end


---@param weekTs number
---@return table
function Sync:getDailyHashes(weekTs)
    local days = {}

    local index = self.weekTsIndex:get(weekTs)

    if index ~= nil then
        local i = index
        while true do
            if i > #ns.db.history then
                break
            end

            local eventAndHash = ns.db.history[i]
            local event = eventAndHash[1]
            local eventTs = event[1]

            local eventWeekTs = math.floor(eventTs / secondsWeek) * secondsWeek
            if eventWeekTs ~= weekTs then
                break
            end

            self.processTimeframeEvent(event, secondsDay, days)

            i = i + 1
        end
    end

    local dailyHashes = {}

    for ts, dayData in pairs(days) do
        local hash = ns.Lib.hash(dayData)
        dailyHashes[ns.Lib.b64Encode(ts)] = ns.Lib.b64Encode(hash)
    end

    return dailyHashes
end


function Sync.processTimeframeEvent(event, timeframeSeconds, timeframes)
    local ts = event[1]
    local players = event[3]
    local mode = event[4]
    local value = event[5]

    local timeframeTs = math.floor(ts / timeframeSeconds) * timeframeSeconds

    if timeframes[timeframeTs] == nil then
        timeframes[timeframeTs] = {}
    end

    local timeframeData = timeframes[timeframeTs]

    for _, player in ipairs(players) do
        if timeframeData[player] == nil then
            timeframeData[player] = {ep = 0, gp = 0}
        end

        if mode == ns.consts.MODE_EP or mode == ns.consts.MODE_BOTH then
            timeframeData[player].ep = timeframeData[player].ep + value
        end

        if mode == ns.consts.MODE_GP or mode == ns.consts.MODE_BOTH then
            timeframeData[player].gp = timeframeData[player].gp + value
        end
    end
end


---@param dayTs number
---@return table
function Sync:getEventHashesByDay(dayTs)
    local events = {}

    local index = self.dayTsIndex:get(dayTs)

    local i = index
    while true do
        local eventAndHash = ns.db.history[i]
        local event = eventAndHash[1]
        local eventTs = event[1]

        local eventDayTs = math.floor(eventTs / secondsDay) * secondsDay
        if eventDayTs ~= dayTs then
            break
        end

        local hash = eventAndHash[2]

        events[ns.Lib.b64Encode(eventTs)] = ns.Lib.b64Encode(hash)

        i = i + 1
    end

    return events
end


---@param timeframe number
---@param timestamps Set
---@return table
function Sync:getEvents(timeframe, timestamps)
    assert(timeframe == self.timeframes.WEEKLY or timeframe == self.timeframes.DAILY or timeframe == self.timeframes.EVENTS,
           ('timeframe must be WEEKLY, DAILY, or EVENTS, not %s'):format(timeframe))

    local events = {}

    if timeframe == self.timeframes.EVENTS then
        for _, eventAndHash in ipairs(ns.db.history) do
            if timestamps:contains(eventAndHash[1][1]) then
                tinsert(events, Sync.encodeEvent(eventAndHash))
            end
        end
    else
        local timeframeTsIndex
        local timeframeSeconds
        if timeframe == self.timeframes.WEEKLY then
            timeframeTsIndex = self.weekTsIndex
            timeframeSeconds = secondsWeek
        elseif timeframe == self.timeframes.DAILY then
            timeframeTsIndex = self.dayTsIndex
            timeframeSeconds = secondsDay
        end

        for timeframeTs in timestamps:iter() do
            local index = timeframeTsIndex:get(timeframeTs)

            -- if index ~= nil then
                local i = index
                while true do
                    if i > #ns.db.history then
                        break
                    end

                    local eventAndHash = ns.db.history[i]
                    local event = eventAndHash[1]
                    local eventTs = event[1]

                    local eventTimeframeTs = math.floor(eventTs / timeframeSeconds) * timeframeSeconds
                    if eventTimeframeTs ~= timeframeTs then
                        break
                    end

                    tinsert(events, Sync.encodeEvent(eventAndHash))

                    i = i + 1
                end
            -- end
        end
    end

    return events
end


---@return table
function Sync.getLmSettings()
    return {
        ns.cfg.defaultDecay,
        ns.cfg.syncAltEp,
        ns.cfg.syncAltGp,
        ns.cfg.gpBase,
        ns.cfg.gpSlotMods,
        ns.cfg.encounterEp,
        ns.db.altData.mainAltMapping,
        ns.db.lmSettingsLastChange,
    }
end


function Sync:syncInit()
    ns.debug('initializing sync')

    local weeklyHashes = self:getWeeklyHashes()
    local lmSettingsLastChange = ns.Lib.b64Encode(ns.db.lmSettingsLastChange)

    self.sendSync0(weeklyHashes, lmSettingsLastChange)
end


---@param weeklyHashes table
---@param lmSettingsLastChange number
function Sync.sendSync0(weeklyHashes, lmSettingsLastChange)
    local parts = {}
    for weekTs, weekHash in pairs(weeklyHashes) do
        tinsert(parts, tostring(weekTs) .. ': ' .. weekHash)
    end
    local weeklyHashesStr = '{' .. table.concat(parts, ', ') .. '}'
    ns.debug('sending weekly hashes: ' .. weeklyHashesStr)

    local toSend = {weeklyHashes, lmSettingsLastChange}

    ns.Comm:send(ns.Comm.msgTypes.SYNC_0, toSend, 'GUILD')
end

---@param differingWeeks table
---@param target string
function Sync.sendSync1(differingWeeks, target)
    local parts = {}
    for weekTs, dayHashes in pairs(differingWeeks) do
        local dayHashesParts = {}
        for dayTs, dayHash in pairs(dayHashes) do
            tinsert(dayHashesParts, ('%s: %s'):format(dayTs, dayHash))
        end
        tinsert(parts, tostring(weekTs) .. ': {' .. table.concat(dayHashesParts, ', ') .. '}')
    end
    local differingWeeksStr = '{' .. table.concat(parts, ', ') .. '}'
    ns.debug('sending differing weeks: ' .. differingWeeksStr)

    ns.Comm:send(ns.Comm.msgTypes.SYNC_1, differingWeeks, target)
end

---@param differingDays table
---@param target string
function Sync.sendSync2(differingDays, target)
    ns.Comm:send(ns.Comm.msgTypes.SYNC_2, differingDays, target)
end

---@param timeframe number
---@param timestamps table
---@param lmSettings boolean
---@param target string
function Sync.sendDataReq(timeframe, timestamps, lmSettings, target)
    local toSend = {timeframe, timestamps, lmSettings}
    ns.Comm:send(ns.Comm.msgTypes.DATA_REQ, toSend, 'WHISPER', target)
end

---@param timeframe number
---@param timestamps Set
---@param sendLmSettings boolean
---@param target string
function Sync:sendDataSend(timeframe, timestamps, sendLmSettings, target)
    local toSend = {}

    tinsert(toSend, self:getEvents(timeframe, timestamps))

    if sendLmSettings then
        tinsert(toSend, self:getLmSettings())
    end

    ns.Comm:send(ns.Comm.msgTypes.DATA_SEND, toSend, 'WHISPER', target)
end

---@param eventAndHash table
function Sync:sendEventToGuild(eventAndHash)
    eventAndHash = self.encodeEvent(eventAndHash)
    local toSend = {{eventAndHash}}

    ns.Comm:send(ns.Comm.msgTypes.DATA_SEND, toSend, 'GUILD')
end

function Sync:sendLmSettingsToGuild()
    local toSend = {{}, self:getLmSettings()}

    ns.Comm:send(ns.Comm.msgTypes.DATA_SEND, toSend, 'GUILD')
end


function Sync.handleSync0(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local data = message.d

    local theirWeeklyHashes = Dict:new(data[1])
    local theirLmSettingsLastChange = ns.Lib.b64Decode(data[2])

    local myWeeklyHashes = Dict:new(Sync:getWeeklyHashes())
    local myLmSettingsLastChange = ns.db.lmSettingsLastChange

    -- if they are an officer, check if I need to ask for data
    if ns.Lib.isOfficer(sender) then
        -- list of weekly timestamps I need from them
        local myMissingWeeks = theirWeeklyHashes:keys():difference(myWeeklyHashes:keys()):toTable()

        local iNeedLmSettings = theirLmSettingsLastChange > myLmSettingsLastChange

        if #myMissingWeeks > 0 or iNeedLmSettings then
            ns.debug(('i\'m missing weeks (%s), requesting from %s'):format(table.concat(myMissingWeeks, ', '), sender))
            Sync.sendDataReq(Sync.timeframes.WEEKLY, myMissingWeeks, iNeedLmSettings, sender)
        end
    end

    -- if I am an officer, check if I need to send data
    if ns.Lib.isOfficer() then
        -- list of weekly timestamps they need from me
        local theirMissingWeeks = Set:new()
        for myWeekTs in myWeeklyHashes:iter() do
            if not theirWeeklyHashes:contains(myWeekTs) then
                theirMissingWeeks:add(ns.Lib.b64Decode(myWeekTs))
            end
        end

        local theyNeedLmSettings = myLmSettingsLastChange > theirLmSettingsLastChange

        if not theirMissingWeeks:isEmpty() or theyNeedLmSettings then
            ns.debug(('they\'re missing weeks (%s), sending to %s'):format(table.concat(theirMissingWeeks:toTable(), ', '), sender))
            Sync:sendDataSend(Sync.timeframes.WEEKLY, theirMissingWeeks, theyNeedLmSettings, sender)
        end
    end

    -- compare weeks we both have
    local differingWeeks = {}
    local shouldSend = false

    local commonTimestamps = myWeeklyHashes:keys():intersection(theirWeeklyHashes:keys())
    for weekTs in commonTimestamps:iter() do
        local myWeekHash = myWeeklyHashes:get(weekTs)
        local theirWeekHash = theirWeeklyHashes:get(weekTs)

        if myWeekHash ~= theirWeekHash then
            differingWeeks[weekTs] = Sync:getDailyHashes(ns.Lib.b64Decode(weekTs))
            shouldSend = true
        end
    end

    if shouldSend then
        Sync.sendSync1(differingWeeks, sender)
    end
end

function Sync.handleSync1(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local data = message.d

    local theirDailyHashesByWeek = Dict:new()
    local myDailyHashesByWeek = Dict:new()

    for weekTs, theirDailyHashes in pairs(data) do
        theirDailyHashesByWeek:set(weekTs, Dict:new(theirDailyHashes))
        myDailyHashesByWeek:set(weekTs, Dict:new(Sync:getDailyHashes(ns.Lib.b64Decode(weekTs))))
    end

    -- if they are an officer, check if I need to ask for data
    if ns.Lib.isOfficer(sender) then
        local myMissingDays = {}  -- list of daily timestamps I need from them
        for weekTs, theirDailyHashes in theirDailyHashesByWeek:iter() do
            local myDailyHashes = myDailyHashesByWeek:get(weekTs)

            for theirDayTs in theirDailyHashes:iter() do
                if not myDailyHashes:contains(theirDayTs) then
                    tinsert(myMissingDays, theirDayTs)
                end
            end
        end

        if #myMissingDays > 0 then
            ns.debug(('i\'m missing days (%s), requesting from %s'):format(table.concat(myMissingDays, ', '), sender))
            Sync.sendDataReq(Sync.timeframes.DAILY, myMissingDays, false, sender)
        end
    end

    -- if I am an officer, check if I need to send data
    if ns.Lib.isOfficer() then
        local theirMissingDays = Set:new()  -- list of daily timestamps they need from me
        for weekTs, theirDailyHashes in theirDailyHashesByWeek:iter() do
            local myDailyHashes = myDailyHashesByWeek:get(weekTs)

            for myDayTs in myDailyHashes:iter() do
                if not theirDailyHashes:contains(myDayTs) then
                    theirMissingDays:add(ns.Lib.b64Decode(myDayTs))
                end
            end
        end

        if not theirMissingDays:isEmpty() then
            ns.debug(('they\'re missing days (%s), sending to %s'):format(table.concat(theirMissingDays:toTable(), ', '), sender))
            Sync:sendDataSend(Sync.timeframes.DAILY, theirMissingDays, false, sender)
        end
    end

    -- compare days we both have
    local differingDays = {}
    local shouldSend = false

    for weekTs, theirDailyHashes in theirDailyHashesByWeek:iter() do
        local myDailyHashes = myDailyHashesByWeek:get(weekTs)

        local commonTimestamps = myDailyHashes:keys():intersection(theirDailyHashes:keys())
        for dayTs in commonTimestamps:iter() do
            local myDayHash = myDailyHashes:get(dayTs)
            local theirDayHash = theirDailyHashes:get(dayTs)

            if myDayHash ~= theirDayHash then
                differingDays[dayTs] = Sync:getEventHashesByDay(ns.Lib.b64Decode(dayTs))
                shouldSend = true
            end
        end
    end

    if shouldSend then
        local parts = {}
        for dayTs, eventHashes in pairs(differingDays) do
            local eventHashesParts = {}
            for eventTs, eventHash in pairs(eventHashes) do
                tinsert(eventHashesParts, ('%s: %s'):format(eventTs, eventHash))
            end
            tinsert(parts, tostring(dayTs) .. ': {' .. table.concat(eventHashesParts, ', ') .. '}')
        end
        local differingDaysStr = '{' .. table.concat(parts, ', ') .. '}'
        ns.debug('sending differing days: ' .. differingDaysStr)
        Sync.sendSync2(differingDays, sender)
    end
end

function Sync.handleSync2(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local data = message.d

    local theirEventHashesByDay = Dict:new()
    local myEventHashesByDay = Dict:new()

    for dayTs, theirEventHashes in pairs(data) do
        theirEventHashesByDay:set(dayTs, Dict:new(theirEventHashes))
        myEventHashesByDay:set(dayTs, Dict:new(Sync:getEventHashesByDay(ns.Lib.b64Decode(dayTs))))
    end

    -- if they are an officer, check if I need to ask for data
    if ns.Lib.isOfficer(sender) then
        local myMissingEvents = {}  -- list of event timestamps I need from them
        for dayTs, theirEventHashes in theirEventHashesByDay:iter() do
            local myEventHashes = myEventHashesByDay:get(dayTs)

            for theirEventTs in theirEventHashes:iter() do
                if not myEventHashes:contains(theirEventTs) then
                    tinsert(myMissingEvents, theirEventTs)
                end
            end
        end

        if #myMissingEvents > 0 then
            Sync.sendDataReq(Sync.timeframes.EVENT, myMissingEvents, false, sender)
        end
    end

    -- if I am an officer, check if I need to send data
    if ns.Lib.isOfficer() then
        local theirMissingEvents = Set:new()  -- list of event timestamps they need from me
        for dayTs, theirEventHashes in theirEventHashesByDay:iter() do
            local myEventHashes = myEventHashesByDay:get(dayTs)

            for myEventTs in myEventHashes:iter() do
                if not theirEventHashes:contains(myEventTs) then
                    theirMissingEvents:add(ns.Lib.b64Decode(myEventTs))
                end
            end
        end

        if not theirMissingEvents:isEmpty() then
            Sync:sendDataSend(Sync.timeframes.EVENT, theirMissingEvents, false, sender)
        end
    end
end

function Sync.handleDataReq(message, sender)
    -- if I am not an officer, drop the message
    if not ns.Lib.isOfficer() then
        return
    end

    local data = message.d

    ---@type number
    local timeframe = data[1]
    ---@type table
    local timestamps = data[2]  -- list of encoded timestamps
    ---@type boolean
    local lmSettings = data[3]

    ns.debug('handle data req, timeframe: ' .. timeframe .. ', timestamps: ' .. table.concat(timestamps, ', '))

    local timestampsDecoded = Set:new()
    for _, timestamp in ipairs(timestamps) do
        timestampsDecoded:add(ns.Lib.b64Decode(timestamp))
    end

    Sync:sendDataSend(timeframe, timestampsDecoded, lmSettings, sender)
end

function Sync.handleDataSend(message, sender)
    -- if they are not an officer, drop the message
    if not ns.Lib.isOfficer(sender) then
        return
    end

    local data = message.d

    ---@type table
    local events = data[1]
    ---@type table?
    local lmSettings = data[2]

    local recompute = false

    local numEvents = #events
    if numEvents > 0 then
        ns.debug(('received %d events from %s'):format(numEvents, sender))

        local fcomp = function(left, right) return left[1][1] < right[1][1] end
        for _, eventAndHash in ipairs(events) do
            eventAndHash = Sync.decodeEvent(eventAndHash)
            ns.Lib.bininsert(ns.db.history, eventAndHash, fcomp)
        end

        recompute = true
    end

    if lmSettings ~= nil then
        ns.debug(('received lmSettings from %s'):format(sender))

        ns.cfg.defaultDecay = lmSettings[1]
        ns.cfg.syncAltEp = lmSettings[2]
        ns.cfg.syncAltGp = lmSettings[3]
        ns.cfg.gpBase = lmSettings[4]
        ns.cfg.gpSlotMods = lmSettings[5]
        ns.cfg.encounterEp = lmSettings[6]
        ns.db.altData.mainAltMapping = lmSettings[7]
        ns.db.lmSettingsLastChange = lmSettings[8]

        LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)

        recompute = true
    end

    if recompute then
        ns.addon:computeStandings()
    end
end


---@param eventAndHash table
---@return table
function Sync.encodeEvent(eventAndHash)
    eventAndHash = ns.Lib.deepcopy(eventAndHash)

    local event = eventAndHash[1]
    local hash = eventAndHash[2]

    event[1] = ns.Lib.b64Encode(event[1])  -- ts
    eventAndHash[2] = ns.Lib.b64Encode(hash)

    return eventAndHash
end


---@param eventAndHash table
---@return table
function Sync.decodeEvent(eventAndHash)
    eventAndHash = ns.Lib.deepcopy(eventAndHash)

    local event = eventAndHash[1]
    local hash = eventAndHash[2]

    event[1] = ns.Lib.b64Decode(event[1])  -- ts
    eventAndHash[2] = ns.Lib.b64Decode(hash)

    return eventAndHash
end
