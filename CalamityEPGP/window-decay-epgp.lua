local addonName, ns = ...  -- Namespace

local DecayEpgpWindow = {}

ns.DecayEpgpWindow = DecayEpgpWindow


function DecayEpgpWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_DecayEpgpWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 175)
	mainFrame:SetPoint('CENTER') -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    mainFrame:SetFrameStrata('DIALOG')
    mainFrame:SetToplevel(true)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('Decay EPGP')

    mainFrame.amountLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabel:SetText('Decay %')
	mainFrame.amountLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.amountEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
    mainFrame.amountEditBox:SetText(tostring(ns.Config:getDefaultDecay()))
    mainFrame.amountEditBox:SetPoint('TOP', mainFrame.amountLabel, 'BOTTOM', 0, -7)
    mainFrame.amountEditBox:SetHeight(20)
    mainFrame.amountEditBox:SetWidth(40)
    mainFrame.amountEditBox:SetAutoFocus(false)

    mainFrame.reasonEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
	mainFrame.reasonEditBox:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 45)
    mainFrame.reasonEditBox:SetWidth(175)
    mainFrame.reasonEditBox:SetHeight(20)
    mainFrame.reasonEditBox:SetAutoFocus(false)

    mainFrame.reasonLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.reasonLabel:SetText('Reason (optional)')
    mainFrame.reasonLabel:SetPoint('BOTTOM', mainFrame.reasonEditBox, 'TOP', 0, 7)

    mainFrame.confirmButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.confirmButton:SetText('Confirm')
    mainFrame.confirmButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.confirmButton:SetWidth(70)

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.cancelButton:SetScript('OnClick', function() self:hide() end)
    mainFrame.confirmButton:SetScript('OnClick', function() self:confirm() end)
    mainFrame.amountEditBox:SetScript('OnEnterPressed', function() self:confirm() end)

    tinsert(UISpecialFrames, mainFrameName)

    mainFrame:HookScript('OnHide', function()
        C_Timer.After(0.1, function()
            tinsert(UISpecialFrames, ns.MainWindow.mainFrame:GetName())
        end)
    end)

    return mainFrame
end

function DecayEpgpWindow:show()
    self:createWindow()
    self.mainFrame:Raise()
    self.mainFrame:Show()
    self.mainFrame.amountEditBox:SetFocus()
end

function DecayEpgpWindow:hide()
    if self.mainFrame ~= nil then
        self.mainFrame:Hide()
    end
end

function DecayEpgpWindow:isShown()
    return self.mainFrame ~= nil and self.mainFrame:IsShown()
end

function DecayEpgpWindow:confirm()
    local value = self.mainFrame.amountEditBox:GetText()

    if not ns.Lib.validateEpgpValue(value) then
        return
    end

    value = tonumber(value)

    if value == 0
            or value < -1000
            or value > 100 then
        return
    end

    local reason = string.format('%s: %s', ns.values.epgpReasons.DECAY, self.mainFrame.reasonEditBox:GetText())

    local players = {}

    for _, charData in pairs(ns.db.standings) do
        tinsert(players, charData.guid)
    end

    ns.addon:modifyEpgp(players, ns.consts.MODE_BOTH, -value, reason, true)

    self:hide()
end
