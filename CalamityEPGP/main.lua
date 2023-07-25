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

local List = ns.List
local Dict = ns.Dict
local Set = ns.Set

local addon = LibStub('AceAddon-3.0'):NewAddon(
    addonName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceSerializer-3.0'
)
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
        lmSettingsLastChange = -1
    }
}


function addon:OnInitialize()
    self.version = C_AddOns.GetAddOnMetadata(addonName, 'Version')
    self.author = C_AddOns.GetAddOnMetadata(addonName, 'Author')

    self.versionNum = ns.Lib.getVersionNum(self.version)

    self.initialized = false
    self.minimapButtonInitialized = false
    self.isOfficer = nil
    self.useForRaidPrompted = false
    self.useForRaid = false
    self.raidRoster = Dict:new()
    self.whisperCommands = {
        INFO = '!ceinfo',
    }

    ns.minSyncVersion = ns.Lib.getVersionNum('0.9.0')

    self:RegisterChatCommand('ce', 'handleSlashCommand')
    self:RegisterEvent('GUILD_ROSTER_UPDATE', 'handleGuildRosterUpdate')
    self:RegisterEvent('CHAT_MSG_SYSTEM', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_PARTY', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_PARTY_LEADER', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_RAID', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_RAID_LEADER', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_RAID_WARNING', 'handleChatMsg')
    self:RegisterEvent('CHAT_MSG_LOOT', 'handleChatMsgLoot')
    self:RegisterEvent('CHAT_MSG_WHISPER', 'handleChatMsgWhisper')
    self:RegisterEvent('TRADE_REQUEST', 'handleTradeRequest')
    self:RegisterEvent('TRADE_SHOW', 'handleTradeShow')
    self:RegisterEvent('TRADE_PLAYER_ITEM_CHANGED', 'handleTradePlayerItemChanged')
    self:RegisterEvent('RAID_INSTANCE_WELCOME', 'handleEnteredRaid')
    self:RegisterEvent('RAID_ROSTER_UPDATE', 'handleEnteredRaid')
    self:RegisterEvent('GROUP_LEFT', 'loadRaidRoster')
    self:RegisterEvent('LOOT_READY', 'handleLootReady')
    self:RegisterEvent('LOOT_CLOSED', 'handleLootClosed')
    self:RegisterEvent('UI_INFO_MESSAGE', 'handleUiInfoMessage')
    self:RegisterEvent('ENCOUNTER_END', 'handleEncounterEnd')
    self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', 'handlePartyLootMethodChanged')

    hooksecurefunc("HandleModifiedItemClick", function(itemLink)
        self:handleItemClick(itemLink, GetMouseButtonClicked())
    end);

    hooksecurefunc("GameTooltip_UpdateStyle", function(frame)
        self:handleTooltipUpdate(frame)
    end)

    if IsInGuild() then
        -- Request guild roster info from server; will receive an event (GUILD_ROSTER_UPDATE)
        GuildRoster()
    else
        self:init()
    end
end


-- function addon:OnEnable()
--     -- Called when the addon is enabled
-- end


-- function addon:OnDisable()
--     -- Called when the addon is disabled
-- end


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
        if rw and (UnitIsGroupLeader('player') or UnitIsGroupAssistant('player')) then
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
        self.showMainWindow()
    elseif input == 'history' then
        ns.HistoryWindow:createWindow()
        ns.HistoryWindow:show()
    elseif input == 'cfg' then
        self.openOptions()
    else
        ns.print('Usage:')
        ns.print('show - Opens the main window')
        ns.print('history - Opens the history window')
        ns.print('cfg - Opens the configuration menu')
    end
end

function addon:handleGuildRosterUpdate()
    C_Timer.After(1, function() self:init(); ns.MainWindow:refresh() end)
end

function addon.showMainWindow()
    ns.MainWindow:createWindow()
    ns.MainWindow:show()
end

function addon.openOptions()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function addon:handleItemClick(itemLink, mouseButton)
    if not itemLink
            or type(itemLink) ~= "string"
            or (mouseButton and mouseButton ~= "LeftButton")
            or not ns.Lib.getItemIDFromLink(itemLink) then
        return;
    end

    local keyPressIdentifier = ns.Lib.getClickCombination(mouseButton);

    if not ((ns.cfg.lmMode and IsMasterLooter()) or ns.cfg.debugMode) then
        return
    end

    if keyPressIdentifier == 'ALT_CLICK' then
        self.showLootDistWindow(itemLink)
    elseif keyPressIdentifier == 'ALT_SHIFT_CLICK' then
        self.showManualAwardWindow(itemLink)
    end
end

function addon.showLootDistWindow(itemLink)
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:createWindow()
    ns.LootDistWindow:show(itemLink)
end

function addon.showManualAwardWindow(itemLink)
    if not ns.cfg.lmMode then
        return
    end

    ns.ManualAwardWindow:show(itemLink)
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

        self.ldb = LibStub('LibDataBroker-1.1', true)
        self.ldbi = LibStub('LibDBIcon-1.0', true)

        self.candy = LibStub('LibCandyBar-3.0')

        self.libc = LibStub('LibCompress')
        self.libcEncodeTable = self.libc:GetAddonEncodeTable()

        ns.Comm:init()

        self.clearAwarded()
    end

    self.isOfficer = C_GuildInfo.CanEditOfficerNote()

    -- Load guild data
    local guildMembers = {}

    for i = 1, GetNumGuildMembers() do
        local fullName, rank, _, level, class, _, _, _, _, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if fullName ~= nil then
            local name = self.getCharName(fullName)

            local charData = ns.db.standings[guid]
            if charData ~= nil then
                charData.name = name
                charData.fullName = fullName
                charData.level = level
                charData.class = class
                charData.classFileName = classFileName
                charData.inGuild = true
                charData.rank = rank
            else
                ns.db.standings[guid] = self.createStandingsEntry(
                    guid, fullName, name, level, class, classFileName, true, rank
                )
            end

            table.insert(guildMembers, guid)
        end
    end

    for guid, charData in pairs(ns.db.standings) do
        if charData.inGuild and not ns.Lib.contains(guildMembers, guid) then
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

    self.fixGp()

    if not self.initialized then
        -- Load config module
        ns.Config:init()

        self:initMinimapButton()

        ns.HistoryWindow.fixHistory()
        self.syncAltEpGp()

        self.initialized = true
        ns.print(string.format('v%s by %s loaded. Type /ce to get started!', addon.version, addon.author))

        ns.Comm:syncInit()
    end
end


function addon.clearAwarded()
    local now = time()

    local newAwarded = {}

    for itemLink, itemData in pairs(ns.db.loot.awarded) do
        for awardee, awardeeData in pairs(itemData) do
            local awardTime = awardeeData.awardTime

            if awardTime ~= nil then
                if now - awardTime < 7200 then  -- 2 hours
                    if newAwarded[itemLink] == nil then
                        newAwarded[itemLink] = {}
                    end

                    if newAwarded[itemLink][awardee] == nil then
                        newAwarded[itemLink][awardee] = {}
                    end

                    newAwarded[itemLink][awardee] = awardeeData
                end
            end
        end
    end

    ns.db.loot.awarded = newAwarded

    local newToTrade = {}

    for player, items in pairs(ns.db.loot.toTrade) do
        for _, itemData in ipairs(items) do
            if type(itemData) == 'table' then
                local ts = itemData[2]

                if now - ts < 7200 then
                    if newToTrade[player] == nil then
                        newToTrade[player] = {}
                    end

                    tinsert(newToTrade[player], itemData)
                end
            end
        end
    end

    ns.db.loot.toTrade = newToTrade

    C_Timer.After(60, addon.clearAwarded)
end


function addon:loadRaidRoster()
    self.raidRoster:clear()

    if IsInRaid() then
        local standings = ns.db.standings

        for i = 1, GetNumGroupMembers() do
            local name, _, _, level, class, classFileName, _, online, _, _, isMl, _ = GetRaidRosterInfo(i)

            if name ~= nil then
                self.raidRoster:set(name, {
                    online = online,
                    ml = isMl,
                })

                if self.useForRaid then
                    local fullName = GetUnitName(name, true)
                    local guid = ns.Lib.getPlayerGuid(name)

                    local charData = standings[guid]
                    if charData == nil then
                        standings[guid] = self.createStandingsEntry(
                            guid, fullName, name, level, class, classFileName, false, nil
                        )
                    elseif not charData.inGuild then
                        charData.fullName = fullName
                        charData.name = name
                        charData.level = level
                        charData.class = class
                        charData.classFileName = classFileName
                    end
                end
            end
        end
    end

    ns.MainWindow:refresh()
end


function addon.getCharName(fullName)
    local nameDash = string.find(fullName, '-')
    local name = string.sub(fullName, 0, nameDash - 1)
    return name
end


function addon.createStandingsEntry(guid, fullName, name, level, class, classFileName, inGuild, rank)
    return {
        guid = guid,
        fullName = fullName,
        name = name,
        level = level,
        class = class,
        classFileName = classFileName,
        inGuild = inGuild,
        rank = rank,
        ep = 0,
        gp = ns.cfg.gpBase,
    }
end


function addon.fixGp()
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


---@param players table
---@param mode 'ep' | 'gp' | 'both'
---@param value number
---@param reason string
---@param percent boolean?
function addon:modifyEpgp(players, mode, value, reason, percent)
    if not ns.cfg.lmMode then
        error('Cannot modify EPGP when loot master mode is off')
        return
    end

    if mode ~= ns.consts.MODE_EP and mode ~= ns.consts.MODE_GP and mode ~= ns.consts.MODE_BOTH then
        error(string.format('Mode (%s) is not one of allowed modes', mode))
        return
    end

    if #players == 0 then
        ns.print('Won\'t modify EP/GP for 0 players')
        return
    end

    local modified = false

    for _, playerGuid in ipairs(players) do
        if mode == ns.consts.MODE_BOTH or mode == ns.consts.MODE_EP then
            self._modifyEpgpSingle(playerGuid, ns.consts.MODE_EP, value, reason, percent)
            modified = true
        end

        if mode == ns.consts.MODE_BOTH or mode == ns.consts.MODE_GP then
            self._modifyEpgpSingle(playerGuid, ns.consts.MODE_GP, value, reason, percent)
            modified = true
        end
    end

    if not modified then
        return
    end

    self.syncAltEpGp(players)

    local createTime = time()
    local eventTime = createTime

    local event = {createTime, eventTime, UnitGUID('player'), players, mode, value, reason, percent}
    local hash = ns.Lib.hash(event)

    tinsert(ns.db.history, {event, hash})

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    ns.Comm:sendUpdate()
end


---@param charGuid string
---@param mode 'ep' | 'gp'
---@param value number
---@param reason string
---@param percent boolean?
function addon._modifyEpgpSingle(charGuid, mode, value, reason, percent)
    if not ns.cfg.lmMode then
        ns.print('Cannot modify EPGP when loot master mode is off')
        return
    end

    local charData = ns.db.standings[charGuid]

    local oldValue = charData[mode]
    local newValue

    if percent then
        -- value is expected to be something like -10, meaning decrease by 10%
        local multiplier = (100 + value) / 100
        newValue = oldValue * multiplier
    else
        newValue = oldValue + value
    end

    if mode == ns.consts.MODE_GP and newValue < ns.cfg.gpBase then
        newValue = ns.cfg.gpBase
    end

    charData[mode] = newValue

    local diff = newValue - oldValue
    if diff ~= 0 then
        local verb = 'gained'
        local amount = diff

        if diff < 0 then
            verb = 'lost'
            amount = -diff
        end

        local baseReason = ns.Lib.split(reason, ':')[1]

        ns.debug(string.format('%s %s %.2f %s (%s)', charData.name, verb, amount, string.upper(mode), baseReason))
    end
end


function addon.syncAltEpGp(players)
    if not ns.cfg.syncAltEp and not ns.cfg.syncAltGp then
        return
    end

    if players ~= nil then
        for _, playerGuid in ipairs(players) do
            local playerData = ns.db.standings[playerGuid]
            local player = playerData.name

            local main = ns.db.altData.altMainMapping[player]

            if main ~= nil then
                local alts = ns.db.altData.mainAltMapping[main]

                for _, alt in ipairs(alts) do
                    if alt ~= player then
                        local altGuid = ns.Lib.getPlayerGuid(alt)
                        local altData = ns.db.standings[altGuid]

                        if ns.cfg.syncAltEp then
                            altData.ep = playerData.ep
                        end

                        if ns.cfg.syncAltGp then
                            altData.gp = playerData.gp
                        end
                    end
                end
            end
        end
    else
        local synced = Set:new()

        for _, eventAndHash in ipairs(ns.db.history) do
            local event = eventAndHash[1]
            players = event[4]

            for _, playerGuid in ipairs(players) do
                local playerData = ns.db.standings[playerGuid]

                if playerData ~= nil then
                    local player = playerData.name

                    if not synced:contains(player) then
                        synced:add(player)

                        local main = ns.db.altData.altMainMapping[player]

                        if main ~= nil then
                            local alts = ns.db.altData.mainAltMapping[main]

                            if alts ~= nil then
                                for _, alt in ipairs(alts) do
                                    if alt ~= player then
                                        local altGuid = ns.Lib.getPlayerGuid(alt)
                                        local altData = ns.db.standings[altGuid]

                                        if ns.cfg.syncAltEp then
                                            altData.ep = playerData.ep
                                        end

                                        if ns.cfg.syncAltGp then
                                            altData.gp = playerData.gp
                                        end

                                        synced:add(alt)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


function addon:initMinimapButton()
    local minimapButton = self.ldb:NewDataObject(addonName, {
        type = 'launcher',
        text = addonName,
        icon = 'Interface\\AddOns\\' ..  addonName .. '\\Assets\\icon',
        OnClick = function(_, button)
            if button == 'LeftButton' then
                addon.showMainWindow()
            elseif button == 'RightButton' then
                addon.openOptions();
            elseif button == 'MiddleButton' then
                ns.HistoryWindow:createWindow()
                ns.HistoryWindow:show()
            end
        end,
        OnEnter = function(buttonFrame)
            local inRaidText = ''
            if IsInRaid() and IsMasterLooter() then
                inRaidText = string.format(
                    '\n%s is %s for this raid\n',
                    addonName,
                    addon.useForRaid and "|cFF00FF00active|r|c00FFC100" or "|cFFFF0000inactive|r|c00FFC100"
                )
            end
            local text = string.format(
                '%s\n' ..
                'Version: %s\n' ..
                '%s\n' ..
                'Left Click: Open the main window\n' ..
                'Middle Click: Open the history window\n' ..
                'Right Click: Open the configuration menu',
                addonName, addon.version, inRaidText
            )
            GameTooltip:SetOwner(buttonFrame, "ANCHOR_BOTTOMRIGHT")
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
                              self.useForRaid = true
                              self.useForRaidPrompted = true
                              self:loadRaidRoster()
                          end,
                          function()  -- callback for "No"
                              self.useForRaid = false
                              self.useForRaidPrompted = true
                          end)
end


function addon:clearData()
    ns.db.standings = {}
    ns.db.history = {}

    ns.MainWindow:refresh()
    ns.HistoryWindow:refresh()

    if IsInGuild() then
        self:handleGuildRosterUpdate()
    end
end


function addon.modifiedLmSettings()
    ns.db.lmSettingsLastChange = time()
    ns.Comm:sendUpdate()
end


-----------------
-- EVENT HANDLERS
-----------------
function addon:handleChatMsg(_, message)
    local duration, itemLink = string.match(message, addonName .. ': You have (%d-) seconds to roll on (.+)')
    if duration then
        duration = tonumber(duration)
        ns.RollWindow:show(itemLink, duration)
        return
    end

    if message == addonName .. ': Stop your rolls!' then
        ns.RollWindow:hide()
        return
    end

    if not ns.cfg or not ns.cfg.lmMode then
        return
    end

    local roller, roll, low, high = string.match(message, ns.LootDistWindow.rollPattern)
    if roller then
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


function addon:handleChatMsgWhisper(_, message, playerFullName)
    local parts = ns.Lib.split(message, ' ')
    local command = parts[1]

    if command == self.whisperCommands.INFO then
        local name
        if parts[2] ~= nil then
            name = parts[2]
        else
            name = self.getCharName(playerFullName)
        end

        local guid = ns.Lib.getPlayerGuid(name)

        if guid == nil or ns.db.standings[guid] == nil then
            local msgName = 'You'
            local msgWord = 'aren\'t'
            if parts[2] ~= nil then
                msgName = parts[2]
                msgWord = 'isn\'t'
            end

            SendChatMessage(string.format('%s %s in the standings!', msgName, msgWord), 'WHISPER', nil, playerFullName)
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

            if self.raidRoster:contains(charData.name) then
                k = k + 1
            end
        end

        local reply = string.format(
            'Standings for %s - EP: %.2f / GP: %.2f / PR: %.3f - Rank: Overall: #%d / Guild: #%d',
            name, playerEp, playerGp, playerPr, overallRank, guildRank
        )

        if self.raidRoster:contains(name) then
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

	ns.LootDistWindow.handleTradeRequest(player)
end


function addon:handleTradeShow()
    if not ns.cfg.lmMode then
        return
    end

	ns.LootDistWindow:handleTradeShow()
end


function addon:handleTradePlayerItemChanged()
    if not ns.cfg.lmMode then
        return
    end

    ns.LootDistWindow:handleTradePlayerItemChanged()
end


function addon:handleEnteredRaid()
    self:loadRaidRoster()

    if ns.cfg and ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() and not self.useForRaidPrompted then
        self:showUseForRaidWindow()
    end
end


function addon:handlePartyLootMethodChanged()
    if ns.cfg and ns.cfg.lmMode and GetLootMethod() == 'master' and IsMasterLooter() then
        if not self.useForRaid then
            self:showUseForRaidWindow()
        end
    else
        self.useForRaid = false
        self.useForRaidPrompted = false
    end
end


function addon:handleLootReady()
    if not ns.cfg or not ns.cfg.lmMode then
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
    if ns.cfg == nil or not ns.cfg.lmMode then
        return
    end

    local player, itemLink = msg:match('(%a+) receives? loot: (.+)%.')

    if player == nil or itemLink == nil then
        return
    end

    ns.LootDistWindow:handleLootReceived(itemLink, player)
end


function addon:handleUiInfoMessage(_, _, msg)
    if not ns.cfg.lmMode then
        return
    end

    if msg == ERR_TRADE_COMPLETE then
        ns.LootDistWindow:handleTradeComplete()
    end
end


---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@param encounterId number
---@param encounterName string
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ any
---@param success number
function addon:handleEncounterEnd(_, encounterId, encounterName, _, _, success)
    if not self.useForRaid or
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

        local players = {}
        for player in self.raidRoster:iter() do
            local guid = ns.Lib.getPlayerGuid(player)
            tinsert(players, guid)
        end

        self:modifyEpgp(players, ns.consts.MODE_EP, ep, reason)

        ns.printPublic(string.format('Awarded %d EP to raid for killing %s', ep, encounterName))
    end

    C_Timer.After(2, function()
        ns.ConfirmWindow:show(string.format('Award %s EP to raid for killing %s?', ep, encounterName), proceedFunc)
    end)
end


function addon:handleTooltipUpdate(frame)
    if frame == nil or not self.initialized then
        return
    end

    local _, itemLink = frame:GetItem()

    if not itemLink or itemLink == nil or itemLink == '' then
        return
    end

    local itemId = ns.Lib.getItemID(ns.Lib.getItemString(itemLink))
    if not ns.Lib.itemExists(itemId) then
        return
    end

    -- add GP to tooltip
    local gp = ns.Lib.getGp(itemLink)
    if gp == nil then
        gp = '?'
    end

    frame:AddLine('GP: ' .. gp, 0.5, 0.6, 1)

    -- add awarded list to tooltip
    local awardedList = List:new()

    local itemAwardedData = ns.db.loot.awarded[itemLink]
    if itemAwardedData ~= nil then
        for player, items in pairs(itemAwardedData) do
            for _, item in ipairs(items) do
                local given = item.given

                awardedList:bininsert({player, given}, function(left, right)
                    return left[1] < right[1]
                end)
            end
        end
    end

    if awardedList:len() > 0 then
        frame:AddLine('Awarded To')

        for awardedItem in awardedList:iter() do
            local player = awardedItem[1]
            local given = awardedItem[2] and 'yes' or 'no'

            local _, classFileName = UnitClass(player)
            local classColor = RAID_CLASS_COLORS[classFileName]

            if classColor ~= nil then
                local playerColored = classColor:WrapTextInColorCode(player)
                frame:AddLine(string.format('  %s | Given: %s', playerColored, given))
            end
        end
    end
end
