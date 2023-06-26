local addonName, ns = ...  -- Namespace

local Config = {
    initialized = false,
}
ns.Config = Config

Config.aceConfig = LibStub("AceConfig-3.0")
Config.aceConfigDialog = LibStub("AceConfigDialog-3.0")

local initialDefaultDecay = 10


function Config:init()
    local cfgRoot = {
        name = addonName,
        handler = self,
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
    self.panel = CreateFrame('FRAME', addonName .. '_AltManagement')
    self.panel.name = 'Alt Management'
    self.panel.parent = addonName
    self.panel.refresh = self.refreshAltManagementMenu

    InterfaceOptions_AddCategory(self.panel)
end


function Config:refreshAltManagementMenu()
    if not Config.initialized and Config.panel:GetWidth() ~= 0 then
        Config:createAltManagementMenu()
        Config.initialized = true
    end

    Config:setAltManagementData()
end


function Config:createAltManagementMenu()
    local panel = self.panel

    local importAltMappingButton = CreateFrame('Button', nil, panel, 'GameMenuButtonTemplate')
    importAltMappingButton:SetText('Import From GRM')
    importAltMappingButton:SetPoint('TOPLEFT', 10, -15)

    local synchroniseGpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    synchroniseGpLabel:SetText('Synchronise Alt GP')
    synchroniseGpLabel:SetTextColor(1, 1, 0)
    synchroniseGpLabel:SetPoint('BOTTOMLEFT', panel, 'BOTTOMLEFT', 10, 25)

    local synchroniseGpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    synchroniseGpCheck:SetPoint('LEFT', synchroniseGpLabel, 'RIGHT', 5, 0)

    local synchroniseEpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    synchroniseEpLabel:SetText('Synchronise Alt EP')
    synchroniseEpLabel:SetTextColor(1, 1, 0)
    synchroniseEpLabel:SetPoint('BOTTOM', synchroniseGpLabel, 'TOP', 0, 15)

    local synchroniseEpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    synchroniseEpCheck:SetPoint('LEFT', synchroniseEpLabel, 'RIGHT', 5, 0)

    panel.tableFrame = CreateFrame('Frame', panel:GetName() .. 'TableFrame', panel)
    panel.tableFrame:SetPoint('TOPLEFT', importAltMappingButton, 'BOTTOMLEFT', 0, -20)
    panel.tableFrame:SetPoint('RIGHT', panel, 'RIGHT', -20, 0)
    panel.tableFrame:SetPoint('BOTTOM', synchroniseEpLabel, 'BOTTOM', 0, 15)

    importAltMappingButton:SetScript('OnClick', function()
        if GRM_Alts == nil then
            ns.addon:Print('GRM data not accessible')
            return
        end

        ns.db.altData.mainAltMapping = {}

        for _, altData in pairs(GRM_Alts[ns.guild]) do
            if #altData.main > 0 then
                local main = ns.addon:getCharName(altData.main)

                local alts = {}

                for _, alt in ipairs(altData) do
                    local name = alt.name
                    if name ~= nil then
                        name = ns.addon:getCharName(name)
                        table.insert(alts, name)
                    end
                end

                ns.db.altData.mainAltMapping[main] = alts
            end
        end

        self:setAltMainMapping()
        self:setAltManagementData()
    end)

    ns.cfg.syncAltEp = ns.cfg.syncAltEp or false
    synchroniseEpCheck:SetChecked(ns.cfg.syncAltEp)
    synchroniseEpCheck:SetScript('OnClick', function() ns.cfg.syncAltEp = synchroniseEpCheck:GetChecked() end)

    ns.cfg.syncAltGp = ns.cfg.syncAltGp or false
    synchroniseGpCheck:SetChecked(ns.cfg.syncAltGp)
    synchroniseGpCheck:SetScript('OnClick', function() ns.cfg.syncAltGp = synchroniseGpCheck:GetChecked() end)

    self:createAltManagementTable()
end


function Config:createAltManagementTable()
    local parent = self.panel.tableFrame

    -- Initialize scroll frame
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -30)
    parent.scrollFrame:SetWidth(parent:GetWidth())
    parent.scrollFrame:SetPoint('BOTTOM', parent, 'BOTTOM', 0, 0)

    parent.scrollChild = CreateFrame('Frame')
    parent.scrollChild:SetWidth(parent.scrollFrame:GetWidth())
    parent.scrollChild:SetHeight(1)
    parent.scrollFrame:SetScrollChild(parent.scrollChild);

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

    parent.contents.rows = {}
end


function Config:setAltManagementData()
    local parent = self.panel.tableFrame

    if parent == nil then
        return
    end

    local i = 1
    for main, alts in pairs(ns.db.altData.mainAltMapping) do
        local row = parent.contents.rows[i]

        if row == nil then
            row = self:addAltManagementRow(i)
            table.insert(parent.contents.rows, row)
        end

        row:Show()

        local altsWithoutMain = ns.Lib:deepcopy(alts)
        ns.Lib:remove(altsWithoutMain, main)

        local altsStr = table.concat(alts, ', ')
        row.mainColumn:SetText(main)
        row.altsColumn:SetText(altsStr)

        i = i + 1
    end

    for j = i, #parent.contents.rows do
        local row = parent.contents.rows[j]
        row:Hide()
    end
end


function Config:addAltManagementRow(index)  -- , main, alts)
    local parent = self.panel.tableFrame

    local rowHeight = 15
    local yOffset = (rowHeight + 3) * (index - 1)

    local row = CreateFrame('Frame', nil, parent.scrollChild)
    row:SetPoint('TOPLEFT', parent.scrollChild, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.mainColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.mainColumn:SetText('temp')
    row.mainColumn:SetPoint('LEFT', row, 'LEFT')

    row.altsColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.altsColumn:SetText('temp')
    row.altsColumn:SetPoint('RIGHT', row, 'RIGHT')
    row.altsColumn:SetJustifyH('RIGHT')

    return row
end


function Config:setAltMainMapping()
    ns.db.altData.altMainMapping = {}

    for main, alts in pairs(ns.db.altData.mainAltMapping) do
        for _, alt in ipairs(alts) do
            ns.db.altData.altMainMapping[alt] = main
        end
    end
end


-------------------------
-- OPTION GETTERS/SETTERS
-------------------------
function Config:getLmMode(info)
    return ns.cfg.lmMode
end

function Config:setLmMode(info, input)
    ns.cfg.lmMode = input
end

function Config:getDefaultDecay(info)
    if ns.cfg.defaultDecay == nil then
        ns.cfg.defaultDecay = initialDefaultDecay
    end

    return tostring(ns.cfg.defaultDecay)
end

function Config:setDefaultDecay(info, input)
    ns.cfg.defaultDecay = input
end
