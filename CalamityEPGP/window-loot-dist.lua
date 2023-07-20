local addonName, ns = ...  -- Namespace

local List = ns.List

local LootDistWindow = {
    data = {
        header = {
            {'Player', 'LEFT'},
            {'Response', 'LEFT'},
            {'Priority', 'RIGHT'},
            {'Roll', 'RIGHT'},
        },
        rolls = {},
    },
    itemLink = nil,
    defaultItemIcon = 'Interface\\Icons\\INV_Misc_QuestionMark',
    rolling = false,
    rollPattern = ns.Lib.createPattern(RANDOM_ROLL_RESULT),
    selectedRoller = nil,
    currentLoot = {},
    trading = {},
    disenchanter = nil,
}

ns.LootDistWindow = LootDistWindow

local duration, seconds, onesec
local countDownFrame = CreateFrame("Frame")
countDownFrame:Hide()
countDownFrame:SetScript("OnUpdate", function(self, elapsed)
    onesec = onesec - elapsed
    duration = duration - elapsed
    if duration <= 0 then
        LootDistWindow:stopRoll()
        self:Hide()
    elseif onesec <= 0 then
        LootDistWindow.mainFrame.countdownLabel:SetText(seconds .. ' seconds left')
        if seconds <= 5 then
            ns.printPublic(seconds .. ' seconds to roll')
            LootDistWindow.mainFrame.countdownLabel:SetTextColor(1, 0.5, 0)
        end
        seconds = seconds - 1
        onesec = 1
    end
end)


function LootDistWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_LootDistWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(500, 375)
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    mainFrame:SetFrameStrata('HIGH')
    mainFrame:SetFrameLevel(5000)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP Loot Distribution')

    mainFrame.itemIcon = mainFrame:CreateTexture(nil, 'OVERLAY')
    mainFrame.itemIcon:SetSize(30, 30)
    mainFrame.itemIcon:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -15)
    mainFrame.itemIcon:SetTexture(self.defaultItemIcon)
    mainFrame.itemIcon:EnableMouse(true)

    mainFrame.itemLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.itemLabel:SetText('Invalid item')
    mainFrame.itemLabel:SetPoint('LEFT', mainFrame.itemIcon, 'RIGHT', 10, 0)
    mainFrame.itemLabel:EnableMouse(true)

    mainFrame.stopButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.stopButton:SetText('Stop')
    mainFrame.stopButton:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -20)
    mainFrame.stopButton:SetPoint('RIGHT', mainFrame, 'RIGHT', -20, 0)
    mainFrame.stopButton:SetWidth(80)
    mainFrame.stopButton:Disable()

    mainFrame.startButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.startButton:SetText('Start')
    mainFrame.startButton:SetPoint('RIGHT', mainFrame.stopButton, 'LEFT', 0, 0)
    mainFrame.startButton:SetWidth(80)

    mainFrame.gpLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.gpLabel:SetPoint('RIGHT', mainFrame.startButton, 'LEFT', -15, 0)
    mainFrame.gpLabel:SetJustifyH('RIGHT')
    mainFrame.gpLabel:SetTextColor(1, 1, 0)

    mainFrame.timerLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.timerLabel:SetText('Timer (s):')
    mainFrame.timerLabel:SetPoint('TOPLEFT', mainFrame.itemIcon, 'BOTTOMLEFT', 0, -17)

    mainFrame.timerEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
    mainFrame.timerEditBox:SetText(tostring(ns.cfg.rollDuration))
    mainFrame.timerEditBox:SetPoint('LEFT', mainFrame.timerLabel, 'RIGHT', 15, 0)
    mainFrame.timerEditBox:SetHeight(20)
    mainFrame.timerEditBox:SetWidth(30)
    mainFrame.timerEditBox:SetNumeric(true)
    mainFrame.timerEditBox:SetAutoFocus(false)

    mainFrame.deButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.deButton:SetText('Disenchant')
    mainFrame.deButton:SetPoint('TOPRIGHT', mainFrame.stopButton, 'BOTTOMRIGHT', 0, -15)
    mainFrame.deButton:SetWidth(100)

    mainFrame.awardButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.awardButton:SetText('Award')
    mainFrame.awardButton:SetPoint('RIGHT', mainFrame.deButton, 'LEFT', 0, 0)
    mainFrame.awardButton:SetWidth(60)

    mainFrame.clearButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.clearButton:SetText('Clear')
    mainFrame.clearButton:SetPoint('RIGHT', mainFrame.awardButton, 'LEFT', 0, 0)
    mainFrame.clearButton:SetWidth(60)

    mainFrame.closeOnAwardCheck = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.closeOnAwardCheck:SetChecked(ns.cfg.closeOnAward)
    mainFrame.closeOnAwardCheck:SetPoint('LEFT', mainFrame.itemIcon, 'LEFT')
    mainFrame.closeOnAwardCheck:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 15)

    mainFrame.closeOnAwardLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.closeOnAwardLabel:SetText('Close on award')
    mainFrame.closeOnAwardLabel:SetPoint('LEFT', mainFrame.closeOnAwardCheck, 'RIGHT', 3, 1)

    mainFrame.countdownLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.countdownLabel:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 25)

    mainFrame.closeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.closeButton:SetText('Close')
    mainFrame.closeButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -20, 20)
    mainFrame.closeButton:SetWidth(80)

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame.timerLabel, 'BOTTOMLEFT', 0, -20)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame.closeButton, 'TOPRIGHT', 0, 10)

    mainFrame.closeButton:SetScript('OnClick', function() mainFrame:Hide() end)
    mainFrame.startButton:SetScript('OnClick', function() self:startRoll() end)
    mainFrame.stopButton:SetScript('OnClick', function() duration = 0 end)
    mainFrame.clearButton:SetScript('OnClick', function() self:clearRolls() end)
    mainFrame.awardButton:SetScript('OnClick', function() self:checkAward() end)
    mainFrame.deButton:SetScript('OnClick', function() self:disenchant() end)

    self:createTable()

	return mainFrame;
end


function LootDistWindow:createTable()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame(
        'ScrollFrame',
        parent:GetName() .. 'ScrollFrame',
        parent,
        'UIPanelScrollFrameTemplate'
    )
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    local scrollFrameName = parent.scrollFrame:GetName()
    parent.scrollBar = _G[scrollFrameName .. 'ScrollBar'];
    parent.scrollUpButton = _G[scrollFrameName .. 'ScrollBarScrollUpButton'];
    parent.scrollDownButton = _G[scrollFrameName .. 'ScrollBarScrollDownButton'];

    parent.scrollUpButton:ClearAllPoints();
    parent.scrollUpButton:SetPoint('TOPRIGHT', parent.scrollFrame, 'TOPRIGHT', -2, 0);

    parent.scrollDownButton:ClearAllPoints();
    parent.scrollDownButton:SetPoint('BOTTOMRIGHT', parent.scrollFrame, 'BOTTOMRIGHT', -2, -2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint('TOP', parent.scrollUpButton, 'BOTTOM', 0, 0);
    parent.scrollBar:SetPoint('BOTTOM', parent.scrollDownButton, 'TOP', 0, 0);

    parent.scrollChild = CreateFrame('Frame')
    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth() - parent.scrollBar:GetWidth() - 7, 1)
    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    -- Header
    parent.header = CreateFrame('Frame', nil, parent)
    parent.header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, 0)
    parent.header:SetHeight(10)
    parent.header:SetPoint('RIGHT', parent.scrollBar, 'LEFT', -5, 0)

    parent.header.columns = {}

    local columnWidth = parent.header:GetWidth() / #data.header

    for i, header in ipairs(data.header) do
        local headerText = header[1]
        local justify = header[2]

        local xOffset = (i - 1) * columnWidth

        local column = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        column:SetText(headerText)
        column:SetJustifyH(justify)
        column:SetPoint('LEFT', parent.header, 'LEFT', xOffset, 0)
        column:SetWidth(columnWidth)

        table.insert(parent.header.columns, column)
    end

    -- Initialize the content
    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetAllPoints(parent.scrollChild)

    parent.contents.rowHighlight = CreateFrame('Frame', nil, parent.contents)
    local highlightTexture = parent.contents.rowHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    parent.contents.rowHighlight:Hide()

    parent.contents.rowSelectedHighlight = CreateFrame('Frame', nil, parent.contents)
    highlightTexture = parent.contents.rowSelectedHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    parent.contents.rowSelectedHighlight:Hide()

    parent.rows = {}
end


function LootDistWindow:show(itemLink)
    -- TODO: way to get back to the window if currently rolling
    if self.rolling then
        return
    end

    local _, _, _, _, _, _, _, _, _, texture, _ = GetItemInfo(itemLink)

    self.mainFrame.itemIcon:SetTexture(texture)
    self.mainFrame.itemIcon:SetScript('OnEnter', function()
        GameTooltip:SetOwner(self.mainFrame.itemIcon, "ANCHOR_TOPLEFT")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    self.mainFrame.itemIcon:SetScript('OnLeave', function() GameTooltip:Hide() end)

    self.mainFrame.itemLabel:SetText(itemLink)
    self.mainFrame.itemLabel:SetScript('OnEnter', function()
        GameTooltip:SetOwner(self.mainFrame.itemLabel, "ANCHOR_TOPLEFT")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    self.mainFrame.itemLabel:SetScript('OnLeave', function() GameTooltip:Hide() end)

    self.mainFrame.countdownLabel:SetText('0 seconds left')
    self.mainFrame.countdownLabel:SetTextColor(1, 0, 0)

    self.selectedRoller = nil
    self.mainFrame.tableFrame.contents.rowSelectedHighlight:Hide()
    self.data.rolls = {}

    self.itemLink = itemLink
    self.itemGp = ns.Lib.getGp(itemLink)

    self.mainFrame.gpLabel:SetText('GP: ' .. self.itemGp)

    self:setData()
    self.mainFrame:Show()
end


function LootDistWindow:startRoll()
    duration = self.mainFrame.timerEditBox:GetNumber()

    if duration < 5 or duration > 600 then
        return
    end

    self.mainFrame.CloseButton:Disable()
    self.mainFrame.closeButton:Disable()
    self.mainFrame.startButton:Disable()
    self.mainFrame.stopButton:Enable()
    self.mainFrame.awardButton:Disable()
    self.mainFrame.clearButton:Disable()
    self.mainFrame.deButton:Disable()
    self.rolling = true

    ns.printPublic('You have ' .. duration .. ' seconds to roll on ' .. self.itemLink, true)
    ns.printPublic('"/roll" for MS and "/roll 99" for OS')

    self.mainFrame.countdownLabel:SetText(duration .. ' seconds left')
    self.mainFrame.countdownLabel:SetTextColor(0, 1, 0)

    if not IsInGroup() and not IsInRaid() then
        ns.RollWindow:show(self.itemLink, duration)
    end

    seconds = duration - 1
    onesec = 1
    countDownFrame:Show()

    self.selectedRoller = nil
    self.mainFrame.tableFrame.contents.rowSelectedHighlight:Hide()
    self.data.rolls = {}
    self:setData()
end


function LootDistWindow:stopRoll()
    ns.RollWindow:hide()

    ns.printPublic('Stop your rolls!', true)

    self.mainFrame.countdownLabel:SetTextColor(1, 0, 0)
    LootDistWindow.mainFrame.countdownLabel:SetText('0 seconds left')

    self.rolling = false
    self.mainFrame.CloseButton:Enable()
    self.mainFrame.closeButton:Enable()
    self.mainFrame.startButton:Enable()
    self.mainFrame.stopButton:Disable()
    self.mainFrame.awardButton:Enable()
    self.mainFrame.clearButton:Enable()
    self.mainFrame.deButton:Enable()

    -- announce all rolls in order
    local rolls = List:new()

    for roller, rollData in pairs(self.data.rolls) do
        local type = rollData.type
        if type ~= nil then
            local roll = rollData[type]
            local pr = rollData.pr

            rolls:bininsert({roller, type, pr, roll}, function(left, right)
                local rollTypeLeft = left[2]
                local rollTypeRight = right[2]
                local prLeft = left[3]
                local prRight = right[3]
                local rollLeft = left[4]
                local rollRight = right[4]

                if rollTypeLeft ~= rollTypeRight then
                    return rollTypeLeft < rollTypeRight
                end

                if prLeft ~= prRight then
                    return prLeft > prRight
                end

                return rollLeft > rollRight
            end)
        end
    end

    if rolls:len() > 0 then
        ns.printPublic('Rolls:')
        for rollData in rolls:iter() do
            ns.printPublic(
                string.format('- %s [%s]  PR: %.3f,  Roll: %d', rollData[1], rollData[2], rollData[3], rollData[4])
            )
        end
    end
end


function LootDistWindow:clearRolls()
    self.selectedRoller = nil
    self.mainFrame.tableFrame.contents.rowSelectedHighlight:Hide()
    self.data.rolls = {}
    self:setData()
end


function LootDistWindow:handleRoll(roller, roll, rollType)
    if not self.rolling then
        return
    end

    local rollerGuid = ns.Lib.getPlayerGuid(roller)
    local charData = ns.db.standings[rollerGuid]
    local priority = tonumber(string.format("%.3f", charData.ep / charData.gp))

    -- local newRoll = false

    if self.data.rolls[roller] == nil then
        self.data.rolls[roller] = {}
        -- newRoll = true
    end

    local rollerData = self.data.rolls[roller]

    if rollerData[rollType] == nil then
        rollerData[rollType] = roll
    end

    roll = rollerData[rollType]

    rollerData.type = rollType
    rollerData.pr = priority

    -- TODO: don't print if roll is already there unless response is changed
    ns.printPublic(roller .. ': ' .. rollType .. ', PR: ' .. priority .. ', Roll: ' .. roll)

    self:setData()
end


function LootDistWindow:handlePass(player)
    if not self.rolling then
        return
    end

    if self.data.rolls[player] == nil then
        return
    end

    self.data.rolls[player].type = nil

    ns.printPublic(player .. ' cancels their roll')

    self:setData()
end


function LootDistWindow:setData()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rows = {}

    for roller, rollData in pairs(data.rolls) do
        local type = rollData.type
        if type ~= nil then
            local roll = rollData[type]
            local pr = rollData.pr

            ns.Lib.bininsert(rows, {roller, type, pr, roll}, function(left, right)
                local rollTypeLeft = left[2]
                local rollTypeRight = right[2]
                local prLeft = left[3]
                local prRight = right[3]
                local rollLeft = left[4]
                local rollRight = right[4]

                if rollTypeLeft ~= rollTypeRight then
                    return rollTypeLeft < rollTypeRight
                end

                if prLeft ~= prRight then
                    return prLeft > prRight
                end

                return rollLeft > rollRight
            end)
        end
    end

    for i, rowData in ipairs(rows) do
        if i > #parent.rows then
            self:addRow(i)
        end

        local row = parent.rows[i]
        row:Show()

        local name = rowData[1]
        local _, classFileName = UnitClass(name)
        local classColorData = RAID_CLASS_COLORS[classFileName]

        for j, columnText in ipairs(rowData) do
            local column = row.columns[j]
            column:SetText(columnText)
            column:SetTextColor(classColorData.r, classColorData.g, classColorData.b)
        end
    end

    if #parent.rows > #rows then
        for i = #rows + 1, #parent.rows do
            local row = parent.rows[i]
            row:Hide()
        end
    end
end


function LootDistWindow:addRow(index)
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rowHeight = 15

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = (rowHeight + 3) * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.columns = {}

    for i, header in ipairs(data.header) do
        local headerColumn = parent.header.columns[i]
        local justify = header[2]

        local column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        column:SetJustifyH(justify)
        column:SetJustifyV('MIDDLE')
        column:SetPoint('TOP', row)
        column:SetPoint('LEFT', headerColumn)
        column:SetSize(headerColumn:GetWidth(), row:GetHeight())

        tinsert(row.columns, column)
    end

    -- Highlight
    row:EnableMouse()

    local highlightFrame = parent.contents.rowHighlight

    row:SetScript('OnEnter', function()
        highlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
        highlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 5, 0)
        highlightFrame:Show()
    end)

    row:SetScript('OnLeave', function()
        highlightFrame:Hide()
    end)

    row:SetScript('OnMouseUp', function(_, button)
        if button == 'LeftButton' then
            LootDistWindow:handleRowClick(row)
        end
    end)

    table.insert(parent.rows, row)
end


function LootDistWindow:handleRowClick(row)
    local charName = row.columns[1]:GetText()
    self.selectedRoller = charName

    local selectedHighlightFrame = self.mainFrame.tableFrame.contents.rowSelectedHighlight
    selectedHighlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
    selectedHighlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 5, 0)
    selectedHighlightFrame:Show()
end


function LootDistWindow:getLoot()
	self:clearLoot()

	for i = 1, GetNumLootItems() do
        if LootSlotHasItem(i) then
            local itemLink = GetLootSlotLink(i)

            if itemLink ~= nil then
                -- ns.debug(i .. ': ' .. itemLink)
                self.currentLoot[itemLink] = i
            end
        end
	end
end


function LootDistWindow:clearLoot()
    self.currentLoot = {}
end


function LootDistWindow:checkAward()
    if not IsMasterLooter() then
		ns.print('You are not the master looter!')
		-- return
	end

    local awardee = self.selectedRoller

    if awardee == nil then
        return
    end

    local rollType = self.data.rolls[awardee].type

    ns.ConfirmAwardWindow:show(self.itemLink, self.itemGp, awardee, rollType)
end


function LootDistWindow:award(itemLink, awardee, rollType, perc, gp)
    ns.debug(itemLink .. ' awarded to ' .. awardee)

    -- add item to awarded table
    if ns.db.loot.awarded[itemLink] == nil then
        ns.db.loot.awarded[itemLink] = {}
    end

    if ns.db.loot.awarded[itemLink][awardee] == nil then
        ns.db.loot.awarded[itemLink][awardee] = {}
    end

    tinsert(ns.db.loot.awarded[itemLink][awardee], {
        itemLink = itemLink,
        awardTime = time(),
        given = false,
        givenTime = nil,
        collected = false,
    })

	local itemIndex = self.currentLoot[itemLink]

	if itemIndex ~= nil then
        -- item is from loot window
        local playerIndex
        for i = 1, GetNumGroupMembers() do
            local candidate = GetMasterLootCandidate(itemIndex, i)
            if candidate == awardee then
                playerIndex = i
                break
            end
        end

		if playerIndex ~= nil then
			GiveMasterLoot(itemIndex, playerIndex)
		else
			ns.print(awardee .. ' is not eligible for loot')
		end
    elseif awardee == UnitName('player') then
        -- item is in inventory and was awarded to me
        self:successfulAward(itemLink, awardee)
    else
        -- item is in inventory and awarded to someone else and must be traded
        self.markAsToTrade(itemLink, awardee)
	end

    local itemName = GetItemInfo(itemLink)

    if rollType ~= nil then
        -- add gp
        local reason = string.format('%s: %s - %s - %.2f', ns.values.epgpReasons.AWARD, itemName, rollType, gp)
        ns.addon:modifyEpgp({ns.Lib.getPlayerGuid(awardee)}, 'GP', gp, reason)
        ns.printPublic(string.format('%s was awarded to %s for %s (%s GP: %d)', itemLink, awardee, rollType, perc, gp))
    else
        ns.printPublic(string.format('%s was awarded to %s', itemLink, awardee))
    end

    if self.mainFrame ~= nil and self.mainFrame.closeOnAwardCheck:GetChecked() then
        self.mainFrame:Hide()
    end
end


function LootDistWindow:handleLootReceived(itemLink, player)
    local awardedData = ns.db.loot.awarded[itemLink]

    -- if this item hasn't been awarded to anyone
    if awardedData == nil then
        return
    end

    -- I received the item
    if player == 'You' then
        ns.debug('i received ' .. itemLink)
        local myName = UnitName('player')

        -- iterate over awarded items for ones that haven't been collected
        for awardedPlayer, awardedItem in pairs(awardedData) do
            if not awardedItem.given and not awardedItem.collected then
                awardedItem.collected = true

                ns.debug(string.format('---- awardedPlayer: %s, awardedItem: %s', awardedPlayer, tostring(awardedItem)))

                -- TODO: fix
                if awardedPlayer == myName then
                    -- if this item was awarded to me, mark it as successful
                    self:successfulAward(itemLink, myName)
                else
                    -- else, mark it as to trade
                    self.markAsToTrade(itemLink, awardedPlayer)
                end

                return
            end
        end
    else
        -- item went to someone else, mark it as successful
        self:successfulAward(itemLink, player)
    end
end


function LootDistWindow.markAsToTrade(itemLink, player)
    ns.debug('marked as to trade: ' .. itemLink .. ' - ' .. player)

    local toTrade = ns.db.loot.toTrade

	if toTrade[player] == nil then
		toTrade[player] = {}
	end

	tinsert(toTrade[player], {itemLink, time()})
end


function LootDistWindow.handleTradeRequest(player)
	if ns.db.loot.toTrade[player] == nil then
		return
	end

    ns.debug('trade request with to-trade player')

	InitiateTrade(player)
end


function LootDistWindow:handleTradeShow()
	local player, _ = UnitName('npc')

	self.trading.player = player

	local itemsToTrade = ns.db.loot.toTrade[player]
	if itemsToTrade == nil then
        ns.debug('nothing to trade with player ' .. player)
		return
	end

    local items = List:new()

    ns.debug(player)
    ns.debug('-- items to trade')

    for _, item in ipairs(itemsToTrade) do
        ns.debug('---- ' .. item[1])
        items:append(item[1])
    end

    local i = 1

    -- iterate through bags (j), and items (k) to find self.itemLink
    for container = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(container)
        for slot = 0, numSlots do
            local containerItemLink = C_Container.GetContainerItemLink(container, slot)

            if items:contains(containerItemLink) then
                ns.debug('-- trade ' .. container .. ' ' .. slot .. ' ' .. containerItemLink)

                C_Timer.After(i * 0.1, function()
                    self.addItemToTrade(container, slot)
                    items:remove(containerItemLink)
                end)

                i = i + 1
            end
        end
    end
end


function LootDistWindow.getToTradeItem(player, itemLink)
    local items = ns.db.loot.toTrade[player]

    if items == nil then
        return
    end

    for _, item in ipairs(items) do
        if item[1] == itemLink then
            return item
        end
    end
end


function LootDistWindow.addItemToTrade(container, slot)
    if (UseContainerItem) then
        UseContainerItem(container, slot)
    else
        C_Container.UseContainerItem(container, slot);
    end
end


function LootDistWindow:handleTradePlayerItemChanged()
    self.trading.items = {}

    for i = 1, MAX_TRADABLE_ITEMS do
        local itemLink = GetTradePlayerItemLink(i);

        if itemLink ~= nil then
            tinsert(self.trading.items, itemLink)
        end
    end
end


function LootDistWindow:handleTradeComplete()
    local player = self.trading.player
    local items = self.trading.items
    ns.debug('handle trade complete with ' .. player)

    local itemsToTrade = ns.db.loot.toTrade[player]

    if itemsToTrade == nil then
        return
    end

    ns.debug('-- ' .. player .. ' ' .. tostring(itemsToTrade))

    for _, itemLink in ipairs(items) do
        self:successfulAward(itemLink, player)
    end
end


function LootDistWindow:successfulAward(itemLink, player)
    ns.debug(itemLink .. ' successfully given to ' .. player)

    local itemToTrade = self.getToTradeItem(player, itemLink)
    if itemToTrade ~= nil then
        local items = ns.db.loot.toTrade[player]
        if items ~= nil then
            ns.Lib.remove(items, itemToTrade)
        end
    end

    local awardedItems = ns.db.loot.awarded[itemLink][player]

    if awardedItems ~= nil then
        for _, awardedItem in ipairs(awardedItems) do
            ns.debug(string.format('-- awardedItem: %s (given: %s)', awardedItem.itemLink, tostring(awardedItem.given)))
            if not awardedItem.given then
                ns.debug('---- set given')
                awardedItem.given = true
                awardedItem.givenTime = time()
                return
            end
        end
    end
end


function LootDistWindow:disenchant()
    if self.disenchanter == nil then
        ns.DeSelectWindow:show()
        return
    end

	ns.printPublic(string.format('Item %s will be disenchanted by %s', self.itemLink, self.disenchanter))

    local itemIndex = self.currentLoot[self.itemLink]

	if itemIndex ~= nil then
        -- item is from loot window
        local playerIndex
        for i = 1, GetNumGroupMembers() do
            local candidate = GetMasterLootCandidate(itemIndex, i)
            if candidate == self.disenchanter then
                playerIndex = i
                break
            end
        end

		if playerIndex ~= nil then
			GiveMasterLoot(itemIndex, playerIndex)
		else
			ns.print(self.disenchanter .. ' is not eligible for loot')
            return
		end
	end

    if self.mainFrame.closeOnAwardCheck:GetChecked() then
        self.mainFrame:Hide()
    end
end