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

        local realmId = 1234

        ns.me = {
            name = playerName,
            guid = ('Player-%s-%s'):format(realmId, playerShortGuid),
        }

        players[playerName] = ns.me

        ns.addon.versionNum = 1
        ns.minSyncVersion = 1

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
            gpBase = 100,
        }

        ns.db = {
            history = {},
            lmSettingsLastChange = 1,
            realmId = realmId,
            altData = {
                altMainMapping = {},
                mainAltMapping = {},
            },
        }

        ns.standings = ns.Dict:new()
        ns.playersLastUpdated = ns.Dict:new()

        ns.Lib.isOfficer = function(player)
            if player == nil then
                player = ns.unitName('player')
            end
            return players[player].officer
        end

        ns.MainWindow = {
            refresh = function() end,
        }

        ns.RaidWindow = {
            refresh = function() end,
        }

        spy.on(ns.addon, 'computeStandings')
        spy.on(ns.addon, 'computeStandingsWithEvents')

        spy.on(ns.Sync, 'sendSync0')
        spy.on(ns.Sync, 'sendSync1')
        spy.on(ns.Sync, 'sendSync2')
        spy.on(ns.Sync, 'sendDataReq')
        spy.on(ns.Sync, 'sendDataSend')
        spy.on(ns.Sync, 'handleSync0')
        spy.on(ns.Sync, 'handleSync1')
        spy.on(ns.Sync, 'handleSync2')
        spy.on(ns.Sync, 'handleDataReq')
        spy.on(ns.Sync, 'handleDataSend')
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
            ns1.Comm.handleMessage(prefix, message, nil, ns2.me.name)
        end

        ns1.Sync:init()
        ns2.Sync:init()
    end)

    after_each(function()
        players = nil
        ns1 = nil
        ns2 = nil
    end)

    describe('sync', function()
        test('officer online, up-to-date; non-officer logs on, behind', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, behind; non-officer logs on, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.not_same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; non-officer logs on, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.same(ns1.standings, ns2.standings)

            assert.spy(ns1.Sync.handleSync0).was.called(1)
            assert.spy(ns1.Sync.handleSync1).was.not_called()
            assert.spy(ns1.Sync.handleSync2).was.not_called()
            assert.spy(ns1.Sync.handleDataReq).was.not_called()
            assert.spy(ns1.Sync.handleDataSend).was.not_called()
            assert.spy(ns1.Sync.sendSync0).was.not_called()
            assert.spy(ns1.Sync.sendSync1).was.not_called()
            assert.spy(ns1.Sync.sendSync2).was.not_called()
            assert.spy(ns1.Sync.sendDataReq).was.not_called()
            assert.spy(ns1.Sync.sendDataSend).was.not_called()

            assert.spy(ns2.Sync.handleSync0).was.not_called()
            assert.spy(ns2.Sync.handleSync1).was.not_called()
            assert.spy(ns2.Sync.handleSync2).was.not_called()
            assert.spy(ns2.Sync.handleDataReq).was.not_called()
            assert.spy(ns2.Sync.handleDataSend).was.not_called()
            assert.spy(ns2.Sync.sendSync0).was.called(1)
            assert.spy(ns2.Sync.sendSync1).was.not_called()
            assert.spy(ns2.Sync.sendSync2).was.not_called()
            assert.spy(ns2.Sync.sendDataReq).was.not_called()
            assert.spy(ns2.Sync.sendDataSend).was.not_called()
        end)

        test('officer online, up-to-date; non-officer logs on, missing a week', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; non-officer logs on, missing first week', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; non-officer logs on, missing first week and some of last', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; non-officer logs on, missing first week and some of last 2', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(2)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; non-officer logs on, missing all', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {}

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        -------------------------------------------------------------

        test('officer online, up-to-date; officer logs on, behind', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, behind; officer logs on, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyMia, ns1.db.history)
            assert.same(historyMia, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.called(1)
            assert.spy(ns1.addon.computeStandingsWithEvents).was.called(2)
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, missing a week', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, missing first week', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, missing first week and some of last', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, missing first week and some of last 2', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(2)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online, up-to-date; officer logs on, missing all', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {}

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer online; officer logs on; mixed', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            local expected = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            assert.same(expected, ns1.db.history)
            assert.same(expected, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.called(1)
            assert.spy(ns1.addon.computeStandingsWithEvents).was.called(2)
            assert.spy(ns2.addon.computeStandings).was.called(2)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        -------------------------------------------------------------

        test('officer logs on, up-to-date; non-officer online, behind', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, behind; non-officer online, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.not_same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, up-to-date', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, missing a week', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, missing first week', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, missing first week and some of last', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, missing first week and some of last 2', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(2)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(2)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer logs on, up-to-date; non-officer online, missing all', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {}

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.called(1)
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        -------------------------------------------------------------

        test('non-officer online, up-to-date; non-officer logs on, behind', function()
            ns1.me.officer = false
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns2.Sync:syncInit()

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.not_same(ns1.standings, ns2.standings)
        end)
    end)

    describe('new event', function()
        test('officer sends new event to non-officer', function()
            ns1.me.officer = true
            ns2.me.officer = false

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:sendEventsToGuild({
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                }
            })

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('officer sends new event to officer', function()
            ns1.me.officer = true
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:sendEventsToGuild({
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                }
            })

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyTucker, ns2.db.history)
            assert.same(ns1.db.history, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.called(1)

            assert.same(ns1.standings, ns2.standings)
        end)

        test('non-officer sends new event to officer', function()
            ns1.me.officer = false
            ns2.me.officer = true

            local historyTucker = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                },
            }

            local historyMia = {
                {
                    {
                        1696208400,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    123,
                },
                {
                    {
                        1696212000,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    234,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    345,
                },
                {
                    {
                        1696294800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    346,
                },
                {
                    {
                        1696813200,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        100,
                        '1:stuff',
                        false,
                        100,
                    },
                    456,
                },
                {
                    {
                        1696816800,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        75,
                        '2:boss',
                        false,
                        100,
                    },
                    567,
                },
            }

            ns1.db.history = ns1.Lib.deepcopy(historyTucker)
            ns2.db.history = ns2.Lib.deepcopy(historyMia)

            ns1.Sync:computeIndices()
            ns2.Sync:computeIndices()

            ns1.addon:computeStandings()
            ns2.addon:computeStandings()
            ns1.addon.computeStandings:clear()
            ns1.addon.computeStandingsWithEvents:clear()
            ns2.addon.computeStandings:clear()
            ns2.addon.computeStandingsWithEvents:clear()

            ns1.Sync:sendEventsToGuild({
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'ep',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    678,
                },
                {
                    {
                        1696899600,
                        '11111111',
                        {
                            '11111111',
                            '22222222',
                        },
                        'gp',
                        -10,
                        '3:weekly',
                        true,
                        100,
                    },
                    679,
                }
            })

            assert.same(historyTucker, ns1.db.history)
            assert.same(historyMia, ns2.db.history)

            assert.spy(ns1.addon.computeStandings).was.not_called()
            assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
            assert.spy(ns2.addon.computeStandings).was.not_called()
            assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

            assert.not_same(ns1.standings, ns2.standings)
        end)
    end)

    test('non-officer sends new event to non-officer', function()
        ns1.me.officer = false
        ns2.me.officer = false

        local historyTucker = {
            {
                {
                    1696208400,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    100,
                    '1:stuff',
                    false,
                    100,
                },
                123,
            },
            {
                {
                    1696212000,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    75,
                    '2:boss',
                    false,
                    100,
                },
                234,
            },
            {
                {
                    1696294800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                345,
            },
            {
                {
                    1696294800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                346,
            },
            {
                {
                    1696813200,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    100,
                    '1:stuff',
                    false,
                    100,
                },
                456,
            },
            {
                {
                    1696816800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    75,
                    '2:boss',
                    false,
                    100,
                },
                567,
            },
            {
                {
                    1696899600,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                678,
            },
            {
                {
                    1696899600,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                679,
            },
        }

        local historyMia = {
            {
                {
                    1696208400,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    100,
                    '1:stuff',
                    false,
                    100,
                },
                123,
            },
            {
                {
                    1696212000,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    75,
                    '2:boss',
                    false,
                    100,
                },
                234,
            },
            {
                {
                    1696294800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                345,
            },
            {
                {
                    1696294800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                346,
            },
            {
                {
                    1696813200,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    100,
                    '1:stuff',
                    false,
                    100,
                },
                456,
            },
            {
                {
                    1696816800,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    75,
                    '2:boss',
                    false,
                    100,
                },
                567,
            },
        }

        ns1.db.history = ns1.Lib.deepcopy(historyTucker)
        ns2.db.history = ns2.Lib.deepcopy(historyMia)

        ns1.Sync:computeIndices()
        ns2.Sync:computeIndices()

        ns1.addon:computeStandings()
        ns2.addon:computeStandings()
        ns1.addon.computeStandings:clear()
        ns1.addon.computeStandingsWithEvents:clear()
        ns2.addon.computeStandings:clear()
        ns2.addon.computeStandingsWithEvents:clear()

        ns1.Sync:sendEventsToGuild({
            {
                {
                    1696899600,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'ep',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                678,
            },
            {
                {
                    1696899600,
                    '11111111',
                    {
                        '11111111',
                        '22222222',
                    },
                    'gp',
                    -10,
                    '3:weekly',
                    true,
                    100,
                },
                679,
            }
        })

        assert.same(historyTucker, ns1.db.history)
        assert.same(historyMia, ns2.db.history)

        assert.spy(ns1.addon.computeStandings).was.not_called()
        assert.spy(ns1.addon.computeStandingsWithEvents).was.not_called()
        assert.spy(ns2.addon.computeStandings).was.not_called()
        assert.spy(ns2.addon.computeStandingsWithEvents).was.not_called()

        assert.not_same(ns1.standings, ns2.standings)
    end)

    -- TODO: test lm settings
end)
