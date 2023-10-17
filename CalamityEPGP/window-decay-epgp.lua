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

    mainFrame.amountLabelEp = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabelEp:SetText('EP Decay %')
	mainFrame.amountLabelEp:SetPoint('TOPRIGHT', mainFrame, 'TOP', -10, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.amountEditBoxEp = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
    mainFrame.amountEditBoxEp:SetText(tostring(ns.Config:getDefaultDecayEp()))
    mainFrame.amountEditBoxEp:SetPoint('TOP', mainFrame.amountLabelEp, 'BOTTOM', 0, -7)
    mainFrame.amountEditBoxEp:SetHeight(20)
    mainFrame.amountEditBoxEp:SetWidth(40)
    mainFrame.amountEditBoxEp:SetAutoFocus(false)

    mainFrame.amountLabelGp = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabelGp:SetText('GP Decay %')
	mainFrame.amountLabelGp:SetPoint('TOPLEFT', mainFrame, 'TOP', 10, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.amountEditBoxGp = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
    mainFrame.amountEditBoxGp:SetText(tostring(ns.Config:getDefaultDecayGp()))
    mainFrame.amountEditBoxGp:SetPoint('TOP', mainFrame.amountLabelGp, 'BOTTOM', 0, -7)
    mainFrame.amountEditBoxGp:SetHeight(20)
    mainFrame.amountEditBoxGp:SetWidth(40)
    mainFrame.amountEditBoxGp:SetAutoFocus(false)

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
    self.mainFrame.reasonEditBox:SetFocus()
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
    local valueEp = self.mainFrame.amountEditBoxEp:GetText()
    local valueGp = self.mainFrame.amountEditBoxGp:GetText()

    if not ns.Lib.validateEpgpValue(valueEp) or not ns.Lib.validateEpgpValue(valueGp) then
        return
    end

    valueEp = tonumber(valueEp)
    valueGp = tonumber(valueGp)

    if valueEp == 0
            or valueEp < -1000
            or valueEp > 100
            or valueGp == 0
            or valueGp < -1000
            or valueGp > 100 then
        return
    end

    local reason = ns.Lib.getEventReason(ns.values.epgpReasons.DECAY, self.mainFrame.reasonEditBox:GetText())

    local players = ns.standings:keys():toTable()

    ns.addon:modifyEpgp(players, ns.consts.MODE_EP, -valueEp, reason, true)
    ns.addon:modifyEpgp(players, ns.consts.MODE_GP, -valueGp, reason, true)

    self:hide()
end
