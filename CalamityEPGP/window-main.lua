local addonName, ns = ...  -- Namespace

local MainWindow = {
    data = {},
    myCharHighlights = {},
}

ns.MainWindow = MainWindow


function MainWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_MainWindow', UIParent, 'BasicFrameTemplateWithInset');
	mainFrame:SetSize(600, 450);
	mainFrame:SetPoint('CENTER'); -- Doesn't need to be ('CENTER', UIParent, 'CENTER')

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText('CalamityEPGP Standings')

    mainFrame.raidOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.raidOnlyLabel:SetText('Raid Only')
    mainFrame.raidOnlyLabel:SetPoint('TOPLEFT', mainFrame.TitleBg, 'BOTTOMLEFT', 15, -20)

    mainFrame.raidOnlyButton = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.raidOnlyButton:SetPoint('LEFT', mainFrame.raidOnlyLabel, 'RIGHT', 3, 0)

    if IsInRaid() then
        mainFrame.raidOnlyButton:SetChecked(true)
    end

    mainFrame.mainsOnlyLabel = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    mainFrame.mainsOnlyLabel:SetText('Mains Only')
    mainFrame.mainsOnlyLabel:SetPoint('LEFT', mainFrame.raidOnlyButton, 'RIGHT', 15, 0)

    mainFrame.mainsOnlyButton = CreateFrame('CheckButton', nil, mainFrame, 'UICheckButtonTemplate')
    mainFrame.mainsOnlyButton:SetPoint('LEFT', mainFrame.mainsOnlyLabel, 'RIGHT', 3, 0)

    mainFrame.optionsButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.optionsButton:SetText('Options')
    mainFrame.optionsButton:SetPoint('TOP', mainFrame.TitleBg, 'BOTTOM', 0, -15)
    mainFrame.optionsButton:SetPoint('RIGHT', mainFrame, 'RIGHT', -20, 0)
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

    mainFrame.tableFrame = ns.Table:new(mainFrame, true, true, nil, self.handleHeaderClick, self.handleRowClick)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.raidOnlyLabel, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMLEFT', mainFrame.addEpButton, 'TOPLEFT', 0, 2)

    mainFrame.optionsButton:SetScript('OnClick', ns.addon.openOptions)
    mainFrame.historyButton:SetScript('OnClick', function() self:handleHistoryClick() end)
    mainFrame.addEpButton:SetScript('OnClick', function() self:handleAddEpClick() end)
    mainFrame.decayEpgpButton:SetScript('OnClick', function() self:handleDecayEpgpClick() end)
    mainFrame.raidOnlyButton:SetScript('OnClick', function() self:filterData(); self:setData() end)
    mainFrame.mainsOnlyButton:SetScript('OnClick', function() self:filterData(); self:setData() end)

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
    if self.mainFrame == nil or not self.mainFrame:IsShown() then
        return
    end

    if not ns.addon.isOfficer or not ns.cfg.lmMode then
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
    if button ~= 'LeftButton' or not ns.addon.isOfficer or not ns.cfg.lmMode then
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
    if not ns.addon.isOfficer or not ns.cfg.lmMode then
        return
    end

    ns.ModifyEpgpWindow:hide()
    ns.DecayEpgpWindow:hide()

    ns.AddEpWindow:show()

    ns.Lib.remove(UISpecialFrames, self.mainFrame:GetName(), true)
end

function MainWindow:handleDecayEpgpClick()
    if not ns.addon.isOfficer or not ns.cfg.lmMode then
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
        if (self.mainFrame.raidOnlyButton:GetChecked() and not ns.addon.raidRoster:contains(row[1]))
                or (self.mainFrame.mainsOnlyButton:GetChecked()
                    and not ns.Lib.dictContains(ns.db.altData.mainAltMapping, row[1])) then
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

    for _, charData in pairs(ns.db.standings) do
        local row = {
            charData.name,
            charData.class,
            charData.inGuild and 'Yes' or 'No',
            charData.rank and charData.rank or 'N/A',
            tonumber(string.format("%.2f", charData.ep)),
            tonumber(string.format("%.2f", charData.gp)),
            tonumber(string.format("%.3f", charData.ep / charData.gp)),
            {
                color = RAID_CLASS_COLORS[charData.classFileName],
            }
        }

        tinsert(data.rowsRaw, row)
    end

    self.data = data

    self:filterData()
    self:sortData()
end
