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

    it('should return when LM mode is off', function()
        ns.cfg.lmMode = false

        addon._modifyEpgpSingle()

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Cannot modify EPGP when loot master mode is off')
        assert.is.falsy(ns.db.standings[charGuid])
        assert.is.falsy(ns.db.standings[charGuid])
    end)

    it('should add EP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    it('should substract EP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', -10, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(90, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    it('should add GP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(350, ns.db.standings[charGuid].gp)
    end)

    it('should substract GP', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -10, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(290, ns.db.standings[charGuid].gp)
    end)

    it('should not let GP go below min', function()
        initEpGp(100, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -200, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.same(100, ns.db.standings[charGuid].ep)
        assert.same(ns.cfg.gpBase, ns.db.standings[charGuid].gp)
    end)

    it('should add EP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', 10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(165, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    it('should subtract EP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'ep', -10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(135, ns.db.standings[charGuid].ep)
        assert.same(300, ns.db.standings[charGuid].gp)
    end)

    it('should add GP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', 10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(330, ns.db.standings[charGuid].gp)
    end)

    it('should subtract GP %', function()
        initEpGp(150, 300)

        addon._modifyEpgpSingle(charGuid, 'gp', -10, reason, true)

        assert.spy(addon.Print).was.not_called()
        assert.same(150, ns.db.standings[charGuid].ep)
        assert.same(270, ns.db.standings[charGuid].gp)
    end)

    it('should not let GP go below min %', function()
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
            hash = function() return 0 end
        })

        ns.MainWindow = mock({
            refresh = function() end
        })

        ns.HistoryWindow = mock({
            refresh = function() end
        })

        ns.Comm = mock({
            sendUpdate = function() end
        })
    end)

    it('should return when LM mode is off', function()
        ns.cfg.lmMode = false

        addon:modifyEpgp()

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Cannot modify EPGP when loot master mode is off')
        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.not_called()
    end)

    it('no players', function()
        addon:modifyEpgp({}, 'ep', 0, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.not_called()
        assert.stub(addon.syncAltEpGp).was.called_with({})
    end)

    it('one player EP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(1)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    it('one player GP', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(1)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    it('one player both', function()
        local players = {'1'}

        addon:modifyEpgp(players, 'both', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    it('multiple players EP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'ep', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'ep', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'ep', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    it('multiple players GP', function()
        local players = {'1', '2'}

        addon:modifyEpgp(players, 'gp', 50, reason, false)

        assert.spy(addon.Print).was.not_called()
        assert.stub(addon._modifyEpgpSingle).was.called(2)
        assert.stub(addon._modifyEpgpSingle).was.called_with('1', 'gp', 50, reason, false)
        assert.stub(addon._modifyEpgpSingle).was.called_with('2', 'gp', 50, reason, false)
        assert.stub(addon.syncAltEpGp).was.called_with(players)
    end)

    it('multiple players both', function()
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

    it('multiple players %', function()
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
                    e1 = 1,
                    e2 = 2,
                },
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

        ns.Lib = mock({
            getPlayerGuid = function(player)
                return 'g' .. player
            end
        })

        addon.useForRaid = true
        addon.raidRoster = ns.List:new({'1', '2'})
    end)

    it('useForRaid off, fail', function()
        addon.useForRaid = false

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 0)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    it('useForRaid off, success', function()
        addon.useForRaid = false

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    it('useForRaid on, fail', function()
        addon.useForRaid = true

        addon:handleEncounterEnd(nil, nil, nil, nil, nil, 0)

        assert.spy(addon.Print).was.not_called()
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    it('unknown encounter', function()
        addon:handleEncounterEnd(nil, 'e3', 'E3', nil, nil, 1)

        assert.spy(addon.Print).was.called(1)
        assert.spy(addon.Print).was.called_with(addon, 'Encounter "E3" (e3) not in encounters table!')
        assert.is.falsy(confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.not_called()
        assert.stub(addon.modifyEpgp).was.not_called()
    end)

    it('encounter 1', function()
        addon:handleEncounterEnd(nil, 'e1', 'E1', nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.same('Award 1 EP to raid for killing E1?', confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.called(1)
        assert.stub(addon.modifyEpgp).was.called(1)
        assert.stub(addon.modifyEpgp).was.called_with(addon, {'g1', 'g2'}, 'ep', 1, 'boss_kill: "E1" (e1)')
    end)

    it('encounter 2', function()
        addon:handleEncounterEnd(nil, 'e2', 'E2', nil, nil, 1)

        assert.spy(addon.Print).was.not_called()
        assert.same('Award 2 EP to raid for killing E2?', confirmWindowMsg)
        assert.spy(ns.ConfirmWindow.show).was.called(1)
        assert.stub(addon.modifyEpgp).was.called(1)
        assert.stub(addon.modifyEpgp).was.called_with(addon, {'g1', 'g2'}, 'ep', 2, 'boss_kill: "E2" (e2)')
    end)
end)
