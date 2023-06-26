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

local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceConsole-3.0', 'AceEvent-3.0')
ns.addon = addon

local dbDefaults = {
    profile = {
        standings = {},
        history = {},
        cfg = {},
    }
}


function addon:OnInitialize()
    -- DB
    ns.db = LibStub('AceDB-3.0'):New(addonName, dbDefaults).profile

    ns.standings = ns.db.standings
    ns.cfg = ns.db.cfg

    ns.Config:init()

    -- Request guild roster info from server; will receive an event (GUILD_ROSTER_UPDATE)
    GuildRoster()

    self:Print('loaded')

    self.showMainWindow(self)
end


function addon:OnEnable()
    -- Called when the addon is enabled
end


function addon:OnDisable()
    -- Called when the addon is disabled
end


-------------------------
-- OPTION GETTERS/SETTERS
-------------------------
function addon:getLmMode(info)
    return ns.cfg.lmMode
end

function addon:setLmMode(info, input)
    ns.cfg.lmMode = input
end

function addon:getDefaultDecay(info)
    return ns.cfg.defaultDecay
end

function addon:setDefaultDecay(info, input)
    ns.cfg.defaultDecay = input
end

-------------------------
-- HANDLERS
-------------------------
function addon:handleSlashCommand(input)
    if (input == 'show') then
        self.showMainWindow(self)
    elseif (input == 'cfg') then
        self:openOptions()
    else
        self:Print('Usage:')
        self:Print('show - Opens the main window')
        self:Print('cfg - Opens the configuration menu')
    end
end

function addon:handleGuildRosterUpdate()
    self:loadGuildData()
    ns.MainWindow:refresh()
end

function addon:showMainWindow()
    ns.mainWindow = ns.mainWindow or ns.MainWindow:createWindow()
    ns.mainWindow:SetShown(true)
end

function addon:openOptions()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end


function addon:loadGuildData()
    local standings = ns.db.standings

    local guildMembers = {}

    for i = 1, GetNumGuildMembers() do
        local fullName, rank, _, level, class, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        local name = self:getCharName(fullName)

        if standings[name] ~= nil then
            local charData = standings[name]
            charData.name = name
            charData.level = level
            charData.class = class
            charData.inGuild = true
            charData.rank = rank
        else
            standings[name] = self:createStandingsEntry(name, level, class, true, rank)
        end

        table.insert(guildMembers, name)
    end

    for name, charData in pairs(ns.db.standings) do
        if charData.inGuild and not ns.Lib:contains(guildMembers, name) then
            charData.inGuild = false
            charData.rank = nil
        end
    end
end


-- TODO: call when joining a raid and when it updates
function addon:loadRaidData()
    local standings = ns.db.standings

    for i = 1, GetNumGroupMembers() do
        local fullName, _, _, level, class, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        local name = self:getCharName(fullName)

        if standings[name] ~= nil then
            local charData = standings[name]
            charData.name = name
            charData.level = level
            charData.class = class
        else
            standings[name] = self:createStandingsEntry(name, level, class, false, nil)
        end
    end
end


function addon:getCharName(fullName)
    local nameDash = string.find(fullName, '-')
    local name = string.sub(fullName, 0, nameDash - 1)

    return name
end


function addon:createStandingsEntry(name, level, class, inGuild, rank)
    return {
        ['name'] = name,
        ['level'] = level,
        ['class'] = class,
        ['inGuild'] = inGuild,
        ['rank'] = rank,
        ['ep'] = 0,
        ['gp'] = 1
    }
end


function addon:modifyEpgp(changes, percent)
    for _, change in ipairs(changes) do
        local charName = change[1]
        local mode = change[2]
        local value = change[3]
        local reason = change[4]

        local charData = ns.db.standings[charName]
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

        local diff = newValue - charData[mode]

        charData[mode] = newValue

        local dt = date('%Y-%m-%dT%H:%M:%S %Z')

        local event = {time(), charName, mode, diff, reason}
        table.insert(ns.db.history, event)

        self:Print(event[1], event[2], event[3], event[4], event[5])
    end

    ns.MainWindow:refresh()
end


addon:RegisterChatCommand('ce', 'handleSlashCommand')
addon:RegisterEvent('GUILD_ROSTER_UPDATE', 'handleGuildRosterUpdate')
