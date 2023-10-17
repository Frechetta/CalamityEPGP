loadfile('test/setup.lua')(spy, stub, mock)


describe('confirm', function()
    local ns
    local dew

    local amountEp
    local amountGp
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
        Util:loadModule('window-decay-epgp', ns)
        Util:loadModule('main', ns)

        dew = ns.DecayEpgpWindow

        amountEp = nil
        amountGp = nil
        reason = nil
        validValue = nil

        dew.mainFrame = mock({
            amountEditBoxEp = mock({
                GetText = function() return amountEp end
            }),
            amountEditBoxGp = mock({
                GetText = function() return amountGp end
            }),
            reasonEditBox = mock({
                GetText = function() return reason end
            }),
        })

        ns.Lib.validateEpgpValue = function(_)
            return validValue
        end

        stub(ns.addon, 'modifyEpgp')
        stub(dew, 'hide')
    end)

    test('invalid value, value 0', function()
        amountEp = '0'
        amountGp = '0'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('invalid value, value -2000', function()
        amountEp = '-2000'
        amountGp = '-2000'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('invalid value, value 150', function()
        amountEp = '150'
        amountGp = '150'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value 0', function()
        amountEp = '0'
        amountGp = '0'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value -1001', function()
        amountEp = '-2000'
        amountGp = '-2000'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value 101', function()
        amountEp = '150'
        amountGp = '150'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value normal', function()
        amountEp = '10'
        amountGp = '10'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'ep', -10, '2:because', true)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'gp', -10, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)

    test('valid value, value -1000', function()
        amountEp = '-1000'
        amountGp = '-1000'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'ep', 1000, '2:because', true)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'gp', 1000, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)

    test('valid value, value 100', function()
        amountEp = '100'
        amountGp = '100'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'ep', -100, '2:because', true)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'gp', -100, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)

    test('valid value, valueEp 10, valueGp 15', function()
        amountEp = '10'
        amountGp = '15'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(2)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'ep', -10, '2:because', true)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid', 'p2_guid', 'p3_guid'}, 'gp', -15, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)
end)
