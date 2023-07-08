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

local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceSerializer-3.0')
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
        lmSettingsLastChange = nil
    }
}

addon.version = C_AddOns.GetAddOnMetadata(addonName, 'Version')
addon.author = C_AddOns.GetAddOnMetadata(addonName, 'Author')

addon.versionNum = ns.Lib:getVersionNum(addon.version)

addon.initialized = false
addon.minimapButtonInitialized = false
addon.isOfficer = nil
addon.useForRaidPrompted = false
addon.useForRaid = false
addon.raidRoster = {}
addon.whisperCommands = {
    INFO = '!ceinfo',
}

ns.minSyncVersion = ns.Lib:getVersionNum('0.7.9')


function addon:OnInitialize()
    self.initialized = false
    self.useForRaidPrompted = false
    self.useForRaid = false

    if IsInGuild() then
        -- Request guild roster info from server; will receive an event (GUILD_ROSTER_UPDATE)
        GuildRoster()
    else
        self:init()
    end
end


function addon:OnEnable()
    -- Called when the addon is enabled
end


function addon:OnDisable()
    -- Called when the addon is disabled
end


function ns.print(msg)
    addon:Print(msg)
end

function ns.debug(msg)
    if not ns.cfg.debugMode then
        return
    end

    ns.print('DEBUG: ' .. tostring(msg))
end

function ns.printPublic(msg, rw)
    local channel

    if IsInRaid() then
        if rw and UnitIsGroupAssistant('player') then
            channel = 'RAID_WARNING'
        else
            channel = 'RAID'
        end
    elseif IsInGroup() then
        channel = 'PARTY'
    end

    msg = tostring(msg)

    if channel ~= nil then
        SendChatMessage('CalamityEPGP: ' .. msg, channel)
    else
        ns.print(msg)
    end
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
        ns.print('Usage:')
        ns.print('show - Opens the main window')
        ns.print('history - Opens the history window')
        ns.print('cfg - Opens the configuration menu')
    end
end

function addon:handleGuildRosterUpdate()
    C_Timer.After(1, function() addon:init(); ns.MainWindow:refresh() end)
end

function addon:showMainWindow()
    ns.MainWindow:createWindow()
    ns.MainWindow:show()
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

    if keyPressIdentifier == 'SHIFT_CLICK' and ((ns.cfg.lmMode and IsMasterLooter()) or ns.cfg.debugMode) then
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


function addon:init()
    if self == nil then
        return
    end

    if not self.initialized then
        -- Get guild name
        local guildName = GetGuildInfo('player')

        -- haven't actually received guild data yet. wait 1 second and run this function again
        if guildName == nil then
            C_Timer.After(1, addon.init)
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

        if ns.db.lmSettingsLastChange == nil then
            self:modifiedLmSettings(false)
        end

        self.ldb = LibStub('LibDataBroker-1.1', true)
        self.ldbi = LibStub('LibDBIcon-1.0', true)

        self.candy = LibStub('LibCandyBar-3.0')

        self.libc = LibStub('LibCompress')
        self.libcEncodeTable = self.libc:GetAddonEncodeTable()

        ns.Comm:init()
    end

    self.isOfficer = C_GuildInfo.CanEditOfficerNote()

    -- Load guild data
    local guildMembers = {}

    for i = 1, GetNumGuildMembers() do
        local fullName, rank, _, level, class, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        local name = self:getCharName(fullName)

        local charData = ns.db.standings[guid]
        if charData ~= nil then
            charData.name = name
            charData.fullName = fullName
            charData.level = level
            charData.class = class
            charData.inGuild = true
            charData.rank = rank
        else
            ns.db.standings[guid] = self:createStandingsEntry(guid, fullName, name, level, class, true, rank)
        end

        table.insert(guildMembers, guid)
    end

    for guid, charData in pairs(ns.db.standings) do
        if charData.inGuild and not ns.Lib:contains(guildMembers, guid) then
            charData.inGuild = false
            charData.rank = nil
        end
    end

    -- load raid data
    if IsInRaid() then
        self:handleEnteredRaid()
    end

    for guid, playerData in pairs(ns.db.standings) do
        local name = playerData.name
        ns.Lib.playerNameToGuid[name] = guid
    end

    self:fixGp()

    if not self.initialized then
        -- Load config module
        ns.Config:init()

        self:initMinimapButton()

        self.initialized = true
        ns.print(string.format('v%s by %s loaded. Type /ce to get started!', addon.version, addon.author))

        ns.Comm:syncInit()
    end
end


function addon:loadRaidRoster()
    self.raidRoster = {}

    if IsInRaid() then
        local standings = ns.db.standings

        for i = 1, GetNumGroupMembers() do
            local name, _, _, level, class, _, _, _, _, _, _ = GetRaidRosterInfo(i)

            if name ~= nil then
                self.raidRoster[name] = i

                if self.useForRaid then
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
                end
            end
        end
    end

    ns.MainWindow:refresh()
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
        ['gp'] = ns.cfg.gpBase,
    }
end


function addon:fixGp()
    for _, charData in pairs(ns.db.standings) do
        local min = 1
        if ns.cfg.lmMode then
            min = ns.cfg.gpBase
        end
        if charData.gp == nil or charData.gp < min then
            charData.gp = min
        end
    end
end


function addon:modifyEpgp(changes, percent)
    if not ns.cfg.lmMode then
        ns.print('Cannot edit EPGP when loot master mode is off')
        return
    end

    for _, change in ipairs(changes) do
        local charGuid = change[1]
        local mode = change[2]
        local value = change[3]
        local reason = change[4]

        self:_modifyEpgpSingle(charGuid, mode, value, reason, percent)

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
                        self:_modifyEpgpSingle(altCharGuid, 'EP', diff, reason)
                    end

                    if ns.cfg.syncAltGp then
                        local diff = charData.gp - altCharData.gp
                        self:_modifyEpgpSingle(altCharGuid, 'GP', diff, reason)
                    end
                end
            end
        end
    end

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    ns.Comm:send(ns.Comm.prefixes.UPDATE, nil, 'GUILD')
end


function addon:_modifyEpgpSingle(charGuid, mode, value, reason, percent)
    if not ns.cfg.lmMode then
        ns.print('Cannot edit EPGP when loot master mode is off')
        return
    end

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

    if mode == 'gp' and newValue < ns.cfg.gpBase then
        newValue = ns.cfg.gpBase
    end

    local diff = newValue - oldValue

    charData[mode] = newValue

    local createTime = time()
    local eventTime = createTime

    local event = self:Serialize({createTime, eventTime, UnitGUID('player'), charGuid, mode, diff, reason})
    local hash = ns.Lib:hash(event)

    tinsert(ns.db.history, {event, hash})

    if diff ~= 0 then
        local verb = 'gained'
        local amount = diff

        if diff < 0 then
            verb = 'lost'
            amount = -diff
        end

        local baseReason = ns.Lib:split(reason, ':')[1]

        ns.debug(string.format('%s %s %.2f %s (%s)', charData.name, verb, amount, string.upper(mode), baseReason))
    end
end


function addon:initMinimapButton()
    local minimapButton = self.ldb:NewDataObject(addonName, {
        type = 'launcher',
        text = addonName,
        icon = 'Interface\\AddOns\\' ..  addonName .. '\\Assets\\icon',
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


function addon:showUseForRaidWindow()
    ns.ConfirmWindow:show('Use CalamityEPGP for this raid?',
                          function()   -- callback for "Yes"
                              addon.useForRaid = true
                              addon.useForRaidPrompted = true
                              addon:loadRaidRoster()
                          end,
                          function()  -- callback for "No"
                              addon.useForRaid = false
                              addon.useForRaidPrompted = true
                          end)
end


function addon:clearData()
    ns.db.standings = {}
    ns.db.history = {}

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    if IsInGuild() then
        addon:handleGuildRosterUpdate()
    end
end


function addon:modifiedLmSettings(sendUpdate)
    ns.db.lmSettingsLastChange = time()

    if sendUpdate == nil then
        sendUpdate = true
    end

    if sendUpdate then
        ns.Comm:send(ns.Comm.prefixes.UPDATE, nil, 'GUILD')
    end
end


-----------------
-- EVENT HANDLERS
-----------------
function addon:handleChatMsg(self, message)
    for duration, itemLink in string.gmatch(message, 'CalamityEPGP: You have (%d-) seconds to roll on (.+)') do
        duration = tonumber(duration)
        ns.RollWindow:show(itemLink, duration)
        return
    end

    if not ns.cfg or not ns.cfg.lmMode then
        return
    end

    for roller, roll, low, high in string.gmatch(message, ns.LootDistWindow.rollPattern) do
        roll = tonumber(roll) or 0
        low = tonumber(low) or 0
        high = tonumber(high) or 0

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


function addon:handleChatMsgWhisper(self, message, playerFullName)
    local parts = ns.Lib:split(message, ' ')
    local command = parts[1]

    if command == addon.whisperCommands.INFO then
        local name
        if parts[2] ~= nil then
            name = parts[2]
        else
            name = addon:getCharName(playerFullName)
        end

        local guid = ns.Lib:getPlayerGuid(name)

        if guid == nil or ns.db.standings[guid] == nil then
            local name = 'You'
            local word = 'aren\'t'
            if parts[2] ~= nil then
                name = parts[2]
                word = 'isn\'t'
            end

            SendChatMessage(string.format('%s %s in the standings!', name, word), 'WHISPER', nil, playerFullName)
            return
        end

        local playerStandings = ns.db.standings[guid]
        local playerEp = playerStandings.ep
        local playerGp = playerStandings.gp
        local playerPr = playerEp / playerGp

        local sortedStandings = {}
        for _, charData in pairs(ns.db.standings) do
            tinsert(sortedStandings, charData)
        end

        table.sort(sortedStandings, function(left, right)
            local prLeft = left.ep / left.gp
            local prRight = right.ep / right.gp

            return prLeft > prRight
        end)

        local overallRank
        local guildRank
        local raidRank

        local j = 1  -- guild index
        local k = 1  -- raid index
        for i, charData in ipairs(sortedStandings) do
            if charData.name == name then
                overallRank = i
                guildRank = j
                raidRank = k
                break
            end

            if charData.inGuild then
                j  = j + 1
            end

            if addon.raidRoster[charData.name] ~= nil then
                k = k + 1
            end
        end

        local reply = string.format('Standings for %s - EP: %.2f / GP: %.2f / PR: %.3f - Rank: Overall: #%d / Guild: #%d', name, playerEp, playerGp, playerPr, overallRank, guildRank)
        if addon.raidRoster[name] ~= nil then
            reply = string.format('%s / Raid: #%d', reply, raidRank)
        end

        SendChatMessage(reply, 'WHISPER', nil, playerFullName)
    else
        return
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
    addon:loadRaidRoster()

    if ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() and not self.useForRaidPrompted then
        addon:showUseForRaidWindow()
    end
end


function addon:handlePartyLootMethodChanged()
    if ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() then
        if not addon.useForRaid then
            addon:showUseForRaidWindow()
        end
    else
        addon.useForRaid = false
        addon.useForRaidPrompted = false
    end

    -- if GetLootMethod() ~= "master" or not IsInRaid() or CEPGP_isML() ~= 0 then
    --     CEPGP_Info.Active[1] = false;
    --     CEPGP_Info.Active[2] = false;	--	Whenever the loot method, loot master or group type is changed, this will enable the check again
    -- end
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
        ns.print(string.format('Encounter "%s" (%s) not in encounters table!', encounterName, encounterId))
        return
    end

    local proceedFunc = function()
        local reason = string.format('%s: "%s" (%s)', ns.values.epgpReasons.BOSS_KILL, encounterName, encounterId)

        local changes = {}

        for player in pairs(addon.raidRoster) do
            local guid = ns.Lib:getPlayerGuid(player)
            table.insert(changes, {guid, 'EP', ep, reason})
        end

        addon:modifyEpgp(changes)

        ns.printPublic(string.format('Awarded %d EP to raid for killing %s', ep, encounterName))
    end

    C_Timer.After(2, ns.ConfirmWindow:show(string.format('Award %s EP to raid for killing %s?', ep, encounterName), proceedFunc))
end


function addon:handleTooltipUpdate(frame)
    if frame == nil or not addon.initialized then
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
addon:RegisterEvent('CHAT_MSG_PARTY', 'handleChatMsg')
addon:RegisterEvent('CHAT_MSG_PARTY_LEADER', 'handleChatMsg')
addon:RegisterEvent('CHAT_MSG_RAID', 'handleChatMsg')
addon:RegisterEvent('CHAT_MSG_RAID_LEADER', 'handleChatMsg')
addon:RegisterEvent('CHAT_MSG_RAID_WARNING', 'handleChatMsg')
addon:RegisterEvent('CHAT_MSG_LOOT', 'handleChatMsgLoot')
addon:RegisterEvent('CHAT_MSG_WHISPER', 'handleChatMsgWhisper')
addon:RegisterEvent('TRADE_REQUEST', 'handleTradeRequest')
addon:RegisterEvent('TRADE_SHOW', 'handleTradeShow')
addon:RegisterEvent('TRADE_CLOSED', 'handleTradeClosed')
addon:RegisterEvent('TRADE_PLAYER_ITEM_CHANGED', 'handleTradePlayerItemChanged')
addon:RegisterEvent('RAID_INSTANCE_WELCOME', 'handleEnteredRaid')
addon:RegisterEvent('RAID_ROSTER_UPDATE', 'handleEnteredRaid')
addon:RegisterEvent('GROUP_LEFT', 'loadRaidRoster')
addon:RegisterEvent('LOOT_READY', 'handleLootReady')
addon:RegisterEvent('LOOT_CLOSED', 'handleLootClosed')
addon:RegisterEvent('UI_INFO_MESSAGE', 'handleUiInfoMessage')
addon:RegisterEvent('ENCOUNTER_END', 'handleEncounterEnd')
addon:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', 'handlePartyLootMethodChanged')

hooksecurefunc("HandleModifiedItemClick", function(itemLink)
    addon:handleItemClick(itemLink, GetMouseButtonClicked())
end);

hooksecurefunc("GameTooltip_UpdateStyle", function(frame)
    addon:handleTooltipUpdate(frame)
end)
