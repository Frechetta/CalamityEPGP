local addonName, ns = ...  -- Namespace

local ConfirmAwardWindow = {}

ns.ConfirmAwardWindow = ConfirmAwardWindow


function ConfirmAwardWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_ConfirmAwardWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(350, 150)
	mainFrame:SetPoint('CENTER')

    mainFrame:SetFrameStrata('DIALOG')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP')

    mainFrame.messageLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.messageLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.rollLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.rollLabel:SetPoint('TOP', mainFrame.messageLabel, 'BOTTOM', 0, -10)

    mainFrame.msButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.msButton:SetPoint('TOP', mainFrame.rollLabel, 'BOTTOM', 0, -10)
    mainFrame.msButton:SetWidth(110)

    mainFrame.osButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.osButton:SetPoint('TOP', mainFrame.msButton, 'BOTTOM', 0, -7)
    mainFrame.osButton:SetWidth(110)

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

    self.mainFrame.msButton:SetText(string.format('MS (100%% GP: %d)', msGp))
    self.mainFrame.osButton:SetText(string.format('OS (10%% GP: %d)', osGp))

    self.mainFrame.msButton:SetScript('OnClick', function()
        ns.LootDistWindow:award(player, 'MS', '100%', msGp)
        ConfirmAwardWindow.mainFrame:Hide()
    end)

    self.mainFrame.osButton:SetScript('OnClick', function()
        ns.LootDistWindow:award(player, 'OS', '10%', osGp)
        ConfirmAwardWindow.mainFrame:Hide()
    end)

    self.mainFrame:Show()
end
