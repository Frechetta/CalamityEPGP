local addonName, ns = ...  -- Namespace

local List = ns.List

local DeSelectWindow = {
    selectedPlayer = nil,
}

ns.DeSelectWindow = DeSelectWindow


function DeSelectWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_DeSelectWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(200, 200)
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetFrameStrata('DIALOG')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('Select Disenchanter')

    mainFrame.confirmButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.confirmButton:SetText('Confirm')
    mainFrame.confirmButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.confirmButton:SetWidth(70)
    mainFrame.confirmButton:Disable()

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT', 6, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -7, 0)
    mainFrame.tableFrame:SetPoint('BOTTOM', mainFrame.confirmButton, 'TOP', 0, 5)

    mainFrame.cancelButton:SetScript('OnClick', function() mainFrame:Hide() end)

    mainFrame.confirmButton:SetScript('OnClick', function()
        ns.LootDistWindow.disenchanter = DeSelectWindow.selectedPlayer
        mainFrame:Hide()
        ns.LootDistWindow:disenchant()
    end)

    self:createTable()

	return mainFrame
end


function DeSelectWindow:createTable()
    local parent = self.mainFrame.tableFrame

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
    parent.scrollDownButton:SetPoint('BOTTOMRIGHT', parent.scrollFrame, 'BOTTOMRIGHT', -2, 2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint('TOP', parent.scrollUpButton, 'BOTTOM', 0, 0);
    parent.scrollBar:SetPoint('BOTTOM', parent.scrollDownButton, 'TOP', 0, 0);

    parent.scrollChild = CreateFrame('Frame')
    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth() - parent.scrollBar:GetWidth() - 7, 1)
    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    -- Initialize the content
    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetPoint('TOPLEFT', parent.scrollChild, 'TOPLEFT', 2, 0)
    parent.contents:SetPoint('BOTTOMRIGHT', parent.scrollDownButton, 'BOTTOMLEFT', -5, 0)

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

    parent.rows = List:new()
end


function DeSelectWindow:show()
    self:createWindow()

    local parent = self.mainFrame.tableFrame

    local players = List:new()
    for player in ns.addon.raidRoster:iter() do
        local playerColored = ns.Lib.getColoredByClass(player)
        players:bininsert({player, playerColored}, function(left, right) return left[1] < right[1] end)
    end

    for i, rowData in players:enumerate() do
        local row = parent.rows:get(i)

        if row == nil then
            row = self:addRow(i)
            parent.rows:append(row)
        end

        local player = rowData[1]
        local playerColored = rowData[2]

        row.text:SetText(playerColored)
        row.player = player

        row:Show()
    end

    if parent.rows:len() > players:len() then
        for i = players:len() + 1, parent.rows:len() do
            local row = parent.rows:get(i)
            row:Hide()
        end
    end

    self.mainFrame:Show()
end


function DeSelectWindow:addRow(index)
    local parent = self.mainFrame.tableFrame

    local rowHeight = 15

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = (rowHeight + 3) * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.contents:GetWidth())
    row:SetHeight(rowHeight)

    row.text = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.text:SetPoint('LEFT', row, 'LEFT', 5, 0)

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

    row:SetScript('OnMouseUp', function(_, button)
        if button == 'LeftButton' then
            DeSelectWindow:handleRowClick(row)
        end
    end)

    return row
end


function DeSelectWindow:handleRowClick(row)
    self.selectedPlayer = row.player

    local selectedHighlightFrame = self.mainFrame.tableFrame.contents.rowSelectedHighlight
    selectedHighlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 6)
    selectedHighlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 3, 3)
    selectedHighlightFrame:Show()

    self.mainFrame.confirmButton:Enable()
end
