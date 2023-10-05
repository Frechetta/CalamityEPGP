loadfile('test/setup.lua')(spy, stub, mock)


describe('confirm', function()
    local ns
    local mew

    local amount
    local reason
    local validValue

    before_each(function()
        ns = {
            cfg = {},
            db = {
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
        Util:loadModule('window-modify-epgp', ns)
        Util:loadModule('main', ns)

        mew = ns.ModifyEpgpWindow

        amount = nil
        reason = nil
        validValue = nil

        ns.addon.raidRoster = ns.List:new({'p1', 'p2'})

        mew.mainFrame = mock({
            amountEditBox = mock({
                GetText = function() return amount end
            }),
            reasonEditBox = mock({
                GetText = function() return reason end
            }),
        })

        ns.Lib.validateEpgpValue = function(_)
            return validValue
        end

        stub(ns.addon, 'modifyEpgp')
        stub(ns, 'printPublic')
        stub(mew, 'hide')
    end)

    test('invalid value, reason non-empty, useForRaid false, player in raid', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason non-empty, useForRaid false, player not in raid', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.addon.useForRaid = false

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason non-empty, useForRaid true, player in raid', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.addon.useForRaid = true

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason non-empty, useForRaid true, player not in raid', function()
        amount = 'hi'
        reason = 'because'
        validValue = false
        ns.addon.useForRaid = true

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason empty, useForRaid false, player in raid', function()
        amount = 'hi'
        reason = ''
        validValue = false
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason empty, useForRaid false, player not in raid', function()
        amount = 'hi'
        reason = ''
        validValue = false
        ns.addon.useForRaid = false

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason empty, useForRaid true, player in raid', function()
        amount = 'hi'
        reason = ''
        validValue = false
        ns.addon.useForRaid = true

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('invalid value, reason empty, useForRaid true, player not in raid', function()
        amount = 'hi'
        reason = ''
        validValue = false
        ns.addon.useForRaid = true

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player in raid', function()
        amount = '31'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'ep', 31, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid', function()
        amount = '31'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'ep', 31, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, useForRaid true, player in raid', function()
        amount = '31'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = true

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'ep', 31, '0:because')

        assert.stub(ns.printPublic).was.called(1)
        assert.stub(ns.printPublic).was.called_with('Awarded 31 EP to p1. Reason: because')

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, useForRaid true, player not in raid', function()
        amount = '31'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = true

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'ep', 31, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason empty, useForRaid false, player in raid', function()
        amount = '31'
        reason = ''
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason empty, useForRaid false, player not in raid', function()
        amount = '31'
        reason = ''
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason empty, useForRaid true, player in raid', function()
        amount = '31'
        reason = ''
        validValue = true
        ns.addon.useForRaid = true

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason empty, useForRaid true, player not in raid', function()
        amount = '31'
        reason = ''
        validValue = true
        ns.addon.useForRaid = true

        mew.charName = 'p3'
        mew.charGuid = 'p3_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value nil', function()
        amount = nil
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value 0', function()
        amount = '0'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value -1000001', function()
        amount = '-1000001'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value 1000001', function()
        amount = '1000001'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(ns.printPublic).was.not_called()
        assert.stub(mew.hide).was.not_called()
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value -1000000', function()
        amount = '-1000000'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'ep', -1000000, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value 1000000', function()
        amount = '1000000'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'ep'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'ep', 1000000, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)

    test('valid value, reason non-empty, useForRaid false, player not in raid, value 150, gp', function()
        amount = '150'
        reason = 'because'
        validValue = true
        ns.addon.useForRaid = false

        mew.charName = 'p1'
        mew.charGuid = 'p1_guid'
        mew.mode = 'gp'

        mew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 150, '0:because')

        assert.stub(ns.printPublic).was.not_called()

        assert.stub(mew.hide).was.called(1)
    end)
end)
