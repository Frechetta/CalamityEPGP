local addonName, ns = ...  -- Namespace

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
    rolling = false,
    rollPattern = ns.Lib:createPattern(RANDOM_ROLL_RESULT),
}

ns.LootDistWindow = LootDistWindow

local defaultItemIcon = 'Interface\\Icons\\INV_Misc_QuestionMark'

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
            LootDistWindow:print(seconds .. ' seconds to roll')
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

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP')

    mainFrame.itemIcon = mainFrame:CreateTexture(nil, 'OVERLAY')
    mainFrame.itemIcon:SetSize(30, 30)
    mainFrame.itemIcon:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -15)
    mainFrame.itemIcon:SetTexture(defaultItemIcon)

    mainFrame.itemLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.itemLabel:SetText('Invalid item')
    mainFrame.itemLabel:SetPoint('LEFT', mainFrame.itemIcon, 'RIGHT', 10, 0)

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
    mainFrame.startButton:SetScript('OnClick', self.startRoll)
    mainFrame.stopButton:SetScript('OnClick', function() duration = 0 end)

    self:createTable()

	return mainFrame;
end

function LootDistWindow:createTable()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    local scrollFrameName = parent.scrollFrame:GetName()
    parent.scrollBar = _G[scrollFrameName .. 'ScrollBar'];
    parent.scrollUpButton = _G[scrollFrameName .. 'ScrollBarScrollUpButton'];
    parent.scrollDownButton = _G[scrollFrameName .. 'ScrollBarScrollDownButton'];

    -- all of these objects will need to be re-anchored (if not, they appear outside the frame and about 30 pixels too high)
    parent.scrollUpButton:ClearAllPoints();
    parent.scrollUpButton:SetPoint('TOPRIGHT', parent.scrollFrame, 'TOPRIGHT', -2, -2);

    parent.scrollDownButton:ClearAllPoints();
    parent.scrollDownButton:SetPoint('BOTTOMRIGHT', parent.scrollFrame, 'BOTTOMRIGHT', -2, 2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint('TOP', parent.scrollUpButton, 'BOTTOM', 0, -2);
    parent.scrollBar:SetPoint('BOTTOM', parent.scrollDownButton, 'TOP', 0, 2);

    parent.scrollChild = CreateFrame('Frame')
    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth(), parent.scrollFrame:GetHeight() * 2)
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

    parent.rows = {}
end


function LootDistWindow:draw(itemLink)
    if self.rolling then
        return
    end

    local _, _, _, _, _, _, _, _, _, texture, _ = GetItemInfo(itemLink)

    self.mainFrame.itemIcon:SetTexture(texture)
    self.mainFrame.itemLabel:SetText(itemLink)
    self.mainFrame.countdownLabel:SetText('0 seconds left')
    self.mainFrame.countdownLabel:SetTextColor(1, 0, 0)

    self.data.rolls = {}
    self:setData()

    self.mainFrame:Show()

    self.itemLink = itemLink
end


function LootDistWindow:startRoll()
    self = LootDistWindow

    self.mainFrame.startButton:Disable()
    self.mainFrame.stopButton:Enable()
    self.rolling = true

    duration = self.mainFrame.timerEditBox:GetNumber()
    seconds = duration - 1
    onesec = 1

    self:print('You have ' .. duration .. ' seconds to roll on ' .. self.itemLink, true)
    self:print('"/roll" for MS and "/roll 99" for OS')

    self.mainFrame.countdownLabel:SetText(duration .. ' seconds left')
    self.mainFrame.countdownLabel:SetTextColor(0, 1, 0)

    countDownFrame:Show()

    self.data.rolls = {}
    self:setData()
end

function LootDistWindow:stopRoll()
    self = LootDistWindow

    self:print('Stop your rolls!', true)

    self.mainFrame.countdownLabel:SetTextColor(1, 0, 0)
    LootDistWindow.mainFrame.countdownLabel:SetText('0 seconds left')

    self.rolling = false
    self.mainFrame.startButton:Enable()
    self.mainFrame.stopButton:Disable()

    -- TODO: implement close on award
end


function LootDistWindow:print(msg, rw)
    if IsInRaid() then
        local channel = rw and 'RAID_WARNING' or 'RAID'
        SendChatMessage('CalamityEPGP: ' .. msg, channel)
    else
        ns.addon:Print(msg)
    end
end


function LootDistWindow:handleRoll(roller, roll, rollType)
    if not self.rolling then
        return
    end

    if self.data.rolls[roller] == nil then
        self.data.rolls[roller] = {}
    end

    local rollerData = self.data.rolls[roller]

    if rollerData[rollType] == nil then
        rollerData[rollType] = roll
    end

    rollerData['type'] = rollType

    self:setData()
end

function LootDistWindow:setData()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rows = {}

    for roller, rollData in pairs(data.rolls) do
        local type = rollData.type
        local roll = rollData[type]

        local rollerGuid = ns.addon.charNameToGuid[roller]
        local charData = ns.db.standings[rollerGuid]
        local priority = tonumber(string.format("%.2f", charData.ep / charData.gp))

        tinsert(rows, {roller, type, priority, roll})
    end

    table.sort(rows, function(left, right)
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
            return prLeft < prRight
        end

        return rollLeft < rollRight
    end)

    for i, rowData in ipairs(rows) do
        if i > #parent.rows then
            self:addRow(i)
        end

        local row = parent.rows[i]
        row:Show()

        for j, columnText in ipairs(rowData) do
            local column = row.columns[j]
            column:SetText(columnText)
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
        column:SetPoint('TOP', row, 'TOP', 0, 0)
        column:SetPoint('LEFT', headerColumn, 'LEFT', 0, 0)
        column:SetWidth(headerColumn:GetWidth())

        tinsert(row.columns, column)
    end

    -- Highlight
    row:EnableMouse()

    local highlightFrame = parent.contents.rowHighlight

    row:SetScript('OnEnter', function()
        highlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
        highlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 1, 0)
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
    ns.addon:Print('clicked ', charName)
end

-- function LootDistWindow:getData()
--     local data = {
--         ['header'] = {
--             {'Name', 'LEFT'},
--             {'Class', 'LEFT'},
--             {'Guildie', 'LEFT'},
--             {'Rank', 'LEFT'},
--             {'EP', 'RIGHT'},
--             {'GP', 'RIGHT'},
--             {'PR', 'RIGHT'}
--         },
--         ['rows'] = {},
--     }

--     for _, charData in pairs(ns.db.standings) do
--         local row = {
--             charData.name,
--             charData.class,
--             charData.inGuild and 'Yes' or 'No',
--             charData.rank,
--             tonumber(string.format("%.2f", charData.ep)),
--             tonumber(string.format("%.2f", charData.gp)),
--             tonumber(string.format("%.2f", charData.ep / charData.gp)),
--             {guid = charData.guid}
--         }

--         table.insert(data.rows, row)
--     end

--     self.data = data
-- end
