local addonName, ns = ...  -- Namespace

local MainWindow = {
    data = {}
}

ns.MainWindow = MainWindow


function MainWindow:createWindow()
    local mainFrame = CreateFrame('Frame', addonName .. '_MainWindow', UIParent, 'BasicFrameTemplateWithInset');
	mainFrame:SetSize(600, 450);
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight');
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0);
	mainFrame.title:SetText('CalamityEPGP');

    mainFrame.raidOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.raidOnlyLabel:SetText('Raid Only')
    mainFrame.raidOnlyLabel:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -20)

    mainFrame.raidOnlyButton = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.raidOnlyButton:SetPoint('LEFT', mainFrame.raidOnlyLabel, 'RIGHT', 5, 0)

    if IsInRaid() then
        mainFrame.raidOnlyButton:SetChecked(true)
    end

    mainFrame.optionsButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.optionsButton:SetText('Options')
    mainFrame.optionsButton:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -15)
    mainFrame.optionsButton:SetPoint('RIGHT', mainFrame, 'RIGHT', -20, 0)
    mainFrame.optionsButton:SetWidth(97)

    -- TODO: disable for non officers
    mainFrame.addEpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.addEpButton:SetText('Add EP')
    mainFrame.addEpButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 10, 8)
    mainFrame.addEpButton:SetWidth(90)

    -- TODO: disable for non officers
    mainFrame.decayEpgpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.decayEpgpButton:SetText('Decay EPGP')
    mainFrame.decayEpgpButton:SetPoint('LEFT', mainFrame.addEpButton, 'RIGHT', 2, 0)
    mainFrame.decayEpgpButton:SetWidth(100)

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.raidOnlyLabel, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMLEFT', mainFrame.addEpButton, 'TOPLEFT', 0, 2)

    mainFrame.optionsButton:SetScript('OnClick', ns.addon.openOptions)
    mainFrame.addEpButton:SetScript('OnClick', self.handleAddEpClick)
    mainFrame.decayEpgpButton:SetScript('OnClick', self.handleDecayEpgpClick)
    mainFrame.raidOnlyButton:SetScript('OnClick', function() self:filterData(); self:setData() end)

    tinsert(UISpecialFrames, mainFrame:GetName())

    self:refresh(true)

	return mainFrame;
end

function MainWindow:refresh(initial)
    if self.mainFrame == nil then
        return
    end

    local initial = initial or false

    self:getData()

    if initial then
        self:createTable()
    end

    self:setData()
end

function MainWindow:createTable()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    -- Initialize header
    -- we will finalize the size once the scroll frame is set up
    parent.header = CreateFrame('Frame', nil, parent)
    parent.header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, 0)
    parent.header:SetHeight(10)

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
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

        local column = CreateFrame('Frame', nil, parent.header)
        column:SetHeight(parent.header:GetHeight())

        local fontString = column:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        fontString:SetText(headerText)
        fontString:SetJustifyH(justify)
        fontString:SetTextColor(1, 1, 0)

        column.fontString = fontString
        column.textWidth = fontString:GetWrappedWidth()
        column.maxWidth = column.textWidth

        column:SetScript('OnEnter', function() fontString:SetTextColor(1, 1, 1) end)
        column:SetScript('OnLeave', function() fontString:SetTextColor(1, 1, 0) end)

        column:SetScript('OnMouseUp', function(self, button)
            if button == 'LeftButton' then
                MainWindow:handleHeaderClick(i)
            end
        end)

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

    for i = 1, #data.rowsFiltered do
        self:addRow(i)
    end
end

function MainWindow:setData()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    for i, rowData in ipairs(data.rowsFiltered) do
        if i > #parent.rows then
            self:addRow(i)
        end

        local row = parent.rows[i]
        row:Show()

        local class = string.upper(rowData[2]):gsub(' ', '')
        local classColorData = RAID_CLASS_COLORS[class]

        for j, columnText in ipairs(rowData) do
            local headerColumn = parent.header.columns[j]

            if headerColumn == nil then
                row.charGuid = columnText['guid']
                break
            end

            local column = row.columns[j]

            column:SetText(columnText)
            column:SetTextColor(classColorData.r, classColorData.g, classColorData.b)

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

        if column.fontString:GetJustifyH() == 'RIGHT' then
            xOffset = xOffset + column.maxWidth - column.textWidth
            column.padding = columnPadding
        end

        column:SetPoint('LEFT', relativeElement, relativePoint, xOffset, 0)
        column:SetWidth(column.textWidth)

        column.fontString:SetAllPoints()
    end

    -- data
    for _, row in ipairs(parent.rows) do
        for i, column in ipairs(row.columns) do
            local headerColumn = parent.header.columns[i]

            local textHeight = column:GetLineHeight()
            local verticalPadding = (row:GetHeight() - textHeight) / 2

            local anchorPoint = headerColumn.fontString:GetJustifyH()
            column:SetPoint(anchorPoint, headerColumn, anchorPoint, 0, 0)
            column:SetPoint('TOP', row, 'TOP', 0, -verticalPadding)
        end
    end
end

function MainWindow:addRow(index)
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rowHeight = 15

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = (rowHeight + 3) * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.columns = {}

    for i = 1, #data.header do
        -- We will set the size later, once we've computed the column width based on the data
        local column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')

        column:SetPoint('TOP', row, 'TOP', 0, 0)

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

    row:SetScript('OnMouseUp', function(self, button)
        if button == 'LeftButton' then
            MainWindow:handleRowClick(row)
        end
    end)

    table.insert(parent.rows, row)
end

function MainWindow:handleHeaderClick(headerIndex)
    local order = 'ascending'
    if self.data.sorted.columnIndex == headerIndex and self.data.sorted.order == order then
        order = 'descending'
    end

    self:sortData(headerIndex, order)
    self:setData()
end

function MainWindow:handleRowClick(row)
    -- TODO: if not officer, return

    ns.ModifyEpgpWindow:show(row.columns[1]:GetText(), row.charGuid)
end

function MainWindow:handleAddEpClick()
    -- TODO: if not officer, return

    ns.AddEpWindow:show()
end

function MainWindow:handleDecayEpgpClick()
    -- TODO: if not officer, return

    ns.DecayEpgpWindow:show()
end

function MainWindow:filterData()
    self.data.rowsFiltered = {}

    for _, row in ipairs(self.data.rows) do
        local keep = true
        if self.mainFrame.raidOnlyButton:GetChecked() and ns.addon.raidRoster[row[1]] == nil then
            keep = false
        end

        if keep then
            tinsert(self.data.rowsFiltered, row)
        end
    end

    self:sortData()
end

function MainWindow:sortData(columnIndex, order)
    if columnIndex == nil then
        columnIndex = self.data.sorted.columnIndex
    end

    if order == nil then
        order = self.data.sorted.order
    end

    if columnIndex == nil or order == nil then
        return
    end

    table.sort(self.data.rowsFiltered, function(left, right)
        if order == 'ascending' then
            return left[columnIndex] < right[columnIndex]
        else
            return left[columnIndex] > right[columnIndex]
        end
    end)

    self.data.sorted.columnIndex = columnIndex
    self.data.sorted.order = order
end

function MainWindow:getData()
    local sorted = {}
    if self.data.sorted ~= nil and self.data.sorted.columnIndex ~= nil then
        sorted = self.data.sorted
    end

    local data = {
        ['header'] = {
            {'Name', 'LEFT'},
            {'Class', 'LEFT'},
            {'Guildie', 'LEFT'},
            {'Rank', 'LEFT'},
            {'EP', 'RIGHT'},
            {'GP', 'RIGHT'},
            {'PR', 'RIGHT'}
        },
        ['rows'] = {},
        ['rowsFiltered'] = {},
        ['sorted'] = sorted,
    }

    for _, charData in pairs(ns.db.standings) do
        local row = {
            charData.name,
            charData.class,
            charData.inGuild and 'Yes' or 'No',
            charData.rank and charData.rank or 'N/A',
            tonumber(string.format("%.2f", charData.ep)),
            tonumber(string.format("%.2f", charData.gp)),
            tonumber(string.format("%.2f", charData.ep / charData.gp)),
            {guid = charData.guid}
        }

        tinsert(data.rows, row)
    end

    self.data = data

    self:filterData()
    self:sortData(7, 'descending')

    -- for _, row in ipairs(data.rowsFiltered) do
    --     ns.addon:Print(unpack(row))
    -- end
end
