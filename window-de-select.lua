local addonName, ns = ...  -- Namespace

local DeSelectWindow = {
    selectedPlayer = nil,
}

ns.DeSelectWindow = DeSelectWindow


function DeSelectWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_DeSelectWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 200)
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetFrameStrata('DIALOG')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('Select Disenchanter')

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame.timerLabel, 'BOTTOMLEFT', 0, -20)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame.closeButton, 'TOPRIGHT', 0, 10)

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.confirmButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.confirmButton:SetText('Confirm')
    mainFrame.confirmButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.confirmButton:SetWidth(70)
    mainFrame.confirmButton:Disable()

    mainFrame.cancelButton:SetScript('OnClick', function() mainFrame:Hide() end)

    mainFrame.confirmButton:SetScript('OnClick', function()
        ns.LootDistWindow.disenchanter = DeSelectWindow.selectedPlayer
        mainFrame:Hide()
        ns.LootDistWindow:disenchant()
    end)

    self:createTable()

	return mainFrame;
end


function DeSelectWindow:createTable()
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
    local highlightTexture = parent.contents.rowSelectedHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    parent.contents.rowSelectedHighlight:Hide()

    parent.rows = {}
end


function DeSelectWindow:show()
    local parent = self.mainFrame.tableFrame

    local players = {}

    for player in pairs(ns.addon.raidRoster) do
        tinsert(players, player)
    end

    table.sort(players, function(left, right)
        return left < right
    end)

    for i, player in ipairs(players) do
        if i > #parent.rows then
            self:addRow(i)
        end

        local _, classFileName = UnitClass(player)
        local classColorData = RAID_CLASS_COLORS[classFileName]

        local row = parent.rows[i]
        row.text:SetText(player)
        row.text:SetTextColor(classColorData.r, classColorData.g, classColorData.b)

        row:Show()
    end

    if #parent.rows > #players then
        for i = #players + 1, #parent.rows do
            local row = parent.rows[i]
            row:Hide()
        end
    end

    self.mainFrame:Show()
end


function DeSelectWindow:addRow(index)
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rowHeight = 15

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = (rowHeight + 3) * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.contents:GetWidth())
    row:SetHeight(rowHeight)

    row.text = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.text:SetAllPoints()

    -- Highlight
    row:EnableMouse()

    local highlightFrame = parent.contents.rowHighlight

    row:SetScript('OnEnter', function()
        highlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 6)
        highlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 3, 3)
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

    table.insert(parent.rows, row)
end


function DeSelectWindow:handleRowClick(row)
    local player = row.text:GetText()
    self.selectedPlayer = player

    local selectedHighlightFrame = self.mainFrame.tableFrame.contents.rowSelectedHighlight
    selectedHighlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 6)
    selectedHighlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 3, 3)
    selectedHighlightFrame:Show()
end
