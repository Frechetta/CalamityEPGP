local addonName, ns = ...  -- Namespace

local ConfirmAwardWindow = {}

ns.ConfirmAwardWindow = ConfirmAwardWindow


function ConfirmAwardWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_ConfirmAwardWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(350, 165)
	mainFrame:SetPoint('CENTER')

    mainFrame:SetFrameStrata('DIALOG')

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

    mainFrame.osButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.osButton:SetPoint('TOP', mainFrame.rollLabel, 'BOTTOM', 0, -15)
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

    mainFrame.cancelButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.cancelButton:SetText('Cancel')
    mainFrame.cancelButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.cancelButton:SetWidth(70)

    mainFrame.cancelButton:SetScript('OnClick', function() ConfirmAwardWindow.mainFrame:Hide() end)

    tinsert(UISpecialFrames, mainFrameName)

    return mainFrame
end

function ConfirmAwardWindow:show(itemLink, player, rollType)
    self:createWindow()

    self.mainFrame.messageLabel:SetText(string.format('Award %s to %s?', itemLink, player))
    self.mainFrame.rollLabel:SetText(string.format('%s rolled for %s', player, rollType))

    local msGp = ns.Lib:getGp(itemLink)
    local osGp = math.floor(msGp * .1)

    self.mainFrame.msButton:SetText(string.format('MS (%d GP)', msGp))
    self.mainFrame.osButton:SetText(string.format('OS (%d GP)', osGp))

    self.mainFrame.msButton:SetScript('OnClick', function()
        ns.LootDistWindow:award(player, 'MS', '100%', msGp)
        ConfirmAwardWindow.mainFrame:Hide()
    end)

    self.mainFrame.osButton:SetScript('OnClick', function()
        ns.LootDistWindow:award(player, 'OS', '10%', osGp)
        ConfirmAwardWindow.mainFrame:Hide()
    end)

    self.mainFrame.freeButton:SetScript('OnClick', function()
        ns.LootDistWindow:award(player)
        ConfirmAwardWindow.mainFrame:Hide()
    end)

    self.mainFrame:Show()
end
