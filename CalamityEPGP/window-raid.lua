local addonName, ns = ...  -- Namespace

local Dict = ns.Dict
local Set = ns.Set

local RaidWindow = {
    data = {},
}

ns.RaidWindow = RaidWindow


function RaidWindow:createWindow()
    if self.mainFrame ~= nil then
        return
    end

    local mainFrame = CreateFrame('Frame', addonName .. '_RaidWindow', UIParent, 'BasicFrameTemplateWithInset')
	mainFrame:SetSize(400, 400)
	mainFrame:SetPoint('CENTER')
    mainFrame:SetToplevel(true)

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	mainFrame.title:SetPoint('LEFT', mainFrame.TitleBg, 'LEFT', 5, 0)
	mainFrame.title:SetText(('%s Raid'):format(addonName))

    mainFrame.addEpButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.addEpButton:SetText('Add EP')
    mainFrame.addEpButton:SetPoint('BOTTOMLEFT', mainFrame, 'BOTTOMLEFT', 10, 8)
    mainFrame.addEpButton:SetWidth(90)

    mainFrame.benchButton = CreateFrame('Button', nil, mainFrame, 'UIPanelButtonTemplate')
    mainFrame.benchButton:SetText('Bench')
    mainFrame.benchButton:SetPoint('BOTTOMRIGHT', mainFrame, 'BOTTOMRIGHT', -15, 8)
    mainFrame.benchButton:SetWidth(97)

    mainFrame.tableFrame = ns.Table:new(mainFrame, nil, true, true, nil, self.handleHeaderClick, self.handleRowClick)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.title, 'BOTTOM', 0, -20)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOMLEFT', mainFrame.addEpButton, 'TOPLEFT', 0, 2)

    mainFrame.addEpButton:SetScript('OnClick', function() self:handleAddEpClick() end)
    mainFrame.benchButton:SetScript('OnClick', function() ns.BenchWindow:show() end)

    tinsert(UISpecialFrames, mainFrame:GetName())

	return mainFrame;
end


function RaidWindow:show()
    self:createWindow()
    self:refresh()
    self.mainFrame:Raise()
    self.mainFrame:Show()
end


function RaidWindow:refresh()
    if self.mainFrame == nil then
        return
    end

    self:getData()
    self:setData()
end


function RaidWindow.handleHeaderClick(headerIndex)
    local order = 'ascending'
    if RaidWindow.data.sorted.columnIndex == headerIndex and RaidWindow.data.sorted.order == order then
        order = 'descending'
    end

    RaidWindow.data.sorted.columnIndex = headerIndex
    RaidWindow.data.sorted.order = order

    RaidWindow:sortData()
    RaidWindow:setData()
end


function RaidWindow.handleRowClick(button, row)
    if button ~= 'LeftButton' or not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    ns.AddEpWindow:hide()
    ns.DecayEpgpWindow:hide()

    local name = row.data[1]
    local guid = ns.Lib.getPlayerGuid(name)

    ns.ModifyEpgpWindow:show(name, guid)

    ns.Lib.remove(UISpecialFrames, RaidWindow.mainFrame:GetName(), true)
end


function RaidWindow:handleAddEpClick()
    if not ns.Lib.isOfficer() or not ns.cfg.lmMode then
        return
    end

    ns.ModifyEpgpWindow:hide()
    ns.DecayEpgpWindow:hide()

    ns.AddEpWindow:show(true)

    ns.Lib.remove(UISpecialFrames, self.mainFrame:GetName(), true)
end


function RaidWindow:setData()
    self.mainFrame.tableFrame:setData(self.data)
end


function RaidWindow:getData()
    local sorted = {}
    if self.data.sorted ~= nil and self.data.sorted.columnIndex ~= nil then
        sorted = self.data.sorted
    else
        sorted.columnIndex = 1
        sorted.order = 'ascending'
    end

    local data = {
        ['header'] = {
            {'Name', 'LEFT'},
            {'Guildie', 'LEFT'},
            {'PR', 'RIGHT'}
        },
        ['rows'] = {},
        ['sorted'] = sorted,
    }

    for name, info in ns.addon.raidRoster:iter() do
        local guid = ns.Lib.getPlayerGuid(name)
        local online = info.online
        local playerData = ns.knownPlayers:get(guid)

        local classFilename = playerData.classFilename
        local inGuild = playerData.inGuild

        local standings = ns.standings:get(guid)

        if standings == nil then
            standings = ns.addon.createStandingsEntry(guid)
            ns.standings:set(guid, standings)
        end

        local ep = standings.ep
        local gp = standings.gp

        local row = {
            name,
            inGuild and 'Yes' or 'No',
            tonumber(string.format("%.3f", ep / gp)),
            {
                color = RAID_CLASS_COLORS[classFilename],
            },
        }

        tinsert(data.rows, row)
    end

    self.data = data

    self:sortData()
end


function RaidWindow:sortData()
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
