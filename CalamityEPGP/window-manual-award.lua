local addonName, ns = ...  -- Namespace

local List = ns.List

local ManualAwardWindow = {
    itemLink = nil,
    selectedPlayer = nil,
}

ns.ManualAwardWindow = ManualAwardWindow


function ManualAwardWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_ManualAwardWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(300, 200)
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
	mainFrame.title:SetText('CalamityEPGP Manual Award')

    mainFrame.itemIcon = mainFrame:CreateTexture(nil, 'OVERLAY')
    mainFrame.itemIcon:SetSize(30, 30)
    mainFrame.itemIcon:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -15)
    mainFrame.itemIcon:SetTexture(self.defaultItemIcon)
    mainFrame.itemIcon:EnableMouse(true)

    mainFrame.itemLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.itemLabel:SetText('Invalid item')
    mainFrame.itemLabel:SetPoint('LEFT', mainFrame.itemIcon, 'RIGHT', 10, 0)
    mainFrame.itemLabel:EnableMouse(true)

    mainFrame.gpLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.gpLabel:SetPoint('TOP', mainFrame.itemLabel)
    mainFrame.gpLabel:SetPoint('RIGHT', mainFrame, 'RIGHT', -20, 0)
    mainFrame.gpLabel:SetJustifyH('RIGHT')
    mainFrame.gpLabel:SetTextColor(1, 1, 0)

    mainFrame.awardButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.awardButton:SetText('Award')
    mainFrame.awardButton:SetPoint('TOPRIGHT', mainFrame.gpLabel, 'BOTTOMRIGHT', 0, -20)
    mainFrame.awardButton:SetWidth(70)

    mainFrame.closeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.closeButton:SetText('Close')
    mainFrame.closeButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -20, 20)
    mainFrame.closeButton:SetWidth(70)

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame.itemIcon, 'BOTTOMLEFT', 0, -20)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame.closeButton, 'BOTTOMLEFT', -15, 0)

    mainFrame.closeButton:SetScript('OnClick', function() mainFrame:Hide() end)
    mainFrame.awardButton:SetScript('OnClick', function() self:checkAward() end)

    self:createTable()

	return mainFrame;
end


function ManualAwardWindow:createTable()
    local parent = self.mainFrame.tableFrame

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame(
        'ScrollFrame',
        parent:GetName() .. 'ScrollFrame',
        parent,
        'UIPanelScrollFrameTemplate'
    )
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, 0)
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

    parent.rows = List:new()
end


function ManualAwardWindow:show(itemLink)
    self:createWindow()

    local _, _, _, _, _, _, _, _, _, texture, _ = ns.Lib.getItemInfo(itemLink)

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

    self.mainFrame.awardButton:Disable()

    self.mainFrame.tableFrame.contents.rowSelectedHighlight:Hide()

    self.itemLink = itemLink
    self.itemGp = ns.Lib.getGp(itemLink)
    self.selectedPlayer = nil

    self.mainFrame.gpLabel:SetText('GP: ' .. self.itemGp)

    self:setData()
    self.mainFrame:Show()
end


function ManualAwardWindow:setData()
    local parent = self.mainFrame.tableFrame

    local rows = List:new()

    for player in ns.addon.raidRoster:iter() do
        local playerColored = ns.Lib.getColoredByClass(player)
        rows:bininsert({player, playerColored}, function(left, right) return left[1] < right[1] end)
    end

    local rowHeight = 15

    for i, rowData in rows:enumerate() do
        local row = parent.rows:get(i)

        if row == nil then
            row = CreateFrame('Frame', nil, parent.contents)

            local yOffset = (rowHeight + 3) * (i - 1)

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
                    ManualAwardWindow:handleRowClick(row)
                end
            end)

            parent.rows:append(row)
        end

        row:Show()

        local player = rowData[1]
        local playerColored = rowData[2]

        row.text:SetText(playerColored)
        row.player = player
    end

    for i = rows:len() + 1, parent.rows:len() do
        local row = parent.rows:get(i)
        row:Hide()
    end
end


function ManualAwardWindow:handleRowClick(row)
    self.selectedPlayer = row.player

    self.mainFrame.awardButton:Enable()

    local selectedHighlightFrame = self.mainFrame.tableFrame.contents.rowSelectedHighlight
    selectedHighlightFrame:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 6)
    selectedHighlightFrame:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 3, 3)
    selectedHighlightFrame:Show()
end


function ManualAwardWindow:checkAward()
    if not IsMasterLooter() then
		ns.print('You are not the master looter!')
		-- return
	end

    local awardee = self.selectedPlayer

    if awardee == nil then
        return
    end

    ns.debug(self.itemLink .. ' ' .. self.itemGp .. ' ' .. awardee)

    ns.ConfirmAwardWindow:show(self.itemLink, self.itemGp, awardee)
end
