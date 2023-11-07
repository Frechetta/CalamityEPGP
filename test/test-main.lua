loadfile('test/setup.lua')(spy, stub, mock)

local match = require('luassert.match')

local function any_function(state, arguments)
    return function(actual)
        return type(actual) == 'function'
    end
end

assert:register('matcher', 'any_function', any_function)


describe('modifyEpgp', function()
    local ns
    local addon

    local reason = '0:stuff'

    before_each(function()
        ns = {
            cfg = {
                lmMode = true,
                gpBase = 250,
            },
            db = {
                history = {},
                altData = {
                    altMainMapping = {},
                    mainAltMapping = {},
                },
            },
        }

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('window-history', ns)
        Util:loadModule('main', ns)

        ns.knownPlayers = ns.Dict:new()
        ns.standings = ns.Dict:new()
        ns.playersLastUpdated = ns.Dict:new()

        addon = ns.addon

        spy.on(addon, 'createHistoryEvent')
        spy.on(addon, 'computeStandingsWithEvents')
        stub(ns, 'debug')

        ns.Lib.hash = function() return 0 end
        ns.Lib.getShortPlayerGuid = function(guid)
            return guid
        end
        ns.Lib.getFullPlayerGuid = function(guid)
            return guid
        end
        ns.Lib.getPlayerInfo = function(guid, callback)
            callback = callback or function() end
            ns.knownPlayers:set(guid, {name = 'p' .. guid})
            callback()
        end

        ns.MainWindow = mock({
            refresh = function() end
        })

        ns.RaidWindow = mock({
            refresh = function() end
        })

        ns.HistoryWindow.refresh = spy.new(function() end)

        ns.Sync = mock({
            sendEventsToGuild = function(_) end,
            computeIndices = function() end,
        })
    end)

    test('error when LM mode is off', function()
        ns.cfg.lmMode = false

        assert.has_error(function() addon:modifyEpgp() end, 'Cannot modify EPGP when loot master mode is off')

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('error when mode is wrong 1', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'EP') end, 'Mode (EP) is not one of allowed modes')

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('error when mode is wrong 2', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'GP') end, 'Mode (GP) is not one of allowed modes')

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('error when mode is wrong 3', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'BOTH') end, 'Mode (BOTH) is not one of allowed modes')

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('error when mode is wrong 4', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'derp') end, 'Mode (derp) is not one of allowed modes')

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('no players', function()
        addon:modifyEpgp({}, 'ep', 0, reason, false)

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Won\'t modify EP/GP for 0 players')
        assert.spy(addon.createHistoryEvent).was.not_called()
        assert.spy(addon.computeStandingsWithEvents).was.not_called()
        assert.stub(ns.MainWindow.refresh).was.not_called()
        assert.stub(ns.RaidWindow.refresh).was.not_called()
        assert.stub(ns.HistoryWindow.refresh).was.not_called()
        assert.stub(ns.Sync.sendEventsToGuild).was.not_called()
        assert.stub(ns.debug).was.not_called()
        assert.same({}, ns.db.history)
        assert.is_true(ns.standings:isEmpty())
    end)

    test('one player EP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        local event = {{123, 'p1_guid', {'1'}, 'ep', 50, reason, false, 250}, 0}

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.called(1)
        assert.spy(addon.createHistoryEvent).was.called_with({'1'}, 'ep', 50, reason, false)
        assert.spy(addon.computeStandingsWithEvents).was.called(1)
        assert.spy(addon.computeStandingsWithEvents).was.called_with(addon, {event}, match.any_function())
        assert.stub(ns.MainWindow.refresh).was.called(2)
        assert.stub(ns.RaidWindow.refresh).was.called(2)
        assert.stub(ns.HistoryWindow.refresh).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called_with(ns.Sync, {event})
        assert.stub(ns.debug).was.called(1)
        assert.stub(ns.debug).was.called_with('p1 gained 50.00 EP (Manual)')
        assert.same({event}, ns.db.history)
        assert.same({['1'] = {guid = '1', ep = 50, gp = 250}}, ns.standings._dict)
    end)

    test('one player GP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        local event = {{123, 'p1_guid', {'1'}, 'gp', 50, reason, false, 250}, 0}

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.called(1)
        assert.spy(addon.createHistoryEvent).was.called_with({'1'}, 'gp', 50, reason, false)
        assert.spy(addon.computeStandingsWithEvents).was.called(1)
        assert.spy(addon.computeStandingsWithEvents).was.called_with(addon, {event}, match.any_function())
        assert.stub(ns.MainWindow.refresh).was.called(2)
        assert.stub(ns.RaidWindow.refresh).was.called(2)
        assert.stub(ns.HistoryWindow.refresh).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called_with(ns.Sync, {event})
        assert.stub(ns.debug).was.called(1)
        assert.stub(ns.debug).was.called_with('p1 gained 50.00 GP (Manual)')
        assert.same({event}, ns.db.history)
        assert.same({['1'] = {guid = '1', ep = 0, gp = 300}}, ns.standings._dict)
    end)

    test('multiple players EP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        local event = {{123, 'p1_guid', {'1', '2'}, 'ep', 50, reason, false, 250}, 0}

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.called(1)
        assert.spy(addon.createHistoryEvent).was.called_with({'1', '2'}, 'ep', 50, reason, false)
        assert.spy(addon.computeStandingsWithEvents).was.called(1)
        assert.spy(addon.computeStandingsWithEvents).was.called_with(addon, {event}, match.any_function())
        assert.stub(ns.MainWindow.refresh).was.called(2)
        assert.stub(ns.RaidWindow.refresh).was.called(2)
        assert.stub(ns.HistoryWindow.refresh).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called_with(ns.Sync, {event})
        assert.stub(ns.debug).was.called(2)
        assert.stub(ns.debug).was.called_with('p1 gained 50.00 EP (Manual)')
        assert.stub(ns.debug).was.called_with('p2 gained 50.00 EP (Manual)')
        assert.same({event}, ns.db.history)
        assert.same({['1'] = {guid = '1', ep = 50, gp = 250}, ['2'] = {guid = '2', ep = 50, gp = 250}}, ns.standings._dict)
    end)

    test('multiple players GP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        local event = {{123, 'p1_guid', {'1', '2'}, 'gp', 50, reason, false, 250}, 0}

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.called(1)
        assert.spy(addon.createHistoryEvent).was.called_with({'1', '2'}, 'gp', 50, reason, false)
        assert.spy(addon.computeStandingsWithEvents).was.called(1)
        assert.spy(addon.computeStandingsWithEvents).was.called_with(addon, {event}, match.any_function())
        assert.stub(ns.MainWindow.refresh).was.called(2)
        assert.stub(ns.RaidWindow.refresh).was.called(2)
        assert.stub(ns.HistoryWindow.refresh).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called_with(ns.Sync, {event})
        assert.stub(ns.debug).was.called(2)
        assert.stub(ns.debug).was.called_with('p1 gained 50.00 GP (Manual)')
        assert.stub(ns.debug).was.called_with('p2 gained 50.00 GP (Manual)')
        assert.same({event}, ns.db.history)
        assert.same({['1'] = {guid = '1', ep = 0, gp = 300}, ['2'] = {guid = '2', ep = 0, gp = 300}}, ns.standings._dict)
    end)

    test('multiple players %', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'ep', -50, reason, false)

        local event = {{123, 'p1_guid', {'1'}, 'ep', -50, reason, false, 250}, 0}

        assert.spy(addon.Print).was.not_called()
        assert.spy(addon.createHistoryEvent).was.called(1)
        assert.spy(addon.createHistoryEvent).was.called_with({'1'}, 'ep', -50, reason, false)
        assert.spy(addon.computeStandingsWithEvents).was.called(1)
        assert.spy(addon.computeStandingsWithEvents).was.called_with(addon, {event}, match.any_function())
        assert.stub(ns.MainWindow.refresh).was.called(2)
        assert.stub(ns.RaidWindow.refresh).was.called(2)
        assert.stub(ns.HistoryWindow.refresh).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called(1)
        assert.stub(ns.Sync.sendEventsToGuild).was.called_with(ns.Sync, {event})
        assert.stub(ns.debug).was.called(1)
        assert.stub(ns.debug).was.called_with('p1 lost 50.00 EP (Manual)')
        assert.same({event}, ns.db.history)
        assert.same({['1'] = {guid = '1', ep = -50, gp = 250}}, ns.standings._dict)
    end)
end)


describe('handleEncounterEnd', function()
    local ns
    local addon

    local confirmWindowMsg

    before_each(function()
        ns = {
            cfg = {
                encounterEp = {
                    [51] = 1,
                    [52] = 2,
                },
            },
            db = {
                benchedPlayers = {},
            },
        }

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('main', ns)

        addon = ns.addon

        stub(ns, 'printPublic')
        stub(addon, 'modifyEpgp')

        confirmWindowMsg = nil

        ns.ConfirmWindow = mock({
            show = function(_, msg, func)
                confirmWindowMsg = msg
                func()
            end
        })

        ns.Lib.getPlayerGuid = spy.new(function(player)
            return 'g' .. player
        end)

        addon.useForRaid = true
        addon.raidRoster = ns.List:new({'1', '2'})
    end)

    test('useForRaid off, fail', function()
        addon.useForRaid = false

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 0)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    test('useForRaid off, success', function()
        addon.useForRaid = false

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    test('useForRaid on, fail', function()
        addon.useForRaid = true

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 0)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    test('unknown encounter', function()
        addon:handleEncounterEnd(nil, 53, 'E3', nil, nil, 1)

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Encounter 53 (E3) not in encounters table!')
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    test('encounter no benched players', function()
        addon:handleEncounterEnd(nil, 51, 'E1', nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.same('Award 1 EP to raid for killing E1?', confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.called(1)
        assert.stub(addon.modifyEpgp).was.called(1)
        assert.stub(addon.modifyEpgp).was.called_with(addon, {'g1', 'g2'}, 'ep', 1, '4:51')
    end)

    test('encounter 2 benched players', function()
        ns.db.benchedPlayers = {'3', '4'}

        addon:handleEncounterEnd(nil, 52, 'E2', nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.same('Award 2 EP to raid for killing E2?', confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.called(1)
        assert.stub(addon.modifyEpgp).was.called(2)
        assert.stub(addon.modifyEpgp).was.called_with(addon, {'g1', 'g2'}, 'ep', 2, '4:52')
        assert.stub(addon.modifyEpgp).was.called_with(addon, {'g3', 'g4'}, 'ep', 2, '4:52:1')
    end)
end)
