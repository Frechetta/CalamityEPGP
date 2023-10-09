loadfile('test/setup.lua')(spy, stub, mock)


describe('encodeEvent', function()
    local ns

    before_each(function()
        ns = {}

        Util:loadModule('constants', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('sync', ns)
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

        local actualEncodedEventAndHash = ns.Sync.encodeEvent(eventAndHash)

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
        Util:loadModule('sync', ns)
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

        local actualEventAndHash = ns.Sync.decodeEvent(encodedEventAndHash)

        assert.same(expectedEventAndHash, actualEventAndHash)
    end)
end)


describe('algorithm', function()
    local ns1
    local ns2

    local players

    local function loadNs(ns, playerName, playerShortGuid)
        assert(#ns == 0)

        local empty = true
        for _, _ in pairs(ns) do
            empty = false
            break
        end
        assert(empty)

        Util:loadModule('constants', ns)
        Util:loadModule('datatypes', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('comm', ns)
        Util:loadModule('sync', ns)
        Util:loadModule('main', ns)

        ns.realmId = 1234

        ns.me = {
            name = playerName,
            guid = ('Player-%s-%s'):format(ns.realmId, playerShortGuid),
        }

        players[playerName] = ns.me

        ns.addon.versionNum = 1
        ns.minSyncVersion = 1

        -- stub(ns, 'debug')

        ns.unitName = function(unit)
            if unit == 'player' then
                return ns.me.name
            end

            local player = players[unit]
            if player ~= nil then
                return player.name
            end

            return nil
        end

        ns.unitGuid = function(unit)
            if unit == 'player' then
                return ns.me.guid
            end

            local player = players[unit]
            if player ~= nil then
                return player.guid
            end

            return nil
        end

        ns.addon.Print = spy.new(function(_, msg) print(('%s: %s'):format(ns.me.name, msg)) end)

        ns.cfg = {
            debugMode = true,
        }

        ns.db = {
            history = {},
            lmSettingsLastChange = 1,
        }

        ns.Lib.isOfficer = function(player)
            if player == nil then
                player = ns.unitName('player')
            end
            return players[player].officer
        end
    end

    before_each(function()
        players = {}

        ns1 = {}
        loadNs(ns1, 'Tucker', 11111111)

        ns2 = {}
        loadNs(ns2, 'Mia', 22222222)

        local knownPlayers = {
            [ns1.me.guid] = {
                guid = ns1.me.guid,
                name = ns1.me.name,
                classFilename = 'WARRIOR',
                inGuild = true,
                rankIndex = 2,
            },
            [ns2.me.guid] = {
                guid = ns2.me.guid,
                name = ns2.me.name,
                classFilename = 'HUNTER',
                inGuild = true,
                rankIndex = 3,
            },
        }

        ns1.knownPlayers = ns1.Dict:new(knownPlayers)
        ns2.knownPlayers = ns2.Dict:new(knownPlayers)

        ns1.addon.SendCommMessage = function(_, prefix, message, distribution, target)
            ns2.Comm.handleMessage(prefix, message, nil, ns1.me.name)
        end

        ns2.addon.SendCommMessage = function(_, prefix, message, distribution, target)
            -- ns1.Comm.handleMessage(prefix, message, nil, ns2.me.name)
        end

        ns1.Sync:init()
        ns2.Sync:init()
    end)

    after_each(function()
        players = nil
        ns1 = nil
        ns2 = nil
    end)

    test('test', function()
        ns1.me.officer = false
        ns2.me.officer = true

        ns1.Sync:syncInit()
    end)
end)
