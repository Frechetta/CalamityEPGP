local _, ns = ...  -- Namespace

local Set = ns.Set
local Dict = ns.Dict

local Sync = {
    timeframes = {
        DAILY = 0,
        WEEKLY = 1,
        EVENTS = 2,
    }
}

ns.Sync = Sync

local secondsDay = 86400
local secondsWeek = 604800

-- local timeframeNames = {}
-- for name, id in pairs(Sync.timeframes) do
--     timeframeNames[id] = name
-- end


function Sync:init()
    local msgTypes = ns.Comm.msgTypes

    ns.Comm:registerHandler(msgTypes.DATA_REQ, self.handleDataReq)
    ns.Comm:registerHandler(msgTypes.DATA_SEND, self.handleDataSend)
    ns.Comm:registerHandler(msgTypes.SYNC_0, self.handleSync0)
    ns.Comm:registerHandler(msgTypes.SYNC_1, self.handleSync1)
    ns.Comm:registerHandler(msgTypes.SYNC_2, self.handleSync2)
end


---@param timeframe number
---@param weekTs number?
---@return table
function Sync:getTimeframeHashes(timeframe, weekTs)
    assert(timeframe == self.timeframes.DAILY or timeframe == self.timeframes.WEEKLY,
           ('unknown timeframe: %s'):format(timeframe))

    local timeframes = {}

    local seconds
    if timeframe == self.timeframes.WEEKLY then
        seconds = secondsWeek
    else
        assert(weekTs ~= nil, 'weekTs must not be nil when timeframe is DAILY')
        seconds = secondsDay
    end

    for _, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]
        local ts = event[1]

        if timeframe == self.timeframes.WEEKLY or (math.floor(ts / secondsWeek) == weekTs) then
            local players = event[3]
            local mode = event[4]
            local value = event[5]

            local timeframeTs = math.floor(ts / seconds)

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
    end

    local hashes = {}

    for ts, timeframeData in pairs(timeframes) do
        local hash = ns.Lib.hash(timeframeData)
        hashes[ns.Lib.b64Encode(ts)] = ns.Lib.b64Encode(hash)
    end

    return hashes
end


---@param dayTimestamps Set
---@return table
function Sync.getEventHashesByDay(dayTimestamps)
    local days = {}

    for _, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]
        local ts = event[1]

        local dayTs = math.floor(ts / secondsDay)

        if dayTimestamps:contains(dayTs) then
            dayTs = ns.Lib.b64Encode(dayTs)

            if days[dayTs] == nil then
                days[dayTs] = {}
            end

            local hash = eventAndHash[2]
            days[dayTs][ns.Lib.b64Encode(ts)] = ns.Lib.b64Encode(hash)
        end
    end

    return days
end


---@param timeframe number
---@param timestamps Set
---@return table
function Sync:getEvents(timeframe, timestamps)
    local seconds
    if timeframe == self.timeframes.WEEKLY then
        seconds = secondsWeek
    elseif timeframe == self.timeframes.DAILY then
        seconds = secondsDay
    end

    local events = {}

    for _, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]
        local ts = event[1]

        local timeframeTs = math.floor(ts / seconds)

        if timestamps:contains(timeframeTs) then
            tinsert(events, Sync.encodeEvent(eventAndHash))
        end
    end

    return events
end


---@return table
function Sync.getLmSettings()
    return {
        defaultDecay = ns.cfg.defaultDecay,
        syncAltEp = ns.cfg.syncAltEp,
        syncAltGp = ns.cfg.syncAltGp,
        gpBase = ns.cfg.gpBase,
        gpSlotMods = ns.cfg.gpSlotMods,
        encounterEp = ns.cfg.encounterEp,
        mainAltMapping = ns.db.altData.mainAltMapping,
        lmSettingsLastChange = ns.db.lmSettingsLastChange,
    }
end


function Sync:syncInit()
    ns.debug('initializing sync')

    local weeklyHashes = self:getTimeframeHashes(self.timeframes.WEEKLY)
    local lmSettingsLastChange = ns.Lib.b64Encode(ns.db.lmSettingsLastChange)

    self.sendSync0(weeklyHashes, lmSettingsLastChange)
end


---@param weeklyHashes table
---@param lmSettingsLastChange number
function Sync.sendSync0(weeklyHashes, lmSettingsLastChange)
    local toSend = {weeklyHashes, lmSettingsLastChange}

    ns.Comm:send(ns.Comm.msgTypes.SYNC_0, toSend, 'GUILD')
end

---@param differingWeeks table
---@param target string
function Sync.sendSync1(differingWeeks, target)
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
function Sync.sendDataSend(timeframe, timestamps, sendLmSettings, target)
    local toSend = {}

    tinsert(toSend, Sync:getEvents(timeframe, timestamps))

    if sendLmSettings then
        tinsert(toSend, Sync:getLmSettings())
    end

    ns.Comm:send(ns.Comm.msgTypes.DATA_SEND, toSend, 'WHISPER', target)
end


function Sync.handleSync0(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local theirWeeklyHashes = message[1]
    local theirLmSettingsLastChange = message[2]
    local theirWeeksDict = Dict:new(theirWeeklyHashes)

    local myWeeklyHashes = Sync:getTimeframeHashes(Sync.timeframes.WEEKLY)
    local myLmSettingsLastChange = ns.Lib.b64Encode(ns.db.lmSettingsLastChange)
    local myWeeksDict = Dict:new(myWeeklyHashes)

    -- if they are an officer, check if I need to ask for data
    if ns.Lib.isOfficer(sender) then
        local myMissingWeeks = {}  -- list of weekly timestamps I need from them
        for theirWeekTs in theirWeeksDict:iter() do
            if not myWeeksDict:contains(theirWeekTs) then
                tinsert(myMissingWeeks, theirWeekTs)
            end
        end

        local iNeedLmSettings = theirLmSettingsLastChange > myLmSettingsLastChange

        Sync.sendDataReq(Sync.timeframes.WEEKLY, myMissingWeeks, iNeedLmSettings, sender)
    end

    -- if I am an officer, check if I need to send data
    if ns.Lib.isOfficer() then
        local theirMissingWeeks = Set:new()  -- list of weekly timestamps they need from me
        for myWeekTs in myWeeksDict:iter() do
            if not theirWeeksDict:contains(myWeekTs) then
                theirMissingWeeks:add(myWeekTs)
            end
        end

        local theyNeedLmSettings = myLmSettingsLastChange > theirLmSettingsLastChange

        Sync.sendDataSend(Sync.timeframes.WEEKLY, theirMissingWeeks, theyNeedLmSettings, sender)
    end

    -- compare weeks we both have
    local differingWeeks = {}

    local commonTimestamps = myWeeksDict:keys():intersection(theirWeeksDict:keys())
    for ts in commonTimestamps:iter() do
        local myWeekHash = myWeeksDict:get(ts)
        local theirWeekHash = theirWeeksDict:get(ts)

        if myWeekHash ~= theirWeekHash then
            local dailyHashes = Sync:getTimeframeHashes(Sync.timeframes.DAILY, ts)
            differingWeeks[ts] = dailyHashes
        end
    end

    Sync.sendSync1(differingWeeks, sender)
end

function Sync.handleSync1(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local differingWeeks = message

    local theirDailyHashes
    local myDailyHashes

    for weekTs, theirWeekDailyHashes in pairs(differingWeeks) do
        theirDailyHashes = Dict:new(theirWeekDailyHashes)

        local myWeekDailyHashes = Sync:getTimeframeHashes(Sync.timeframes.DAILY, weekTs)
        myDailyHashes = Dict:new(myWeekDailyHashes)
    end

    -- if they are an officer, check if I need to ask for data
    if ns.Lib.isOfficer(sender) then
        local myMissingDays = {}  -- list of weekly timestamps I need from them
        for theirDayTs in theirDailyHashes:iter() do
            if not myDailyHashes:contains(theirDayTs) then
                tinsert(myMissingDays, theirDayTs)
            end
        end

        Sync.sendDataReq(Sync.timeframes.DAILY, myMissingDays, false, sender)
    end

    -- if I am an officer, check if I need to send data
    if ns.Lib.isOfficer() then
        local theirMissingDays = Set:new()  -- list of weekly timestamps they need from me
        for myDayTs in myDailyHashes:iter() do
            if not theirDailyHashes:contains(myDayTs) then
                theirMissingDays:add(myDayTs)
            end
        end

        Sync.sendDataSend(Sync.timeframes.DAILY, theirMissingDays, false, sender)
    end

    -- compare weeks we both have
    local dayTimestamps = Set:new()

    local commonTimestamps = myDailyHashes:keys():intersection(theirDailyHashes:keys())
    for ts in commonTimestamps:iter() do
        local myDayHash = myDailyHashes:get(ts)
        local theirDayHash = theirDailyHashes:get(ts)

        if myDayHash ~= theirDayHash then
            dayTimestamps:add(ts)
        end
    end

    local differingDays = Sync.getEventHashesByDay(dayTimestamps)

    Sync.sendSync2(differingDays, sender)
end

function Sync.handleSync2(message, sender)
    -- if we are both guildies, drop the message
    if not ns.Lib.isOfficer() and not ns.Lib.isOfficer(sender) then
        return
    end

    local differingDays = message
end

function Sync.handleDataReq(message, sender)

end

function Sync.handleDataSend(message, sender)

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

    self:send(self.msgTypes.LM_SETTINGS, toSend, distribution, target)
end


function Comm:sendLmSettingsToTarget(target)
    self:sendLmSettings('WHISPER', target)
end


function Comm:sendLmSettingsToGuild()
    self:sendLmSettings('GUILD')
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
