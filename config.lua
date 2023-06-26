local addonName, ns = ...  -- Namespace

local Config = {}
ns.Config = Config

Config.aceConfig = LibStub("AceConfig-3.0")
Config.aceConfigDialog = LibStub("AceConfigDialog-3.0")

local altData = {
    mainAltMapping = {
        Beathane = {'Beathane', 'Morfus', 'Wildviolet'},
        Burchmalurch = {'Burchmalurch', 'Zandral'},
        Donmur = {'Donmur', 'Donshero', 'Themur'},
        Kardiir = {'Kardiir', 'Kardiologist', 'Kardibank', 'Megapynt'},
    },
    altMainMapping = {}
}

for main, alts in pairs(altData.mainAltMapping) do
    for _, alt in ipairs(alts) do
        altData.altMainMapping[alt] = main
    end
end


function Config:init()
    local cfgRoot = {
        name = addonName,
        handler = ns.addon,
        type = 'group',
        args = {
            lmMode = {
                type = 'toggle',
                name = 'Loot master mode',
                order = 1,
                set = 'setLmMode',
                get = 'getLmMode',
                width = 'full',
            },
            decay = {
                type = 'input',
                name = 'Default decay %',
                set = 'setDefaultDecay',
                get = 'getDefaultDecay',
                pattern = '%d+',
                width = 'half',
            },
        }
    }

    self:addOptionsMenu(addonName, cfgRoot)
    self:initAltManagementMenu()
    -- Config:addOptionsMenu(addonName .. '_AltManagement', cfgAltManagement, addonName)
end


function Config:addOptionsMenu(ident, options, parent)
    self.aceConfig:RegisterOptionsTable(ident, options)
    self.aceConfigDialog:AddToBlizOptions(ident, options.name, parent)
end


function Config:initAltManagementMenu()
    local panel = CreateFrame('FRAME', addonName .. '_AltManagement')
    panel.name = 'Alt Management'
    panel.parent = addonName
    panel.refresh = self.createAltManagementMenu

    self.panel = panel

    InterfaceOptions_AddCategory(panel)
end


function Config:createAltManagementMenu()
    local panel = Config.panel

    panel.tableFrame = CreateFrame('Frame', panel:GetName() .. 'TableFrame', panel)
    panel.tableFrame:SetPoint('TOPLEFT', panel, 'TOPLEFT', 10, -20)
    panel.tableFrame:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -20, 2)

    Config:createTable()
end


function Config:createTable()
    local parent = self.panel.tableFrame

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    parent.scrollChild = CreateFrame('Frame')

    local scrollFrameName = parent.scrollFrame:GetName()
    parent.scrollBar = _G[scrollFrameName .. 'ScrollBar'];
    parent.scrollUpButton = _G[scrollFrameName .. 'ScrollBarScrollUpButton'];
    parent.scrollDownButton = _G[scrollFrameName .. 'ScrollBarScrollDownButton'];

    -- all of these objects will need to be re-anchored (if not, they appear outside the frame and about 30 pixels too high)
    parent.scrollUpButton:ClearAllPoints();
    parent.scrollUpButton:SetPoint('TOPRIGHT', parent.scrollFrame, 'TOPRIGHT', -2, -2);

    parent.scrollDownButton:ClearAllPoints();
    parent.scrollDownButton:SetPoint('BOTTOMRIGHT', parent.scrollFrame, 'BOTTOMRIGHT', -2, 2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint('TOP', parent.scrollUpButton, 'BOTTOM', 0, -2);
    parent.scrollBar:SetPoint('BOTTOM', parent.scrollDownButton, 'TOP', 0, 2);

    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth(), parent.scrollFrame:GetHeight() * 2)

    -- Initialize header
    parent.header = CreateFrame('Frame', nil, parent)
    parent.header:SetPoint('LEFT', parent, 'LEFT', 0, 0)
    parent.header:SetHeight(10)
    parent.header:SetPoint('BOTTOMRIGHT', parent.scrollUpButton, 'TOPLEFT', -7, 15)

    local mainColumn = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    mainColumn:SetText('Main')
    mainColumn:SetTextColor(1, 1, 0)
    mainColumn:SetPoint('LEFT', parent.header, 'LEFT')

    local altsColumn = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    altsColumn:SetText('Alts')
    altsColumn:SetJustifyH('RIGHT')
    altsColumn:SetTextColor(1, 1, 0)
    altsColumn:SetPoint('RIGHT', parent.header, 'RIGHT')

    -- Initialize the content
    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetAllPoints(parent.scrollChild)

    local i = 1
    for main, alts in pairs(altData.mainAltMapping) do
        local altsWithoutMain = ns.Lib:deepcopy(alts)
        ns.Lib:remove(altsWithoutMain, main)

        self:addRow(i, main, altsWithoutMain)

        i = i + 1
    end
end


function Config:addRow(index, main, alts)
    local parent = self.panel.tableFrame

    local rowHeight = 15
    local yOffset = (rowHeight + 3) * (index - 1)

    local row = CreateFrame('Frame', nil, parent.contents)
    row:SetPoint('TOPLEFT', parent.contents, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    -- row:SetPoint('RIGHT', parent.header, 'RIGHT')
    row:SetHeight(rowHeight)

    local mainColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    mainColumn:SetText(main)
    mainColumn:SetPoint('LEFT', row, 'LEFT')

    local altsStr = table.concat(alts, ', ')

    local altsColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    altsColumn:SetText(altsStr)
    altsColumn:SetPoint('RIGHT', row, 'RIGHT')
    altsColumn:SetJustifyH('RIGHT')
end
