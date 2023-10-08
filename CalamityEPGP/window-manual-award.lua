local addonName, ns = ...  -- Namespace

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
	mainFrame:SetSize(300, 250)
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')
    mainFrame:SetFrameStrata('HIGH')
    mainFrame:SetToplevel(true)

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText(('%s Manual Award'):format(addonName))

    mainFrame.itemIcon = mainFrame:CreateTexture(nil, 'OVERLAY')
    mainFrame.itemIcon:SetSize(30, 30)
    mainFrame.itemIcon:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -15)
    mainFrame.itemIcon:SetTexture(self.defaultItemIcon)
    mainFrame.itemIcon:EnableMouse(true)

    mainFrame.itemLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.itemLabel:SetText('Invalid item')
    mainFrame.itemLabel:SetPoint('LEFT', mainFrame.itemIcon, 'RIGHT', 10, 0)
    mainFrame.itemLabel:EnableMouse(true)

    mainFrame.closeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.closeButton:SetText('Close')
    mainFrame.closeButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -20, 20)
    mainFrame.closeButton:SetWidth(70)

    mainFrame.tableFrame = ns.Table:new(mainFrame, nil, false, true, true, nil, self.handleRowClick)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame.itemIcon, 'BOTTOMLEFT', 0, -10)
    mainFrame.tableFrame:SetPoint('BOTTOMRIGHT', mainFrame.closeButton, 'BOTTOMLEFT', -15, 0)

    mainFrame.awardButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.awardButton:SetText('Award')
    mainFrame.awardButton:SetPoint('TOP', mainFrame.tableFrame:getFrame())
    mainFrame.awardButton:SetPoint('RIGHT', mainFrame.closeButton)
    mainFrame.awardButton:SetWidth(70)

    mainFrame.closeButton:SetScript('OnClick', function() mainFrame:Hide() end)
    mainFrame.awardButton:SetScript('OnClick', function() self:checkAward() end)

	return mainFrame;
end


function ManualAwardWindow:show(itemLink)
    self:createWindow()

    self.mainFrame:Raise()

    ns.Lib.getItemInfo(itemLink, function(itemInfo)
        self.mainFrame.itemIcon:SetTexture(itemInfo.icon)
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

        self.itemLink = itemLink
        self.selectedPlayer = nil

        self:setData()
        self.mainFrame:Show()
    end)
end


function ManualAwardWindow:setData()
    local data = {
        rows = {}
    }

    for player in ns.addon.raidRoster:iter() do
        local row = {
            player,
            {color = ns.Lib.getPlayerClassColor(player)}
        }
        ns.Lib.bininsert(data.rows, row, function(left, right) return left[1] < right[1] end)
    end

    self.mainFrame.tableFrame:setData(data)
end


function ManualAwardWindow.handleRowClick(button, row)
    if button ~= 'LeftButton' then
        return
    end

    ManualAwardWindow.selectedPlayer = row.data[1]
    ManualAwardWindow.mainFrame.awardButton:Enable()
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

    ns.debug(self.itemLink .. ' ' .. awardee)

    ns.ConfirmAwardWindow:show(self.itemLink, awardee)
end
