local addonName, ns = ...  -- Namespace

local ModifyEpgpWindow = {}

ns.ModifyEpgpWindow = ModifyEpgpWindow


function ModifyEpgpWindow:createWindow()
    local mainFrameName = addonName .. '_ModifyEPGPWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 200)
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
	mainFrame.title:SetText('Modify EPGP')

    mainFrame.topLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.topLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.epButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.epButton:SetText('EP')
    mainFrame.epButton:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -40)

    mainFrame.gpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate ')
    mainFrame.gpButton:SetText('GP')
    mainFrame.gpButton:SetPoint('TOPLEFT', mainFrame.epButton, 'BOTTOMLEFT', 0, -2)

    mainFrame.amountEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
	mainFrame.amountEditBox:SetPoint('LEFT', mainFrame.gpButton, 'RIGHT', 40, 0)
	mainFrame.amountEditBox:SetPoint('RIGHT', mainFrame, 'RIGHT', -40, 0)
    mainFrame.amountEditBox:SetHeight(20)
    mainFrame.amountEditBox:SetAutoFocus(false)
    mainFrame.amountEditBox:SetFocus()

    mainFrame.amountLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabel:SetPoint('BOTTOM', mainFrame.amountEditBox, 'TOP', 0, 7)

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

    if self.mode == nil then
        self.mode = 'EP'
    end

    mainFrame.epButton:SetScript('OnClick', function()
        ModifyEpgpWindow.mode = 'EP'
        ModifyEpgpWindow:fillIn()
    end)

    mainFrame.gpButton:SetScript('OnClick', function()
        ModifyEpgpWindow.mode = 'GP'
        ModifyEpgpWindow:fillIn()
    end)

    mainFrame.cancelButton:SetScript('OnClick', function() mainFrame:Hide() end)

    mainFrame.confirmButton:SetScript('OnClick', function()
        local value = mainFrame.amountEditBox:GetNumber()
        local reason = 'manual_single: ' .. mainFrame.reasonEditBox:GetText()

        ns.addon:modifyEpgp({{self.charGuid, self.mode, value, reason}})

        mainFrame:Hide()
    end)

    tinsert(UISpecialFrames, mainFrameName)

    return mainFrame
end

function ModifyEpgpWindow:show(charName, charGuid)
    self.charName = charName
    self.charGuid = charGuid

    local window = self.mainFrame or self:createWindow()
    self:fillIn()
    self.mainFrame.amountEditBox:SetText('')
    window:Show()
end

function ModifyEpgpWindow:fillIn()
    self.mainFrame.topLabel:SetText('Modify EP/GP for ' .. self.charName)
    self.mainFrame.amountLabel:SetText(self.mode .. ' Amount')
end
