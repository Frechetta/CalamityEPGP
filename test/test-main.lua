loadfile('test/setup.lua')(spy, stub, mock)


describe('modifyEpgpSingle', function()
    local ns
    local addon

    local charGuid = '0'
    local reason = 'stuff: stuff'

    before_each(function()
        ns = {
            cfg = {
                lmMode = true,
                gpBase = 250,
            },
            db = {
                standings = {}
            }
        }

        Util:loadModule('constants', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('main', ns)

        addon = ns.addon
    end)

    local initEpGp = function(initialEp, initialGp)
        ns.db.standings[charGuid] = {
            name = 'p1',
            ep = initialEp,
            gp = initialGp,
        }
    end

    test('return when LM mode is off', function()
        ns.cfg.lmMode = false

        addon._modifyEpgpSingle()

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Cannot modify EPGP when loot master mode is off')
        assert.is.falsy(ns.db.standings[charGuid])
        assert.is.falsy(ns.db.standings[charGuid])
    end)

    test('add EP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    test('substract EP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', -10, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(90, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    test('add GP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(350, ns.db.standings[charGuid].gp)
    end)

    test('subtract GP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -10, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(290, ns.db.standings[charGuid].gp)
    end)

    test('don\'t let GP go below min', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -200, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(ns.cfg.gpBase, ns.db.standings[charGuid].gp)
    end)

    test('add EP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', 10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(165, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    test('subtract EP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', -10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(135, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    test('add GP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', 10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(330, ns.db.standings[charGuid].gp)
    end)

    test('subtract GP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(270, ns.db.standings[charGuid].gp)
    end)

    test('don\'t let GP go below min %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -50, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(ns.cfg.gpBase, ns.db.standings[charGuid].gp)
    end)
end)


describe('modifyEpgp', function()
    local ns
    local addon

    local reason = 'stuff: stuff'

    before_each(function()
        ns = {
            cfg = {
                lmMode = true,
                gpBase = 250,
            },
            db = {
                standings = {},
                history = {},
            }
        }

        Util:loadModule('constants', ns)
        Util:loadModule('main', ns)

        addon = ns.addon

        stub(addon, '_modifyEpgpSingle')
        stub(addon, 'syncAltEpGp')

        ns.Lib = mock({
            hash = function() return 0 end,
            getShortPlayerGuid = function(guid)
                return guid
            end
        })

        ns.MainWindow = mock({
            refresh = function() end
        })

        ns.HistoryWindow = mock({
            refresh = function() end
        })

        ns.Comm = mock({
            sendStandingsToGuild = function() end,
            sendEventToGuild = function(eventAndHash) end
        })
    end)

    test('error when LM mode is off', function()
        ns.cfg.lmMode = false

        assert.has_error(function() addon:modifyEpgp() end, 'Cannot modify EPGP when loot master mode is off')

        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('error when mode is wrong 1', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'EP') end, 'Mode (EP) is not one of allowed modes')

        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('error when mode is wrong 2', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'GP') end, 'Mode (GP) is not one of allowed modes')

        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('error when mode is wrong 3', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'BOTH') end, 'Mode (BOTH) is not one of allowed modes')

        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('error when mode is wrong 4', function()
        assert.has_error(function() addon:modifyEpgp(nil, 'derp') end, 'Mode (derp) is not one of allowed modes')

        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('no players', function()
        addon:modifyEpgp({}, 'ep', 0, reason, false)

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Won\'t modify EP/GP for 0 players')
        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    test('one player EP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(1)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('one player GP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(1)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('one player both', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'both', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('multiple players EP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'ep', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('multiple players GP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('multiple players both', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'both', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(4)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    test('multiple players %', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'both', -10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(4)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', -10, reason, true)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', -10, reason, true)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'ep', -10, reason, true)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'gp', -10, reason, true)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
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
