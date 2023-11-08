local addonName, ns = ...  -- Namespace

local ModifyEpgpWindow = {}

ns.ModifyEpgpWindow = ModifyEpgpWindow


function ModifyEpgpWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_ModifyEPGPWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, ns.MainWindow.mainFrame, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 200)
	mainFrame:SetPoint('CENTER')
    mainFrame:SetFrameStrata('DIALOG')
    mainFrame:SetToplevel(true)

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

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

    mainFrame.amountLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.amountLabel:SetPoint('BOTTOM', mainFrame.amountEditBox, 'TOP', 0, 7)

    mainFrame.reasonEditBox = CreateFrame('EditBox', nil, mainFrame, 'InputBoxTemplate')
	mainFrame.reasonEditBox:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 45)
    mainFrame.reasonEditBox:SetWidth(175)
    mainFrame.reasonEditBox:SetHeight(20)
    mainFrame.reasonEditBox:SetAutoFocus(false)

    mainFrame.reasonLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.reasonLabel:SetText('Reason')
    mainFrame.reasonLabel:SetPoint('BOTTOM', mainFrame.reasonEditBox, 'TOP', 0, 7)

    mainFrame.confirmButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.confirmButton:SetText('Confirm')
    mainFrame.confirmButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.confirmButton:SetWidth(70)

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.cancelButton:SetWidth(70)

    if self.mode == nil then
        self.mode = ns.consts.MODE_EP
    end

    mainFrame.epButton:SetScript('OnClick', function()
        ModifyEpgpWindow.mode = ns.consts.MODE_EP
        ModifyEpgpWindow:fillIn()
    end)

    mainFrame.gpButton:SetScript('OnClick', function()
        ModifyEpgpWindow.mode = ns.consts.MODE_GP
        ModifyEpgpWindow:fillIn()
    end)

    mainFrame.cancelButton:SetScript('OnClick', function() ModifyEpgpWindow:hide() end)
    mainFrame.confirmButton:SetScript('OnClick', function() ModifyEpgpWindow:confirm() end)
    mainFrame.amountEditBox:SetScript('OnEnterPressed', function() ModifyEpgpWindow:confirm() end)

    tinsert(UISpecialFrames, mainFrameName)

    mainFrame:HookScript('OnHide', function()
        C_Timer.After(0.1, function()
            tinsert(UISpecialFrames, ns.MainWindow.mainFrame:GetName())

            if ns.RaidWindow.mainFrame ~= nil then
                tinsert(UISpecialFrames, ns.RaidWindow.mainFrame:GetName())
            end
        end)
    end)

    return mainFrame
end

function ModifyEpgpWindow:show(charName, charGuid)
    self.charName = charName
    self.charGuid = charGuid

    self:createWindow()
    self.mainFrame:Raise()
    self:fillIn()
    self.mainFrame:Show()

    self.mainFrame.amountEditBox:SetFocus()
end

function ModifyEpgpWindow:hide()
    if self.mainFrame ~= nil then
        self.mainFrame:Hide()
    end
end

function ModifyEpgpWindow:isShown()
    return self.mainFrame ~= nil and self.mainFrame:IsShown()
end

function ModifyEpgpWindow:fillIn()
    self.mainFrame.topLabel:SetText('Modify EP/GP for ' .. self.charName)
    self.mainFrame.amountLabel:SetText(string.upper(self.mode) .. ' Amount')
end

function ModifyEpgpWindow:confirm()
    local value = self.mainFrame.amountEditBox:GetText()

    if not ns.Lib.validateEpgpValue(value) then
        return
    end

    value = tonumber(value)

    if value == nil
            or value == 0
            or value < -1000000
            or value > 1000000 then
        return
    end

    local enteredReason = self.mainFrame.reasonEditBox:GetText()

    if #enteredReason == 0 then
        return
    end

    local reason = ns.Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE, enteredReason)

    ns.addon:modifyEpgp({self.charGuid}, self.mode, value, reason)

    if ns.addon.useForRaid and ns.addon.raidRoster:contains(self.charName) then
        ns.printPublic(
            string.format('Awarded %d %s to %s. Reason: %s', value, string.upper(self.mode), self.charName, enteredReason)
        )
    end

    self:hide()
end
