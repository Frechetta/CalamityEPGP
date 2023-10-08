loadfile('test/setup.lua')(spy, stub, mock)

local match = require('luassert.match')

local function unordered_table(state, arguments)
    local expected = arguments[1]

    local expectedMap = {}
    for _, item in ipairs(expected) do
        expectedMap[item] = true
    end

    assert(type(expected) == 'table')

    return function(actual)
        if type(actual) ~= 'table' then
            return false
        end

        if #expected ~= #actual then
            return false
        end

        for _, item in ipairs(actual) do
            if expectedMap[item] == nil then
                return false
            end
        end

        return true
    end
end

assert:register('matcher', 'unordered_table', unordered_table)


describe('confirm', function()
    local ns
    local dew

    local amount
    local reason
    local validValue

    before_each(function()
        ns = {
            cfg = {},
        }

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('window-decay-epgp', ns)
        Util:loadModule('main', ns)

        ns.standings = ns.Dict:new({
            p1_guid = {guid = 'p1_guid'},
            p2_guid = {guid = 'p2_guid'},
            p3_guid = {guid = 'p3_guid'},
        })

        dew = ns.DecayEpgpWindow

        amount = nil
        reason = nil
        validValue = nil

        dew.mainFrame = mock({
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
        stub(dew, 'hide')
    end)

    test('invalid value, value 0', function()
        amount = '0'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('invalid value, value -2000', function()
        amount = '-2000'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('invalid value, value 150', function()
        amount = '150'
        reason = 'because'
        validValue = false

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value 0', function()
        amount = '0'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value -1001', function()
        amount = '-2000'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value 101', function()
        amount = '150'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.not_called()
        assert.stub(dew.hide).was.not_called()
    end)

    test('valid value, value normal', function()
        amount = '10'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, match.unordered_table({'p1_guid', 'p2_guid', 'p3_guid'}), 'both', -10, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)

    test('valid value, value -1000', function()
        amount = '-1000'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, match.unordered_table({'p1_guid', 'p2_guid', 'p3_guid'}), 'both', 1000, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)

    test('valid value, value 100', function()
        amount = '100'
        reason = 'because'
        validValue = true

        dew:confirm()

        assert.stub(ns.addon.modifyEpgp).was.called(1)
        assert.stub(ns.addon.modifyEpgp).was.called_with(ns.addon, match.unordered_table({'p1_guid', 'p2_guid', 'p3_guid'}), 'both', -100, '2:because', true)

        assert.stub(dew.hide).was.called(1)
    end)
end)
