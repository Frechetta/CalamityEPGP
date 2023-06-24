SLASH_RELOADUI1 = '/rl'
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = '/fs'
SlashCmdList.FRAMESTK = function()
    LoadAddOn('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end

for i = 1, NUM_CHAT_WINDOWS do
    _G['ChatFrame' .. i .. 'EditBox']:SetAltArrowKeyMode(false)
end
---------------------------------------------------------------

local addonName, ns = ...  -- Namespace

local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceConsole-3.0')
ns.addon = addon

local dbDefaults = {
    profile = {
        standings = {}
    }
}


function addon:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New(addonName, dbDefaults)
    guildName, _, _ = GetGuildInfo(UnitName('player'))

    for i = 1, GetNumGuildMembers() do
        local name, rank, _, level, class, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        if (self.db.profile.standings[name] == nil) then
            self.db.profile.standings[name] = {
                ['name'] = name,
                ['level'] = level,
                ['class'] = class,
                ['inGuild'] = true,
                ['rank'] = rank,
                ['ep'] = 0,
                ['gp'] = 1
            }
        end
    end

    self:Print('loaded')

    self.ShowWindowHandler(self)
end


function addon:OnEnable()
    -- Called when the addon is enabled
end


function addon:OnDisable()
    -- Called when the addon is disabled
end


function addon:SlashCommandHandler(input)
    if (input == 'show') then
        self.ShowWindowHandler(self)
    elseif (input == 'cfg') then
        self:Print('show options')
    else
        self:Print('Usage:')
        self:Print('show - Open the main window')
        self:Print('cfg - Opens the configuration menu')
    end
end


addon:RegisterChatCommand('ce', 'SlashCommandHandler')

function addon:ShowWindowHandler()
    local window = self:createWindow()
    window:SetShown(true)
end

function addon:createWindow()
    local mainFrame = CreateFrame("Frame", addonName .. "_MainFrame", UIParent, "BasicFrameTemplateWithInset");
	mainFrame:SetSize(500, 400);
	mainFrame:SetPoint("CENTER"); -- Doesn't need to be ("CENTER", UIParent, "CENTER")

    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag('LeftButton')
    mainFrame:SetScript('OnDragStart', mainFrame.StartMoving)
    mainFrame:SetScript('OnDragStop', mainFrame.StopMovingOrSizing)

    self.mainFrame = mainFrame

	mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0);
	mainFrame.title:SetText("CalamityEPGP");

	----------------------------------
	-- Buttons
	----------------------------------
	-- Save Button:
	mainFrame.saveBtn = self:createButton(mainFrame, "CENTER", mainFrame, "TOP", -70, "Save");

    mainFrame.tableFrame = CreateFrame('Frame', mainFrame:GetName() .. 'TableFrame', mainFrame)
    mainFrame.tableFrame:SetPoint('TOP', mainFrame.saveBtn, 'BOTTOM', 0, -10)
    mainFrame.tableFrame:SetPoint('LEFT', mainFrame, 'LEFT', 10, 0)
    mainFrame.tableFrame:SetPoint('RIGHT', mainFrame, 'RIGHT', -8, 0)
    mainFrame.tableFrame:SetPoint('BOTTOM', mainFrame, 'BOTTOM', 0, 6)

    self:getData()
    self:createTable()
    self:setData()

	return mainFrame;
end

function addon:createButton(parent, point, relativeFrame, relativePoint, yOffset, text)
	local btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate");
	btn:SetPoint(point, relativeFrame, relativePoint, 0, yOffset);
	btn:SetSize(140, 40);
	btn:SetText(text);
	btn:SetNormalFontObject("GameFontNormalLarge");
	btn:SetHighlightFontObject("GameFontHighlightLarge");
	return btn;
end

function addon:createTable()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    -- Initialize header
    -- we will finalize the size once the scroll frame is set up
    parent.header = CreateFrame('Frame', nil, parent)
    parent.header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, 0)
    parent.header:SetHeight(10)

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    parent.scrollChild = CreateFrame('Frame')

    local scrollFrameName = parent.scrollFrame:GetName()
    parent.scrollBar = _G[scrollFrameName .. "ScrollBar"];
    parent.scrollUpButton = _G[scrollFrameName .. "ScrollBarScrollUpButton"];
    parent.scrollDownButton = _G[scrollFrameName .. "ScrollBarScrollDownButton"];

    -- all of these objects will need to be re-anchored (if not, they appear outside the frame and about 30 pixels too high)
    parent.scrollUpButton:ClearAllPoints();
    parent.scrollUpButton:SetPoint("TOPRIGHT", parent.scrollFrame, "TOPRIGHT", -2, -2);

    parent.scrollDownButton:ClearAllPoints();
    parent.scrollDownButton:SetPoint("BOTTOMRIGHT", parent.scrollFrame, "BOTTOMRIGHT", -2, 2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint("TOP", parent.scrollUpButton, "BOTTOM", 0, -2);
    parent.scrollBar:SetPoint("BOTTOM", parent.scrollDownButton, "TOP", 0, 2);

    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth(), parent.scrollFrame:GetHeight() * 2)

    -- Back to the header
    parent.header:SetPoint('RIGHT', parent.scrollBar, 'LEFT', -5, 0)

    parent.header.columns = {}

    for i, header in ipairs(data.header) do
        local headerText = header[1]
        local justify = header[2]

        local column = CreateFrame('Frame', nil, parent.header)
        column:SetHeight(parent.header:GetHeight())

        local fontString = column:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        fontString:SetText(headerText)
        fontString:SetJustifyH(justify)
        fontString:SetTextColor(1, 1, 0)

        column.fontString = fontString
        column.textWidth = fontString:GetWrappedWidth()
        column.maxWidth = column.textWidth

        column:SetScript('OnEnter', function() fontString:SetTextColor(1, 1, 1) end)
        column:SetScript('OnLeave', function() fontString:SetTextColor(1, 1, 0) end)

        column:SetScript("OnMouseUp", function(self, button)
            if button == 'LeftButton' then
                addon:handleHeaderClick(i)
            end
        end)

        table.insert(parent.header.columns, column)
    end

    -- Initialize the content
    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetAllPoints(parent.scrollChild)

    parent.rows = {}

    for i = 1, #data.rows do
        self:addRow(i)
    end
end

function addon:addRow(index)
    local parent = self.mainFrame.tableFrame
    local data = self.data

    local rowHeight = 20

    local row = CreateFrame('Frame', nil, parent.contents)

    local yOffset = rowHeight * (index - 1)

    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.columns = {}

    for i = 1, #data.header do
        -- We will set the size later, once we've computed the column width based on the data
        local column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')

        column:SetPoint('TOP', row, 'TOP', 0, 0)

        table.insert(row.columns, column)
    end

    table.insert(parent.rows, row)
end

function addon:setData()
    local parent = self.mainFrame.tableFrame
    local data = self.data

    for i, rowData in ipairs(data.rows) do
        if i > #parent.rows then
            self:Print('adding row!')
            self:addRow(i)
        end

        local row = parent.rows[i]

        local class = string.upper(rowData[2]):gsub(' ', '')
        local classColorData = RAID_CLASS_COLORS[class]

        for j, columnText in ipairs(rowData) do
            local headerColumn = parent.header.columns[j]
            local column = row.columns[j]

            column:SetText(columnText)
            column:SetTextColor(classColorData.r, classColorData.g, classColorData.b)

            local text_width = column:GetWrappedWidth()
            if (text_width > headerColumn.maxWidth) then
                headerColumn.maxWidth = text_width
            end
        end
    end

    if #parent.rows > #data.rows then
        for i = #data.rows + 1, #parent.rows do
            self:Print('removing row!')
            local row = parent.rows[i]
            row:Hide()
        end
    end

    -- Calculate column padding
    local columnWidthTotal = 0
    for _, column in ipairs(parent.header.columns) do
        columnWidthTotal = columnWidthTotal + column.maxWidth
    end

    local leftover = parent.header:GetWidth() - columnWidthTotal
    local columnPadding = leftover / #parent.header.columns

    -- Finally set column width
    for i, column in ipairs(parent.header.columns) do
        local relativeElement = parent.header
        local relativePoint = 'LEFT'
        local padding = 0
        if (i > 1) then
            relativeElement = parent.header.columns[i - 1]
            relativePoint = 'RIGHT'
            padding = relativeElement.padding
        end

        column.padding = column.maxWidth + columnPadding - column.textWidth

        local xOffset = padding
        if column.fontString:GetJustifyH() == 'RIGHT' then
            xOffset = xOffset + column.padding - column.textWidth
        end

        column:SetPoint('LEFT', relativeElement, relativePoint, xOffset, 0)
        column:SetWidth(column.textWidth)

        column.fontString:SetAllPoints()
    end

    for _, row in ipairs(parent.rows) do
        for i, column in ipairs(row.columns) do
            local headerColumn = parent.header.columns[i]

            local anchorPoint = headerColumn.fontString:GetJustifyH()
            column:SetPoint(anchorPoint, headerColumn, anchorPoint, 0, 0)
        end
    end
end

function addon:handleHeaderClick(headerIndex)
    local order = 'ascending'
    if self.data.sorted.columnIndex == headerIndex and self.data.sorted.order == order then
        order = 'descending'
    end

    self:sortData(headerIndex, order)
    self:setData()
end

function addon:sortData(columnIndex, order)
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

function addon:getData()
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
        ['rows'] = {},
        ['sorted'] = {}
    }

    for character, charData in pairs(self.db.profile.standings) do
        local nameDash = string.find(character, '-')
        local name = string.sub(character, 0, nameDash - 1)

        local row = {
            name,
            charData.class,
            charData.inGuild and 'Yes' or 'No',
            charData.rank,
            charData.ep,
            charData.gp,
            charData.ep / charData.gp
        }

        table.insert(data.rows, row)
    end

    self.data = data

    self:sortData(7, 'descending')
end
