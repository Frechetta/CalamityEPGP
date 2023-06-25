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
    ns.db = LibStub('AceDB-3.0'):New(addonName, dbDefaults)
    guildName, _, _ = GetGuildInfo(UnitName('player'))

    for i = 1, GetNumGuildMembers() do
        local name, rank, _, level, class, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        if (ns.db.profile.standings[name] == nil) then
            ns.db.profile.standings[name] = {
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
    ns.mainWindow = ns.mainWindow or ns.MainWindow:createWindow()
    ns.mainWindow:SetShown(true)
end

function addon:modifyEpgp(changes, percent)
    for _, change in ipairs(changes) do
        local charFullName = change[1]
        local mode = change[2]
        local value = change[3]
        local reason = change[4]

        local charData = ns.db.profile.standings[charFullName]
        mode = string.lower(mode)

        local newValue

        if percent then
            -- value is expected to be something like -10, meaning decrease by 10%
            local multiplier = (100 + value) / 100
            newValue = charData[mode] * multiplier
        else
            newValue = charData[mode] + value
        end

        if mode == 'gp' and newValue < 1 then
            newValue = 1
        end

        charData[mode] = newValue

        self:Print('set', charFullName, mode, value, reason)
    end

    ns.MainWindow:refresh()
end
