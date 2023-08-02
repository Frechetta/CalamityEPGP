loadfile('test/setup.lua')(spy, stub, mock)


describe('award', function()
    local ns
    local ldw

    local itemInfo = {
        i1 = {
            id = 1,
            name = 'item1',
        },
        i2 = {
            id = 2,
            name = 'item2',
        },
        i3 = {
            id = 3,
            name = 'item3',
        },
        i4 = {
            id = 4,
            name = 'item4',
        },
    }

    local candidates = {
        [1] = {
            'p1',
            'p2',
            'p3',
        },
        [2] = {
            'p1',
            'p2',
            'p3',
        },
        [3] = {
            'p1',
            'p3',
        },
    }

    local numGroupMembers
    local closeOnAward

    before_each(function()
        ns = {
            cfg = {},
            db = {
                loot = {
                    awarded = {},
                },
            },
        }

        numGroupMembers = 0
        closeOnAward = false

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('window-loot-dist', ns)
        Util:loadModule('main', ns)

        ldw = ns.LootDistWindow

        ldw.currentLoot = {}

        _G.GetNumGroupMembers = function() return numGroupMembers end

        _G.GetMasterLootCandidate = function(itemIndex, playerIndex)
            if candidates[itemIndex] ~= nil then
                return candidates[itemIndex][playerIndex]
            end
        end

        _G.GiveMasterLoot = spy.new()

        stub(ldw, 'successfulAward')
        stub(ldw, 'markAsToTrade')

        ns.Lib.getItemInfo = function(itemLink, callback)
            if itemInfo[itemLink] ~= nil then
                callback({name = itemInfo[itemLink].name})
            end
        end

        ns.addon.modifyEpgp = spy.new()

        ns.Lib.getPlayerGuid = function(playerName)
            return playerName .. '_guid'
        end

        ldw.mainFrame = mock({
            closeOnAwardCheck = mock({
                GetChecked = function(_) return closeOnAward end
            }),
            Hide = spy.new(),
        })

        stub(ns, 'printPublic')
    end)

    test('loot window not self GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i2 = {
                p3 = {
                    {
                        itemLink = 'i2',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i2', 'p3', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(2, 3)

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'gp', 100, 'award: item2 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window self GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i2 = {
                p1 = {
                    {
                        itemLink = 'i2',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i2', 'p1', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(2, 1)

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 100, 'award: item2 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p1 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window awardee not eligible GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        local expectedAwarded = {}

        ldw:award('i3', 'p2', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()
        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i4 = {
                p1 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p1', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.called(1)
        assert.stub(ldw.successfulAward).was.called_with(ldw, 'i4', 'p1')

        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 100, 'award: item4 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p1 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory not self GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i4 = {
                p2 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p2', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p2_guid'}, 'gp', 100, 'award: item4 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window not self no GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i2 = {
                p3 = {
                    {
                        itemLink = 'i2',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i2', 'p3')

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(2, 3)

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window awardee not eligible no GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        local expectedAwarded = {}

        ldw:award('i3', 'p2')

        assert.spy(GiveMasterLoot).was.not_called()
        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self no GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i4 = {
                p1 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p1')

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.called(1)
        assert.stub(ldw.successfulAward).was.called_with(ldw, 'i4', 'p1')

        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p1')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory not self no GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3

        local expectedAwarded = {
            i4 = {
                p2 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p2')

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window not self GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i2 = {
                p3 = {
                    {
                        itemLink = 'i2',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i2', 'p3', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(2, 3)

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'gp', 100, 'award: item2 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window awardee not eligible GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {}

        ldw:award('i3', 'p2', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()
        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self GP no hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i4 = {
                p1 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p1', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.called(1)
        assert.stub(ldw.successfulAward).was.called_with(ldw, 'i4', 'p1')

        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 100, 'award: item4 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p1 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('inventory not self GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i4 = {
                p2 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p2', 'DERP', '87%', 100)

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p2_guid'}, 'gp', 100, 'award: item4 - DERP - 100.00')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2 for DERP (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window not self no GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i2 = {
                p3 = {
                    {
                        itemLink = 'i2',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i2', 'p3')

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(2, 3)

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window awardee not eligible no GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {}

        ldw:award('i3', 'p2')

        assert.spy(GiveMasterLoot).was.not_called()
        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self no GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i4 = {
                p1 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p1')

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.called(1)
        assert.stub(ldw.successfulAward).was.called_with(ldw, 'i4', 'p1')

        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p1')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('inventory not self no GP hide', function()
        ldw.currentLoot = {
            i1 = 1,
            i2 = 2,
            i3 = 3,
        }

        numGroupMembers = 3
        closeOnAward = true

        local expectedAwarded = {
            i4 = {
                p2 = {
                    {
                        itemLink = 'i4',
                        awardTime = 123,
                        given = false,
                        givenTime = nil,
                        collected = false,
                    }
                }
            }
        }

        ldw:award('i4', 'p2')

        assert.spy(GiveMasterLoot).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)
end)
