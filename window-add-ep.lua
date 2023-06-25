local addonName, ns = ...  -- Namespace

local AddEpWindow = {}

ns.AddEpWindow = AddEpWindow


function AddEpWindow:createWindow()
    local mainFrameName = addonName .. '_AddEPWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 175)
	mainFrame:SetPoint('CENTER') -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    mainFrame:SetFrameStrata('DIALOG')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('Add EP')

    mainFrame.amountLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabel:SetText('Adds/Subtracts EP for filtered roster')
	mainFrame.amountLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.amountEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
    mainFrame.amountEditBox:SetPoint('TOP', mainFrame.amountLabel, 'BOTTOM', 0, -7)
    mainFrame.amountEditBox:SetHeight(20)
    mainFrame.amountEditBox:SetWidth(100)
    mainFrame.amountEditBox:SetAutoFocus(false)
    mainFrame.amountEditBox:SetFocus()

    mainFrame.reasonEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
	mainFrame.reasonEditBox:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 45)
    mainFrame.reasonEditBox:SetWidth(175)
    mainFrame.reasonEditBox:SetHeight(20)
    mainFrame.reasonEditBox:SetAutoFocus(false)

    mainFrame.reasonLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.reasonLabel:SetText('Reason (optional)')
    mainFrame.reasonLabel:SetPoint('BOTTOM', mainFrame.reasonEditBox, 'TOP', 0, 7)

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.confirmButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.confirmButton:SetText('Confirm')
    mainFrame.confirmButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.confirmButton:SetWidth(70)

    mainFrame.cancelButton:SetScript('OnClick', function() mainFrame:Hide() end)

    mainFrame.confirmButton:SetScript('OnClick', function()
        local value = mainFrame.amountEditBox:GetNumber()
        local reason = 'manual_multiple:' .. mainFrame.reasonEditBox:GetText()

        local changes = {}

        for _, charData in ipairs(ns.MainWindow.data.rowsFiltered) do
            table.insert(changes, {charData[1], 'EP', value, reason})
        end

        ns.addon:modifyEpgp(changes)

        mainFrame:Hide()
    end)

    tinsert(UISpecialFrames, mainFrameName)

    return mainFrame
end

function AddEpWindow:show()
    local window = self.mainFrame or self:createWindow()
    window:Show()
end
