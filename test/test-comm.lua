loadfile('test/setup.lua')(spy, stub, mock)


describe('encodeEvent', function()
    local ns

    before_each(function()
        ns = {}

        Util:loadModule('constants', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('comm', ns)
    end)

    test('test', function()
        local eventAndHash = {
            {
                1690330283,
                'p1',
                {
                    'p1',
                    'p2',
                    'p3',
                },
                'ep',
                20,
                '1:wee'
            },
            2074722407
        }

        local expectedEncodedEventAndHash = {
            {
                'BkwGSr',
                'p1',
                {
                    'p1',
                    'p2',
                    'p3',
                },
                'ep',
                20,
                '1:wee'
            },
            'B7qcBn'
        }

        local actualEncodedEventAndHash = ns.Comm.encodeEvent(eventAndHash)

        assert.same(expectedEncodedEventAndHash, actualEncodedEventAndHash)
    end)
end)


describe('decodeEvent', function()
    local ns

    before_each(function()
        ns = {}

        Util:loadModule('constants', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('comm', ns)
    end)

    test('test', function()
        local encodedEventAndHash = {
            {
                'BkwGSr',
                'p1',
                {
                    'p1',
                    'p2',
                    'p3',
                },
                'ep',
                20,
                '1:wee'
            },
            'B7qcBn'
        }

        local expectedEventAndHash = {
            {
                1690330283,
                'p1',
                {
                    'p1',
                    'p2',
                    'p3',
                },
                'ep',
                20,
                '1:wee'
            },
            2074722407
        }

        local actualEventAndHash = ns.Comm.decodeEvent(encodedEventAndHash)

        assert.same(expectedEventAndHash, actualEventAndHash)
    end)
end)
