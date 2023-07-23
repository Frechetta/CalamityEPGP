loadfile('test/setup.lua')(spy, stub, mock)

local ns = {}
Util:loadModule('datatypes', ns)


describe('List', function()
    local List = ns.List

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

    describe('sort', function()
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
end)
