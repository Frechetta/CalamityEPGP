local addonName, ns = ...  -- Namespace

local MainWindow = {
    data = {},
    myCharHighlights = {},
}

ns.MainWindow = MainWindow


function MainWindow:createWindow()
    if not ns.addon.initialized or self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_MainWindow', UIParent, 'BasicFrameTemplateWithInset');
	mainFrame:SetSize(600, 450);
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')
    mainFrame:SetToplevel(true)

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText(('%s Standings'):format(addonName))

    mainFrame.raidOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.raidOnlyLabel:SetText('Raid Only')
    mainFrame.raidOnlyLabel:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -20)

    mainFrame.raidOnlyButton = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.raidOnlyButton:SetPoint('LEFT', mainFrame.raidOnlyLabel, 'RIGHT', 3, 0)

    if IsInRaid() then
        self:setRaidOnly(true)
    end

    mainFrame.mainsOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.mainsOnlyLabel:SetText('Mains Only')
    mainFrame.mainsOnlyLabel:SetPoint('LEFT', mainFrame.raidOnlyButton, 'RIGHT', 15, 0)

    mainFrame.mainsOnlyButton = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.mainsOnlyButton:SetPoint('LEFT', mainFrame.mainsOnlyLabel, 'RIGHT', 3, 0)

    mainFrame.optionsButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.optionsButton:SetText('Options')
    mainFrame.optionsButton:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -15)
    mainFrame.optionsButton:SetPoint('RIGHT', mainFrame, 'RIGHT', -15, 0)
    mainFrame.optionsButton:SetWidth(97)

    mainFrame.historyButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.historyButton:SetText('View History')
    mainFrame.historyButton:SetPoint('RIGHT', mainFrame.optionsButton, 'LEFT', -5, 0)
    mainFrame.historyButton:SetWidth(97)

    mainFrame.addEpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.addEpButton:SetText('Add EP')
    mainFrame.addEpButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 10, 8)
    mainFrame.addEpButton:SetWidth(90)

    mainFrame.decayEpgpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.decayEpgpButton:SetText('Decay EPGP')
    mainFrame.decayEpgpButton:SetPoint('LEFT', mainFrame.addEpButton, 'RIGHT', 2, 0)
    mainFrame.decayEpgpButton:SetWidth(100)

    mainFrame.benchButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.benchButton:SetText('Bench')
    mainFrame.benchButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 8)
    mainFrame.benchButton:SetWidth(97)

    mainFrame.tableFrame = ns.Table:new(mainFrame, nil, true, true, nil, self.handleHeaderClick, self.handleRowClick)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.raidOnlyLabel, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMLEFT', mainFrame.addEpButton, 'TOPLEFT', 0, 2)

    mainFrame.optionsButton:SetScript('OnClick', ns.addon.openOptions)
    mainFrame.historyButton:SetScript('OnClick', function() self:handleHistoryClick() end)
    mainFrame.addEpButton:SetScript('OnClick', function() self:handleAddEpClick() end)
    mainFrame.decayEpgpButton:SetScript('OnClick', function() self:handleDecayEpgpClick() end)
    mainFrame.raidOnlyButton:SetScript('OnClick', function()
        self:filterData()
        self:setData()
    end)
    mainFrame.mainsOnlyButton:SetScript('OnClick', function() self:filterData(); self:setData() end)
    mainFrame.benchButton:SetScript('OnClick', function() ns.BenchWindow:show() end)

    tinsert(UISpecialFrames, mainFrame:GetName())

    self:refresh()

	return mainFrame;
end

function MainWindow:refresh()
    if self.mainFrame == nil then
        return
    end

    self:getData()
    self:setData()
end

function MainWindow:setData()
    self.mainFrame.tableFrame:setData(self.data)
end

function MainWindow:show()
    if self.mainFrame == nil then
        return
    end

    self.mainFrame:Raise()

    if not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        self.mainFrame.addEpButton:Disable()
        self.mainFrame.addEpButton:Hide()

        self.mainFrame.decayEpgpButton:Disable()
        self.mainFrame.decayEpgpButton:Hide()
    else
        self.mainFrame.addEpButton:Enable()
        self.mainFrame.addEpButton:Show()

        self.mainFrame.decayEpgpButton:Enable()
        self.mainFrame.decayEpgpButton:Show()
    end

    self.mainFrame:Show()
end

---@return boolean
function MainWindow:getRaidOnly()
    return self.mainFrame.raidOnlyButton:GetChecked()
end

---@param raidOnly boolean
function MainWindow:setRaidOnly(raidOnly)
    self.mainFrame.raidOnlyButton:SetChecked(raidOnly)
end

function MainWindow.handleHeaderClick(headerIndex)
    local order = 'ascending'
    if MainWindow.data.sorted.columnIndex == headerIndex and MainWindow.data.sorted.order == order then
        order = 'descending'
    end

    MainWindow.data.sorted.columnIndex = headerIndex
    MainWindow.data.sorted.order = order

    MainWindow:sortData()
    MainWindow:setData()
end

function MainWindow:handleHistoryClick()
    ns.HistoryWindow:createWindow()
    ns.HistoryWindow:show()

    ns.ModifyEpgpWindow:hide()
    ns.AddEpWindow:hide()
    ns.DecayEpgpWindow:hide()

    ns.Lib.remove(UISpecialFrames, self.mainFrame:GetName(), true)
end

function MainWindow.handleRowClick(button, row)
    if button ~= 'LeftButton' or not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    ns.AddEpWindow:hide()
    ns.DecayEpgpWindow:hide()

    local name = row.data[1]
    local guid = ns.Lib.getPlayerGuid(name)

    ns.ModifyEpgpWindow:show(name, guid)

    ns.Lib.remove(UISpecialFrames, MainWindow.mainFrame:GetName(), true)
end

function MainWindow:handleAddEpClick()
    if not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    ns.ModifyEpgpWindow:hide()
    ns.DecayEpgpWindow:hide()

    ns.AddEpWindow:show()

    ns.Lib.remove(UISpecialFrames, self.mainFrame:GetName(), true)
end

function MainWindow:handleDecayEpgpClick()
    if not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    ns.AddEpWindow:hide()
    ns.ModifyEpgpWindow:hide()

    ns.DecayEpgpWindow:show()

    ns.Lib.remove(UISpecialFrames, self.mainFrame:GetName(), true)
end

function MainWindow:filterData()
    self.data.rows = {}

    for _, row in ipairs(self.data.rowsRaw) do
        local keep = true
        if (self:getRaidOnly() and not ns.addon.raidRoster:contains(row[1]))
                or (self.mainFrame.mainsOnlyButton:GetChecked()
                    and not ns.Lib.contains(ns.db.altData.mainAltMapping, row[1])) then
            keep = false
        end

        if keep then
            tinsert(self.data.rows, row)
        end
    end

    self:sortData()
end

function MainWindow:sortData()
    local columnIndex = self.data.sorted.columnIndex
    local order = self.data.sorted.order

    if columnIndex == nil or order == nil then
        return
    end

    table.sort(self.data.rows, function(left, right)
        if order == 'ascending' then
            return left[columnIndex] < right[columnIndex]
        else
            return left[columnIndex] > right[columnIndex]
        end
    end)

    self.data.sorted.columnIndex = columnIndex
    self.data.sorted.order = order
end

function MainWindow:getData()
    local sorted = {}
    if self.data.sorted ~= nil and self.data.sorted.columnIndex ~= nil then
        sorted = self.data.sorted
    else
        sorted.columnIndex = 7
        sorted.order = 'descending'
    end

    local data = {
        ['header'] = {
            {'Name', 'LEFT'},
            {'Class', 'LEFT'},
            {'Guildie', 'LEFT'},
            {'Rank', 'LEFT'},
            {'EP', 'RIGHT'},
            {'GP', 'RIGHT'},
            {'PR', 'RIGHT'}
        },
        ['rowsRaw'] = {},
        ['rows'] = {},
        ['sorted'] = sorted,
    }

    for guid, playerStandings in ns.standings:iter() do
        local playerData = ns.knownPlayers:get(guid)

        local name = playerData.name
        local classFilename = playerData.classFilename
        local class = LOCALIZED_CLASS_NAMES_MALE[classFilename]
        local inGuild = playerData.inGuild
        local rankIndex = playerData.rankIndex

        local ep = playerStandings.ep
        local gp = playerStandings.gp

        local row = {
            name,
            class,
            inGuild and 'Yes' or 'No',
            rankIndex and ns.Lib.getRankName(rankIndex) or 'N/A',
            tonumber(string.format("%.2f", ep)),
            tonumber(string.format("%.2f", gp)),
            tonumber(string.format("%.3f", ep / gp)),
            {
                color = RAID_CLASS_COLORS[classFilename],
            }
        }

        tinsert(data.rowsRaw, row)
    end

    self.data = data

    self:filterData()
    self:sortData()
end
