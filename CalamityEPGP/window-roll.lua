local addonName, ns = ...  -- Namespace

local RollWindow = {}

ns.RollWindow = RollWindow


function RollWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_RollWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent)
    mainFrame.texture = mainFrame:CreateTexture(nil, 'BACKGROUND')
    mainFrame.texture:SetAllPoints()
    mainFrame.texture:SetColorTexture(0, 0, 0, 0.5)
	mainFrame:SetSize(350, 72)
	mainFrame:SetPoint('CENTER')
    mainFrame:SetFrameStrata('FULLSCREEN_DIALOG')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

    mainFrame.titleBar = CreateFrame('Frame', nil, mainFrame)
    mainFrame.titleBar:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT')
    mainFrame.titleBar:SetPoint('BOTTOMRIGHT', mainFrame, 'TOPRIGHT', 0, -20)
    mainFrame.titleBar.texture = mainFrame:CreateTexture(nil, 'BACKGROUND')
    mainFrame.titleBar.texture:SetAllPoints()
    mainFrame.titleBar.texture:SetColorTexture(0, 0, 0, 0.8)

    mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.title:SetPoint('LEFT', mainFrame.titleBar, 'LEFT', 5, 0)
    mainFrame.title:SetText(addonName .. ' - Now Rolling:')

    mainFrame.closeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelCloseButton')
    mainFrame.closeButton:SetPoint('RIGHT', mainFrame.titleBar, 'RIGHT', 5, 0)

    mainFrame.msButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.msButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 3, 3)
    mainFrame.msButton:SetWidth(110)

    mainFrame.osButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.osButton:SetPoint('LEFT', mainFrame.msButton, 'RIGHT', 3, 0)
    mainFrame.osButton:SetWidth(110)

    mainFrame.passButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.passButton:SetText('Pass')
    mainFrame.passButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -3, 3)
    mainFrame.passButton:SetWidth(50)

    mainFrame.closeButton:SetScript('OnClick', function() RollWindow:hide() end)

    self.mainFrame.msButton:SetScript('OnClick', function()
        RandomRoll(1, 100)
        RollWindow.mainFrame.msButton:Disable()
        RollWindow.mainFrame.osButton:Enable()
    end)

    self.mainFrame.osButton:SetScript('OnClick', function()
        RandomRoll(1, 99)
        RollWindow.mainFrame.msButton:Enable()
        RollWindow.mainFrame.osButton:Disable()
    end)

    mainFrame.passButton:SetScript('OnClick', function()
        RollWindow:hide()

        ns.LootDistWindow:handlePass(ns.unitName('player'))

        ns.addon.sendRollPass()
    end)

    return mainFrame
end

function RollWindow:show(itemLink, duration)
    self:createWindow()

    self.mainFrame:Raise()

    ns.Lib.canPlayerUseItem(itemLink, function(usable)
        local label
        if usable then
            label = itemLink
            RollWindow.mainFrame.msButton:Enable()
            RollWindow.mainFrame.osButton:Enable()
        else
            label = 'You can\'t use this item!'
            RollWindow.mainFrame.msButton:Disable()
            RollWindow.mainFrame.osButton:Disable()
        end

        ns.Lib.getItemInfo(itemLink, function(itemInfo)
            self.mainFrame.timerBar = ns.addon.candy:New(
                'Interface\\AddOns\\' .. addonName .. '\\Assets\\timer-bar',
                self.mainFrame:GetWidth(),
                24
            )
            self.mainFrame.timerBar:SetParent(self.mainFrame)
            self.mainFrame.timerBar:SetPoint('TOPLEFT', self.mainFrame.titleBar, 'BOTTOMLEFT')
            self.mainFrame.timerBar.candyBarLabel:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE");
            self.mainFrame.timerBar.candyBarDuration:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE");
            self.mainFrame.timerBar:SetDuration(duration)
            self.mainFrame.timerBar:SetIcon(itemInfo.icon)
            self.mainFrame.timerBar:SetLabel(label)

            self.mainFrame.timerBar:SetScript('OnEnter', function()
                GameTooltip:SetOwner(self.mainFrame.timerBar, "ANCHOR_TOPLEFT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end)
            self.mainFrame.timerBar:SetScript('OnLeave', function() GameTooltip:Hide() end)

            local msGp = itemInfo.gp
            local osGp = math.floor(msGp * .1)

            self.mainFrame.msButton:SetText(string.format('MS (100%% GP: %d)', msGp))
            self.mainFrame.osButton:SetText(string.format('OS (10%% GP: %d)', osGp))

            self.mainFrame:Show()
            self.mainFrame.timerBar:Start()

            C_Timer.After(duration, function() RollWindow:hide() end)
        end)
    end)
end

function RollWindow:hide()
    if self.mainFrame == nil then
        return
    end

    if self.mainFrame.timerBar then
        self.mainFrame.timerBar:SetParent(UIParent);
        self.mainFrame.timerBar:Stop();
        self.mainFrame.timerBar = nil;
    end

    self.mainFrame:Hide()
end
