local addonName, ns = ...  -- Namespace

local List = ns.List
local Set = ns.Set

local Config = {
    initialized = false,
    altManagementMenuInitialized = false,
    defaults = {
        lmMode = false,
        defaultDecayEp = 10,
        defaultDecayGp = 10,
        syncAltEp = false,
        syncAltGp = true,
        rollDuration = 17,
        closeOnAward = true,
        gpBase = ns.values.gpDefaults.base,
        gpSlotMods = ns.values.gpDefaults.slotModifiers,
        encounterEp = {},
        minimap = {
            hide = false,
        },
        debugMode = false,
    },
    mains = Set:new(),
    alts = Set:new(),
}

ns.Config = Config

-- add default encounter EP to defaults

for encounterId, encounterData in pairs(ns.values.encounters) do
    local ep = encounterData.defaultEp
    Config.defaults.encounterEp[encounterId] = ep
end

Config.aceConfig = LibStub("AceConfig-3.0")
Config.aceConfigDialog = LibStub("AceConfigDialog-3.0")


function Config.cfgTableIndex(table, key)
    local dbTable = ns.Lib.findTableValue(ns.db.cfg, table._path)
    local defaultsTable = ns.Lib.findTableValue(Config.defaults, table._path)

    if dbTable ~= nil then
        local dbValue = rawget(dbTable, key)
        if dbValue ~= nil then
            return dbValue
        end
    end

    if defaultsTable ~= nil then
        local defaultValue = defaultsTable[key]
        if defaultValue ~= nil then
            return defaultValue
        end
    end

    return nil
end

function Config.cfgTableNewIndex(table, key, value)
    local dbTable = ns.db.cfg
    if table._path ~= '.' then
        for _, key in ipairs(ns.Lib.split(table._path, '.')) do
            if dbTable[key] == nil then
                dbTable[key] = {}
            end

            dbTable = dbTable[key]
        end
    end

    dbTable[key] = value
end

function Config.cfgTablePairs(t)
    local dbTable = ns.Lib.findTableValue(ns.db.cfg, t._path)
    local defaultsTable = ns.Lib.findTableValue(Config.defaults, t._path)
    return function(t, k)
        local v
        repeat
            k, v = next(t, k)
        until k == nil or k ~= '_path'

        if dbTable ~= nil then
            v = dbTable[k]
        end

        return k, v
    end, defaultsTable, nil
end


function Config:setupCfg(cfgTable, defaultsTable, path)
    path = path or '.'

    rawset(cfgTable, '_path', path)

    setmetatable(cfgTable, {
        __index = self.cfgTableIndex,
        __newindex = self.cfgTableNewIndex,
        __pairs = self.cfgTablePairs,
    })

    for key, val in pairs(defaultsTable) do
        if type(val) == 'table' then
            if rawget(cfgTable, key) == nil then
                rawset(cfgTable, key, {})
            end

            local newPath
            if path == '.' then
                newPath = key
            else
                newPath = path .. '.' .. key
            end

            self:setupCfg(rawget(cfgTable, key), val, newPath)
        end
    end
end


function Config:init()
    if self.initialized then
        return
    end

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
                defaultDecayEp = {
                    type = 'input',
                    name = 'Default decay % (EP)',
                    width = 'half',
                    pattern = '%d+',
                    order = 3,
                    get = 'getDefaultDecayEp',
                    set = 'setDefaultDecayEp',
                    disabled = 'getDefaultDecayEpDisabled',
                },
                defaultDecayGp = {
                    type = 'input',
                    name = 'Default decay % (GP)',
                    width = 'half',
                    pattern = '%d+',
                    order = 4,
                    get = 'getDefaultDecayGp',
                    set = 'setDefaultDecayGp',
                    disabled = 'getDefaultDecayGpDisabled',
                },
                linebreak1 = {
                    type = 'description',
                    name = '',
                    order = 5,
                },
                clearData = {
                    type = 'execute',
                    name = 'Clear all data',
                    order = 6,
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
                    order = 1,
                    get = 'getDebugMode',
                    set = 'setDebugMode',
                },
                clearDataForAll = {
                    type = 'execute',
                    name = 'Clear all data for everyone',
                    order = 2,
                    func = 'clearDataForAll',
                    disabled = 'getClearDataForAllDisabled',
                },
            }
        }
    }

    -- create options menus
    self:addOptionsMenu(addonName, menus.root)
    self:initAltManagementMenu()
    self:addOptionsMenu(addonName .. '_LootDistribution', menus.lootDistribution, addonName)
    self:addOptionsMenu(addonName .. '_GpManagement', menus.gpManagement, addonName)
    self:addOptionsMenu(addonName .. '_Advanced', menus.advanced, addonName)

    self.initialized = true
end


function Config:addOptionsMenu(ident, options, parent)
    self.aceConfig:RegisterOptionsTable(ident, options)
    self.aceConfigDialog:AddToBlizOptions(ident, options.name, parent)
end


function Config:initAltManagementMenu()
    self.aamPanel = CreateFrame('FRAME', addonName .. '_AltManagement')
    self.aamPanel.name = 'Alt Management'
    self.aamPanel.parent = addonName
    self.aamPanel.refresh = function() self:refreshAltManagementMenu() end

    local category = Settings.GetCategory(addonName)
    Settings.RegisterCanvasLayoutSubcategory(category, self.aamPanel, self.aamPanel.name)
end


function Config:refreshAltManagementMenu()
    if not self.altManagementMenuInitialized and self.aamPanel:GetWidth() ~= 0 then
        self:createAltManagementMenu()
        self.altManagementMenuInitialized = true
    end

    self:setAltMainMapping()
    self:setAltManagementData()

    if self.altManagementMenuInitialized then
        if ns.cfg.lmMode then
            self.aamPanel.importAltMappingButton:Enable()
            self.aamPanel.synchroniseEpCheck:Enable()
            self.aamPanel.synchroniseGpCheck:Enable()
            -- self.aamPanel.mainEditBox:Enable()
            -- self.aamPanel.altEditBox:Enable()
        else
            self.aamPanel.importAltMappingButton:Disable()
            self.aamPanel.synchroniseEpCheck:Disable()
            self.aamPanel.synchroniseGpCheck:Disable()
            -- self.aamPanel.mainEditBox:Disable()
            -- self.aamPanel.altEditBox:Disable()
        end
    end
end


function Config:createAltManagementMenu()
    local panel = self.aamPanel

    panel.importAltMappingButton = CreateFrame('Button', nil, panel, 'GameMenuButtonTemplate')
    panel.importAltMappingButton:SetText('Import from GRM')
    panel.importAltMappingButton:SetPoint('TOPLEFT', 10, -15)
    panel.importAltMappingButton:SetHeight(25)

    panel.synchroniseGpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    panel.synchroniseGpCheck:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -10, 10)

    panel.synchroniseGpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    panel.synchroniseGpLabel:SetText('Synchronise Alt GP')
    panel.synchroniseGpLabel:SetTextColor(1, 1, 0)
    panel.synchroniseGpLabel:SetPoint('RIGHT', panel.synchroniseGpCheck, 'LEFT', -5, 0)

    panel.synchroniseEpLabel = panel:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    panel.synchroniseEpLabel:SetText('Synchronise Alt EP')
    panel.synchroniseEpLabel:SetTextColor(1, 1, 0)
    panel.synchroniseEpLabel:SetPoint('BOTTOM', panel.synchroniseGpLabel, 'TOP', 0, 15)

    panel.synchroniseEpCheck = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    panel.synchroniseEpCheck:SetPoint('LEFT', panel.synchroniseEpLabel, 'RIGHT', 5, 0)

    local highlightHoverCondition = function()
        local parent = panel.tableFrame

        return parent.altsWindow == nil
            or not parent.altsWindow:IsShown()
            or not parent.altsWindow:IsMouseOver()
            or parent.editPlayerWindow == nil
            or not parent.editPlayerWindow:IsShown()
            or not parent.editPlayerWindow:IsMouseOver()
    end

    panel.tableFrame = ns.Table:new(panel, nil, true, highlightHoverCondition, nil, nil, self.handleRowClick)
    panel.tableFrame:SetPoint('TOPLEFT', panel.importAltMappingButton, 'BOTTOMLEFT', 5, -20)
    panel.tableFrame:SetPoint('BOTTOMRIGHT', panel.synchroniseEpCheck, 'TOPRIGHT', 0, 15)

    panel.importAltMappingButton:SetScript('OnClick', function()
        if GRM_Alts == nil then
            ns.print('GRM data not accessible')
            return
        end

        for _, altData in pairs(GRM_Alts[ns.guild]) do
            if #altData.main > 0 then
                local main = ns.addon.getCharName(altData.main)

                if ns.db.altData.mainAltMapping[main] == nil then
                    ns.db.altData.mainAltMapping[main] = {}
                end

                for _, alt in ipairs(altData) do
                    local name = alt.name
                    if name ~= nil then
                        name = ns.addon.getCharName(name)

                        if not ns.Lib.contains(ns.db.altData.mainAltMapping[main], name) then
                            tinsert(ns.db.altData.mainAltMapping[main], name)
                        end
                    end
                end
            end
        end

        ns.addon.modifiedLmSettings()

        self:setAltMainMapping()
        self:setAltManagementData()
    end)

    panel.synchroniseEpCheck:SetChecked(ns.cfg.syncAltEp)
    panel.synchroniseEpCheck:SetScript('OnClick', function()
        ns.cfg.syncAltEp = panel.synchroniseEpCheck:GetChecked()
        ns.addon.modifiedLmSettings()
        ns.addon:computeStandings()
    end)

    panel.synchroniseGpCheck:SetChecked(ns.cfg.syncAltGp)
    panel.synchroniseGpCheck:SetScript('OnClick', function()
        ns.cfg.syncAltGp = panel.synchroniseGpCheck:GetChecked()
        ns.addon.modifiedLmSettings()
        ns.addon:computeStandings()
    end)
end


function Config:setAltManagementData()
    if self.aamPanel == nil then
        return
    end

    local parent = self.aamPanel.tableFrame

    if parent == nil then
        return
    end

    local data = {
        header = {
            {'Main', 'LEFT'},
            {'Alt', 'RIGHT'},
        },
        rows = {}
    }

    for guid in ns.standings:iter() do
        local playerData = ns.db.knownPlayers[guid]

        if playerData ~= nil then
            local player = playerData.name

            local main_alt = 'Unknown'
            if self.mains:contains(player) then
                main_alt = 'Main'
            end
            if self.alts:contains(player) then
                main_alt = 'Alt'
            end

            local row = {
                player,
                main_alt,
                {color = RAID_CLASS_COLORS[playerData.classFilename]}
            }

            ns.Lib.bininsert(data.rows, row, function(left, right)
                return left[1] < right[1]
            end)
        end
    end

    self.data = data

    parent:setData(data)
end


function Config.handleRowClick(button, row)
    if button == 'LeftButton' then
        Config:showAltsWindow(row.data[1])
    elseif button == 'RightButton' then
        Config:showEditPlayerWindow(row.data[1])
    end
end


function Config:showEditPlayerWindow(player)
    if not ns.cfg.lmMode then
        return
    end

    local parent = self.aamPanel.tableFrame._mainFrame

    local editPlayerWindow = parent.editPlayerWindow

    if editPlayerWindow == nil then
        editPlayerWindow = CreateFrame('Frame', self.aamPanel:GetName() .. '_EditPlayerWindow', parent)
        editPlayerWindow.texture = editPlayerWindow:CreateTexture(nil, 'BACKGROUND')
        editPlayerWindow.texture:SetAllPoints()
        editPlayerWindow.texture:SetColorTexture(0, 0, 0, 0.8)
        editPlayerWindow:SetSize(90, 77)
        editPlayerWindow:SetFrameStrata('DIALOG')

        editPlayerWindow.title = editPlayerWindow:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        editPlayerWindow.title:SetPoint('TOP', editPlayerWindow, 'TOP', 0, -7)

        editPlayerWindow:EnableMouse()
        editPlayerWindow:SetScript('OnEnter', function()
            parent.contents.rowHighlight:Hide()
        end)

        editPlayerWindow.setButton = CreateFrame('Button', nil, editPlayerWindow, 'UIPanelButtonTemplate')
        editPlayerWindow.setButton:SetPoint('TOP', editPlayerWindow.title, 'BOTTOM', 0, -5)
        editPlayerWindow.setButton:SetWidth(70)

        editPlayerWindow.cancelButton = CreateFrame('Button', nil, editPlayerWindow, 'UIPanelButtonTemplate')
        editPlayerWindow.cancelButton:SetText('Cancel')
        editPlayerWindow.cancelButton:SetPoint('TOP', editPlayerWindow.setButton, 'BOTTOM', 0, -2)
        editPlayerWindow.cancelButton:SetWidth(70)
        editPlayerWindow.cancelButton:SetScript('OnClick', function()
            editPlayerWindow:Hide()
        end)

        parent.editPlayerWindow = editPlayerWindow
    end

    editPlayerWindow:SetPoint('CENTER', parent)

    editPlayerWindow.title:SetText(ns.Lib.getColoredByClass(player))

    local setButtonText
    local setButtonFunc

    if self.mains:contains(player) then
        setButtonText = 'Set as Alt'

        setButtonFunc = function()
            ns.db.altData.mainAltMapping[player] = nil
        end
    elseif self.alts:contains(player) then
        setButtonText = 'Set as Main'

        setButtonFunc = function()
            local main = ns.db.altData.altMainMapping[player]
            local alts = ns.db.altData.mainAltMapping[main]

            ns.db.altData.mainAltMapping[main] = nil
            ns.db.altData.mainAltMapping[player] = alts
        end
    else
        setButtonText = 'Set as Main'

        setButtonFunc = function()
            ns.db.altData.mainAltMapping[player] = {}
        end
    end

    editPlayerWindow.setButton:SetText(setButtonText)
    editPlayerWindow.setButton:SetScript('OnClick', function()
        setButtonFunc()
        ns.addon.modifiedLmSettings()
        editPlayerWindow:Hide()
        Config:setAltMainMapping()
        Config:setAltManagementData()
    end)

    editPlayerWindow:Show()
end


function Config:showAltsWindow(player)
    local parent = self.aamPanel.tableFrame._mainFrame

    local altsWindow = parent.altsWindow

    if altsWindow == nil then
        altsWindow = CreateFrame(
            'Frame',
            self.aamPanel:GetName() .. '_AltsWindow',
            parent,
            'TooltipBorderedFrameTemplate'
        )
        altsWindow:SetWidth(200)
        altsWindow:SetFrameStrata('DIALOG')

        altsWindow.closeButton = CreateFrame('Button', nil, altsWindow, 'UIPanelCloseButton')
        altsWindow.closeButton:SetPoint('TOPRIGHT', altsWindow, 'TOPRIGHT', 2, 2)
        altsWindow.closeButton:SetScript('OnClick', function()
            altsWindow:Hide()
        end)

        altsWindow.title = altsWindow:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        altsWindow.title:SetPoint('TOP', altsWindow, 'TOP', 0, -7)

        altsWindow:EnableMouse()
        altsWindow:SetScript('OnEnter', function()
            Config.aamPanel.tableFrame._mainFrame.contents.rowHighlight:Hide()
        end)

        altsWindow.cellsFrame = CreateFrame('Frame', nil, altsWindow)
        altsWindow.cellsFrame:SetPoint('TOP', altsWindow.title, 'BOTTOM', 0, -5)
        altsWindow.cellsFrame:SetWidth(altsWindow:GetWidth())

        altsWindow.addAltButton = CreateFrame('Button', nil, altsWindow, 'UIPanelButtonTemplate')
        altsWindow.addAltButton:SetText('Add alt')
        altsWindow.addAltButton:SetPoint('BOTTOM', altsWindow, 'BOTTOM', 0, 5)
        altsWindow.addAltButton:SetSize(60, 25)

        altsWindow.cells = List:new()

        tinsert(UISpecialFrames, altsWindow:GetName())

        parent.altsWindow = altsWindow
    end

    altsWindow.addAltButton:SetScript('OnClick', function()
        Config:showAltSelector(player)
    end)

    if ns.cfg.lmMode then
        altsWindow.addAltButton:Enable()
    else
        altsWindow.addAltButton:Disable()
    end

    altsWindow:SetPoint('CENTER', parent)

    local title = player .. ' Alts'
    altsWindow.title:SetText(ns.Lib.getColoredByClass(player, title))

    for cell in altsWindow.cells:iter() do
        cell:Hide()
    end

    local i = 1
    local main = ns.db.altData.altMainMapping[player]
    local alts = ns.db.altData.mainAltMapping[main]

    local rowHeight = 25

    if alts ~= nil then
        table.sort(alts)

        for _, alt in ipairs(alts) do
            if alt ~= player then
                local cell = altsWindow.cells:get(i)

                if cell == nil then
                    cell = CreateFrame('Frame', nil, altsWindow.cellsFrame)
                    cell:SetHeight(rowHeight)

                    cell.text = cell:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
                    cell.text:SetAllPoints()
                    cell.text:SetWordWrap(true)
                    cell.text:SetJustifyH('CENTER')

                    local row = math.floor((i - 1) / 2)
                    local yOffset = row * rowHeight

                    cell:SetPoint('TOP', altsWindow.cellsFrame, 'TOP', 0, -yOffset)

                    if (i - 1) % 2 == 0 then
                        cell:SetPoint('LEFT', altsWindow.cellsFrame)
                        cell:SetPoint('RIGHT', altsWindow.cellsFrame, 'CENTER')
                    else
                        cell:SetPoint('RIGHT', altsWindow.cellsFrame)
                        cell:SetPoint('LEFT', altsWindow.cellsFrame, 'CENTER')
                    end

                    cell:EnableMouse()

                    altsWindow.cells:append(cell)
                end

                if ns.cfg.lmMode then
                    cell:SetScript('OnMouseUp', function(_, button)
                        if button == 'RightButton' then
                            Config:showAltEditWindow(player, alt, cell)
                        end
                    end)
                end

                local text = ns.Lib.getColoredByClass(alt)

                if alt == main then
                    text = text .. '\n' .. ns.Lib.getColoredText('(main)', CreateColor(1, 0, 0))
                end

                cell.text:SetText(text)
                cell:Show()

                i = i + 1
            end
        end
    end

    local numRows = math.floor((i - 1) / 2)
    local cellsFrameHeight = numRows * rowHeight
    local minHeight = rowHeight * 3

    if cellsFrameHeight < minHeight then
        cellsFrameHeight = minHeight
    end

    altsWindow.cellsFrame:SetHeight(cellsFrameHeight)
    altsWindow:SetHeight(
          7 + altsWindow.title:GetHeight()
        + 5 + cellsFrameHeight
        + 5 + altsWindow.addAltButton:GetHeight()
        + 5
    )

    altsWindow:Show()
end


function Config:showAltEditWindow(selectedPlayer, clickedPlayer, clickedFrame)
    local parent = self.aamPanel.tableFrame._mainFrame.altsWindow

    local altEditWindow = parent.altEditWindow

    if altEditWindow == nil then
        altEditWindow = CreateFrame(
            'Frame',
            self.aamPanel:GetName() .. '_AltEditWindow',
            parent,
            'TooltipBorderedFrameTemplate'
        )
        altEditWindow:SetWidth(80)
        altEditWindow:SetFrameStrata('DIALOG')
        altEditWindow:SetFrameLevel(5000)

        altEditWindow.title = altEditWindow:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
        altEditWindow.title:SetPoint('TOP', altEditWindow, 'TOP', 0, -7)

        altEditWindow.cancelButton = CreateFrame('Button', nil, altEditWindow, 'UIPanelButtonTemplate')
        altEditWindow.cancelButton:SetText('Cancel')
        altEditWindow.cancelButton:SetPoint('BOTTOM', altEditWindow, 'BOTTOM', 0, 5)
        altEditWindow.cancelButton:SetWidth(70)
        altEditWindow.cancelButton:SetScript('OnClick', function() altEditWindow:Hide() end)

        altEditWindow.removeButton = CreateFrame('Button', nil, altEditWindow, 'UIPanelButtonTemplate')
        altEditWindow.removeButton:SetText('Remove')
        altEditWindow.removeButton:SetPoint('BOTTOM', altEditWindow.cancelButton, 'TOP', 0, 1)
        altEditWindow.removeButton:SetWidth(70)

        altEditWindow.setAsButton = CreateFrame('Button', nil, altEditWindow, 'UIPanelButtonTemplate')
        altEditWindow.setAsButton:SetPoint('BOTTOM', altEditWindow.removeButton, 'TOP', 0, 1)
        altEditWindow.setAsButton:SetWidth(70)

        tinsert(UISpecialFrames, altEditWindow:GetName())

        parent.altEditWindow = altEditWindow
    end

    altEditWindow.setAsButton:SetScript('OnClick', function()
        if self.mains:contains(clickedPlayer) then
            -- set as alt
            ns.db.altData.mainAltMapping[clickedPlayer] = nil
        else
            -- set as main
            local main = ns.db.altData.altMainMapping[clickedPlayer]
            local alts = ns.db.altData.mainAltMapping[main]
            ns.db.altData.mainAltMapping[main] = nil
            ns.db.altData.mainAltMapping[clickedPlayer] = alts
        end

        ns.addon.modifiedLmSettings()

        altEditWindow:Hide()
        self:setAltMainMapping()
        self:setAltManagementData()

        Config:showAltsWindow(selectedPlayer)
    end)

    altEditWindow.removeButton:SetScript('OnClick', function()
        if self.mains:contains(clickedPlayer) then
            ns.db.altData.mainAltMapping[clickedPlayer] = nil
        else
            local main = ns.db.altData.altMainMapping[clickedPlayer]
            ns.Lib.remove(ns.db.altData.mainAltMapping[main], clickedPlayer)
        end

        ns.addon.modifiedLmSettings()

        altEditWindow:Hide()
        self:setAltMainMapping()
        self:setAltManagementData()

        Config:showAltsWindow(selectedPlayer)
    end)

    altEditWindow.title:SetText(clickedPlayer)

    local height = 7 + altEditWindow.title:GetHeight()
                 + 5 + altEditWindow.cancelButton:GetHeight()
                 + 1 + altEditWindow.removeButton:GetHeight()
                 + 1 + altEditWindow.setAsButton:GetHeight()
                 + 5
    altEditWindow:SetHeight(height)

    local mainAlt
    if self.mains:contains(clickedPlayer) then
        mainAlt = 'Alt'
    else
        mainAlt = 'Main'
    end
    altEditWindow.setAsButton:SetText('Set as ' .. mainAlt)

    altEditWindow:SetPoint('TOPRIGHT', clickedFrame, 'CENTER')

    altEditWindow:Show()
end


function Config:showAltSelector(player)
    local parent = self.aamPanel.tableFrame._mainFrame.altsWindow

    local addAltWindow = parent.addAltWindow

    if addAltWindow == nil then
        addAltWindow = CreateFrame(
            'Frame',
            self.aamPanel:GetName() .. '_AddAltWindow',
            parent,
            'TooltipBorderedFrameTemplate'
        )
        addAltWindow:SetSize(135, parent:GetHeight())
        addAltWindow:SetPoint('TOPLEFT', parent, 'TOPRIGHT', -3, 0)
        addAltWindow:SetFrameStrata('DIALOG')

        addAltWindow.altEditBox = CreateFrame('EditBox', nil, addAltWindow, 'InputBoxTemplate')
        addAltWindow.altEditBox:SetPoint('TOPLEFT', addAltWindow, 'TOPLEFT', 10, -5)
        addAltWindow.altEditBox:SetWidth(115)
        addAltWindow.altEditBox:SetHeight(25)
        addAltWindow.altEditBox:SetAutoFocus(false)
        addAltWindow.altEditBox:SetFocus()

        addAltWindow.playerList = CreateFrame('Frame', nil, addAltWindow)
        addAltWindow.playerList:SetPoint('TOPLEFT', addAltWindow.altEditBox, 'BOTTOMLEFT', 3, -5)
        addAltWindow.playerList:SetPoint('BOTTOM', addAltWindow, 'BOTTOM', 0, 5)
        addAltWindow.playerList:SetWidth(addAltWindow.altEditBox:GetWidth() - 6)

        addAltWindow.playerList.rowHighlight = CreateFrame('Frame', nil, addAltWindow.playerList)
        local highlightTexture = addAltWindow.playerList.rowHighlight:CreateTexture(nil, 'OVERLAY')
        highlightTexture:SetAllPoints()
        highlightTexture:SetColorTexture(1, 1, 0, 0.3)
        highlightTexture:SetBlendMode('ADD')
        addAltWindow.playerList.rowHighlight:Hide()

        addAltWindow.playerList.rows = List:new()

        addAltWindow.altEditBox:SetScript('OnTextChanged', function()
            Config:handleAltEditBoxChange()
        end)

        tinsert(UISpecialFrames, addAltWindow:GetName())

        parent.addAltWindow = addAltWindow
    end

    addAltWindow.selectedRow = 0

    addAltWindow.altEditBox:SetScript('OnKeyDown', function(_, key)
        if key == 'UP' or key == 'DOWN' then
            if key == 'UP' then
                addAltWindow.selectedRow = addAltWindow.selectedRow - 1
            elseif key == 'DOWN' then
                addAltWindow.selectedRow = addAltWindow.selectedRow + 1
            end

            local lastRow = 0
            for row in addAltWindow.playerList.rows:iter() do
                if row:IsShown() then
                    lastRow = lastRow + 1
                end
            end

            if addAltWindow.selectedRow < 1 then
                addAltWindow.selectedRow = 1
            elseif addAltWindow.selectedRow > lastRow then
                addAltWindow.selectedRow = lastRow
            end

            local row = addAltWindow.playerList.rows:get(addAltWindow.selectedRow)

            if row ~= nil then
                addAltWindow.playerList.rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT')
                addAltWindow.playerList.rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT')
                addAltWindow.playerList.rowHighlight:Show()

                addAltWindow.altEditBox:SetText(row.player)
            end
        end
    end)

    addAltWindow.altEditBox:SetScript('OnEnterPressed', function()
        local alt = addAltWindow.altEditBox:GetText()

        local allPlayers = Set:new()
        for guid in ns.standings:iter() do
            local playerData = ns.db.knownPlayers[guid]
            allPlayers:add(playerData.name)
        end

        if alt == nil or #alt == 0 or not allPlayers:contains(alt) then
            return
        end

        if Config.mains:contains(player) then
            local alts = ns.db.altData.mainAltMapping[player]
            if not ns.Lib.contains(alts, alt) then
                tinsert(alts, alt)
            end

            local oldMain = ns.db.altData.altMainMapping[alt]
            if oldMain ~= nil then
                ns.Lib.remove(ns.db.altData.mainAltMapping[oldMain], alt)
            end
        elseif Config.alts:contains(player) then
            local main = ns.db.altData.altMainMapping[player]
            local alts = ns.db.altData.mainAltMapping[main]
            if not ns.Lib.contains(alts, alt) then
                tinsert(alts, alt)
            end
        else
            ns.db.altData.mainAltMapping[player] = {}
            local alts = ns.db.altData.mainAltMapping[player]
            tinsert(alts, alt)
            tinsert(alts, player)
        end

        ns.addon.modifiedLmSettings()

        self:setAltMainMapping()
        self:setAltManagementData()

        addAltWindow:Hide()
        Config:showAltsWindow(player)
    end)

    addAltWindow:Show()
end


function Config:handleAltEditBoxChange()
    local parent = self.aamPanel.tableFrame._mainFrame.altsWindow.addAltWindow

    local text = parent.altEditBox:GetText()

    if #text > 0 then
        local players = self:filterPlayers(text)
        self:fillPlayers(players)
    end
end


function Config:filterPlayers(text)
    local rows = self.data.rows

    local players = List:new()

    for _, row in ipairs(rows) do
        local player = row[1]
        local mainAlt = row[2]

        if mainAlt == 'Unknown' and string.find(string.lower(player), string.lower(text)) then
            local playerText = ns.Lib.getColoredByClass(player)
            players:bininsert({player, playerText}, function(left, right) return left[1] < right[1] end)
        end
    end

    return players
end


function Config:fillPlayers(players)
    local rowHeight = 15

    local parent = self.aamPanel.tableFrame._mainFrame.altsWindow.addAltWindow
    local playerList = parent.playerList
    local rows = playerList.rows

    for i, playerData in players:enumerate() do
        local player = playerData[1]
        local playerText = playerData[2]

        local row = rows:get(i)

        if row == nil then
            row = CreateFrame('Frame', nil, playerList)
            row:SetSize(playerList:GetWidth(), rowHeight)
            row.text = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
            row.text:SetAllPoints()
            rows:append(row)
        end

        local yOffset = (i - 1) * rowHeight

        row.text:SetText(playerText)
        row:SetPoint('TOP', playerList, 'TOP', 0, -yOffset)
        row.player = player
        row:Show()

        -- Highlight
        row:EnableMouse()

        row:SetScript('OnEnter', function()
            playerList.rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT')
            playerList.rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT')
            playerList.rowHighlight:Show()
        end)

        row:SetScript('OnLeave', function()
            playerList.rowHighlight:Hide()
        end)

        row:SetScript('OnMouseUp', function(_, button)
            if button == 'LeftButton' then
                parent.altEditBox:SetText(player)
            end
        end)
    end

    for i = players:len() + 1, rows:len() do
        local row = rows:get(i)
        row:Hide()
    end
end


function Config:setAltMainMapping()
    ns.db.altData.altMainMapping = {}
    self.mains:clear()
    self.alts:clear()

    for main, alts in pairs(ns.db.altData.mainAltMapping) do
        self.mains:add(main)

        if not ns.Lib.contains(alts, main) then
            tinsert(alts, main)
        end

        for _, alt in ipairs(alts) do
            ns.db.altData.altMainMapping[alt] = main

            if alt ~= main then
                self.alts:add(alt)
            end
        end
    end
end


function Config.clearData()
    ns.ConfirmWindow:show(
        'Are you sure you want to clear all data?\nWARNING: this is irreversible!',
        function() ns.addon:clearData() end
    )
end


function Config.clearDataForAll()
    if not ns.Lib.isOfficer() then
        error('Non-officers cannot clear data for everyone')
        return
    end

    if not ns.cfg.lmMode then
        error('Cannot clear data for everyone when loot master mode is off')
        return
    end

    ns.ConfirmWindow:show(
        'Are you sure you want to clear all data for everyone?\nWARNING: this is irreversible!',
        function() ns.addon:clearDataForAll() end
    )
end


-------------------------
-- OPTION GETTERS/SETTERS
-------------------------
function Config:getLmMode(_)
    if not ns.Lib.isOfficer() then
        ns.cfg.lmMode = false
    end

    return ns.cfg.lmMode
end

function Config:setLmMode(_, input)
    if not ns.Lib.isOfficer() then
        ns.cfg.lmMode = false
        return
    end

    ns.cfg.lmMode = input

    ns.MainWindow:refresh()
end

function Config:getDefaultDecayEp(_)
    return tostring(ns.cfg.defaultDecayEp)
end

function Config:setDefaultDecayEp(_, input)
    ns.cfg.defaultDecayEp = tonumber(input)
    ns.addon.modifiedLmSettings()
end

function Config:getDefaultDecayGp(_)
    return tostring(ns.cfg.defaultDecayGp)
end

function Config:setDefaultDecayGp(_, input)
    ns.cfg.defaultDecayGp = tonumber(input)
    ns.addon.modifiedLmSettings()
end

function Config:getRollDuration(_)
    return tostring(ns.cfg.rollDuration)
end

function Config:setRollDuration(_, input)
    ns.cfg.rollDuration = input
end

function Config:getCloseOnAward(_)
    return ns.cfg.closeOnAward
end

function Config:setCloseOnAward(_, input)
    ns.cfg.closeOnAward = input
end

function Config:getShowMinimapButton(_)
    return not ns.cfg.minimap.hide
end

function Config:setShowMinimapButton(_, input)
    ns.cfg.minimap.hide = not input

    if ns.cfg.minimap.hide then
        ns.addon.ldbi:Hide(addonName)
    else
        ns.addon.ldbi:Show(addonName)
    end
end

function Config:getBaseGp(_)
    return tostring(ns.cfg.gpBase)
end

function Config:setBaseGp(_, input)
    ns.cfg.gpBase = tonumber(input)
    ns.addon.modifiedLmSettings()
    ns.addon:computeStandings()
end

function Config:setDebugMode(_, input)
    ns.cfg.debugMode = input
end

function Config:getDebugMode(_)
    return ns.cfg.debugMode
end


function Config:getLmModeDisabled()
    return not ns.Lib.isOfficer()
end

function Config:getDefaultDecayEpDisabled()
    return not ns.Lib.isOfficer() or not ns.cfg.lmMode
end

function Config:getDefaultDecayGpDisabled()
    return not ns.Lib.isOfficer() or not ns.cfg.lmMode
end

function Config:getGpManagementDisabled()
    return not ns.Lib.isOfficer() or not ns.cfg.lmMode
end

function Config:getClearDataForAllDisabled()
    return not ns.Lib.isOfficer() or not ns.cfg.lmMode
end
