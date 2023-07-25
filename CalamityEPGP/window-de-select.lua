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

    mainFrame.tableFrame = ns.Table:new(mainFrame, nil, false, true, true, nil, self.handleRowClick)
    mainFrame.tableFrame:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT', 6, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -7, 0)
    mainFrame.tableFrame:SetPoint('BOTTOM', mainFrame.confirmButton, 'TOP', 0, 5)

    mainFrame.cancelButton:SetScript('OnClick', function() mainFrame:Hide() end)

    mainFrame.confirmButton:SetScript('OnClick', function()
        ns.LootDistWindow.disenchanter = DeSelectWindow.selectedPlayer
        mainFrame:Hide()
        ns.LootDistWindow:disenchant()
    end)

	return mainFrame
end


function DeSelectWindow:show()
    self:createWindow()

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

    self.mainFrame:Show()
end


function DeSelectWindow.handleRowClick(row)
    DeSelectWindow.selectedPlayer = row.data[1]
    DeSelectWindow.mainFrame.confirmButton:Enable()
end
