local addonName, ns = ...  -- Namespace

local Set = ns.Set

local BenchWindow = {
    playersAvailableSelected = nil,
    playersBenchedSelected = nil,
}

ns.BenchWindow = BenchWindow


function BenchWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_BenchWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(500, 375)
	mainFrame:SetPoint('CENTER')
    mainFrame:SetFrameStrata('HIGH')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP Bench')

    mainFrame.tableAvailable = ns.Table:new(mainFrame, 'Available', false, true, true, nil, self.handleRowClickAvailable)
    mainFrame.tableAvailable:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -35)
    mainFrame.tableAvailable:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableAvailable:SetPoint('RIGHT', mainFrame, 'CENTER', -20, 0)
    mainFrame.tableAvailable:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 10)

    mainFrame.tableBenched = ns.Table:new(mainFrame, 'Benched', false, true, true, nil, self.handleRowClickBenched)
    mainFrame.tableBenched:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -35)
    mainFrame.tableBenched:SetPoint('LEFT', mainFrame, 'CENTER', 20, 0)
    mainFrame.tableBenched:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableBenched:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 10)

    mainFrame.availableLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.availableLabel:SetPoint('BOTTOM', mainFrame.tableAvailable:getFrame(), 'TOP', 0, 5)
	mainFrame.availableLabel:SetText('Available')

    mainFrame.benchedLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.benchedLabel:SetPoint('BOTTOM', mainFrame.tableBenched:getFrame(), 'TOP', 0, 5)
	mainFrame.benchedLabel:SetText('Benched')

    -- TODO: move buttons

    tinsert(UISpecialFrames, mainFrame:GetName())
end

function BenchWindow:show()
    self:createWindow()
    self:setData()
    self.mainFrame:Show()
end

function BenchWindow:setData()
    if self.mainFrame == nil then
        return
    end

    local dataAvailable = {rows = {}}
    local dataBenched = {rows = {}}

    local playersBenched = ns.db.benchedPlayers

    for _, charData in pairs(ns.db.standings) do
        local player = charData.name

        if not ns.Lib.contains(playersBenched, player) then
            local row = {
                player,
                {color = RAID_CLASS_COLORS[charData.classFileName]}
            }

            tinsert(dataAvailable.rows, row)
        end
    end


    for _, player in ipairs(playersBenched) do
        local row = {
            player,
            {color = ns.Lib.getPlayerClassColor(player)}
        }

        tinsert(dataBenched.rows, row)
    end

    self.mainFrame.tableAvailable:setData(dataAvailable)
    self.mainFrame.tableBenched:setData(dataBenched)
end

function BenchWindow.handleRowClickAvailable(button, row)
    if button ~= 'LeftButton' or not ns.addon.isOfficer or not ns.cfg.lmMode then
        return
    end

    local player = row.data[1]
    BenchWindow.playersAvailableSelected = player
end

function BenchWindow.handleRowClickBenched(button, row)
    if button ~= 'LeftButton' or not ns.addon.isOfficer or not ns.cfg.lmMode then
        return
    end

    local player = row.data[1]
    BenchWindow.playersBenchedSelected = player
end
