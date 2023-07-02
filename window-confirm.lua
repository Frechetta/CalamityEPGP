local addonName, ns = ...  -- Namespace

local ConfirmWindow = {}

ns.ConfirmWindow = ConfirmWindow


function ConfirmWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrameName = addonName .. '_ConfirmWindow'

    local mainFrame = CreateFrame('Frame', mainFrameName, UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(250, 100)
	mainFrame:SetPoint('CENTER')

    mainFrame:SetFrameStrata('DIALOG')

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP')

    mainFrame.messageLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.messageLabel:SetPoint('TOP', mainFrame, 'TOP', 0, -mainFrame.TitleBg:GetHeight() - 20)

    mainFrame.yesButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.yesButton:SetText('Yes')
    mainFrame.yesButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 15, 12)
    mainFrame.yesButton:SetWidth(70)

    mainFrame.noButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.noButton:SetText('No')
    mainFrame.noButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 12)
    mainFrame.noButton:SetWidth(70)

    tinsert(UISpecialFrames, mainFrameName)

    return mainFrame
end

function ConfirmWindow:show(message, callbackYes, callbackNo)
    self:createWindow()

    self.mainFrame.messageLabel:SetText(message)

    if callbackYes == nil then
        callbackYes = function() end
    end

    if callbackNo == nil then
        callbackNo = function() end
    end

    self.mainFrame.yesButton:SetScript('OnClick', function() callbackYes(); ConfirmWindow.mainFrame:Hide() end)
    self.mainFrame.noButton:SetScript('OnClick', function() callbackNo(); ConfirmWindow.mainFrame:Hide() end)

    self.mainFrame:Show()
end
