loadfile('test/setup.lua')(spy, stub, mock)


describe('confirm', function()
    local ns
    local aew

    local amount
    local reason
    local validValue

    before_each(function()
        ns = {
            cfg = {},
            db = {
                benchedPlayers = {},
                standings = {
                    {guid = 'p1_guid'},
                    {guid = 'p2_guid'},
                    {guid = 'p3_guid'},
                },
            },
        }

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('window-add-ep', ns)
        Util:loadModule('main', ns)

        aew = ns.AddEpWindow

        amount = nil
        reason = nil
        validValue = nil

        ns.addon.raidRoster = ns.List:new({'p1', 'p2'})

        aew.mainFrame = mock({
            amountEditBox = mock({
                GetText = function() return amount end
            }),
            reasonEditBox = mock({
                GetText = function() return reason end
            }),
        })

        ns.MainWindow = {
            raidOnly = false,

            getRaidOnly = function(self)
                return self.raidOnly
            end,

            setRaidOnly = function(self, raidOnly)
                self.raidOnly = raidOnly
            end
        }

        ns.Lib.validateEpgpValue = function(_)
            return validValue
        end

        ns.Lib.getPlayerGuid = function(playerName)
            return playerName .. '_guid'
        end

        ns.ConfirmWindow = mock({
            show = function(_, msg, callback)
                callback()
            end
        })

        stub(ns.addon, 'modifyEpgp')
        stub(ns, 'printPublic')
        stub(aew, 'hide')
    end)

    test('invalid value, reason non-empty, raidOnly false', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.not_called()
    end)

    test('invalid value, reason empty, raidOnly false', function()
        amount = 'hi'
        reason = ''
        validValue = false
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.not_called()
    end)

    test('invalid value, reason non-empty, raidOnly true', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.MainWindow:setRaidOnly(true)
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, raidOnly false', function()
        amount = '45'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'ep', 45, 'manual_multiple: because')

        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.called(1)
    end)

    test('valid value, reason empty, raidOnly false', function()
        amount = '45'
        reason = ''
        validValue = true
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, raidOnly true, useForRaid false, bench empty', function()
        amount = '45'
        reason = 'because'
        validValue = true
        ns.MainWindow:setRaidOnly(true)
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid'}, 'ep', 45, 'manual_multiple: because')

        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, raidOnly true, useForRaid true, bench empty', function()
        amount = '45'
        reason = 'because'
        validValue = true
        ns.MainWindow:setRaidOnly(true)
        ns.addon.useForRaid = true
        ns.db.benchedPlayers = {}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid'}, 'ep', 45, 'manual_multiple: because')

        assert.stub(ns.printPublic).was.called(1)
        assert.stub(ns.printPublic).was.called_with('Awarded 45 EP to raid. Reason: because')

        assert.stub(aew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, raidOnly true, useForRaid false, bench non-empty', function()
        amount = '45'
        reason = 'because'
        validValue = true
        ns.MainWindow:setRaidOnly(true)
        ns.addon.useForRaid = false
        ns.db.benchedPlayers = {'p3'}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid'}, 'ep', 45, 'manual_multiple: because')
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'ep', 45, 'manual_multiple: because BENCH')

        assert.stub(ns.printPublic).was.not_called()
        assert.stub(aew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, raidOnly true, useForRaid true, bench non-empty', function()
        amount = '45'
        reason = 'because'
        validValue = true
        ns.MainWindow:setRaidOnly(true)
        ns.addon.useForRaid = true
        ns.db.benchedPlayers = {'p3'}

        aew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid'}, 'ep', 45, 'manual_multiple: because')
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'ep', 45, 'manual_multiple: because BENCH')

        assert.stub(ns.printPublic).was.called(1)
        assert.stub(ns.printPublic).was.called_with('Awarded 45 EP to raid. Reason: because')

        assert.stub(aew.hide).was.called(1)
    end)
end)
