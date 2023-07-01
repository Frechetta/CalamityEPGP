local addonName, ns = ...  -- Namespace

local HistoryWindow = {
    data = {
        ['header'] = {
            {'Time', 'LEFT'},
            {'Player', 'LEFT'},
            {'Issued By', 'LEFT'},
            {'Reason', 'LEFT'},
            {'Action', 'LEFT'},
            {'EP Delta', 'RIGHT'},
            {'GP Delta', 'RIGHT'},
            {'PR Delta', 'RIGHT'},
        },
        ['rows'] = {},
        ['rowsFiltered'] = {},
    }
}

ns.HistoryWindow = HistoryWindow

local fontSize = 10


function HistoryWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_HistoryWindow', UIParent, 'BasicFrameTemplateWithInset');
	mainFrame:SetSize(800, 500);
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    mainFrame:SetFrameStrata('HIGH')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight');
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0);
	mainFrame.title:SetText('CalamityEPGP History');

    mainFrame.searchLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.searchLabel:SetText('Search:')
    mainFrame.searchLabel:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -20)

    mainFrame.searchEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
	mainFrame.searchEditBox:SetPoint('LEFT', mainFrame.searchLabel, 'RIGHT', 10, 0)
    mainFrame.searchEditBox:SetWidth(175)
    mainFrame.searchEditBox:SetHeight(20)
    mainFrame.searchEditBox:SetAutoFocus(false)

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.searchLabel, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -8, 7)

    tinsert(UISpecialFrames, mainFrame:GetName())

    self:createTable()

	return mainFrame;
end

function HistoryWindow:createTable()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    -- Initialize header
    -- we will finalize the size once the scroll frame is set up
    parent.header = CreateFrame('Frame', nil, parent)
    parent.header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, 0)
    parent.header:SetHeight(10)

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -20)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    parent.scrollChild = CreateFrame('Frame')

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

    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth(), parent.scrollFrame:GetHeight() * 2)

    -- Back to the header
    parent.header:SetPoint('RIGHT', parent.scrollBar, 'LEFT', -5, 0)

    parent.header.columns = {}

    for i, header in ipairs(data.header) do
        local headerText = header[1]
        local justify = header[2]

        local column = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        column:SetText(headerText)
        column:SetJustifyH(justify)
        column:SetTextColor(1, 1, 0)
        column:SetFont('Fonts\\ARIALN.TTF', 10)

        column.textWidth = column:GetWrappedWidth()
        column.maxWidth = column.textWidth

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

function HistoryWindow:show()
    self:getData()
    self:setData()
    self.mainFrame:Show()
end

function HistoryWindow:setData()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    for i, rowData in ipairs(data.rowsFiltered) do
        if i > #parent.rows then
            self:addRow(i)
        end

        local row = parent.rows[i]
        row:Show()

        for j, columnText in ipairs(rowData) do
            local headerColumn = parent.header.columns[j]

            local column = row.columns[j]
            column:SetText(columnText)

            local text_width = column:GetWrappedWidth()
            if (text_width > headerColumn.maxWidth) then
                headerColumn.maxWidth = text_width
            end
        end
    end

    if #parent.rows > #data.rowsFiltered then
        for i = #data.rowsFiltered + 1, #parent.rows do
            local row = parent.rows[i]
            row:Hide()
        end
    end

    -- Calculate column padding
    local columnWidthTotal = 0
    for _, column in ipairs(parent.header.columns) do
        columnWidthTotal = columnWidthTotal + column.maxWidth
    end

    local leftover = parent.header:GetWidth() - columnWidthTotal
    local columnPadding = leftover / #parent.header.columns

    -- Finally set column widths
    -- header
    for i, column in ipairs(parent.header.columns) do
        local relativeElement = parent.header
        local relativePoint = 'LEFT'
        local padding = 0
        if (i > 1) then
            relativeElement = parent.header.columns[i - 1]
            relativePoint = 'RIGHT'
            padding = relativeElement.padding
        end

        local xOffset = padding
        column.padding = column.maxWidth + columnPadding - column.textWidth

        if column:GetJustifyH() == 'RIGHT' then
            xOffset = xOffset + column.maxWidth - column.textWidth
            column.padding = columnPadding
        end

        column:SetPoint('LEFT', relativeElement, relativePoint, xOffset, 0)
        column:SetWidth(column.textWidth)
    end

    -- data
    for _, row in ipairs(parent.rows) do
        for i, column in ipairs(row.columns) do
            local headerColumn = parent.header.columns[i]

            local textHeight = column:GetLineHeight()
            local verticalPadding = (row:GetHeight() - textHeight) / 2

            local anchorPoint = headerColumn:GetJustifyH()
            column:SetPoint(anchorPoint, headerColumn, anchorPoint, 0, 0)
            column:SetPoint('TOP', row, 'TOP', 0, -verticalPadding)
        end
    end
end

function HistoryWindow:addRow(index)
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rowHeight = 15

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = (rowHeight + 1) * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.columns = {}

    for i = 1, #data.header do
        -- We will set the size later, once we've computed the column width based on the data
        local column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')

        column:SetPoint('TOP', row, 'TOP', 0, 0)
        column:SetFont('Fonts\\ARIALN.TTF', 10)

        table.insert(row.columns, column)
    end

    -- Highlight
    row:EnableMouse()

    local highlightFrame = parent.contents.rowHighlight

    row:SetScript('OnEnter', function()
        highlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
        highlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
        highlightFrame:Show()
    end)

    row:SetScript('OnLeave', function()
        highlightFrame:Hide()
    end)

    table.insert(parent.rows, row)
end

function HistoryWindow:filterData()
    self.data.rowsFiltered = self.data.rows

    -- for _, row in ipairs(self.data.rows) do
    --     local keep = true
    --     if self.mainFrame.raidOnlyButton:GetChecked() and ns.addon.raidRoster[row[1]] == nil then
    --         keep = false
    --     end

    --     if keep then
    --         tinsert(self.data.rowsFiltered, row)
    --     end
    -- end
end

function HistoryWindow:getData()
    self.data.rows = {}
    self.data.rowsFiltered = {}

    local playerGuidToName = {}
    for player, guid in pairs(ns.Lib.playerNameToGuid) do
        playerGuidToName[guid] = player
    end

    local playerValsTracker = {}
    for guid, standings in pairs(ns.standings) do
        if playerValsTracker[guid] == nil then
            playerValsTracker[guid] = {}
        end

        playerValsTracker[guid]['EP'] = standings.ep
        playerValsTracker[guid]['GP'] = standings.gp
    end

    for i = #ns.db.history, 1, -1 do
        local event = ns.db.history[i]
        local diff = event[5]

        if diff ~= 0 then
            local playerGuid = event[3]

            local time = date('%Y-%m-%d %H:%M:%S', event[1])
            local issuedBy = playerGuidToName[event[2]]
            local player = playerGuidToName[playerGuid]
            local mode = string.upper(event[4])
            local reason = event[6]

            local reasonSplit = ns.Lib:split(reason, ':')
            local baseReason = reasonSplit[1]
            local enteredReason = strtrim(reasonSplit[2])

            if string.find(baseReason, 'manual') then
                baseReason = 'manual'
            end

            reason = baseReason
            if #enteredReason > 0 then
                reason = string.format('%s (%s)', reason, enteredReason)
            end

            local diffStr = diff > 0 and string.format('+%d', diff) or tostring(diff)
            local action = string.format('%s %s', mode, diffStr)

            local standings = playerValsTracker[playerGuid]

            local epDelta
            local gpDelta

            local epAfter = standings['EP']
            local gpAfter = standings['GP']

            local epBefore = epAfter
            if mode == 'EP' then
                epBefore = epBefore - diff

                epDelta = string.format('%d -> %d', epBefore, epAfter)
                gpDelta = gpAfter
            end

            local gpBefore = gpAfter
            if mode == 'GP' then
                gpBefore = gpBefore - diff

                epDelta = epAfter
                gpDelta = string.format('%d -> %d', gpBefore, gpAfter)
            end

            local prAfter = epAfter / gpAfter
            local prBefore = epBefore / gpBefore
            local prDelta = string.format('%.2f -> %.2f', prBefore, prAfter)

            local row = {
                time,
                player,
                issuedBy,
                reason,
                action,
                epDelta,
                gpDelta,
                prDelta,
            }

            standings['EP'] = epBefore
            standings['GP'] = gpBefore

            tinsert(self.data.rows, row)
        end
    end

    self:filterData()
end
