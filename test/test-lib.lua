loadfile('test/setup.lua')(spy, stub, mock)

local ns = {}
Util:loadModule('constants', ns)
Util:loadModule('datatypes', ns)

describe('lib', function()
    local Lib

    before_each(function()
        Util:loadModule('lib', ns)
        Lib = ns.Lib
    end)

    after_each(function()
        ns.Lib = nil
        Lib = nil
    end)

    describe('equals', function()
        describe('number', function()
            test('same not ignore', function()
                assert.is_true(Lib.equals(23, 23, false))
            end)

            test('same ignore', function()
                assert.is_true(Lib.equals(23, 23, true))
            end)

            test('different not ignore', function()
                assert.is_false(Lib.equals(23, 59, false))
            end)

            test('different ignore', function()
                assert.is_false(Lib.equals(23, 59, true))
            end)
        end)

        describe('string', function()
            test('same not ignore', function()
                assert.is_true(Lib.equals('hello', 'hello', false))
            end)

            test('same ignore', function()
                assert.is_true(Lib.equals('hello', 'hello', true))
            end)

            test('different not ignore', function()
                assert.is_false(Lib.equals('hello', 'hola', false))
            end)

            test('different ignore', function()
                assert.is_false(Lib.equals('hello', 'hola', true))
            end)
        end)

        describe('table', function()
            test('basic same not ignore', function()
                assert.is_true(Lib.equals({5, 6, 7}, {5, 6, 7}, false))
            end)

            test('basic same ignore', function()
                assert.is_true(Lib.equals({5, 6, 7}, {5, 6, 7}, true))
            end)

            test('basic different not ignore', function()
                assert.is_false(Lib.equals({5, 6, 7}, {7, 8}, false))
            end)

            test('basic different ignore', function()
                assert.is_false(Lib.equals({5, 6, 7}, {7, 8}, true))
            end)

            test('complex same not ignore', function()
                assert.is_true(Lib.equals({five = 5, six = 'six', seven = {7}}, {five = 5, six = 'six', seven = {7}}, false))
            end)

            test('complex same ignore', function()
                assert.is_true(Lib.equals({five = 5, six = 'six', seven = {7}}, {five = 5, six = 'six', seven = {7}}, true))
            end)

            test('complex different not ignore', function()
                assert.is_false(Lib.equals({five = 5, six = 'six', seven = {7}}, {five = 5, seven = {7}}, false))
            end)

            test('complex different ignore', function()
                assert.is_false(Lib.equals({five = 5, six = 'six', seven = {7}}, {five = 5, seven = {7}}, true))
            end)
        end)
    end)

    describe('find', function()
        test('container valid; value nil', function()
            assert.has_error(function() Lib.find({1, 2}, nil) end, 'value argument must not be nil')
        end)

        test('container nil; value valid', function()
            assert.has_error(function() Lib.find(nil, 5) end, 'container argument must not be nil')
        end)

        test('container nil; value nil', function()
            assert.has_error(function() Lib.find(nil, nil) end, 'container argument must not be nil')
        end)

        test('container invalid type', function()
            assert.has_error(function() Lib.find(2, 5) end, 'container argument type is unsupported')
        end)

        test('container table; container empty', function()
            local expected = -1
            local actual = Lib.find({}, 5)

            assert.is.same(expected, actual)
        end)

        test('container table; single element; value in container', function()
            local expected = 1
            local actual = Lib.find({5}, 5)

            assert.is.same(expected, actual)
        end)

        test('container table; single element; value not in container', function()
            local expected = -1
            local actual = Lib.find({5}, 3)

            assert.is.same(expected, actual)
        end)

        test('container table; multiple elements 1; value in container', function()
            local expected = 1
            local actual = Lib.find({5, 6, 7}, 5)

            assert.is.same(expected, actual)
        end)

        test('container table; multiple elements 2; value in container', function()
            local expected = 2
            local actual = Lib.find({5, 6, 7}, 6)

            assert.is.same(expected, actual)
        end)

        test('container table; multiple elements 3; value in container', function()
            local expected = 3
            local actual = Lib.find({5, 6, 7}, 7)

            assert.is.same(expected, actual)
        end)

        test('container table; multiple elements; value not in container', function()
            local expected = -1
            local actual = Lib.find({5, 6, 7}, 8)

            assert.is.same(expected, actual)
        end)

        test('container table; multiple elements; value not in container; different type', function()
            local expected = -1
            local actual = Lib.find({5, 6, 7}, '5')

            assert.is.same(expected, actual)
        end)

        test('container string; container empty', function()
            local expected = -1
            local actual = Lib.find('', 'g')

            assert.is.same(expected, actual)
        end)

        test('container string; single element; value in container', function()
            local expected = 1
            local actual = Lib.find('g', 'g')

            assert.is.same(expected, actual)
        end)

        test('container string; single element; value not in container', function()
            local expected = -1
            local actual = Lib.find('g', 'z')

            assert.is.same(expected, actual)
        end)

        test('container string; multiple elements 1; value in container', function()
            local expected = 1
            local actual = Lib.find('hey', 'h')

            assert.is.same(expected, actual)
        end)

        test('container string; multiple elements 2; value in container', function()
            local expected = 2
            local actual = Lib.find('hey', 'e')

            assert.is.same(expected, actual)
        end)

        test('container string; multiple elements 3; value in container', function()
            local expected = 3
            local actual = Lib.find('hey', 'y')

            assert.is.same(expected, actual)
        end)

        test('container string; multiple elements; value not in container', function()
            local expected = -1
            local actual = Lib.find('hey', 'g')

            assert.is.same(expected, actual)
        end)

        test('container string; multiple elements; value not in container; different type', function()
            local expected = -1
            local actual = Lib.find('hey', 5)

            assert.is.same(expected, actual)
        end)
    end)

    describe('contains', function()
        test('container valid; value nil', function()
            assert.has_error(function() Lib.contains({1, 2}, nil) end, 'value argument must not be nil')
        end)

        test('container nil; value valid', function()
            assert.has_error(function() Lib.contains(nil, 5) end, 'container argument must not be nil')
        end)

        test('container nil; value nil', function()
            assert.has_error(function() Lib.contains(nil, nil) end, 'container argument must not be nil')
        end)

        test('container invalid type', function()
            assert.has_error(function() Lib.contains(2, 5) end, 'container argument type is unsupported')
        end)

        test('container list; container empty', function()
            local present = Lib.contains({}, 5)
            assert.is_false(present)
        end)

        test('container list; single element; value in container', function()
            local present = Lib.contains({5}, 5)
            assert.is_true(present)
        end)

        test('container list; single element; value not in container', function()
            local present = Lib.contains({5}, 3)
            assert.is_false(present)
        end)

        test('container list; multiple elements 1; value in container', function()
            local present = Lib.contains({5, 6, 7}, 5)
            assert.is_true(present)
        end)

        test('container list; multiple elements 2; value in container', function()
            local present = Lib.contains({5, 6, 7}, 6)
            assert.is_true(present)
        end)

        test('container list; multiple elements 3; value in container', function()
            local present = Lib.contains({5, 6, 7}, 7)
            assert.is_true(present)
        end)

        test('container list; multiple elements; value not in container', function()
            local present = Lib.contains({5, 6, 7}, 8)
            assert.is_false(present)
        end)

        test('container list; multiple elements; value not in container; different type', function()
            local present = Lib.contains({5, 6, 7}, '5')
            assert.is_false(present)
        end)

        test('container string; container empty', function()
            local present = Lib.contains('', 'g')
            assert.is_false(present)
        end)

        test('container string; single element; value in container', function()
            local present = Lib.contains('g', 'g')
            assert.is_true(present)
        end)

        test('container string; single element; value not in container', function()
            local present = Lib.contains('g', 'z')
            assert.is_false(present)
        end)

        test('container string; multiple elements 1; value in container', function()
            local present = Lib.contains('hey', 'h')
            assert.is_true(present)
        end)

        test('container string; multiple elements 2; value in container', function()
            local present = Lib.contains('hey', 'e')
            assert.is_true(present)
        end)

        test('container string; multiple elements 3; value in container', function()
            local present = Lib.contains('hey', 'y')
            assert.is_true(present)
        end)

        test('container string; multiple elements; value not in container', function()
            local present = Lib.contains('hey', 'g')
            assert.is_false(present)
        end)

        test('container string; multiple elements; value not in container; different type', function()
            local present = Lib.contains('hey', 5)
            assert.is_false(present)
        end)

        test('container dict; container empty', function()
            local present = Lib.contains({}, 5)
            assert.is_false(present)
        end)

        test('container dict; single element; value in container', function()
            local present = Lib.contains({five = 5}, 'five')
            assert.is_true(present)
        end)

        test('container dict; single element; value not in container', function()
            local present = Lib.contains({five = 5}, 'three')
            assert.is_false(present)
        end)

        test('container dict; multiple elements 1; value in container', function()
            local present = Lib.contains({five = 5, six = 6, seven = 7}, 'five')
            assert.is_true(present)
        end)

        test('container dict; multiple elements 2; value in container', function()
            local present = Lib.contains({five = 5, six = 6, seven = 7}, 'six')
            assert.is_true(present)
        end)

        test('container dict; multiple elements 3; value in container', function()
            local present = Lib.contains({five = 5, six = 6, seven = 7}, 'seven')
            assert.is_true(present)
        end)

        test('container dict; multiple elements; value not in container', function()
            local present = Lib.contains({five = 5, six = 6, seven = 7}, 'eight')
            assert.is_false(present)
        end)

        test('container dict; multiple elements; value not in container; different type', function()
            local present = Lib.contains({five = 5, six = 6, seven = 7}, 5)
            assert.is_false(present)
        end)
    end)

    describe('remove', function()
        test('container valid; value nil', function()
            assert.has_error(function() Lib.remove({1, 2}, nil) end, 'value argument must not be nil')
        end)

        test('container nil; value valid', function()
            assert.has_error(function() Lib.remove(nil, 5) end, 'container argument must not be nil')
        end)

        test('container nil; value nil', function()
            assert.has_error(function() Lib.remove(nil, nil) end, 'container argument must not be nil')
        end)

        test('container empty; all false', function()
            local container = {}
            Lib.remove(container, 5)
            assert.same({}, container)
        end)

        test('container empty; all true', function()
            local container = {}
            Lib.remove(container, 5, true)
            assert.same({}, container)
        end)

        test('single element; value not in container; all false', function()
            local container = {5}
            Lib.remove(container, 4)
            assert.same({5}, container)
        end)

        test('single element; value not in container; all true', function()
            local container = {5}
            Lib.remove(container, 4, true)
            assert.same({5}, container)
        end)

        test('multiple elements 1; value in container; all false', function()
            local container = {5, 6, 7}
            Lib.remove(container, 5)
            assert.same({6, 7}, container)
        end)

        test('multiple elements 2; value in container; all false', function()
            local container = {5, 6, 7}
            Lib.remove(container, 6)
            assert.same({5, 7}, container)
        end)

        test('multiple elements 3; value in container; all false', function()
            local container = {5, 6, 7}
            Lib.remove(container, 7)
            assert.same({5, 6}, container)
        end)

        test('multiple elements; value not in container; all false', function()
            local container = {5, 6, 7}
            Lib.remove(container, 9)
            assert.same({5, 6, 7}, container)
        end)

        test('multiple elements; value in container; all true', function()
            local container = {5, 6, 7}
            Lib.remove(container, 5, true)
            assert.same({6, 7}, container)
        end)

        test('multiple elements; duplicates; value in container; all false', function()
            local container = {5, 6, 5, 7}
            Lib.remove(container, 5)
            assert.same({6, 5, 7}, container)
        end)

        test('multiple elements; duplicates; value in container; all true', function()
            local container = {5, 6, 5, 7}
            Lib.remove(container, 5, true)
            assert.same({6, 7}, container)
        end)
    end)

    -- TODO: b64Encode

    -- TODO: b64Decode

    -- TODO: getShortPlayerGuid

    -- TODO: getFullPlayerGuid

    -- TODO: isShortPlayerGuid

    -- TODO: isFullPlayerGuid

    describe('strStartsWith', function()
        test('first char', function()
            local s = 'Hello, world!'
            local pattern = 'H'

            local result = Lib.strStartsWith(s, pattern)

            assert.is_true(result)
        end)

        test('first chars', function()
            local s = 'Hello, world!'
            local pattern = 'Hello, w'

            local result = Lib.strStartsWith(s, pattern)

            assert.is_true(result)
        end)

        test('whole string', function()
            local s = 'Hello, world!'
            local pattern = 'Hello, world!'

            local result = Lib.strStartsWith(s, pattern)

            assert.is_true(result)
        end)

        test('random chars', function()
            local s = 'Hello, world!'
            local pattern = 'derp'

            local result = Lib.strStartsWith(s, pattern)

            assert.is_false(result)
        end)

        test('later chars', function()
            local s = 'Hello, world!'
            local pattern = 'ello'

            local result = Lib.strStartsWith(s, pattern)

            assert.is_false(result)
        end)

        test('empty', function()
            local s = 'Hello, world!'
            local pattern = ''

            local result = Lib.strStartsWith(s, pattern)

            assert.is_true(result)
        end)
    end)

    describe('strEndsWith', function()
        test('last char', function()
            local s = 'Hello, world!'
            local pattern = '!'

            local result = Lib.strEndsWith(s, pattern)

            assert.is_true(result)
        end)

        test('last chars', function()
            local s = 'Hello, world!'
            local pattern = ' world!'

            local result = Lib.strEndsWith(s, pattern)

            assert.is_true(result)
        end)

        test('whole string', function()
            local s = 'Hello, world!'
            local pattern = 'Hello, world!'

            local result = Lib.strEndsWith(s, pattern)

            assert.is_true(result)
        end)

        test('random chars', function()
            local s = 'Hello, world!'
            local pattern = 'derp'

            local result = Lib.strEndsWith(s, pattern)

            assert.is_false(result)
        end)

        test('earlier chars', function()
            local s = 'Hello, world!'
            local pattern = 'worl'

            local result = Lib.strEndsWith(s, pattern)

            assert.is_false(result)
        end)

        test('empty', function()
            local s = 'Hello, world!'
            local pattern = ''

            local result = Lib.strEndsWith(s, pattern)

            assert.is_true(result)
        end)
    end)

    describe('getEventReason', function()
        before_each(function()
            Util:loadModule('values', ns)
        end)

        after_each(function()
            ns.values = nil
        end)

        describe('manual_single', function()
            test('nominal', function()
                local expected = '0:derp'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE, 'derp')

                assert.same(expected, actual)
            end)

            test('empty', function()
                local expected = '0:'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE, '')

                assert.same(expected, actual)
            end)

            test('nil', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE) end)
            end)

            test('wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.MANUAL_SINGLE, 5) end)
            end)
        end)

        describe('manual_multiple', function()
            test('nominal', function()
                local expected = '1:derp'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, 'derp')

                assert.same(expected, actual)
            end)

            test('nominal with false bench', function()
                local expected = '1:derp'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, 'derp', false)

                assert.same(expected, actual)
            end)

            test('nominal with true bench', function()
                local expected = '1:derp:1'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, 'derp', true)

                assert.same(expected, actual)
            end)

            test('empty', function()
                local expected = '1:'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, '')

                assert.same(expected, actual)
            end)

            test('empty with bench', function()
                local expected = '1::1'
                local actual = Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, '', true)

                assert.same(expected, actual)
            end)

            test('nil', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE) end)
            end)

            test('wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, 5) end)
            end)

            test('bench wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.MANUAL_MULTIPLE, 'derp', 5) end)
            end)
        end)

        describe('decay', function()
            test('nominal', function()
                local expected = '2:derp'
                local actual = Lib.getEventReason(ns.values.epgpReasons.DECAY, 'derp')

                assert.same(expected, actual)
            end)

            test('empty', function()
                local expected = '2:'
                local actual = Lib.getEventReason(ns.values.epgpReasons.DECAY, '')

                assert.same(expected, actual)
            end)

            test('nil', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.DECAY) end)
            end)

            test('wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.DECAY, 5) end)
            end)
        end)

        describe('award', function()
            test('nominal MS', function()
                local expected = '3:ms:11'
                local actual = Lib.getEventReason(ns.values.epgpReasons.AWARD, 'MS', 11)

                assert.same(expected, actual)
            end)

            test('nominal OS', function()
                local expected = '3:os:11'
                local actual = Lib.getEventReason(ns.values.epgpReasons.AWARD, 'OS', 11)

                assert.same(expected, actual)
            end)

            test('nominal item name', function()
                local expected = '3:os:item'
                local actual = Lib.getEventReason(ns.values.epgpReasons.AWARD, 'OS', 'item')

                assert.same(expected, actual)
            end)

            test('unknown roll', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.AWARD, 'FS', 11) end)
            end)

            test('empty roll', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.AWARD, '', 11) end)
            end)

            test('nil roll', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.AWARD, nil, 11) end)
            end)

            test('wrong roll type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.AWARD, 5, 11) end)
            end)

            test('wrong item type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.AWARD, 'MS', true) end)
            end)
        end)

        describe('boss_kill', function()
            test('nominal', function()
                local expected = '4:52'
                local actual = Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, 52)

                assert.same(expected, actual)
            end)

            test('nominal with false bench', function()
                local expected = '4:52'
                local actual = Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, 52, false)

                assert.same(expected, actual)
            end)

            test('nominal with true bench', function()
                local expected = '4:52:1'
                local actual = Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, 52, true)

                assert.same(expected, actual)
            end)

            test('nil', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL) end)
            end)

            test('wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, 'boss') end)
            end)

            test('bench wrong type', function()
                assert.has.errors(function() Lib.getEventReason(ns.values.epgpReasons.BOSS_KILL, 52, 5) end)
            end)
        end)

        test('unknown', function()
            assert.has.errors(function() Lib.getEventReason(5, 'derp') end)
        end)
    end)

    describe('createKnownPlayer', function()
        before_each(function()
            ns.db = {
                knownPlayers = {}
            }
            Lib.playerNameToGuid = {}
        end)

        after_each(function()
            ns.db = nil
            Lib.playerNameToGuid = nil
        end)

        test('empty knownPlayers new', function()
            local playerData = Lib.createKnownPlayer('p1_guid', 'p1', 'DERP', true, 5)

            local expectedPlayerData = {guid = 'p1_guid', name = 'p1', classFilename = 'DERP', inGuild = true, rankIndex = 5}

            assert.same(expectedPlayerData, playerData)
            assert.same({p1_guid = expectedPlayerData}, ns.db.knownPlayers)
            assert.same({p1 = 'p1_guid'}, Lib.playerNameToGuid)
        end)

        test('populated knownPlayers new', function()
            local existingPlayerData = {guid = 'p2_guid', name = 'p2', classFilename = 'HERP', inGuild = true, rankIndex = 4}

            ns.db.knownPlayers['p2_guid'] = existingPlayerData
            Lib.playerNameToGuid.p2 = 'p2_guid'

            local playerData = Lib.createKnownPlayer('p1_guid', 'p1', 'DERP', true, 5)

            local expectedPlayerData = {guid = 'p1_guid', name = 'p1', classFilename = 'DERP', inGuild = true, rankIndex = 5}

            assert.same(expectedPlayerData, playerData)
            assert.same({p1_guid = expectedPlayerData, p2_guid = existingPlayerData}, ns.db.knownPlayers)
            assert.same({p1 = 'p1_guid', p2 = 'p2_guid'}, Lib.playerNameToGuid)
        end)

        test('populated knownPlayers overwrite', function()
            local existingPlayerData = {guid = 'p1_guid', name = 'p1', classFilename = 'DERP', inGuild = false, rankIndex = nil}

            ns.db.knownPlayers['p1_guid'] = existingPlayerData
            Lib.playerNameToGuid.p1 = 'p1_guid'

            local playerData = Lib.createKnownPlayer('p1_guid', 'p1', 'DERP', true, 5)

            local expectedPlayerData = {guid = 'p1_guid', name = 'p1', classFilename = 'DERP', inGuild = true, rankIndex = 5}

            assert.same(expectedPlayerData, playerData)
            assert.same({p1_guid = expectedPlayerData}, ns.db.knownPlayers)
            assert.same({p1 = 'p1_guid'}, Lib.playerNameToGuid)
        end)
    end)
end)
