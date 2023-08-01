loadfile('test/setup.lua')(spy, stub, mock)

local ns = {}
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
end)
