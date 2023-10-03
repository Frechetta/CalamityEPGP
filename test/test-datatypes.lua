loadfile('test/setup.lua')(spy, stub, mock)

local ns = {}
Util:loadModule('datatypes', ns)

local List = ns.List
local Set = ns.Set
local Dict = ns.Dict


describe('List', function()
    describe('new', function()
        test('no arg', function()
            local l = List:new()
            assert.same({}, l._list)
        end)

        test('zero elements', function()
            local l = List:new({})
            assert.same({}, l._list)
        end)

        test('one element', function()
            local l = List:new({1})
            assert.same({1}, l._list)
        end)

        test('multiple elements', function()
            local l = List:new({1, 5, 2})
            assert.same({1, 5, 2}, l._list)
        end)
    end)

    describe('contains', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('empty', function()
            local l = List:new()
            assert.is_false(l:contains(1))
        end)

        test('one element', function()
            local l = List:new({1})
            assert.is_true(l:contains(1))
        end)

        test('multiple elements 1', function()
            local l = List:new({1, 2, 3})
            assert.is_true(l:contains(1))
        end)

        test('multiple elements 2', function()
            local l = List:new({2, 1, 3})
            assert.is_true(l:contains(1))
        end)

        test('multiple elements 3', function()
            local l = List:new({2, 3, 1})
            assert.is_true(l:contains(1))
        end)

        test('arg doesn\'t exist', function()
            local l = List:new({1, 2, 3})
            assert.is_false(l:contains(4))
        end)
    end)

    describe('len', function()
        test('empty', function()
            local l = List:new()
            assert.same(0, l:len())
        end)

        test('one element', function()
            local l = List:new({1})
            assert.same(1, l:len())
        end)

        test('multiple elements', function()
            local l = List:new({1, 2, 3})
            assert.same(3, l:len())
        end)
    end)

    describe('iter', function()
        test('empty', function()
            local l = List:new()

            local elements = {}
            for element in l:iter() do
                table.insert(elements, element)
            end

            assert.same({}, elements)
        end)

        test('one element', function()
            local l = List:new({1})

            local elements = {}
            for element in l:iter() do
                table.insert(elements, element)
            end

            assert.same({1}, elements)
        end)

        test('multiple elements', function()
            local l = List:new({1, 2, 3})

            local elements = {}
            for element in l:iter() do
                table.insert(elements, element)
            end

            assert.same({1, 2, 3}, elements)
        end)

        test('empty reverse', function()
            local l = List:new()

            local elements = {}
            for element in l:iter(true) do
                table.insert(elements, element)
            end

            assert.same({}, elements)
        end)

        test('one element reverse', function()
            local l = List:new({1})

            local elements = {}
            for element in l:iter(true) do
                table.insert(elements, element)
            end

            assert.same({1}, elements)
        end)

        test('multiple elements reverse', function()
            local l = List:new({1, 2, 3})

            local elements = {}
            for element in l:iter(true) do
                table.insert(elements, element)
            end

            assert.same({3, 2, 1}, elements)
        end)

        test('empty enumerate', function()
            local l = List:new()

            local elements = {}
            for i, element in l:iter(false, true) do
                table.insert(elements, {i, element})
            end

            assert.same({}, elements)
        end)

        test('one element enumerate', function()
            local l = List:new({5})

            local elements = {}
            for i, element in l:iter(false, true) do
                table.insert(elements, {i, element})
            end

            assert.same({{1, 5}}, elements)
        end)

        test('multiple elements enumerate', function()
            local l = List:new({5, 6, 7})

            local elements = {}
            for i, element in l:iter(false, true) do
                table.insert(elements, {i, element})
            end

            assert.same({{1, 5}, {2, 6}, {3, 7}}, elements)
        end)

        test('multiple elements enumerate nil reverse', function()
            local l = List:new({5, 6, 7})

            local elements = {}
            for i, element in l:iter(nil, true) do
                table.insert(elements, {i, element})
            end

            assert.same({{1, 5}, {2, 6}, {3, 7}}, elements)
        end)

        test('empty reverse enumerate', function()
            local l = List:new()

            local elements = {}
            for i, element in l:iter(true, true) do
                table.insert(elements, {i, element})
            end

            assert.same({}, elements)
        end)

        test('one element reverse enumerate', function()
            local l = List:new({5})

            local elements = {}
            for i, element in l:iter(true, true) do
                table.insert(elements, {i, element})
            end

            assert.same({{1, 5}}, elements)
        end)

        test('multiple elements reverse enumerate', function()
            local l = List:new({5, 6, 7})

            local elements = {}
            for i, element in l:iter(true, true) do
                table.insert(elements, {i, element})
            end

            assert.same({{1, 7}, {2, 6}, {3, 5}}, elements)
        end)
    end)

    describe('enumerate', function()
        local l

        before_each(function()
            stub(List, 'iter')
            l = List:new()
        end)

        after_each(function()
            List.iter:revert()
        end)

        test('no args', function()
            l:enumerate()
            assert.stub(List.iter).was.called(1)
            assert.stub(List.iter).was.called_with(l, nil, true)
        end)

        test('reverse false', function()
            l:enumerate(false)
            assert.stub(List.iter).was.called(1)
            assert.stub(List.iter).was.called_with(l, false, true)
        end)

        test('reverse true', function()
            l:enumerate(true)
            assert.stub(List.iter).was.called(1)
            assert.stub(List.iter).was.called_with(l, true, true)
        end)
    end)

    describe('clear', function()
        test('empty', function()
            local l = List:new()
            l:clear()
            assert.same({}, l._list)
        end)

        test('one element', function()
            local l = List:new({1})
            l:clear()
            assert.same({}, l._list)
        end)

        test('multiple elements', function()
            local l = List:new({1, 2, 3})
            l:clear()
            assert.same({}, l._list)
        end)
    end)

    describe('append', function()
        test('empty', function()
            local l = List:new()
            l:append(2)
            assert.same({2}, l._list)
        end)

        test('one element', function()
            local l = List:new({1})
            l:append(2)
            assert.same({1, 2}, l._list)
        end)

        test('different types', function()
            local l = List:new({1})
            l:append('d')
            assert.same({1, 'd'}, l._list)
        end)
    end)

    describe('get', function()
        test('empty', function()
            local l = List:new()
            local item = l:get(1)
            assert.same(nil, item)
        end)

        test('empty -1', function()
            local l = List:new()
            local item = l:get(-1)
            assert.same(nil, item)
        end)

        test('one element 1', function()
            local l = List:new({1})
            local item = l:get(1)
            assert.same(1, item)
        end)

        test('one element 2', function()
            local l = List:new({1})
            local item = l:get(2)
            assert.same(nil, item)
        end)

        test('one element -1', function()
            local l = List:new({1})
            local item = l:get(-1)
            assert.same(1, item)
        end)

        test('one element -2', function()
            local l = List:new({1})
            local item = l:get(-2)
            assert.same(nil, item)
        end)

        test('multiple elements 1', function()
            local l = List:new({6, 7, 8})
            local item = l:get(1)
            assert.same(6, item)
        end)

        test('multiple elements 2', function()
            local l = List:new({6, 7, 8})
            local item = l:get(2)
            assert.same(7, item)
        end)

        test('multiple elements 6', function()
            local l = List:new({6, 7, 8})
            local item = l:get(6)
            assert.same(nil, item)
        end)

        test('multiple elements -1', function()
            local l = List:new({6, 7, 8})
            local item = l:get(-1)
            assert.same(8, item)
        end)

        test('multiple elements -2', function()
            local l = List:new({6, 7, 8})
            local item = l:get(-2)
            assert.same(7, item)
        end)
    end)

    describe('set', function()
        test('empty', function()
            local l = List:new()
            assert.has_error(function() l:set(1, 5) end, 'no item at index 1')
        end)

        test('empty -1', function()
            local l = List:new()
            assert.has_error(function() l:set(-1, 5) end, 'no item at index 0')
        end)

        test('one element 1', function()
            local l = List:new({1})
            l:set(1, 5)
            assert.same({5}, l._list)
        end)

        test('one element 2', function()
            local l = List:new({1})
            assert.has_error(function() l:set(2, 5) end, 'no item at index 2')
        end)

        test('one element -1', function()
            local l = List:new({1})
            l:set(-1, 5)
            assert.same({5}, l._list)
        end)

        test('one element -2', function()
            local l = List:new({1})
            assert.has_error(function() l:set(-2, 5) end, 'no item at index 0')
        end)

        test('multiple elements 1', function()
            local l = List:new({6, 7, 8})
            l:set(1, 9)
            assert.same({9, 7, 8}, l._list)
        end)

        test('multiple elements 2', function()
            local l = List:new({6, 7, 8})
            l:set(2, 9)
            assert.same({6, 9, 8}, l._list)
        end)

        test('multiple elements 6', function()
            local l = List:new({6, 7, 8})
            assert.has_error(function() l:set(6, 9) end, 'no item at index 6')
        end)

        test('multiple elements -1', function()
            local l = List:new({6, 7, 8})
            l:set(-1, 9)
            assert.same({6, 7, 9}, l._list)
        end)

        test('multiple elements -2', function()
            local l = List:new({6, 7, 8})
            l:set(-2, 9)
            assert.same({6, 9, 8}, l._list)
        end)
    end)

    describe('sort', function()
        local l

        before_each(function()
            stub(table, 'sort')
            l = List:new()
        end)

        after_each(function()
            table.sort:revert()
        end)

        test('no func', function()
            l:sort()

            assert.stub(table.sort).was.called(1)
            assert.stub(table.sort).was.called_with(l._list, nil)
        end)

        test('with func', function()
            l:sort(5)

            assert.stub(table.sort).was.called(1)
            assert.stub(table.sort).was.called_with(l._list, 5)
        end)
    end)

    describe('toTable', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('empty', function()
            local l = List:new()
            local t = l:toTable()
            assert.are_not.equals(t, l._list)
            assert.same(t, l._list)
        end)

        test('non empty', function()
            local l = List:new({1, 2, 3})
            local t = l:toTable()
            assert.are_not.equals(t, l._list)
            assert.same(t, l._list)
        end)
    end)

    describe('bininsert', function()
        local l

        before_each(function()
            ns.Lib = mock({
                bininsert = spy.new()
            })

            l = List:new()
        end)

        after_each(function()
            ns.Lib = nil
        end)

        test('no func', function()
            l:bininsert(5)

            assert.spy(ns.Lib.bininsert).was.called(1)
            assert.spy(ns.Lib.bininsert).was.called_with(l._list, 5, nil)
        end)

        test('with func', function()
            l:bininsert(5, 1)

            assert.spy(ns.Lib.bininsert).was.called(1)
            assert.spy(ns.Lib.bininsert).was.called_with(l._list, 5, 1)
        end)
    end)

    describe('remove', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('empty', function()
            local l = List:new()
            l:remove(2)
            assert.same({}, l._list)
        end)

        test('one element dne', function()
            local l = List:new({1})
            l:remove(2)
            assert.same({1}, l._list)
        end)

        test('one element', function()
            local l = List:new({1})
            l:remove(1)
            assert.same({}, l._list)
        end)

        test('multiple elements dne', function()
            local l = List:new({1, 2, 3})
            l:remove(5)
            assert.same({1, 2, 3}, l._list)
        end)

        test('multiple elements 1', function()
            local l = List:new({1, 2, 3})
            l:remove(1)
            assert.same({2, 3}, l._list)
        end)

        test('multiple elements dne', function()
            local l = List:new({1, 2, 3})
            l:remove(2)
            assert.same({1, 3}, l._list)
        end)

        test('multiple elements dne', function()
            local l = List:new({1, 2, 3})
            l:remove(3)
            assert.same({1, 2}, l._list)
        end)

        test('duplicate elements', function()
            local l = List:new({1, 2, 3, 2})
            l:remove(2)
            assert.same({1, 3, 2}, l._list)
        end)

        test('duplicate elements', function()
            local l = List:new({1, 2, 3, 2})
            l:remove(2, true)
            assert.same({1, 3}, l._list)
        end)
    end)

    describe('removeIndex', function()
        test('index 1', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(1)
            assert.same({2, 3, 4}, l._list)
        end)

        test('index 3', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(3)
            assert.same({1, 2, 4}, l._list)
        end)

        test('index 4', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(4)
            assert.same({1, 2, 3}, l._list)
        end)

        test('index -1', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(-1)
            assert.same({1, 2, 3}, l._list)
        end)

        test('index -3', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(-3)
            assert.same({1, 3, 4}, l._list)
        end)

        test('index -4', function()
            local l = List:new({1, 2, 3, 4})
            l:removeIndex(-4)
            assert.same({2, 3, 4}, l._list)
        end)

        test('index 5', function()
            local l = List:new({1, 2, 3, 4})
            assert.has.errors(function() l:removeIndex(5) end)
        end)

        test('index -5', function()
            local l = List:new({1, 2, 3, 4})
            assert.has.errors(function() l:removeIndex(-5) end)
        end)

        test('wrong type', function()
            local l = List:new({1, 2, 3, 4})
            assert.has.errors(function() l:removeIndex('hi') end)
        end)
    end)
end)


describe('Set', function()
    describe('new', function()
        test('no arg', function()
            local s = Set:new()
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('zero elements', function()
            local s = Set:new({})
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('one element', function()
            local s = Set:new({1})
            assert.same({
                [1] = true,
            }, s._set)
            assert.same(1, s._len)
        end)

        test('multiple elements', function()
            local s = Set:new({1, 5, 2})
            assert.same({
                [1] = true,
                [2] = true,
                [5] = true,
            }, s._set)
            assert.same(3, s._len)
        end)
    end)

    describe('contains', function()
        test('empty', function()
            local s = Set:new()
            assert.is_false(s:contains(1))
        end)

        test('one element', function()
            local s = Set:new({1})
            assert.is_true(s:contains(1))
        end)

        test('multiple elements 1', function()
            local s = Set:new({1, 2, 3})
            assert.is_true(s:contains(1))
        end)

        test('multiple elements 2', function()
            local s = Set:new({2, 1, 3})
            assert.is_true(s:contains(1))
        end)

        test('multiple elements 3', function()
            local s = Set:new({2, 3, 1})
            assert.is_true(s:contains(1))
        end)

        test('arg doesn\'t exist', function()
            local s = Set:new({1, 2, 3})
            assert.is_false(s:contains(4))
        end)
    end)

    describe('len', function()
        test('empty', function()
            local s = Set:new()
            assert.same(0, s:len())
        end)

        test('one element', function()
            local s = Set:new({1})
            assert.same(1, s:len())
        end)

        test('multiple elements', function()
            local s = Set:new({1, 2, 3})
            assert.same(3, s:len())
        end)
    end)

    describe('add', function()
        test('empty', function()
            local s = Set:new()
            s:add(2)
            assert.same({
                [2] = true
            }, s._set)
            assert.same(1, s._len)
        end)

        test('one element', function()
            local s = Set:new({5})
            s:add(3)
            assert.same({
                [5] = true,
                [3] = true,
            }, s._set)
            assert.same(2, s._len)
        end)

        test('different types', function()
            local s = Set:new({5})
            s:add('d')
            assert.same({
                [5] = true,
                ['d'] = true,
            }, s._set)
            assert.same(2, s._len)
        end)

        test('multiple elements', function()
            local s = Set:new({5, 7})
            s:add(3)
            assert.same({
                [5] = true,
                [7] = true,
                [3] = true,
            }, s._set)
            assert.same(3, s._len)
        end)

        test('already exists', function()
            local s = Set:new({5, 7})
            s:add(5)
            assert.same({
                [5] = true,
                [7] = true,
            }, s._set)
            assert.same(2, s._len)
        end)
    end)

    describe('remove', function()
        test('empty', function()
            local s = Set:new()
            s:remove(2)
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('one element item exists', function()
            local s = Set:new({5})
            s:remove(5)
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('one element item does not exist', function()
            local s = Set:new({5})
            s:remove(2)
            assert.same({
                [5] = true,
            }, s._set)
            assert.same(1, s._len)
        end)

        test('multiple elements item exists first', function()
            local s = Set:new({5, 6, 7})
            s:remove(5)
            assert.same({
                [6] = true,
                [7] = true,
            }, s._set)
            assert.same(2, s._len)
        end)

        test('multiple elements item exists middle', function()
            local s = Set:new({5, 6, 7})
            s:remove(6)
            assert.same({
                [5] = true,
                [7] = true,
            }, s._set)
            assert.same(2, s._len)
        end)

        test('multiple elements item exists last', function()
            local s = Set:new({5, 6, 7})
            s:remove(7)
            assert.same({
                [5] = true,
                [6] = true,
            }, s._set)
            assert.same(2, s._len)
        end)

        test('multiple elements item does not exist', function()
            local s = Set:new({5, 6, 7})
            s:remove(2)
            assert.same({
                [5] = true,
                [6] = true,
                [7] = true,
            }, s._set)
            assert.same(3, s._len)
        end)

        test('different types', function()
            local s = Set:new({5, 'd', 7})
            s:remove('d')
            assert.same({
                [5] = true,
                [7] = true,
            }, s._set)
            assert.same(2, s._len)
        end)
    end)

    describe('iter', function()
        test('empty', function()
            local s = Set:new()

            local elements = {}
            for element in s:iter() do
                table.insert(elements, element)
            end

            assert.same({}, elements)
        end)

        test('one element', function()
            local s = Set:new({1})

            local elements = {}
            for element in s:iter() do
                table.insert(elements, element)
            end

            assert.same({1}, elements)
        end)

        test('multiple elements', function()
            local s = Set:new({1, 2, 3})

            local elements = {}
            for element in s:iter() do
                table.insert(elements, element)
            end

            assert.same({1, 2, 3}, elements)
        end)

        test('multiple elements with remove', function()
            local s = Set:new({1, 2, 3})

            s:remove(2)

            local elements = {}
            for element in s:iter() do
                table.insert(elements, element)
            end

            assert.same({1, 3}, elements)
        end)

        test('multiple elements with add', function()
            local s = Set:new({1, 5, 6})

            s:add(4)

            local elements = {}
            for element in s:iter() do
                table.insert(elements, element)
            end

            table.sort(elements)

            assert.same({1, 4, 5, 6}, elements)
        end)
    end)

    describe('clear', function()
        test('empty', function()
            local s = Set:new()
            s:clear()
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('one element', function()
            local s = Set:new({1})
            s:clear()
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)

        test('multiple elements', function()
            local s = Set:new({1, 2, 3})
            s:clear()
            assert.same({}, s._set)
            assert.same(0, s._len)
        end)
    end)

    describe('toTable', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('empty', function()
            local s = Set:new()
            local t = s:toTable()
            assert.same({}, t)
        end)

        test('non empty', function()
            local s = Set:new({1, 2, 3})
            local t = s:toTable()
            assert.same({1, 2, 3}, t)
        end)
    end)

    describe('difference', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('both empty', function()
            local s1 = Set:new()
            local s2 = Set:new()
            local s = s1:difference(s2)
            assert.same({}, s._set)
        end)

        test('second empty', function()
            local s1 = Set:new({5, 6, 7})
            local s2 = Set:new()
            local s = s1:difference(s2)
            assert.same({
                [5] = true,
                [6] = true,
                [7] = true,
            }, s._set)
        end)

        test('first empty', function()
            local s1 = Set:new()
            local s2 = Set:new({5, 6, 7})
            local s = s1:difference(s2)
            assert.same({}, s._set)
        end)

        test('first contains second', function()
            local s1 = Set:new({5, 6, 7, 8})
            local s2 = Set:new({5, 7})
            local s = s1:difference(s2)
            assert.same({
                [6] = true,
                [8] = true,
            }, s._set)
        end)

        test('second contains first', function()
            local s1 = Set:new({5, 7})
            local s2 = Set:new({5, 6, 7, 8})
            local s = s1:difference(s2)
            assert.same({}, s._set)
        end)

        test('some elements in common', function()
            local s1 = Set:new({5, 6, 7, 8})
            local s2 = Set:new({4, 5, 7, 9})
            local s = s1:difference(s2)
            assert.same({
                [6] = true,
                [8] = true,
            }, s._set)
        end)

        test('no elements in common', function()
            local s1 = Set:new({5, 6})
            local s2 = Set:new({7, 8})
            local s = s1:difference(s2)
            assert.same({
                [5] = true,
                [6] = true,
            }, s._set)
        end)
    end)
end)


describe('Dict', function()
    describe('new', function()
        test('no arg', function()
            local d = Dict:new()

            local expectedDict = {}
            local expectedKeys = Set:new()
            local expectedValues = List:new()

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('zero elements', function()
            local d = Dict:new({})

            local expectedDict = {}
            local expectedKeys = Set:new()
            local expectedValues = List:new()

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('one element', function()
            local d = Dict:new({
                a = 5,
            })

            local expectedDict = {a = 5}
            local expectedKeys = Set:new({'a'})
            local expectedValues = List:new({5})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('multiple elements', function()
            local d = Dict:new({
                a = 5,
                b = 6,
                c = 7,
            })

            local expectedDict = {a = 5, c = 7, b = 6}
            local expectedKeys = Set:new({'a', 'b', 'c'})
            local expectedValues = List:new({5, 7, 6})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)
    end)

    describe('contains', function()
        test('empty', function()
            local d = Dict:new()
            assert.is_false(d:contains(1))
        end)

        test('one element', function()
            local d = Dict:new({a = 1})
            assert.is_true(d:contains('a'))
        end)

        test('multiple elements 1', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.is_true(d:contains('a'))
        end)

        test('multiple elements 2', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.is_true(d:contains('b'))
        end)

        test('multiple elements 3', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.is_true(d:contains('c'))
        end)

        test('arg doesn\'t exist', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.is_false(d:contains('d'))
        end)
    end)

    describe('len', function()
        test('empty', function()
            local d = Dict:new()
            assert.same(0, d:len())
        end)

        test('one element', function()
            local d = Dict:new({a = 5})
            assert.same(1, d:len())
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(3, d:len())
        end)
    end)

    describe('isEmpty', function()
        test('empty', function()
            local d = Dict:new()
            assert.is_true(d:isEmpty())
        end)

        test('one element', function()
            local d = Dict:new({a = 5})
            assert.is_false(d:isEmpty())
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.is_false(d:isEmpty())
        end)
    end)

    describe('keys', function()
        test('empty', function()
            local d = Dict:new()
            assert.same(Set:new(), d:keys())
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(Set:new({'a', 'b', 'c'}), d:keys())
        end)
    end)

    describe('values', function()
        test('empty', function()
            local d = Dict:new()
            assert.same(List:new(), d:values())
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(List:new({5, 7, 6}), d:values())
        end)
    end)

    describe('get', function()
        test('empty', function()
            local d = Dict:new()
            assert.same(nil, d:get('a'))
        end)

        test('one element key exists', function()
            local d = Dict:new({a = 5})
            assert.same(5, d:get('a'))
        end)

        test('one element key does not exist', function()
            local d = Dict:new({a = 5})
            assert.same(nil, d:get('c'))
        end)

        test('multiple elements 1', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(5, d:get('a'))
        end)

        test('multiple elements 2', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(6, d:get('b'))
        end)

        test('multiple elements 3', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(7, d:get('c'))
        end)

        test('multiple elements key does not exist', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            assert.same(nil, d:get(5))
        end)
    end)

    describe('set', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        test('empty', function()
            local d = Dict:new()

            d:set('a', 5)

            local expectedDict = {a = 5}
            local expectedKeys = Set:new({'a'})
            local expectedValues = List:new({5})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('one element key exists', function()
            local d = Dict:new({a = 5})

            d:set('a', 9)

            local expectedDict = {a = 9}
            local expectedKeys = Set:new({'a'})
            local expectedValues = List:new({9})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('one element key does not exist', function()
            local d = Dict:new({a = 5})

            d:set('b', 6)

            local expectedDict = {a = 5, b = 6}
            local expectedKeys = Set:new({'a', 'b'})
            local expectedValues = List:new({5, 6})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('multiple elements key exists', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            d:set('b', 9)

            local expectedDict = {a = 5, c = 7, b = 9}
            local expectedKeys = Set:new({'a', 'b', 'c'})
            local expectedValues = List:new({5, 7, 9})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('multiple elements key does not exist', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            d:set('d', 1)

            local expectedDict = {a = 5, c = 7, b = 6, d = 1}
            local expectedKeys = Set:new({'a', 'b', 'c', 'd'})
            local expectedValues = List:new({5, 7, 6, 1})

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)
    end)

    describe('iter', function()
        test('empty', function()
            local d = Dict:new()

            local actual = {}
            for k, v in d:iter() do
                actual[k] = v
            end

            assert.same({}, actual)
        end)

        test('one element', function()
            local d = Dict:new({a = 5})

            local actual = {}
            for k, v in d:iter() do
                actual[k] = v
            end

            assert.same({a = 5}, actual)
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            local actual = {}
            for k, v in d:iter() do
                actual[k] = v
            end

            assert.same({a = 5, b = 6, c = 7}, actual)
        end)

        test('keys', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            local keys = {}
            for k in d:iter() do
                table.insert(keys, k)
            end

            assert.same({'a', 'c', 'b'}, keys)
        end)

        test('values', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            local values = {}
            for _, v in d:iter() do
                table.insert(values, v)
            end

            assert.same({5, 7, 6}, values)
        end)
    end)

    describe('clear', function()
        test('empty', function()
            local d = Dict:new()

            d:clear()

            local expectedDict = {}
            local expectedKeys = Set:new()
            local expectedValues = List:new()

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('one element', function()
            local d = Dict:new({a = 5})

            d:clear()

            local expectedDict = {}
            local expectedKeys = Set:new()
            local expectedValues = List:new()

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)

        test('multiple elements', function()
            local d = Dict:new({a = 5, b = 6, c = 7})

            d:clear()

            local expectedDict = {}
            local expectedKeys = Set:new()
            local expectedValues = List:new()

            assert.same(expectedDict, d._dict)
            assert.same(expectedKeys, d._keys)
            assert.same(expectedValues, d._values)
        end)
    end)

    describe('toTable', function()
        setup(function()
            Util:loadModule('lib', ns)
        end)

        teardown(function()
            ns.Lib = nil
        end)

        test('empty', function()
            local d = Dict:new()
            local t = d:toTable()
            assert.are_not.equals(t, d._dict)
            assert.same(t, d._dict)
        end)

        test('non empty', function()
            local d = Dict:new({a = 5, b = 6, c = 7})
            local t = d:toTable()
            assert.are_not.equals(t, d._dict)
            assert.same(t, d._dict)
        end)
    end)
end)
