local addonName, ns = ...  -- Namespace

local Config = {
    altManagementMenuInitialized = false,
    defaults = {
        lmMode = false,
        defaultDecay = 10,
        syncAltEp = false,
        syncAltGp = true,
        rollDuration = 25,
        closeOnAward = true,
        gpBase = ns.values.gpDefaults.base,
        gpSlotMods = ns.values.gpDefaults.slotModifiers,
        encounterEp = {},
        minimap = {
            hide = false,
        },
        debugMode = false,
    }
}

ns.Config = Config

-- add default encounter EP to defaults
for _, expansion in ipairs(ns.values.epDefaults) do
    for _, instance in ipairs(expansion[2]) do
        for _, encounter in ipairs(instance[2]) do
            local encounterId = encounter[2]
            local ep = encounter[3]
            Config.defaults.encounterEp[encounterId] = ep
        end
    end
end

Config.aceConfig = LibStub("AceConfig-3.0")
Config.aceConfigDialog = LibStub("AceConfigDialog-3.0")


function Config:init()
    local menus = {
        root = {
            name = addonName,
            handler = self,
            type = 'group',
            args = {
                lmMode = {
                    type = 'toggle',
                    name = 'Loot master mode',
                    width = 'full',
                    order = 1,
                    get = 'getLmMode',
                    set = 'setLmMode',
                    disabled = 'getLmModeDisabled',
                },
                showMinimapButton = {
                    type = 'toggle',
                    name = 'Show minimap button',
                    width = 'full',
                    order = 2,
                    get = 'getShowMinimapButton',
                    set = 'setShowMinimapButton',
                },
                decay = {
                    type = 'input',
                    name = 'Default decay %',
                    width = 'half',
                    pattern = '%d+',
                    order = 3,
                    get = 'getDefaultDecay',
                    set = 'setDefaultDecay',
                    disabled = 'getDefaultDecayDisabled',
                },
                linebreak1 = {type = 'description', name = '', order = 4},
                clearData = {
                    type = 'execute',
                    name = 'Clear all data',
                    order = 5,
                    func = 'clearData',
                },
            }
        },
        lootDistribution = {
            name = 'Loot Distribution',
            handler = self,
            type = 'group',
            args = {
                duration = {
                    type = 'input',
                    name = 'Roll duration',
                    width = 'half',
                    get = 'getRollDuration',
                    set = 'setRollDuration',
                },
                closeOnAward = {
                    type = 'toggle',
                    name = 'Close distribution window on award',
                    width = 'full',
                    order = 1,
                    get = 'getCloseOnAward',
                    set = 'setCloseOnAward',
                },
            }
        },
        gpManagement = {
            name = 'GP Management',
            handler = self,
            type = 'group',
            disabled = 'getGpManagementDisabled',
            args = {
                gpBase = {
                    type = 'input',
                    name = 'Base GP',
                    width = 'half',
                    pattern = '%d+',
                    get = 'getBaseGp',
                    set = 'setBaseGp',
                }
            }
        },
        advanced = {
            name = 'Advanced',
            handler = self,
            type = 'group',
            order = -1,
            args = {
                debugMode = {
                    type = 'toggle',
                    name = 'Debug Mode',
                    get = 'getDebugMode',
                    set = 'setDebugMode',
                }
            }
        }
    }

    -- add defaults to ns.cfg if it's not already poulated
    for optName, default in pairs(self.defaults) do
        if ns.cfg[optName] == nil then
            ns.cfg[optName] = default
        end
    end

    -- create options menus
    self:addOptionsMenu(addonName, menus.root)
    self:initAltManagementMenu()
    self:addOptionsMenu(addonName .. '_LootDistribution', menus.lootDistribution, addonName)
    self:addOptionsMenu(addonName .. '_GpManagement', menus.gpManagement, addonName)
    self:addOptionsMenu(addonName .. '_Advanced', menus.advanced, addonName)
end


function Config:addOptionsMenu(ident, options, parent)
    self.aceConfig:RegisterOptionsTable(ident, options)
    self.aceConfigDialog:AddToBlizOptions(ident, options.name, parent)
end


function Config:initAltManagementMenu()
    self.aamPanel = CreateFrame('FRAME', addonName .. '_AltManagement')
    self.aamPanel.name = 'Alt Management'
    self.aamPanel.parent = addonName
    self.aamPanel.refresh = self.refreshAltManagementMenu

    InterfaceOptions_AddCategory(self.aamPanel)
end


function Config:refreshAltManagementMenu()
    self = Config

    if not self.altManagementMenuInitialized and self.aamPanel:GetWidth() ~= 0 then
        self:createAltManagementMenu()
        self.altManagementMenuInitialized = true
    end

    self:setAltManagementData()

    if self.altManagementMenuInitialized then
        if ns.cfg.lmMode then
            self.aamPanel.importAltMappingButton:Enable()
            self.aamPanel.synchroniseEpCheck:Enable()
            self.aamPanel.synchroniseGpCheck:Enable()
        else
            self.aamPanel.importAltMappingButton:Disable()
            self.aamPanel.synchroniseEpCheck:Disable()
            self.aamPanel.synchroniseGpCheck:Disable()
        end
    end
end


function Config:createAltManagementMenu()
    local panel = self.aamPanel

    panel.importAltMappingButton = CreateFrame('Button', nil, panel, 'GameMenuButtonTemplate')
    panel.importAltMappingButton:SetText('Import From GRM')
    panel.importAltMappingButton:SetPoint('TOPLEFT', 10, -15)

    panel.synchroniseGpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    panel.synchroniseGpLabel:SetText('Synchronise Alt GP')
    panel.synchroniseGpLabel:SetTextColor(1, 1, 0)
    panel.synchroniseGpLabel:SetPoint('BOTTOMLEFT', panel, 'BOTTOMLEFT', 10, 25)

    panel.synchroniseGpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    panel.synchroniseGpCheck:SetPoint('LEFT', panel.synchroniseGpLabel, 'RIGHT', 5, 0)

    panel.synchroniseEpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    panel.synchroniseEpLabel:SetText('Synchronise Alt EP')
    panel.synchroniseEpLabel:SetTextColor(1, 1, 0)
    panel.synchroniseEpLabel:SetPoint('BOTTOM', panel.synchroniseGpLabel, 'TOP', 0, 15)

    panel.synchroniseEpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    panel.synchroniseEpCheck:SetPoint('LEFT', panel.synchroniseEpLabel, 'RIGHT', 5, 0)

    panel.tableFrame = CreateFrame('Frame', panel:GetName() .. 'TableFrame', panel)
    panel.tableFrame:SetPoint('TOPLEFT', panel.importAltMappingButton, 'BOTTOMLEFT', 0, -20)
    panel.tableFrame:SetPoint('RIGHT', panel, 'RIGHT', -20, 0)
    panel.tableFrame:SetPoint('BOTTOM', panel.synchroniseEpLabel, 'BOTTOM', 0, 15)

    panel.importAltMappingButton:SetScript('OnClick', function()
        if GRM_Alts == nil then
            ns.print('GRM data not accessible')
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

    panel.synchroniseEpCheck:SetChecked(ns.cfg.syncAltEp)
    panel.synchroniseEpCheck:SetScript('OnClick', function()
        ns.cfg.syncAltEp = panel.synchroniseEpCheck:GetChecked()
        ns.addon:modifiedLmSettings()
    end)

    panel.synchroniseGpCheck:SetChecked(ns.cfg.syncAltGp)
    panel.synchroniseGpCheck:SetScript('OnClick', function()
        ns.cfg.syncAltGp = panel.synchroniseGpCheck:GetChecked()
        ns.addon:modifiedLmSettings()
    end)

    self:createAltManagementTable()
end


function Config:createAltManagementTable()
    local parent = self.aamPanel.tableFrame

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
    local parent = self.aamPanel.tableFrame

    if parent == nil then
        return
    end

    local rows = {}
    for main, alts in pairs(ns.db.altData.mainAltMapping) do
        local altsWithoutMain = ns.Lib:deepcopy(alts)
        ns.Lib:remove(altsWithoutMain, main)

        if #altsWithoutMain > 0 then
            table.insert(rows, {main, alts})
        end
    end

    table.sort(rows, function(left, right)
        return left[1] < right[1]
    end)

    local i = 1
    for _, dataRow in ipairs(rows) do
        local main = dataRow[1]
        local alts = dataRow[2]

        local altsWithoutMain = ns.Lib:deepcopy(alts)
        ns.Lib:remove(altsWithoutMain, main)

        if #altsWithoutMain > 0 then
            local row = parent.contents.rows[i]

            if row == nil then
                row = self:addAltManagementRow(i)
                table.insert(parent.contents.rows, row)
            end

            row:Show()

            local altsStr = table.concat(altsWithoutMain, ', ')
            row.mainColumn:SetText(main)
            row.altsColumn:SetText(altsStr)

            i = i + 1
        end
    end

    for j = i, #parent.contents.rows do
        local row = parent.contents.rows[j]
        row:Hide()
    end
end


function Config:addAltManagementRow(index)
    local parent = self.aamPanel.tableFrame

    local rowHeight = 15
    local yOffset = (rowHeight + 3) * (index - 1)

    local row = CreateFrame('Frame', nil, parent.scrollChild)
    row:SetPoint('TOPLEFT', parent.scrollChild, 'TOPLEFT', 0, -yOffset)
    row:SetWidth(parent.header:GetWidth())
    row:SetHeight(rowHeight)

    row.mainColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.mainColumn:SetPoint('LEFT', row, 'LEFT')

    row.altsColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
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


function Config:clearData()
    ns.ConfirmWindow:show('Are you sure you want to clear all data?\nWARNING: this is irreversible!', ns.addon.clearData)
end


-------------------------
-- OPTION GETTERS/SETTERS
-------------------------
function Config:getLmMode(info)
    if not ns.addon.isOfficer then
        return false
    end

    return ns.cfg.lmMode
end

function Config:setLmMode(info, input)
    if not ns.addon.isOfficer then
        ns.cfg.lmMode = false
        return
    end

    ns.cfg.lmMode = input
    ns.addon:modifiedLmSettings()

    ns.MainWindow:refresh()
end

function Config:getDefaultDecay(info)
    return tostring(ns.cfg.defaultDecay)
end

function Config:setDefaultDecay(info, input)
    ns.cfg.defaultDecay = input
    ns.addon:modifiedLmSettings()
end

function Config:getRollDuration(info)
    return tostring(ns.cfg.rollDuration)
end

function Config:setRollDuration(info, input)
    ns.cfg.rollDuration = input
end

function Config:getCloseOnAward(info)
    return ns.cfg.closeOnAward
end

function Config:setCloseOnAward(info, input)
    ns.cfg.closeOnAward = input
end

function Config:getShowMinimapButton(info)
    return not ns.cfg.minimap.hide
end

function Config:setShowMinimapButton(info, input)
    ns.cfg.minimap.hide = not input

    if ns.cfg.minimap.hide then
        ns.addon.ldbi:Hide(addonName)
    else
        ns.addon.ldbi:Show(addonName)
    end
end

function Config:getBaseGp(info)
    return tostring(ns.cfg.gpBase)
end

function Config:setBaseGp(info, input)
    ns.cfg.gpBase = tonumber(input)
    ns.addon:modifiedLmSettings()
    ns.addon:fixGp()
end

function Config:setDebugMode(info, input)
    ns.cfg.debugMode = input
end

function Config:getDebugMode(info)
    return ns.cfg.debugMode
end


function Config:getLmModeDisabled()
    return not ns.addon.isOfficer
end

function Config:getDefaultDecayDisabled()
    return not ns.cfg.lmMode
end

function Config:getGpManagementDisabled()
    return not ns.cfg.lmMode
end
