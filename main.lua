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
        altData = {
            mainAltMapping = {},
            altMainMapping = {},
        },
        loot = {
            toTrade = {},
        },
    }
}

addon.initialized = false
addon.charNameToGuid = {}
addon.useForRaid = false


function addon:OnInitialize()
    -- Request guild roster info from server; will receive an event (GUILD_ROSTER_UPDATE)
    GuildRoster()
end


function addon:OnEnable()
    -- Called when the addon is enabled
end


function addon:OnDisable()
    -- Called when the addon is disabled
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
    ns.mainWindow:Show()
end

function addon:openOptions()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function addon:handleItemClick(itemLink, mouseButton)
    if not itemLink
            or type(itemLink) ~= "string"
            or (mouseButton and mouseButton ~= "LeftButton")
            or not ns.Lib:getItemIDFromLink(itemLink) then
        return;
    end

    local keyPressIdentifier = ns.Lib:getClickCombination(mouseButton);

    if keyPressIdentifier == 'SHIFT_CLICK' then
        self:showLootDistWindow(itemLink)
    end
end

function addon:showLootDistWindow(itemLink)
    ns.LootDistWindow:createWindow()
    ns.LootDistWindow:draw(itemLink)
end


function addon:loadGuildData()
    if self == nil then
        return
    end

    if not self.initialized then
        -- Get guild name
        local guildName = GetGuildInfo('player')

        -- haven't actually received guild data yet. wait 1 second and run this function again
        if guildName == nil then
            C_Timer.After(1, addon.loadGuildData)
            return
        end

        local realmName = GetRealmName()
        local guildFullName = guildName .. '-' .. realmName

        -- DB
        local db = LibStub('AceDB-3.0'):New(addonName, dbDefaults)
        db:SetProfile(guildFullName)

        ns.db = db.profile
        ns.standings = ns.db.standings
        ns.cfg = ns.db.cfg

        ns.guild = guildFullName
    end

    -- Load guild data
    local guildMembers = {}

    for i = 1, GetNumGuildMembers() do
        local fullName, rank, _, level, class, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        local name = self:getCharName(fullName)

        self.charNameToGuid[name] = guid

        local charData = ns.standings[guid]
        if charData ~= nil then
            charData.name = name
            charData.fullName = fullName
            charData.level = level
            charData.class = class
            charData.inGuild = true
            charData.rank = rank
        else
            ns.standings[guid] = self:createStandingsEntry(guid, fullName, name, level, class, true, rank)
        end

        table.insert(guildMembers, guid)
    end

    for guid, charData in pairs(ns.standings) do
        if charData.inGuild and not ns.Lib:contains(guildMembers, guid) then
            charData.inGuild = false
            charData.rank = nil
        end
    end

    if not self.initialized then
        -- Load config module
        ns.Config:init()

        self.initialized = true
        addon:Print('loaded')

        -- self.showMainWindow(self)
    end

    local _, type = GetInstanceInfo()
    if type == 'raid' then
        self:handleEnteredRaid()
    end
end


-- TODO: call when joining a raid and when it updates
function addon:loadRaidData()
    local standings = ns.db.standings

    for i = 1, GetNumGroupMembers() do
        local name, _, _, level, class, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        local realm = GetNormalizedRealmName()
        local fullName = name .. '-' .. realm
        local guid = UnitGUID(name)

        self.charNameToGuid[name] = guid

        local charData = standings[guid]
        if charData == nil then
            standings[guid] = self:createStandingsEntry(guid, fullName, name, level, class, false, nil)
        elseif not charData.inGuild then
            charData.fullName = fullName
            charData.name = name
            charData.level = level
            charData.class = class
        end
    end
end


function addon:getCharName(fullName)
    local nameDash = string.find(fullName, '-')
    local name = string.sub(fullName, 0, nameDash - 1)

    return name
end


function addon:createStandingsEntry(guid, fullName, name, level, class, inGuild, rank)
    return {
        ['guid'] = guid,
        ['fullName'] = fullName,
        ['name'] = name,
        ['level'] = level,
        ['class'] = class,
        ['inGuild'] = inGuild,
        ['rank'] = rank,
        ['ep'] = 0,
        ['gp'] = 1,
    }
end


function addon:modifyEpgp(changes, percent)
    for _, change in ipairs(changes) do
        local charGuid = change[1]
        local mode = change[2]
        local value = change[3]
        local reason = change[4]

        self:modifyEpgpSingle(charGuid, mode, value, reason, percent)

        -- sync alt ep/gp depending on setting
        local charData = ns.db.standings[charGuid]
        local name = charData.name

        local main = ns.db.altData.altMainMapping[name]
        local alts = ns.db.altData.mainAltMapping[main]

        if alts ~= nil then
            for _, alt in ipairs(alts) do
                if alt ~= name then
                    local altCharGuid = self.charNameToGuid[alt]
                    local altCharData = ns.db.standings[altCharGuid]

                    if ns.cfg.syncAltEp then
                        self:Print('syncing EP for ' .. alt .. ' with ' .. main)
                        local diff = charData.ep - altCharData.ep
                        self:modifyEpgpSingle(altCharGuid, 'EP', diff, 'alt_sync: ' .. charGuid)
                    end

                    if ns.cfg.syncAltGp then
                        self:Print('syncing GP for ' .. alt .. ' with ' .. main)
                        local diff = charData.gp - altCharData.gp
                        self:modifyEpgpSingle(altCharGuid, 'GP', diff, 'alt_sync: ' .. charGuid)
                    end
                end
            end
        end
    end

    ns.MainWindow:refresh()
end


function addon:modifyEpgpSingle(charGuid, mode, value, reason, percent)
    local charData = ns.db.standings[charGuid]
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

    local event = {time(), charGuid, mode, diff, reason}
    table.insert(ns.db.history, event)

    self:Print(event[1], event[2], event[3], event[4], event[5])
end


-----------------
-- EVENT HANDLERS
-----------------
function addon:handleChatMsg(self, message)
    for roller, roll, low, high in string.gmatch(message, ns.LootDistWindow.rollPattern) do
        roll = tonumber(roll) or 0;
        low = tonumber(low) or 0;
        high = tonumber(high) or 0;

        local rollType
        if low == 1 then
            if high == 100 then
                rollType = 'MS'
            elseif high == 99 then
                rollType = 'OS'
            end
        end

        if rollType ~= nil then
            ns.LootDistWindow:handleRoll(roller, roll, rollType)
            return
        end
    end
end


function addon:handleTradeRequest(player)
	ns.LootDistWindow:handleTradeRequest(player)
end


function addon:handleTradeShow()
	ns.LootDistWindow:handleTradeShow()
end


function addon:handleTradeAcceptUpdate(player1Accept, player2Accept)
	if player1Accept == 1 and player2Accept == 1 then
		ns.LootDistWindow:handleTradeAccepted()
	end
end


function addon:handleTradeClosed()
	ns.LootDistWindow:handleTradeClosed()
end


function addon:handleEnteredRaid()
    self:loadRaidData()

    -- check if you want to use addon for raid if LM mode
    if not self.useForRaid and ns.cfg.lmMode then
        -- open confirm window
        -- on yes, self.useForRaid = true
    end
end


addon:RegisterChatCommand('ce', 'handleSlashCommand')
addon:RegisterEvent('GUILD_ROSTER_UPDATE', 'handleGuildRosterUpdate')
addon:RegisterEvent('CHAT_MSG_SYSTEM', 'handleChatMsg')
addon:RegisterEvent('TRADE_REQUEST', 'handleTradeRequest')
addon:RegisterEvent('TRADE_SHOW', 'handleTradeShow')
addon:RegisterEvent('TRADE_ACCEPT_UPDATE', 'handleTradeAcceptUpdate')
addon:RegisterEvent('TRADE_CLOSED', 'handleTradeClosed')
addon:RegisterEvent('RAID_INSTANCE_WELCOME', 'handleEnteredRaid')
addon:RegisterEvent('RAID_ROSTER_UPDATE', 'handleEnteredRaid')

hooksecurefunc("HandleModifiedItemClick", function(itemLink)
    addon:handleItemClick(itemLink, GetMouseButtonClicked())
end);
