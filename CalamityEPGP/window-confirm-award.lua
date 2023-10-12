local addonName, ns = ...  -- Namespace

local ConfirmAwardWindow = {
    baseGp = nil,
    msGp = nil,
    osGp = nil,
}

ns.ConfirmAwardWindow = ConfirmAwardWindow


function ConfirmAwardWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_ConfirmAwardWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(350, 185)
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
	mainFrame.title:SetText('Confirm Award')

    mainFrame.messageLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.messageLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)
    mainFrame.messageLabel:SetTextScale(1.2)

    mainFrame.rollLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.rollLabel:SetPoint('TOP', mainFrame.messageLabel, 'BOTTOM', 0, -10)
    mainFrame.rollLabel:SetTextScale(1.2)

    mainFrame.specButtonRow = CreateFrame('Frame', nil, mainFrame)
    mainFrame.specButtonRow:SetPoint('TOP', mainFrame.rollLabel, 'BOTTOM', 0, -10)
    mainFrame.specButtonRow:SetWidth(mainFrame:GetWidth())
    mainFrame.specButtonRow:SetHeight(30)
    mainFrame.specButtonRow.buttons = {
        CreateFrame('CheckButton', mainFrameName .. 'SpecButton1', mainFrame.specButtonRow, 'UICheckButtonTemplate'),
        CreateFrame('CheckButton', mainFrameName .. 'SpecButton2', mainFrame.specButtonRow, 'UICheckButtonTemplate'),
    }

    mainFrame.osButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.osButton:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 45)
    mainFrame.osButton:SetWidth(100)
    mainFrame.osButton:SetHeight(30)
    mainFrame.osButton:GetFontString():SetTextScale(1.2)

    mainFrame.msButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.msButton:SetPoint('RIGHT', mainFrame.osButton, 'LEFT', -5, 0)
    mainFrame.msButton:SetWidth(100)
    mainFrame.msButton:SetHeight(30)
    mainFrame.msButton:GetFontString():SetTextScale(1.2)

    mainFrame.freeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.freeButton:SetPoint('LEFT', mainFrame.osButton, 'RIGHT', 5, 0)
    mainFrame.freeButton:SetWidth(100)
    mainFrame.freeButton:SetHeight(30)
    mainFrame.freeButton:GetFontString():SetTextScale(1.2)
    mainFrame.freeButton:SetText('Free')

    mainFrame.baseGpLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.baseGpLabel:SetPoint('BOTTOMRIGHT', mainFrame.osButton, 'TOP', -10, 10)

    mainFrame.theirGpLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.theirGpLabel:SetPoint('BOTTOMLEFT', mainFrame.osButton, 'TOP', 10, 10)

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.cancelButton:SetScript('OnClick', function() ConfirmAwardWindow.mainFrame:Hide() end)

    tinsert(UISpecialFrames, mainFrameName)

    return mainFrame
end

---@param itemLink string
---@param player string
---@param rollType string
function ConfirmAwardWindow:show(itemLink, player, rollType)
    self:createWindow()

    self.baseGp = nil
    self.msGp = nil
    self.osGp = nil

    self.mainFrame.specButtonRow.buttons[1]:Hide()
    self.mainFrame.specButtonRow.buttons[1]:SetChecked(false)
    self.mainFrame.specButtonRow.buttons[2]:Hide()
    self.mainFrame.specButtonRow.buttons[2]:SetChecked(false)
    self.mainFrame.specButtonRow:Hide()

    self.mainFrame:SetHeight(185)

    self.mainFrame:Raise()

    self.mainFrame.messageLabel:SetText(string.format('Award %s to %s?', itemLink, player))

    if rollType ~= nil then
        self.mainFrame.rollLabel:SetText(string.format('%s rolled for %s', player, rollType))
    end

    ns.Lib.getItemInfo(itemLink, function(itemInfo)
        local playerGuid = ns.Lib.getPlayerGuid(player)
        local classFilename = ns.db.standings[playerGuid].classFileName

        self.baseGp = ns.Lib.getGpWithInfo(itemInfo)
        self.baseClassGp = ns.Lib.getGpWithInfo(itemInfo, classFilename)

        self.msGp = self.baseClassGp
        self.osGp = math.floor(self.msGp * .1)

        self.mainFrame.baseGpLabel:SetText(string.format('Base GP: %d', self.baseGp))
        self.mainFrame.theirGpLabel:SetText(string.format('Their GP: %d', self.msGp))

        self.mainFrame.msButton:SetText(string.format('MS (%d GP)', self.msGp))
        self.mainFrame.osButton:SetText(string.format('OS (%d GP)', self.osGp))

        local slotMod = ns.cfg.gpSlotMods[itemInfo.slot]
        if slotMod ~= nil then
            local slotModOverrides = slotMod.overrides
            if slotModOverrides ~= nil then
                local classOverride = slotModOverrides[classFilename]
                if classOverride ~= nil and type(classOverride) == 'table' then
                    self:_renderSpecButtonRow(classFilename, classOverride, itemInfo)
                end
            end
        end

        self.mainFrame.msButton:SetScript('OnClick', function()
            ns.LootDistWindow:award(itemLink, player, 'MS', '100%', self.msGp)
            ConfirmAwardWindow.mainFrame:Hide()
        end)

        self.mainFrame.osButton:SetScript('OnClick', function()
            ns.LootDistWindow:award(itemLink, player, 'OS', '10%', self.osGp)
            ConfirmAwardWindow.mainFrame:Hide()
        end)

        self.mainFrame.freeButton:SetScript('OnClick', function()
            ns.LootDistWindow:award(itemLink, player)
            ConfirmAwardWindow.mainFrame:Hide()
        end)

        self.mainFrame:Show()
    end)
end

function ConfirmAwardWindow:_renderSpecButtonRow(classFilename, classOverride, itemInfo)
    local i = 0
    for spec in pairs(classOverride) do
        i = i + 1

        local button = self.mainFrame.specButtonRow.buttons[i]
        button.index = i

        local fontString = _G[button:GetName() .. 'Text']
        fontString:SetText(spec)

        button:SetScript('OnClick', function()
            local otherButton
            if button.index == 1 then
                otherButton = self.mainFrame.specButtonRow.buttons[2]
            else
                otherButton = self.mainFrame.specButtonRow.buttons[1]
            end
            otherButton:SetChecked(false)

            if button:GetChecked() then
                self.msGp = ns.Lib.getGpWithInfo(itemInfo, classFilename, spec)
            else
                self.msGp = self.baseClassGp
            end

            self.osGp = math.floor(self.msGp * .1)

            self.mainFrame.theirGpLabel:SetText(string.format('Their GP: %d', self.msGp))

            self.mainFrame.msButton:SetText(string.format('MS (%d GP)', self.msGp))
            self.mainFrame.osButton:SetText(string.format('OS (%d GP)', self.osGp))
        end)
    end

    self.mainFrame:SetHeight(215)

    self.mainFrame.specButtonRow:Show()

    if i == 1 then
        local button = self.mainFrame.specButtonRow.buttons[1]
        local fontString = _G[button:GetName() .. 'Text']
        local width = button:GetWidth() + fontString:GetWidth()
        button:SetPoint('LEFT', self.mainFrame.specButtonRow, 'CENTER', -(width / 2), 0)
        button:Show()
    else
        local button1 = self.mainFrame.specButtonRow.buttons[1]
        local button1fontString = _G[button1:GetName() .. 'Text']
        button1:SetPoint('RIGHT', self.mainFrame.specButtonRow, 'CENTER', -button1fontString:GetWidth() - 5, 0)
        button1:Show()

        local button2 = self.mainFrame.specButtonRow.buttons[2]
        button2:SetPoint('LEFT', self.mainFrame.specButtonRow, 'CENTER', 5, 0)
        button2:Show()
    end
end
