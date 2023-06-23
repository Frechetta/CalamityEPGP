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

-- local UIConfig = CreateFrame('Frame', 'CalamityEPGP_Frame', UIParent, 'BasicFrameTemplateWithInset')
-- UIConfig:SetSize(300, 300)
-- UIConfig:SetPoint('Center', UIParent, 'Center')

-- UIConfig.title = UIConfig:CreateFontString(nil, 'OVERLAY')
-- UIConfig.title:SetFontObject('GameFontHighlight')
-- UIConfig.title:SetPoint('LEFT', UIConfig.TitleBg, 'LEFT', 5, 0)
-- UIConfig.title:SetText('CalamityEPGP Options')

-- UIConfig.saveButton = CreateFrame('Button', nil, UIConfig, 'GameMenuButtonTemplate')
-- UIConfig.saveButton:SetPoint('CENTER', UIConfig, 'TOP', 0, -70)
-- UIConfig.saveButton:SetSize(140, 40)
-- UIConfig.saveButton:SetText('Save')
-- UIConfig.saveButton:SetNormalFontObject('GameFontNormalLarge')
-- UIConfig.saveButton:SetHighlightFontObject('GameFontHighlightLarge')

-- UIConfig.resetButton = CreateFrame('Button', nil, UIConfig, 'GameMenuButtonTemplate')
-- UIConfig.resetButton:SetPoint('TOP', UIConfig.saveButton, 'BOTTOM', 0, -10)
-- UIConfig.resetButton:SetSize(140, 40)
-- UIConfig.resetButton:SetText('Reset')
-- UIConfig.resetButton:SetNormalFontObject('GameFontNormalLarge')
-- UIConfig.resetButton:SetHighlightFontObject('GameFontHighlightLarge')

-- UIConfig.loadButton = CreateFrame('Button', nil, UIConfig, 'GameMenuButtonTemplate')
-- UIConfig.loadButton:SetPoint('TOP', UIConfig.resetButton, 'BOTTOM', 0, -10)
-- UIConfig.loadButton:SetSize(140, 40)
-- UIConfig.loadButton:SetText('Load')
-- UIConfig.loadButton:SetNormalFontObject('GameFontNormalLarge')
-- UIConfig.loadButton:SetHighlightFontObject('GameFontHighlightLarge')


function CalamityEPGP_OnLoad(self)
    -- SetPortraitToTexture(self.portrait, "Interface\\Icons\\INV_Misc_EngGizmos_30")

    print('CalamityEPGP loaded')
end


Addon = LibStub('AceAddon-3.0'):NewAddon('CalamityEPGP', 'AceConsole-3.0')
AceGUI = LibStub('AceGUI-3.0')


function Addon:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New('CalamityEPGPDB')
    guildName, _, _ = GetGuildInfo(UnitName('player'))

    if (self.db.profile.standings == nil) then
        self.db.profile.standings = {}
    end

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

    Addon:Print('CalamityEPGP loaded')

    self.ShowWindowHandler(self)
end


function Addon:OnEnable()
    -- Called when the addon is enabled
end


function Addon:OnDisable()
    -- Called when the addon is disabled
end


function Addon:SlashCommandHandler(input)
    if (input == 'show') then
        self.ShowWindowHandler(self)
    elseif (input == 'cfg') then
        Addon:Print('show options')
    else
        Addon:Print('CalamityEPGP Usage')
        Addon:Print('show - Open the CalamityEPGP window')
        Addon:Print('cfg - Opens the configuration menu for CalamityEPGP')
    end
end


Addon:RegisterChatCommand('ce', 'SlashCommandHandler')

function Addon:ShowWindowHandler()
    local textStore

    local frame = AceGUI:Create('Frame')
    frame:SetTitle('Example Frame')
    frame:SetStatusText('AceGUI-3.0 Example Container Frame')
    frame:SetCallback('OnClose', function(widget) AceGUI:Release(widget) end)
    frame:SetLayout('Flow')

    local editbox = AceGUI:Create('EditBox')
    editbox:SetLabel('Insert text:')
    editbox:SetWidth(200)
    editbox:SetCallback('OnEnterPressed', function(widget, event, text) textStore = text end)
    frame:AddChild(editbox)

    local button = AceGUI:Create('Button')
    button:SetText('Click Me!')
    button:SetWidth(200)
    button:SetCallback('OnClick', function() print(textStore) end)
    frame:AddChild(button)

    local standingsContainer = AceGUI:Create('SimpleGroup')
    standingsContainer:SetFullWidth(true)
    standingsContainer:SetFullHeight(true)
    standingsContainer:SetLayout('Fill')
    frame:AddChild(standingsContainer)

    local standingsTable = AceGUI:Create('ScrollFrame')
    standingsTable:SetLayout('Flow')
    standingsContainer:AddChild(standingsTable)

    local columns = 9
    local frameWidth = standingsTable.frame.width
    local columnWidth = frameWidth / columns

    for character in pairs(self.db.profile.standings) do
        local row = AceGUI:Create('SimpleGroup')
        row:SetFullWidth(true)
        row:SetLayout('Flow')
        standingsTable:AddChild(row)

        local nameDash = string.find(character, '-')
        local name = string.sub(character, 0, nameDash - 1)
        local charData = self.db.profile.standings[character]

        local labelChar = AceGUI:Create('Label')
        labelChar:SetText(name)
        labelChar:SetWidth(columnWidth)
        row:AddChild(labelChar)

        local labelLevel = AceGUI:Create('Label')
        labelLevel:SetText(charData.level)
        labelLevel:SetWidth(columnWidth)
        row:AddChild(labelLevel)

        local labelClass = AceGUI:Create('Label')
        labelClass:SetText(charData.class)
        labelClass:SetWidth(columnWidth)
        row:AddChild(labelClass)

        local labelInGuild = AceGUI:Create('Label')
        labelInGuild:SetText(tostring(charData.inGuild))
        labelInGuild:SetWidth(columnWidth)
        row:AddChild(labelInGuild)

        local labelGuildRank = AceGUI:Create('Label')
        labelGuildRank:SetText(charData.rank)
        labelGuildRank:SetWidth(columnWidth)
        row:AddChild(labelGuildRank)

        local labelEp = AceGUI:Create('Label')
        labelEp:SetText(charData.ep)
        labelEp:SetWidth(columnWidth)
        row:AddChild(labelEp)

        local labelGp = AceGUI:Create('Label')
        labelGp:SetText(charData.gp)
        labelGp:SetWidth(columnWidth)
        row:AddChild(labelGp)

        local labelPr = AceGUI:Create('Label')
        labelPr:SetText(charData.ep / charData.gp)
        labelPr:SetWidth(columnWidth)
        row:AddChild(labelPr)
    end
end
