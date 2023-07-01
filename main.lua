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
            awarded = {},
        },
    }
}

addon.initialized = false
addon.minimapButtonInitialized = false
addon.useForRaid = false
addon.raidRoster = {}

addon.version = C_AddOns.GetAddOnMetadata(addonName, 'Version')


function addon:OnInitialize()
    self.initialized = false
    self.useForRaid = false

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
    if input == 'show' then
        self.showMainWindow(self)
    elseif input == 'history' then
        ns.HistoryWindow:createWindow()
        ns.HistoryWindow:show()
    elseif input == 'cfg' then
        self:openOptions()
    else
        self:Print('Usage:')
        self:Print('show - Opens the main window')
        self:Print('history - Opens the history window')
        self:Print('cfg - Opens the configuration menu')
    end
end

function addon:handleGuildRosterUpdate()
    self:loadGuildData()
    ns.MainWindow:refresh()
end

function addon:showMainWindow()
    ns.MainWindow:createWindow()
    ns.MainWindow:show()
end

function addon:openOptions()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function addon:handleItemClick(itemLink, mouseButton)
    if not ns.cfg.lmMode then
        return
    end

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
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:createWindow()
    ns.LootDistWindow:show(itemLink)
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

        self.ldb = LibStub("LibDataBroker-1.1", true)
        self.ldbi = LibStub("LibDBIcon-1.0", true)
    end

    -- Load guild data
    local guildMembers = {}

    for i = 1, GetNumGuildMembers() do
        local fullName, rank, _, level, class, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        local name = self:getCharName(fullName)

        ns.Lib.playerNameToGuid[name] = guid

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

    -- load raid data
    if IsInRaid() then
        self:handleEnteredRaid()
    end

    -- if not self.minimapButtonInitialized then
    --     self:initMinimapButton()
    -- end

    if not self.initialized then
        -- Load config module
        ns.Config:init()

        self:initMinimapButton()

        self.initialized = true
        addon:Print(string.format('v%s loaded', addon.version))
    end
end


function addon:loadRaidRoster()
    local standings = ns.db.standings
    self.raidRoster = {}

    for i = 1, GetNumGroupMembers() do
        local name, _, _, level, class, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        local fullName = GetUnitName(name, true)
        local guid = ns.Lib:getPlayerGuid(name)

        local charData = standings[guid]
        if charData == nil then
            standings[guid] = self:createStandingsEntry(guid, fullName, name, level, class, false, nil)
        elseif not charData.inGuild then
            charData.fullName = fullName
            charData.name = name
            charData.level = level
            charData.class = class
        end

        self.raidRoster[name] = i
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
    -- TODO: if not officer, return

    for _, change in ipairs(changes) do
        local charGuid = change[1]
        local mode = change[2]
        local value = change[3]
        local reason = change[4]

        self:modifyEpgpSingle(charGuid, mode, value, reason, percent)

        -- sync alt epgp
        local charData = ns.db.standings[charGuid]
        local name = charData.name

        local main = ns.db.altData.altMainMapping[name]
        local alts = ns.db.altData.mainAltMapping[main]

        if alts ~= nil then
            for _, alt in ipairs(alts) do
                if alt ~= name then
                    local altCharGuid = ns.Lib:getPlayerGuid(alt)
                    local altCharData = ns.db.standings[altCharGuid]

                    local reason = string.format('%s: %s', ns.values.epgpReasons.ALT_SYNC, charGuid)

                    if ns.cfg.syncAltEp then
                        local diff = charData.ep - altCharData.ep
                        self:modifyEpgpSingle(altCharGuid, 'EP', diff, reason)
                    end

                    if ns.cfg.syncAltGp then
                        local diff = charData.gp - altCharData.gp
                        self:modifyEpgpSingle(altCharGuid, 'GP', diff, reason)
                    end
                end
            end
        end
    end

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()
end


function addon:modifyEpgpSingle(charGuid, mode, value, reason, percent)
    -- TODO: if not officer, return

    local charData = ns.db.standings[charGuid]
    mode = string.lower(mode)

    local oldValue = charData[mode]
    local newValue

    if percent then
        -- value is expected to be something like -10, meaning decrease by 10%
        local multiplier = (100 + value) / 100
        newValue = oldValue * multiplier
    else
        newValue = oldValue + value
    end

    if mode == 'gp' and newValue < 1 then
        newValue = 1
    end

    local diff = newValue - oldValue

    charData[mode] = newValue

    local event = {time(), UnitGUID('player'), charGuid, mode, diff, reason}
    table.insert(ns.db.history, event)

    if diff ~= 0 then
        local verb = 'gained'
        local amount = diff

        if diff < 0 then
            verb = 'lost'
            amount = -diff
        end

        local baseReason = ns.Lib:split(reason, ':')[1]

        self:Print(string.format('%s %s %d %s (%s)', charData.name, verb, amount, string.upper(mode), baseReason))
    end
end


function addon:initMinimapButton()
    local minimapButton = self.ldb:NewDataObject(addonName, {
        type = 'launcher',
        text = addonName,
        icon = 'Interface\\AddOns\\' ..  addonName .. '\\Icons\\icon',
        OnClick = function(self, button)
            if button == 'LeftButton' then
                addon:showMainWindow()
            elseif button == 'RightButton' then
                addon:openOptions();
            elseif button == 'MiddleButton' then
                ns.HistoryWindow:createWindow()
                ns.HistoryWindow:show()
            end
        end,
        OnEnter = function(self)
            local inRaidText = ''
            if IsInRaid() and IsMasterLooter() then
                inRaidText = string.format('\n%s is %s for this raid\n', addonName, addon.useForRaid and "|cFF00FF00active|r|c00FFC100" or "|cFFFF0000inactive|r|c00FFC100")
            end
            local text = string.format('%s\nVersion: %s\n%s\nLeft Click: Open the main window\nMiddle Click: Open the history window\nRight Click: Open the configuration menu', addonName, addon.version, inRaidText)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText(text)
        end,
        OnLeave = function()
            GameTooltip:Hide()
        end
    })

    self.ldbi:Register(addonName, minimapButton, ns.cfg.minimap)

    self.minimapButtonInitialized = true
end


-----------------
-- EVENT HANDLERS
-----------------
function addon:handleChatMsg(self, message)
    if not ns.cfg.lmMode then
        return
    end

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
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow:handleTradeRequest(player)
end


function addon:handleTradeShow()
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow:handleTradeShow()
end


function addon:handleTradeClosed()
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow:handleTradeClosed()
end


function addon:handleTradePlayerItemChanged()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:handleTradePlayerItemChanged()
end


function addon:handleEnteredRaid()
    self = addon

    self:loadRaidRoster()

    if ns.cfg.lmMode and not self.useForRaid then
        ns.ConfirmWindow:show('Use CalamityEPGP for this raid?',
                              function() addon.useForRaid = true; self:Print('use for raid') end,   -- callback for "Yes"
                              function() addon.useForRaid = false; self:Print('do not use for raid') end)  -- callback for "No"
    end
end


function addon:handleLootReady()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:getLoot()
end


function addon:handleLootClosed()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:clearLoot()
end


function addon:handleChatMsgLoot(_, msg)
    if not ns.cfg.lmMode then
        return
    end

    local player, itemLink = msg:match('(%a+) receives? loot: (.+)%.')

    if player == nil or itemLink == nil then
        return
    end

    ns.LootDistWindow:handleLootReceived(itemLink, player)
end


function addon:handleUiInfoMessage(self, _, msg)
    if not ns.cfg.lmMode then
        return
    end

    if msg == ERR_TRADE_COMPLETE then
        ns.LootDistWindow:handleTradeComplete()
    end
end


function addon:handleEncounterEnd(self, encounterId, encounterName, _, _, success)
    if not addon.useForRaid or
            success ~= 1 then
        return
    end

    local ep = ns.cfg.encounterEp[encounterId]

    if ep == nil then
        addon:Print('Encounter "' .. encounterName .. '" (' .. encounterId .. ') not in encounters table!')
        return
    end

    local reason = 'boss kill: "' .. encounterName .. '" (' .. encounterId .. ')'

    local changes = {}

    for player in pairs(addon.raidRoster) do
        local guid = ns.Lib:getPlayerGuid(player)
        table.insert(changes, {guid, 'EP', ep, reason})
    end

    addon:modifyEpgp(changes)
end


function addon:handleTooltipUpdate(frame)
    self = addon

    if frame == nil or not self.initialized then
        return
    end

    local _, itemLink = frame:GetItem()

    if not itemLink or itemLink == nil or itemLink == '' then
        return
    end

    local itemId = ns.Lib:getItemID(ns.Lib:getItemString(itemLink))
    if not ns.Lib:itemExists(itemId) then
        return
    end

    -- add GP to tooltip
    local gp = ns.Lib:getGp(itemLink)
    if gp == nil then
        gp = '?'
    end

    frame:AddLine('GP: ' .. gp, 0.5, 0.6, 1)

    -- add awarded list to tooltip
    local awardedList = {}

    local itemAwardedData = ns.db.loot.awarded[itemLink]
    if itemAwardedData ~= nil then
        for player, items in pairs(itemAwardedData) do
            for _, item in ipairs(items) do
                local given = item.given
                tinsert(awardedList, {player, given})
            end
        end
    end

    table.sort(awardedList, function(left, right)
        return left[1] < right[1]
    end)

    if #awardedList > 0 then
        frame:AddLine('Awarded To')

        for _, awardedItem in ipairs(awardedList) do
            local player = awardedItem[1]
            local given = awardedItem[2] and 'yes' or 'no'

            local _, classFileName = UnitClass(player)
            local classColor = RAID_CLASS_COLORS[classFileName]

            local playerColored = classColor:WrapTextInColorCode(player)

            frame:AddLine(string.format('  %s | Given: %s', playerColored, given))
        end
    end
end


addon:RegisterChatCommand('ce', 'handleSlashCommand')
addon:RegisterEvent('GUILD_ROSTER_UPDATE', 'handleGuildRosterUpdate')
addon:RegisterEvent('CHAT_MSG_SYSTEM', 'handleChatMsg')
addon:RegisterEvent('TRADE_REQUEST', 'handleTradeRequest')
addon:RegisterEvent('TRADE_SHOW', 'handleTradeShow')
addon:RegisterEvent('TRADE_CLOSED', 'handleTradeClosed')
addon:RegisterEvent('TRADE_PLAYER_ITEM_CHANGED', 'handleTradePlayerItemChanged')
addon:RegisterEvent('RAID_INSTANCE_WELCOME', 'handleEnteredRaid')
addon:RegisterEvent('RAID_ROSTER_UPDATE', 'handleEnteredRaid')
addon:RegisterEvent('LOOT_READY', 'handleLootReady')
addon:RegisterEvent('LOOT_CLOSED', 'handleLootClosed')
addon:RegisterEvent('CHAT_MSG_LOOT', 'handleChatMsgLoot')
addon:RegisterEvent('UI_INFO_MESSAGE', 'handleUiInfoMessage')
addon:RegisterEvent('ENCOUNTER_END', 'handleEncounterEnd')

hooksecurefunc("HandleModifiedItemClick", function(itemLink)
    addon:handleItemClick(itemLink, GetMouseButtonClicked())
end);

hooksecurefunc("GameTooltip_UpdateStyle", function(frame)
    addon:handleTooltipUpdate(frame)
end)
