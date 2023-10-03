local addonName, ns = ...  -- Namespace

local Set = ns.Set

local HistoryWindow = {
    data = {
        header = {},
        rowsRaw = {},
        rowsRendered = {},
        rows = {},
    },
    epgpReasonsPretty = {
        [ns.values.epgpReasons.MANUAL_SINGLE] = 'Manual',
        [ns.values.epgpReasons.MANUAL_MULTIPLE] = 'Manual',
        [ns.values.epgpReasons.DECAY] = 'Decay',
        [ns.values.epgpReasons.AWARD] = 'Award',
        [ns.values.epgpReasons.BOSS_KILL] = 'Boss Kill',
    },
    dropDownRows = 8,
    dropDownItemWidth = 70,
    dropDownItemHeight = 15,
    dropDownItemPadding = 2.5,
    selectedPlayer = 'All',
    mainsOnly = false,
}

ns.HistoryWindow = HistoryWindow


function HistoryWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_HistoryWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(900, 500)
	mainFrame:SetPoint('CENTER')
    mainFrame:SetToplevel(true)

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP History')

    mainFrame.reasonsLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.reasonsLabel:SetText('Reason:')
    mainFrame.reasonsLabel:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -20)

    mainFrame.reasonChecks = {}
    for _, reason in pairs(self.epgpReasonsPretty) do
        local name = mainFrame:GetName() .. '_Check' .. reason

        if _G[name .. 'Text'] == nil then
            local reasonCheck = CreateFrame('CheckButton', name, mainFrame, 'UICheckButtonTemplate')

            local numChecks = #mainFrame.reasonChecks
            local relativeFrame
            local extraOffset
            if numChecks == 0 then
                relativeFrame = mainFrame.reasonsLabel
                extraOffset = 0
            else
                relativeFrame = mainFrame.reasonChecks[numChecks]
                extraOffset = relativeFrame.textWidth
            end

            reasonCheck:SetPoint('LEFT', relativeFrame, 'RIGHT', 2 + extraOffset, 0)
            reasonCheck:SetChecked(true)

            local fontString = _G[name .. 'Text']
            fontString:SetText(reason)

            reasonCheck.textWidth = fontString:GetWidth()
            reasonCheck.text = reason

            reasonCheck:SetScript('OnClick', function() HistoryWindow:filterData(); HistoryWindow:setTableData() end)

            tinsert(mainFrame.reasonChecks, reasonCheck)
        end
    end

    mainFrame.detailLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.detailLabel:SetText('Detail:')
    mainFrame.detailLabel:SetPoint('TOPLEFT', mainFrame.reasonsLabel, 'BOTTOMLEFT', 0, -20)

    mainFrame.detailCheck = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.detailCheck:SetPoint('LEFT', mainFrame.detailLabel, 'RIGHT', 2, 0)
    mainFrame.detailCheck:SetScript('OnClick', function()
        HistoryWindow.detail = mainFrame.detailCheck:GetChecked()

        if HistoryWindow.mainFrame.dropDown.itemsFrame:IsShown() then
            HistoryWindow:handleDropdownClick()
        end

        mainFrame.playerLabel:SetShown(HistoryWindow.detail)
        mainFrame.dropDown:SetShown(HistoryWindow.detail)
        mainFrame.mainsOnlyLabel:SetShown(HistoryWindow.detail)
        mainFrame.mainsOnlyCheck:SetShown(HistoryWindow.detail)

        mainFrame.dropDown.Text:SetText('All')
        HistoryWindow.selectedPlayer = 'All'

        HistoryWindow:getRenderedData()
        HistoryWindow:setTableData()
    end)

    mainFrame.playerLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.playerLabel:SetText('Player:')
    mainFrame.playerLabel:SetPoint('LEFT', mainFrame.detailCheck, 'RIGHT', 20, 0)
    mainFrame.playerLabel:SetShown(mainFrame.detailCheck:GetChecked())

    mainFrame.dropDown = CreateFrame('Frame', nil, mainFrame, 'UIDropDownMenuTemplate')
    mainFrame.dropDown:SetPoint('LEFT', mainFrame.playerLabel, 'RIGHT', -10, 0)
    mainFrame.dropDown:SetWidth(100)
    mainFrame.dropDown.Text:SetText(self.selectedPlayer)
    mainFrame.dropDown.Button:SetScript('onClick', function() self:handleDropdownClick() end)
    mainFrame.dropDown:SetShown(mainFrame.detailCheck:GetChecked())

    mainFrame.mainsOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.mainsOnlyLabel:SetText('Mains only:')
    mainFrame.mainsOnlyLabel:SetPoint('LEFT', mainFrame.dropDown, 'RIGHT', 80, 0)
    mainFrame.mainsOnlyLabel:SetShown(mainFrame.detailCheck:GetChecked())

    mainFrame.mainsOnlyCheck = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.mainsOnlyCheck:SetPoint('LEFT', mainFrame.mainsOnlyLabel, 'RIGHT', 2, 0)
    mainFrame.mainsOnlyCheck:SetShown(mainFrame.detailCheck:GetChecked())
    mainFrame.mainsOnlyCheck:SetScript('OnClick', function()
        HistoryWindow.mainsOnly = mainFrame.mainsOnlyCheck:GetChecked()

        if HistoryWindow.mainFrame.dropDown.itemsFrame:IsShown() then
            HistoryWindow:handleDropdownClick()
        end

        HistoryWindow:filterData()
        HistoryWindow:setDropDownData()
        HistoryWindow:setTableData()
    end)

    mainFrame.tableFrame = ns.Table:new(mainFrame, nil, true, true)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.detailLabel, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -8, 7)

    tinsert(UISpecialFrames, mainFrame:GetName())

    mainFrame:HookScript('OnHide', function()
        if ns.MainWindow.mainFrame ~= nil then
            C_Timer.After(0.1, function()
                tinsert(UISpecialFrames, ns.MainWindow.mainFrame:GetName())
            end)
        end
    end)

    self:createDropdownItemsFrame()

	return mainFrame;
end


function HistoryWindow:createDropdownItemsFrame()
    local dropDown = self.mainFrame.dropDown

    dropDown.itemsFrame = CreateFrame('Frame', nil, dropDown, 'InsetFrameTemplate2')
    dropDown.itemsFrame:SetPoint('TOPLEFT', dropDown, 'BOTTOMLEFT', 0, 0)
    dropDown.itemsFrame:SetFrameLevel(self.mainFrame:GetFrameLevel() + 50)
    dropDown.itemsFrame:EnableMouse()
    dropDown.itemsFrame:SetScript('OnEnter', function()
        self.mainFrame.tableFrame._mainFrame.contents.rowHighlight:Hide()
    end)

    dropDown.itemsFrame.items = {}

    local itemsFrameTexture = dropDown.itemsFrame:CreateTexture(nil, 'BACKGROUND')
    itemsFrameTexture:SetAllPoints()
    itemsFrameTexture:SetColorTexture(0.05, 0.01, 0.01, 1)
    -- itemsFrameTexture:SetBlendMode('ADD')

    dropDown.itemsFrame.itemHighlight = CreateFrame('Frame', nil, dropDown.itemsFrame)
    local highlightTexture = dropDown.itemsFrame.itemHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    dropDown.itemsFrame.itemHighlight:Hide()

    dropDown.itemsFrame:Hide()
end


function HistoryWindow:handleDropdownClick()
    local itemsFrame = self.mainFrame.dropDown.itemsFrame

    if itemsFrame:IsShown() then
        itemsFrame:Hide()
        for _, item in ipairs(itemsFrame.items) do
            item:Hide()
        end
    else
        itemsFrame:Show()
        for _, item in ipairs(itemsFrame.items) do
            if item.active then
                item:Show()
            end
        end
    end
end


function HistoryWindow:show()
    if self.mainFrame == nil then
        return
    end

    self.mainFrame:Raise()

    self:refresh()
    self.mainFrame:Show()
end


function HistoryWindow:refresh()
    if self.mainFrame == nil then
        return
    end

    self:getData(function()
        HistoryWindow:getRenderedData()
        HistoryWindow:setDropDownData()
        HistoryWindow:setTableData()
    end)
end


function HistoryWindow:setDropDownData()
    local dropDown = self.mainFrame.dropDown

    local players = {}
    for _, playerData in pairs(ns.standings) do
        local playerName = playerData.name
        -- filter if mainsOnly == true
        if not self.mainsOnly or ns.db.altData.altMainMapping[playerName] == playerName then
            tinsert(players, playerName)
        end
    end

    table.sort(players)
    tinsert(players, 1, 'All')

    local items = dropDown.itemsFrame.items

    for i, player in ipairs(players) do
        if i > #items then
            self:addDropDownItem(i)
        end

        local item = items[i]
        item.text:SetText(player)
        item.active = true

        item:SetScript('OnMouseUp', function()
            HistoryWindow.selectedPlayer = player
            dropDown.itemsFrame:Hide()
            dropDown.Text:SetText(HistoryWindow.selectedPlayer)
            HistoryWindow:filterData()
            HistoryWindow:setTableData()
        end)
    end

    for i = #players + 1, #items do
        local item = items[i]
        item.active = false
    end

    -- set rowCount to self.dropDownRows if there are more items than rows
    local rowCount = #players > self.dropDownRows and self.dropDownRows or #players
    local height = rowCount * (self.dropDownItemHeight + self.dropDownItemPadding * 2) + 7

    local columnCount = math.ceil(#players / self.dropDownRows)
    local width = columnCount * (self.dropDownItemWidth + self.dropDownItemPadding * 2) + 5

    dropDown.itemsFrame:SetSize(width, height)
end


function HistoryWindow:setTableData()
    self.mainFrame.tableFrame:setData(self.data)
end


function HistoryWindow:addDropDownItem(index)
    local dropDown = self.mainFrame.dropDown

    local row = (index - 1) % self.dropDownRows
    local column = math.floor((index - 1) / self.dropDownRows)

    local xOffset = column * (self.dropDownItemWidth + self.dropDownItemPadding * 2) + 5
    local yOffset = row * (self.dropDownItemHeight + self.dropDownItemPadding * 2) + 6.5

    local item = CreateFrame('Frame', nil, dropDown.itemsFrame)
    item:SetPoint('TOPLEFT', dropDown.itemsFrame, 'TOPLEFT', xOffset, -yOffset)
    item:SetSize(self.dropDownItemWidth, self.dropDownItemHeight)
    item:Hide()

    item.text = item:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    item.text:SetPoint('LEFT', item, 'LEFT', 2, 0)
    item.text:SetJustifyH('LEFT')

    -- Highlight
    item:EnableMouse()

    item:SetScript('OnEnter', function()
        dropDown.itemsFrame.itemHighlight:SetPoint('TOPLEFT', item, 'TOPLEFT')
        dropDown.itemsFrame.itemHighlight:SetPoint('BOTTOMRIGHT', item, 'BOTTOMRIGHT')
        dropDown.itemsFrame.itemHighlight:Show()
    end)

    item:SetScript('OnLeave', function()
        dropDown.itemsFrame.itemHighlight:Hide()
    end)

    tinsert(dropDown.itemsFrame.items, item)
end


function HistoryWindow:filterData()
    self.data.rows = {}

    local filters = {}
    for _, reasonCheck in ipairs(self.mainFrame.reasonChecks) do
        filters[reasonCheck.text] = reasonCheck:GetChecked()
    end

    for _, row in ipairs(self.data.rowsRendered) do
        local keep = true

        local metadata = row[#row]
        local baseReason = metadata.baseReason

        if self.detail then
            local player = row[3]

            if (self.selectedPlayer ~= 'All' and player ~= self.selectedPlayer)
                    or (self.mainsOnly and ns.db.altData.mainAltMapping[player] == nil)
                    or not filters[baseReason] then
                keep = false
            end
        else
            local playerGuids = metadata.players
            local players = Set:new()

            local hasMain = false
            for _, playerGuid in ipairs(playerGuids) do
                local playerData = ns.db.standings[playerGuid]

                if playerData ~= nil then
                    local player = playerData.name
                    players:add(player)

                    if ns.db.altData.mainAltMapping[player] ~= nil then
                        hasMain = true
                    end
                end
            end

            if (self.selectedPlayer ~= 'All' and not players:contains(self.selectedPlayer))
                    or (self.mainsOnly and not hasMain)
                    or not filters[baseReason] then
                keep = false
            end
        end

        if keep then
            tinsert(self.data.rows, row)
        end
    end
end


---@param callback function
function HistoryWindow:getData(callback)
    callback = callback or function(_) end

    self.data.rowsRaw = {}

    local playerGuidToName = {}
    local playerValsTracker = {}
    for guid, playerData in pairs(ns.db.standings) do
        playerGuidToName[guid] = playerData.name

        if playerValsTracker[guid] == nil then
            playerValsTracker[guid] = {}
        end

        playerValsTracker[guid]['EP'] = playerData.ep
        playerValsTracker[guid]['GP'] = playerData.gp
    end

    local numEvents = #ns.db.history
    local eventsProcessed = 0

    for _, eventAndHash in ipairs(ns.db.history) do
        local event = eventAndHash[1]

        local time = date('%Y-%m-%d %H:%M:%S', event[1])
        local issuedBy = playerGuidToName[ns.Lib.getFullPlayerGuid(event[2])]
        local players = event[3]
        local mode = event[4]
        local value = event[5]
        local reason = event[6]
        local percent = event[7]

        local newPlayers = {}
        for _, guidShort in ipairs(players) do
            tinsert(newPlayers, ns.Lib.getFullPlayerGuid(guidShort))
        end

        self:getFormattedReason(reason, function(reason, prettyReason)
            local row = {
                time,
                issuedBy,
                mode,
                value,
                reason,
                percent,
                {baseReason = prettyReason, players = newPlayers}
            }

            ns.Lib.bininsert(self.data.rowsRaw, row, function(left, right)
                return left[1] > right[1]
            end)

            eventsProcessed = eventsProcessed + 1
            if eventsProcessed == numEvents then
                callback()
            end
        end)
    end
end


---@param reason string
---@param callback function
function HistoryWindow:getFormattedReason(reason, callback)
    if reason == nil then
        callback(nil, nil)
        return
    end

    local reasonType, details = string.match(reason, '^(%d):(.*)$')
    reasonType = tonumber(reasonType)

    local bench = false
    if ns.Lib.strEndsWith(details, ':1') then
        bench = true
        details = details:sub(1, #details - 2)
    end

    local prettyReason = self.epgpReasonsPretty[reasonType]

    if reasonType == ns.values.epgpReasons.AWARD then
        local rollType, item = string.match(details, '^(.+):(.+)$')
        rollType = strupper(rollType)

        local itemId = tonumber(item)
        if itemId then
            ns.Lib.getItemInfo(itemId, function(itemInfo)
                if itemInfo == nil then
                    callback(nil, nil)
                    return
                end

                details = string.format('%s (%s)', itemInfo.name, rollType)
                reason = string.format('%s (%s)', prettyReason, details)

                if bench then
                    reason = reason + ' [BENCH]'
                end

                callback(reason, prettyReason)
            end)
            return
        end

        details = string.format('%s (%s)', item, rollType)
    elseif reasonType == ns.values.epgpReasons.BOSS_KILL then
        local bossId = tonumber(details)
        details = ns.values.encounters[bossId].name
    end

    if details ~= nil and #details > 0 then
        reason = string.format('%s (%s)', prettyReason, details)
    else
        reason = prettyReason
    end

    if bench then
        reason = reason .. ' [BENCH]'
    end

    callback(reason, prettyReason)
end


function HistoryWindow:getRenderedData()
    self.data.rowsRendered = {}

    if self.detail then
        self.data.header = {
            {'Time', 'LEFT'},
            {'Issued By', 'LEFT'},
            {'Player', 'LEFT'},
            {'Reason', 'LEFT'},
            {'Action', 'LEFT'},
            {'EP Delta', 'RIGHT'},
            {'GP Delta', 'RIGHT'},
            {'PR Delta', 'RIGHT'},
        }

        local playerValsTracker = {}
        for guid, playerData in pairs(ns.db.standings) do
            if playerValsTracker[guid] == nil then
                playerValsTracker[guid] = {}
            end

            playerValsTracker[guid]['EP'] = playerData.ep
            playerValsTracker[guid]['GP'] = playerData.gp
        end

        for _, row in ipairs(self.data.rowsRaw) do
            local time = row[1]
            local issuedBy = row[2]
            local mode = row[3]
            local value = row[4]
            local reason = row[5]
            local percent = row[6]

            local metadata = row[7]
            local baseReason = metadata.baseReason
            local players = metadata.players

            for _, playerGuid in ipairs(players) do
                local playerData = ns.db.standings[playerGuid]

                if playerData ~= nil then
                    local player = playerData.name

                    -- get action
                    local valueStr = tostring(value)
                    valueStr = percent and valueStr .. '%' or valueStr
                    valueStr = value > 0 and '+' .. valueStr or valueStr

                    local actionMode = mode == 'both' and 'EP/GP' or string.upper(mode)
                    local action = string.format('%s %s', actionMode, valueStr)

                    -- get ep, gp, pr deltas
                    local standings = playerValsTracker[playerGuid]

                    local epDelta
                    local gpDelta

                    local epAfter = standings['EP']
                    local gpAfter = standings['GP']

                    local epBefore = epAfter
                    local gpBefore = gpAfter

                    local getDelta = function(m)
                        if m == 'ep' then
                            if percent then
                                local multiplier = (100 - value) / 100
                                epBefore = epAfter * multiplier
                            else
                                epBefore = epBefore - value
                            end

                            epDelta = string.format('%.2f -> %.2f', epBefore, epAfter)
                        end

                        if m == 'gp' then
                            if percent then
                                local multiplier = (100 - value) / 100
                                gpBefore = gpAfter * multiplier
                            else
                                gpBefore = gpBefore - value
                            end

                            gpDelta = string.format('%.2f -> %.2f', gpBefore, gpAfter)
                        end
                    end

                    if mode == 'both' then
                        getDelta('ep')
                        getDelta('gp')
                    else
                        getDelta(mode)
                    end

                    if epDelta == nil then
                        epDelta = string.format('%.2f', epAfter)
                    end

                    if gpDelta == nil then
                        gpDelta = string.format('%.2f', gpAfter)
                    end

                    local prAfter = epAfter / gpAfter
                    local prBefore = epBefore / gpBefore
                    local prDelta = string.format('%.3f -> %.3f', prBefore, prAfter)

                    local newRow = {
                        time,
                        issuedBy,
                        player,
                        reason,
                        action,
                        epDelta,
                        gpDelta,
                        prDelta,
                        {baseReason = baseReason}
                    }

                    tinsert(self.data.rowsRendered, newRow)

                    standings['EP'] = epBefore
                    standings['GP'] = gpBefore
                end
            end
        end
    else
        self.data.header = {
            {'Time', 'LEFT'},
            {'Issued By', 'LEFT'},
            {'Player', 'LEFT'},
            {'Reason', 'LEFT'},
            {'Action', 'LEFT'},
        }

        for _, row in ipairs(self.data.rowsRaw) do
            local time = row[1]
            local issuedBy = row[2]
            local mode = row[3]
            local value = row[4]
            local reason = row[5]
            local percent = row[6]

            local metadata = row[7]
            local baseReason = metadata.baseReason
            local players = metadata.players

            if #players >= 1 then
                local player
                if #players > 1 then
                    player = string.format('Multiple (%d)', #players)
                else
                    local guid = players[1]
                    player = ns.db.standings[guid].name
                end

                local valueStr = tostring(value)
                valueStr = percent and valueStr .. '%' or valueStr
                valueStr = value >= 0 and '+' .. valueStr or valueStr

                local actionMode = mode == 'both' and 'EP/GP' or string.upper(mode)
                local action = string.format('%s %s', actionMode, valueStr)

                local newRow = {
                    time,
                    issuedBy,
                    player,
                    reason,
                    action,
                    {baseReason = baseReason, players = players}
                }

                tinsert(self.data.rowsRendered, newRow)
            end
        end
    end

    self:filterData()
end


function HistoryWindow.fixHistory()
    local fixedHistory = {}

    local eventsByTime = {}

    for _, eventAndHash in ipairs(ns.db.history) do
        if type(eventAndHash[1]) == 'string' then
            local serializedEvent = eventAndHash[1]
            local _, event = ns.addon:Deserialize(serializedEvent)

            local createTime = event[1]

            if createTime == nil then
                fixedHistory = {}
                eventsByTime = {}
                break
            end

            if eventsByTime[createTime] == nil then
                eventsByTime[createTime] = {}
            end

            tinsert(eventsByTime[createTime], event)
        else
            tinsert(fixedHistory, eventAndHash)
        end
    end

    for createTime, events in pairs(eventsByTime) do
        local newEvent = nil

        for i, event in ipairs(events) do
            local reason = event[7]

            if string.find(reason, 'alt_sync') == nil then
                if i == 1 then
                    local eventTime = event[2]
                    local issuer = event[3]
                    local mode = event[5]
                    local diff = event[6]

                    local value
                    local percent
                    if string.find(reason, 'decay') then
                        value = -10
                        percent = true
                        mode = 'both'
                    else
                        value = diff
                        percent = false
                    end

                    newEvent = {createTime, eventTime, issuer, {}, mode, value, reason, percent}
                end

                local player = event[4]
                tinsert(newEvent[4], player)
            end
        end

        local hash = ns.Lib.hash(newEvent)
        tinsert(fixedHistory, {newEvent, hash})
    end

    table.sort(fixedHistory, function(left, right)
        return left[1][1] < right[1][1]
    end)

    ns.db.history = fixedHistory
end
