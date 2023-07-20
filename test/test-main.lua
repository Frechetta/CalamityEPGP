local patch = Util.patch


TestModifyEpgpSingle = {}
    function TestModifyEpgpSingle:setUp()
        local ns = {
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

        self.ns = ns
        self.addon = ns.addon

        self.charGuid = '0'
        self.reason = 'stuff: stuff'

        self.initialEp = nil
        self.initialGp = nil

        self.expectedPrinted = {}
        self.expectedNewEp = nil
        self.expectedNewGp = nil
    end

    function TestModifyEpgpSingle:doIt(mode, vaLUe, percent)
        self.ns.db.standings[self.charGuid] = {
            name = 'p1',
            ep = self.initialEp,
            gp = self.initialGp,
        }

        self.addon._modifyEpgpSingle(self.charGuid, mode, vaLUe, self.reason, percent)

        LU.assertEquals(self.addon.printed, self.expectedPrinted)
        LU.assertEquals(self.ns.db.standings[self.charGuid].ep, self.expectedNewEp)
        LU.assertEquals(self.ns.db.standings[self.charGuid].gp, self.expectedNewGp)
    end

    function TestModifyEpgpSingle:testLmModeOff()
        self.ns.cfg.lmMode = false

        self.expectedPrinted = {'Cannot modify EPGP when loot master mode is off'}

        self:doIt()
    end

    function TestModifyEpgpSingle:testPosEp()
        self.initialEp = 100
        self.initialGp = 300

        self.expectedNewEp = 150
        self.expectedNewGp = 300

        self:doIt('ep', 50, false)
    end

    function TestModifyEpgpSingle:testNegEp()
        self.initialEp = 100
        self.initialGp = 300

        self.expectedNewEp = 90
        self.expectedNewGp = 300

        self:doIt('ep', -10, false)
    end

    function TestModifyEpgpSingle:testPosGp()
        self.initialEp = 100
        self.initialGp = 300

        self.expectedNewEp = 100
        self.expectedNewGp = 350

        self:doIt('gp', 50, false)
    end

    function TestModifyEpgpSingle:testNegGp()
        self.initialEp = 100
        self.initialGp = 300

        self.expectedNewEp = 100
        self.expectedNewGp = 290

        self:doIt('gp', -10, false)
    end

    function TestModifyEpgpSingle:testNegGpBelowMin()
        self.initialEp = 100
        self.initialGp = 300

        self.expectedNewEp = 100
        self.expectedNewGp = self.ns.cfg.gpBase

        self:doIt('gp', -100, false)
    end

    function TestModifyEpgpSingle:testPosPercEp()
        self.initialEp = 150
        self.initialGp = 300

        self.expectedNewEp = 165
        self.expectedNewGp = 300

        self:doIt('ep', 10, true)
    end

    function TestModifyEpgpSingle:testNegPercEp()
        self.initialEp = 150
        self.initialGp = 300

        self.expectedNewEp = 135
        self.expectedNewGp = 300

        self:doIt('ep', -10, true)
    end

    function TestModifyEpgpSingle:testPosPercGp()
        self.initialEp = 150
        self.initialGp = 300

        self.expectedNewEp = 150
        self.expectedNewGp = 330

        self:doIt('gp', 10, true)
    end

    function TestModifyEpgpSingle:testNegPercGp()
        self.initialEp = 150
        self.initialGp = 300

        self.expectedNewEp = 150
        self.expectedNewGp = 270

        self:doIt('gp', -10, true)
    end

    function TestModifyEpgpSingle:testNegPercGpBelowMin()
        self.initialEp = 150
        self.initialGp = 300

        self.expectedNewEp = 150
        self.expectedNewGp = self.ns.cfg.gpBase

        self:doIt('gp', -50, true)
    end
-- end of TestModifyEpgpSingle


TestModifyEpgp = {}
    function TestModifyEpgp:setUp()
        local ns = {
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

        self.ns = ns
        self.addon = ns.addon

        ns.Lib.hash = patch(function() return 0 end)

        self.modifyEpgpSingleMock = patch()
        self.addon._modifyEpgpSingle = self.modifyEpgpSingleMock

        self.syncAltEpGpMock = patch()
        self.addon.syncAltEpGp = self.syncAltEpGpMock

        ns.MainWindow = {}
        ns.MainWindow.refresh = patch()

        ns.HistoryWindow = {}
        ns.HistoryWindow.refresh = patch()

        ns.Comm = {}
        ns.Comm.sendUpdate = patch()

        self.reason = 'stuff: stuff'

        self.expectedPrinted = {}
        self.expectedCalls = {}
    end

    function TestModifyEpgp:doIt(players, mode, vaLUe, percent)
        self.addon:modifyEpgp(players, mode, vaLUe, self.reason, percent)

        LU.assertEquals(self.addon.printed, self.expectedPrinted)
        LU.assertEquals(self.modifyEpgpSingleMock.calls, self.expectedCalls)

        local expectedSyncAltGpCalls = players and {{players}} or {}
        LU.assertEquals(self.syncAltEpGpMock.calls, expectedSyncAltGpCalls)
    end

    function TestModifyEpgp:testLmModeOff()
        self.ns.cfg.lmMode = false

        self.expectedPrinted = {'Cannot modify EPGP when loot master mode is off'}

        self:doIt()
    end

    function TestModifyEpgp:testZeroPlayers()
        self:doIt({}, 'ep', 0, false)
    end

    function TestModifyEpgp:testOnePlayerEp()
        local players = {'1'}

        self.expectedCalls = {
            {'1', 'ep', 50, self.reason, false}
        }

        self:doIt(players, 'ep', 50, false)
    end

    function TestModifyEpgp:testOnePlayerGp()
        local players = {'1'}

        self.expectedCalls = {
            {'1', 'gp', 50, self.reason, false}
        }

        self:doIt(players, 'gp', 50, false)
    end

    function TestModifyEpgp:testOnePlayerBoth()
        local players = {'1'}

        self.expectedCalls = {
            {'1', 'ep', 50, self.reason, false},
            {'1', 'gp', 50, self.reason, false},
        }

        self:doIt(players, 'both', 50, false)
    end

    function TestModifyEpgp:testMulPlayerEp()
        local players = {'1', '2'}

        self.expectedCalls = {
            {'1', 'ep', 50, self.reason, false},
            {'2', 'ep', 50, self.reason, false},
        }

        self:doIt(players, 'ep', 50, false)
    end

    function TestModifyEpgp:testMulPlayerGp()
        local players = {'1', '2'}

        self.expectedCalls = {
            {'1', 'gp', 50, self.reason, false},
            {'2', 'gp', 50, self.reason, false},
        }

        self:doIt(players, 'gp', 50, false)
    end

    function TestModifyEpgp:testMulPlayerBoth()
        local players = {'1', '2'}

        self.expectedCalls = {
            {'1', 'ep', 50, self.reason, false},
            {'1', 'gp', 50, self.reason, false},
            {'2', 'ep', 50, self.reason, false},
            {'2', 'gp', 50, self.reason, false},
        }

        self:doIt(players, 'both', 50, false)
    end

    function TestModifyEpgp:testMulPlayerPerc()
        local players = {'1', '2'}

        self.expectedCalls = {
            {'1', 'ep', -10, self.reason, true},
            {'1', 'gp', -10, self.reason, true},
            {'2', 'ep', -10, self.reason, true},
            {'2', 'gp', -10, self.reason, true},
        }

        self:doIt(players, 'both', -10, true)
    end
-- end of TestModifyEpgp
