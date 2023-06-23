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


function addon:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New(addonName)
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
        self:Print(addonName .. ' Usage')
        self:Print('show - Open the main window')
        self:Print('cfg - Opens the configuration menu')
    end
end


addon:RegisterChatCommand('ce', 'SlashCommandHandler')

function addon:ShowWindowHandler()
    -- CalamityEPGP_MainFrame:Show()
    -- local textStore

    -- local frame = AceGUI:Create('Frame')
    -- frame:SetTitle('Example Frame')
    -- frame:SetStatusText('AceGUI-3.0 Example Container Frame')
    -- frame:SetCallback('OnClose', function(widget) AceGUI:Release(widget) end)
    -- frame:SetLayout('Flow')

    -- local editbox = AceGUI:Create('EditBox')
    -- editbox:SetLabel('Insert text:')
    -- editbox:SetWidth(200)
    -- editbox:SetCallback('OnEnterPressed', function(widget, event, text) textStore = text end)
    -- frame:AddChild(editbox)

    -- local button = AceGUI:Create('Button')
    -- button:SetText('Click Me!')
    -- button:SetWidth(200)
    -- button:SetCallback('OnClick', function() print(textStore) end)
    -- frame:AddChild(button)

    -- local standingsContainer = AceGUI:Create('SimpleGroup')
    -- standingsContainer:SetFullWidth(true)
    -- standingsContainer:SetFullHeight(true)
    -- standingsContainer:SetLayout('Fill')
    -- frame:AddChild(standingsContainer)

    -- local standingsTable = AceGUI:Create('ScrollFrame')
    -- standingsTable:SetLayout('Flow')
    -- standingsContainer:AddChild(standingsTable)

    -- for character in pairs(self.db.profile.standings) do
    --     local group = AceGUI:Create('SimpleGroup')
    --     group:SetFullWidth(true)
    --     group:SetLayout('Flow')
    --     standingsTable:AddChild(group)

    --     local level = self.db.profile.standings[character].level

    --     local labelChar = AceGUI:Create('Label')
    --     labelChar:SetText(character)
    --     group:AddChild(labelChar)

    --     local labelLevel = AceGUI:Create('Label')
    --     labelLevel:SetText(level)
    --     group:AddChild(labelLevel)
    -- end
end
