local addonName, ns = ...  -- Namespace

local AddEpWindow = {}

ns.AddEpWindow = AddEpWindow


function AddEpWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

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

function AddEpWindow:show()
    self:createWindow()
    self.mainFrame:Show()

    self.mainFrame.amountEditBox:SetFocus()
end

function AddEpWindow:hide()
    if self.mainFrame ~= nil then
        self.mainFrame:Hide()
    end
end

function AddEpWindow:isShown()
    return self.mainFrame ~= nil and self.mainFrame:IsShown()
end

function AddEpWindow:confirm()
    local value = self.mainFrame.amountEditBox:GetText()

    if not ns.Lib.validateEpgpValue(value) then
        return
    end

    value = tonumber(value)

    if value == 0
            or value < -1000000
            or value > 1000000 then
        return
    end

    local enteredReason = self.mainFrame.reasonEditBox:GetText()

    if #enteredReason == 0 then
        return
    end

    ns.debug(string.format('add %d EP to %s', value, ns.MainWindow.raidOnly and 'raid' or 'everyone'))

    local reason = string.format('%s: %s', ns.values.epgpReasons.MANUAL_MULTIPLE, enteredReason)

    if ns.MainWindow.raidOnly then
        local players = {}

        for player in ns.addon.raidRoster:iter() do
            local guid = ns.Lib.getPlayerGuid(player)
            tinsert(players, guid)
        end

        ns.addon:modifyEpgp(players, ns.consts.MODE_EP, value, reason)

        if #ns.db.benchedPlayers > 0 then
            local benchedReason = reason .. ' BENCH'
            local benchedPlayers = {}
            for _, player in ipairs(ns.db.benchedPlayers) do
                local guid = ns.Lib.getPlayerGuid(player)
                tinsert(benchedPlayers, guid)
            end

            ns.addon:modifyEpgp(benchedPlayers, ns.consts.MODE_EP, value, benchedReason)
        end

        if ns.addon.useForRaid then
            ns.printPublic(string.format('Awarded %d EP to raid. Reason: %s', value, enteredReason))
        end
    else
        local players = {}

        for _, charData in pairs(ns.db.standings) do
            tinsert(players, charData.guid)
        end

        ns.addon:modifyEpgp(players, ns.consts.MODE_EP, value, reason)
    end

    self:hide()
end
