local addonName, ns = ...  -- Namespace

List = ns.List
Set = ns.Set

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
    },
    mains = Set:new(),
    alts = Set:new(),
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

    panel.tableFrame = CreateFrame('Frame', panel:GetName() .. 'TableFrame', panel)
    panel.tableFrame:SetPoint('TOPLEFT', panel.importAltMappingButton, 'BOTTOMLEFT', 5, -20)
    panel.tableFrame:SetPoint('BOTTOMRIGHT', panel.synchroniseEpCheck, 'TOPRIGHT', 0, 15)

    panel.importAltMappingButton:SetScript('OnClick', function()
        if GRM_Alts == nil then
            ns.print('GRM data not accessible')
            return
        end

        for _, altData in pairs(GRM_Alts[ns.guild]) do
            if #altData.main > 0 then
                local main = ns.addon:getCharName(altData.main)

                if ns.db.altData.mainAltMapping[main] == nil then
                    ns.db.altData.mainAltMapping[main] = {}
                end

                for _, alt in ipairs(altData) do
                    local name = alt.name
                    if name ~= nil then
                        name = ns.addon:getCharName(name)

                        if not ns.Lib:contains(ns.db.altData.mainAltMapping[main], name) then
                            tinsert(ns.db.altData.mainAltMapping[main], name)
                        end
                    end
                end
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

    local nameColumn = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    nameColumn:SetText('Name')
    nameColumn:SetTextColor(1, 1, 0)
    nameColumn:SetPoint('LEFT', parent.header, 'LEFT')

    local mainAltColumn = parent.header:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    mainAltColumn:SetText('Main/Alt')
    -- mainAltColumn:SetJustifyH('RIGHT')
    mainAltColumn:SetTextColor(1, 1, 0)
    mainAltColumn:SetPoint('RIGHT', parent.header, 'RIGHT')

    -- Initialize the content
    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetAllPoints(parent.scrollChild)

    parent.contents.rows = List:new()

    parent.rowHighlight = CreateFrame('Frame', nil, parent)
    local highlightTexture = parent.rowHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    parent.rowHighlight:Hide()
end


function Config:setAltManagementData()
    local parent = self.aamPanel.tableFrame

    if parent == nil then
        return
    end

    local rows = List:new()
    for _, playerData in pairs(ns.db.standings) do
        local player = playerData.name
        local playerColored = ns.Lib:getColoredByClass(player)

        local main_alt = 'Unknown'
        if self.mains:contains(player) then
            main_alt = 'Main'
        end
        if self.alts:contains(player) then
            main_alt = 'Alt'
        end

        rows:bininsert({player, playerColored, main_alt}, function(left, right)
            return left[1] < right[1]
        end)
    end

    for i, rowData in rows:enumerate() do
        local player = rowData[1]
        local playerColored = rowData[2]
        local main_alt = rowData[3]

        local row = parent.contents.rows:get(i)

        if row == nil then
            row = self:addAltManagementRow(i)
            parent.contents.rows:append(row)
        end

        row.nameColumn:SetText(playerColored)
        row.mainAltColumn:SetText(main_alt)

        if main_alt == 'Unknown' then
            row.mainAltColumn:SetTextColor(1, 0, 0)
        else
            row.mainAltColumn:SetTextColor(0, 1, 0)
        end

        row.player = player

        row:Show()
    end

    for i = rows:len() + 1, parent.contents.rows:len() do
        local row = parent.contents.rows:get(i)
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

    row.nameColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.nameColumn:SetPoint('LEFT', row, 'LEFT')

    row.mainAltColumn = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
    row.mainAltColumn:SetPoint('RIGHT', row, 'RIGHT')
    -- row.mainAltColumn:SetJustifyH('RIGHT')

    row:EnableMouse()

    row:SetScript('OnEnter', function()
        if parent.altsWindow == nil
                or not parent.altsWindow:IsShown()
                or not parent.altsWindow:IsMouseOver()
                or parent.editPlayerWindow == nil
                or not parent.editPlayerWindow:IsShown()
                or not parent.editPlayerWindow:IsMouseOver() then
            parent.rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
            parent.rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
            parent.rowHighlight:Show()
        end
    end)

    row:SetScript('OnLeave', function()
        parent.rowHighlight:Hide()
    end)

    row:SetScript('OnMouseUp', function(_, button)
        if button == 'LeftButton' then
            Config:showAltsWindow(row.player)
        elseif button == 'RightButton' then
            Config:showEditPlayerWindow(row.player)
        end
    end)

    return row
end


function Config:showEditPlayerWindow(player)
    if not ns.cfg.lmMode then
        return
    end

    local parent = self.aamPanel.tableFrame

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
            Config.aamPanel.tableFrame.rowHighlight:Hide()
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

    editPlayerWindow.title:SetText(ns.Lib:getColoredByClass(player))

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
        editPlayerWindow:Hide()
        Config:setAltMainMapping()
        Config:setAltManagementData()
    end)

    editPlayerWindow:Show()
end


function Config:showAltsWindow(player)
    local parent = self.aamPanel.tableFrame

    local altsWindow = parent.altsWindow

    if altsWindow == nil then
        altsWindow = CreateFrame('Frame', self.aamPanel:GetName() .. '_AltsWindow', parent, 'TooltipBorderedFrameTemplate')
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
            Config.aamPanel.tableFrame.rowHighlight:Hide()
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
    altsWindow.title:SetText(ns.Lib:getColoredByClass(player, title))

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

                local text = ns.Lib:getColoredByClass(alt)

                if alt == main then
                    text = text .. '\n' .. ns.Lib:getColoredText('(main)', CreateColor(1, 0, 0))
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
    altsWindow:SetHeight(7 + altsWindow.title:GetHeight() + 5 + cellsFrameHeight + 5 + altsWindow.addAltButton:GetHeight() + 5)

    altsWindow:Show()
end


function Config:showAltEditWindow(selectedPlayer, clickedPlayer, clickedFrame)
    local parent = self.aamPanel.tableFrame.altsWindow

    local altEditWindow = parent.altEditWindow

    if altEditWindow == nil then
        altEditWindow = CreateFrame('Frame', self.aamPanel:GetName() .. '_AltEditWindow', parent, 'TooltipBorderedFrameTemplate')
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
            ns.Lib:remove(ns.db.altData.mainAltMapping[main], clickedPlayer)
        end

        altEditWindow:Hide()
        self:setAltMainMapping()
        self:setAltManagementData()

        Config:showAltsWindow(selectedPlayer)
    end)

    altEditWindow.title:SetText(clickedPlayer)

    local height = 7 + altEditWindow.title:GetHeight() + 5 + altEditWindow.cancelButton:GetHeight() + 1 + altEditWindow.removeButton:GetHeight() + 1 + altEditWindow.setAsButton:GetHeight() + 5
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
    local parent = self.aamPanel.tableFrame.altsWindow

    local addAltWindow = parent.addAltWindow

    if addAltWindow == nil then
        addAltWindow = CreateFrame('Frame', self.aamPanel:GetName() .. '_AddAltWindow', parent, 'TooltipBorderedFrameTemplate')
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
        for _, playerData in pairs(ns.db.standings) do
            allPlayers:add(playerData.name)
        end

        if alt == nil or #alt == 0 or not allPlayers:contains(alt) then
            return
        end

        if Config.mains:contains(player) then
            local alts = ns.db.altData.mainAltMapping[player]
            if not ns.Lib:contains(alts, alt) then
                tinsert(alts, alt)
            end

            local oldMain = ns.db.altData.altMainMapping[alt]
            if oldMain ~= nil then
                ns.Lib:remove(ns.db.altData.mainAltMapping[oldMain], alt)
            end
        elseif Config.alts:contains(player) then
            local main = ns.db.altData.altMainMapping[player]
            local alts = ns.db.altData.mainAltMapping[main]
            if not ns.Lib:contains(alts, alt) then
                tinsert(alts, alt)
            end
        else
            ns.db.altData.mainAltMapping[player] = {}
            local alts = ns.db.altData.mainAltMapping[player]
            tinsert(alts, alt)
            tinsert(alts, player)
        end

        self:setAltMainMapping()
        self:setAltManagementData()

        addAltWindow:Hide()
        Config:showAltsWindow(player)
    end)

    addAltWindow:Show()
end


function Config:handleAltEditBoxChange()
    local parent = self.aamPanel.tableFrame.altsWindow.addAltWindow

    local text = parent.altEditBox:GetText()

    if #text > 0 then
        local players = self:filterPlayers(text)
        self:fillPlayers(players)
    end
end


function Config:filterPlayers(text)
    local playerRows = self.aamPanel.tableFrame.contents.rows

    local players = List:new()

    for row in playerRows:iter() do
        local player = row.player

        if row.mainAltColumn:GetText() == 'Unknown' and string.find(string.lower(player), string.lower(text)) then
            local playerText = ns.Lib:getColoredByClass(player)
            players:bininsert({player, playerText}, function(left, right) return left[1] < right[1] end)
        end
    end

    return players
end


function Config:fillPlayers(players)
    local rowHeight = 15

    local parent = self.aamPanel.tableFrame.altsWindow.addAltWindow
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

        if not ns.Lib:contains(alts, main) then
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


function Config:clearData()
    ns.ConfirmWindow:show('Are you sure you want to clear all data?\nWARNING: this is irreversible!', ns.addon.clearData)
end


-------------------------
-- OPTION GETTERS/SETTERS
-------------------------
function Config:getLmMode(info)
    if not ns.addon.isOfficer then
        ns.cfg.lmMode = false
    end

    return ns.cfg.lmMode
end

function Config:setLmMode(info, input)
    if not ns.addon.isOfficer then
        ns.cfg.lmMode = false
        return
    end

    ns.cfg.lmMode = input

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
