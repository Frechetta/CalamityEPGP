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

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    mainFrame:SetToplevel(true)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText(('%s Bench'):format(addonName))

    mainFrame.tableAvailable = ns.Table:new(mainFrame, 'Available', false, true, true, nil, self.handleRowClickAvailable)
    mainFrame.tableAvailable:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -35)
    mainFrame.tableAvailable:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableAvailable:SetPoint('RIGHT', mainFrame, 'CENTER', -35, 0)
    mainFrame.tableAvailable:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 10)

    mainFrame.tableBenched = ns.Table:new(mainFrame, 'Benched', false, true, true, nil, self.handleRowClickBenched)
    mainFrame.tableBenched:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -35)
    mainFrame.tableBenched:SetPoint('LEFT', mainFrame, 'CENTER', 35, 0)
    mainFrame.tableBenched:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableBenched:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 10)

    mainFrame.availableLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.availableLabel:SetPoint('BOTTOM', mainFrame.tableAvailable:getFrame(), 'TOP', 0, 5)
	mainFrame.availableLabel:SetText('Available')

    mainFrame.benchedLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.benchedLabel:SetPoint('BOTTOM', mainFrame.tableBenched:getFrame(), 'TOP', 0, 5)
	mainFrame.benchedLabel:SetText('Benched')

    mainFrame.benchButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.benchButton:SetText('Bench')
    mainFrame.benchButton:SetPoint('LEFT', mainFrame.tableAvailable:getFrame(), 'RIGHT', 5, 0)
    mainFrame.benchButton:SetPoint('RIGHT', mainFrame.tableBenched:getFrame(), 'LEFT', -5, 0)
    mainFrame.benchButton:SetPoint('BOTTOM', mainFrame.tableAvailable:getFrame(), 'CENTER', 0, 7)
    mainFrame.benchButton:Disable()

    mainFrame.removeButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.removeButton:SetText('Remove')
    mainFrame.removeButton:SetPoint('LEFT', mainFrame.tableAvailable:getFrame(), 'RIGHT', 5, 0)
    mainFrame.removeButton:SetPoint('RIGHT', mainFrame.tableBenched:getFrame(), 'LEFT', -5, 0)
    mainFrame.removeButton:SetPoint('TOP', mainFrame.tableAvailable:getFrame(), 'CENTER', 0, -7)
    mainFrame.removeButton:Disable()

    mainFrame.benchButton:SetScript('OnClick', function()
        local player = self.playersAvailableSelected

        if player == nil then
            return
        end

        if not ns.Lib.contains(ns.db.benchedPlayers, player) then
            tinsert(ns.db.benchedPlayers, player)
        end

        self:show()
    end)

    mainFrame.removeButton:SetScript('OnClick', function()
        local player = self.playersBenchedSelected

        if player == nil then
            return
        end

        ns.Lib.remove(ns.db.benchedPlayers, player)

        self:show()
    end)

    tinsert(UISpecialFrames, mainFrame:GetName())
end

function BenchWindow:show()
    self:createWindow()
    self.mainFrame:Raise()
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

    for guid in ns.standings:iter() do
        local playerData = ns.db.knownPlayers[guid]
        local player = playerData.name

        if not ns.Lib.contains(playersBenched, player) then
            local row = {
                player,
                {color = RAID_CLASS_COLORS[playerData.classFilename]}
            }

            ns.Lib.bininsert(dataAvailable.rows, row, function(left, right) return left[1] < right[1] end)
        end
    end


    for _, player in ipairs(playersBenched) do
        local row = {
            player,
            {color = ns.Lib.getPlayerClassColor(player)}
        }

        ns.Lib.bininsert(dataBenched.rows, row, function(left, right) return left[1] < right[1] end)
    end

    self.mainFrame.tableAvailable:setData(dataAvailable)
    self.mainFrame.tableBenched:setData(dataBenched)
end

function BenchWindow.handleRowClickAvailable(button, row)
    if button ~= 'LeftButton' or not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    local player = row.data[1]
    BenchWindow.playersAvailableSelected = player

    BenchWindow.mainFrame.benchButton:Enable()
    BenchWindow.mainFrame.removeButton:Disable()
end

function BenchWindow.handleRowClickBenched(button, row)
    if button ~= 'LeftButton' or not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    local player = row.data[1]
    BenchWindow.playersBenchedSelected = player

    BenchWindow.mainFrame.benchButton:Disable()
    BenchWindow.mainFrame.removeButton:Enable()
end
