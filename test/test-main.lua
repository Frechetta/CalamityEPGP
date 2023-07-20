require('test.setup')

local patch = Util.patch


describe('modifyEpgpSingle', function()
    local ns
    local addon

    local charGuid
    local reason

    local initialEp
    local initialGp

    local expectedPrinted
    local expectedNewEp
    local expectedNewGp

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

        charGuid = '0'
        reason = 'stuff: stuff'

        initialEp = nil
        initialGp = nil

        expectedPrinted = {}
        expectedNewEp = nil
        expectedNewGp = nil
    end)

    local doIt = function(mode, value, percent)
        ns.db.standings[charGuid] = {
            name = 'p1',
            ep = initialEp,
            gp = initialGp,
        }

        addon._modifyEpgpSingle(charGuid, mode, value, reason, percent)

        assert.same(expectedPrinted, addon.printed)
        assert.same(expectedNewEp, ns.db.standings[charGuid].ep)
        assert.same(expectedNewGp, ns.db.standings[charGuid].gp)
    end

    it('should return when LM mode is off', function()
        ns.cfg.lmMode = false

        expectedPrinted = {'Cannot modify EPGP when loot master mode is off'}

        doIt()
    end)

    it('should add EP', function()
        initialEp = 100
        initialGp = 300

        expectedNewEp = 150
        expectedNewGp = 300

        doIt('ep', 50, false)
    end)

    it('should substract EP', function()
        initialEp = 100
        initialGp = 300

        expectedNewEp = 90
        expectedNewGp = 300

        doIt('ep', -10, false)
    end)

    it('should add GP', function()
        initialEp = 100
        initialGp = 300

        expectedNewEp = 100
        expectedNewGp = 350

        doIt('gp', 50, false)
    end)

    it('should substract GP', function()
        initialEp = 100
        initialGp = 300

        expectedNewEp = 100
        expectedNewGp = 290

        doIt('gp', -10, false)
    end)

    it('should not let GP go below min', function()
        initialEp = 100
        initialGp = 300

        expectedNewEp = 100
        expectedNewGp = ns.cfg.gpBase

        doIt('gp', -100, false)
    end)

    it('should add EP %', function()
        initialEp = 150
        initialGp = 300

        expectedNewEp = 165
        expectedNewGp = 300

        doIt('ep', 10, true)
    end)

    it('should subtract EP %', function()
        initialEp = 150
        initialGp = 300

        expectedNewEp = 135
        expectedNewGp = 300

        doIt('ep', -10, true)
    end)

    it('should add GP %', function()
        initialEp = 150
        initialGp = 300

        expectedNewEp = 150
        expectedNewGp = 330

        doIt('gp', 10, true)
    end)

    it('should subtract GP %', function()
        initialEp = 150
        initialGp = 300

        expectedNewEp = 150
        expectedNewGp = 270

        doIt('gp', -10, true)
    end)

    it('should not let GP go below min %', function()
        initialEp = 150
        initialGp = 300

        expectedNewEp = 150
        expectedNewGp = ns.cfg.gpBase

        doIt('gp', -50, true)
    end)
end)


describe('modifyEpgp', function()
    local ns
    local addon

    local modifyEpgpSingleMock
    local syncAltEpGpMock

    local reason

    local expectedPrinted
    local expectedCalls

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
        Util:loadModule('lib', ns)
        Util:loadModule('main', ns)

        addon = ns.addon

        ns.Lib.hash = patch(function() return 0 end)

        modifyEpgpSingleMock = patch()
        addon._modifyEpgpSingle = modifyEpgpSingleMock

        syncAltEpGpMock = patch()
        addon.syncAltEpGp = syncAltEpGpMock

        ns.MainWindow = {}
        ns.MainWindow.refresh = patch()

        ns.HistoryWindow = {}
        ns.HistoryWindow.refresh = patch()

        ns.Comm = {}
        ns.Comm.sendUpdate = patch()

        reason = 'stuff: stuff'

        expectedPrinted = {}
        expectedCalls = {}
    end)

    local doIt = function(players, mode, value, percent)
        addon:modifyEpgp(players, mode, value, reason, percent)

        assert.same(expectedPrinted, addon.printed)
        assert.same(expectedCalls, modifyEpgpSingleMock.calls)

        local expectedSyncAltGpCalls = players and {{players}} or {}
        assert.same(expectedSyncAltGpCalls, syncAltEpGpMock.calls)
    end

    it('should return when LM mode is off', function()
        ns.cfg.lmMode = false

        expectedPrinted = {'Cannot modify EPGP when loot master mode is off'}

        doIt()
    end)

    it('no players', function()
        doIt({}, 'ep', 0, false)
    end)

    it('one player EP', function()
        local players = {'1'}

        expectedCalls = {
            {'1', 'ep', 50, reason, false}
        }

        doIt(players, 'ep', 50, false)
    end)

    it('one player GP', function()
        local players = {'1'}

        expectedCalls = {
            {'1', 'gp', 50, reason, false}
        }

        doIt(players, 'gp', 50, false)
    end)

    it('one player both', function()
        local players = {'1'}

        expectedCalls = {
            {'1', 'ep', 50, reason, false},
            {'1', 'gp', 50, reason, false},
        }

        doIt(players, 'both', 50, false)
    end)

    it('multiple players EP', function()
        local players = {'1', '2'}

        expectedCalls = {
            {'1', 'ep', 50, reason, false},
            {'2', 'ep', 50, reason, false},
        }

        doIt(players, 'ep', 50, false)
    end)

    it('multiple players GP', function()
        local players = {'1', '2'}

        expectedCalls = {
            {'1', 'gp', 50, reason, false},
            {'2', 'gp', 50, reason, false},
        }

        doIt(players, 'gp', 50, false)
    end)

    it('multiple players both', function()
        local players = {'1', '2'}

        expectedCalls = {
            {'1', 'ep', 50, reason, false},
            {'1', 'gp', 50, reason, false},
            {'2', 'ep', 50, reason, false},
            {'2', 'gp', 50, reason, false},
        }

        doIt(players, 'both', 50, false)
    end)

    it('multiple players %', function()
        local players = {'1', '2'}

        expectedCalls = {
            {'1', 'ep', -10, reason, true},
            {'1', 'gp', -10, reason, true},
            {'2', 'ep', -10, reason, true},
            {'2', 'gp', -10, reason, true},
        }

        doIt(players, 'both', -10, true)
    end)
end)


describe('handleEncounterEnd', function()
    local ns
    local addon

    local encounterNames

    local confirmWindowMsg
    local confirmWindowShowMock

    local modifyEpgpMock

    local success

    local expectedPrinted
    local expectedConfirmWindowMsg
    local expectedProceedCalled
    local expectedModifyEpgpCalls

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

        encounterNames = {
            e1 = 'E1',
            e2 = 'E2',
            e3 = 'E3',
        }

        confirmWindowMsg = nil
        confirmWindowShowMock = patch(function(_, msg, func)
            confirmWindowMsg = msg
            func()
        end)

        ns.ConfirmWindow = {}
        ns.ConfirmWindow.show = confirmWindowShowMock

        addon.raidRoster = ns.List:new({'1', '2'})

        ns.Lib.getPlayerGuid = patch(function(player) return 'g' .. player end)

        ns.printedPublic = {}
        ns.printPublic = patch(function(msg, _) table.insert(ns.printPublic, msg) end)

        modifyEpgpMock = patch(nil, true)
        addon.modifyEpgp = modifyEpgpMock

        addon.useForRaid = true
        success = 1

        expectedPrinted = {}
        expectedConfirmWindowMsg = nil
        expectedProceedCalled = false
        expectedModifyEpgpCalls = {}
    end)

    local doIt = function(encounterId)
        local encounterName
        if encounterId ~= nil then
            encounterName = encounterNames[encounterId]
        end

        addon:handleEncounterEnd(nil, encounterId, encounterName, nil, nil, success)

        assert.same(expectedPrinted, addon.printed)
        assert.same(expectedConfirmWindowMsg, confirmWindowMsg)
        assert.same(expectedProceedCalled, confirmWindowShowMock.called)
        assert.same(expectedModifyEpgpCalls, modifyEpgpMock.calls)
    end

    it('useForRaid off, fail', function()
        addon.useForRaid = false
        success = 0

        doIt()
    end)

    it('useForRaid off, success', function()
        addon.useForRaid = false
        success = 1

        doIt()
    end)

    it('useForRaid on, fail', function()
        addon.useForRaid = true
        success = 0

        doIt()
    end)

    it('no encounter', function()
        expectedPrinted = {'Encounter "E3" (e3) not in encounters table!'}
        doIt('e3')
    end)

    it('encounter 1', function()
        expectedConfirmWindowMsg = 'Award 1 EP to raid for killing E1?'
        expectedProceedCalled = true
        expectedModifyEpgpCalls = {{{'g1', 'g2'}, 'ep', 1, 'boss_kill: "E1" (e1)'}}

        doIt('e1')
    end)

    it('encounter 2', function()
        expectedConfirmWindowMsg = 'Award 2 EP to raid for killing E2?'
        expectedProceedCalled = true
        expectedModifyEpgpCalls = {{{'g1', 'g2'}, 'ep', 2, 'boss_kill: "E2" (e2)'}}

        doIt('e2')
    end)
end)
