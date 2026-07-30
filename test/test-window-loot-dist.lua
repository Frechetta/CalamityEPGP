loadfile('test/setup.lua')(spy, stub, mock)


describe('give loot', function()
    local ns
    local ldw

    local candidates = {
        [1] = {
            'p1',
            'p2',
            'p3-Atiesh',
        },
        [2] = {
            'p1',
            'p2',
            'p3-Atiesh',
        },
        [3] = {
            'p1',
            'p3-Atiesh',
        },
    }

    before_each(function()
        ns = {}

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('window-loot-dist', ns)
        Util:loadModule('main', ns)

        ldw = ns.LootDistWindow

        _G.GetMasterLootCandidate = function(itemIndex, playerIndex)
            return candidates[itemIndex][playerIndex]
        end

        _G.GiveMasterLoot = spy.new()
    end)

    test('provided same realm candidate same realm eligible', function()
        local result = ldw:giveLootFromLootWindow(1, 'p2')

        assert.is_true(result)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(1, 2)
    end)

    test('provided same realm candidate same realm ineligible', function()
        local result = ldw:giveLootFromLootWindow(3, 'p2')

        assert.is_false(result)

        assert.spy(GiveMasterLoot).was.not_called()
    end)

    test('provided different realm candidate same realm eligible', function()
        local result = ldw:giveLootFromLootWindow(1, 'p2-Atiesh')

        assert.is_true(result)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(1, 2)
    end)

    test('provided different realm candidate same realm ineligible', function()
        local result = ldw:giveLootFromLootWindow(3, 'p2-Atiesh')

        assert.is_false(result)

        assert.spy(GiveMasterLoot).was.not_called()
    end)

    test('provided different realm candidate different realm eligible', function()
        local result = ldw:giveLootFromLootWindow(1, 'p3-Atiesh')

        assert.is_true(result)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(1, 3)
    end)

    test('provided same realm candidate different realm eligible', function()
        local result = ldw:giveLootFromLootWindow(1, 'p3')

        assert.is_true(result)

        assert.spy(GiveMasterLoot).was.called(1)
        assert.spy(GiveMasterLoot).was.called_with(1, 3)
    end)
end)


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

    local awardeeEligible
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

        awardeeEligible = nil
        closeOnAward = nil

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('window-loot-dist', ns)
        Util:loadModule('main', ns)

        ldw = ns.LootDistWindow

        ldw.getLootItemIndex = function(_, itemLink)
            if itemInfo[itemLink] ~= nil then
                local itemId = itemInfo[itemLink].id
                if itemId ~= 4 then
                    return itemId
                end
            end
        end

        ldw.giveLootFromLootWindow = spy.new(function(_, _itemIndex, _playerFullName)
            return awardeeEligible
        end)

        stub(ldw, 'successfulAward')
        stub(ldw, 'markAsToTrade')

        ns.Lib.getItemIdFromLink = function(itemLink)
            if itemInfo[itemLink] ~= nil then
                return itemInfo[itemLink].id
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
        awardeeEligible = true
        closeOnAward = false

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

        ldw:award('i2', 'p3', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p3')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'gp', 100, '3:ms:2')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window self GP no hide', function()
        awardeeEligible = true
        closeOnAward = false

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

        ldw:award('i2', 'p1', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p1')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 100, '3:ms:2')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p1 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window awardee not eligible GP no hide', function()
        awardeeEligible = false
        closeOnAward = false

        local expectedAwarded = {}

        ldw:award('i1', 'p2', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 1, 'p2')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self GP no hide', function()
        closeOnAward = false

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

        ldw:award('i4', 'p1', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

        assert.stub(ldw.successfulAward).was.called(1)
        assert.stub(ldw.successfulAward).was.called_with(ldw, 'i4', 'p1')

        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p1_guid'}, 'gp', 100, '3:ms:4')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p1 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory not self GP no hide', function()
        closeOnAward = false

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

        ldw:award('i4', 'p2', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p2_guid'}, 'gp', 100, '3:ms:4')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window not self no GP no hide', function()
        awardeeEligible = true
        closeOnAward = false

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

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p3')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window awardee not eligible no GP no hide', function()
        awardeeEligible = false
        closeOnAward = false

        local expectedAwarded = {}

        ldw:award('i3', 'p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 3, 'p2')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self no GP no hide', function()
        closeOnAward = false

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

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

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
        closeOnAward = false

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

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

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
        awardeeEligible = true
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

        ldw:award('i2', 'p3', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p3')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'gp', 100, '3:ms:2')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window awardee not eligible GP hide', function()
        awardeeEligible = false
        closeOnAward = true

        local expectedAwarded = {}

        ldw:award('i3', 'p2', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 3, 'p2')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory not self GP hide', function()
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

        ldw:award('i4', 'p2', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p2_guid'}, 'gp', 100, '3:ms:4')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window not self no GP hide', function()
        awardeeEligible = true
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

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p3')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window awardee not eligible no GP hide', function()
        awardeeEligible = false
        closeOnAward = true

        local expectedAwarded = {}

        ldw:award('i3', 'p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 3, 'p2')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()
        assert.spy(ns.addon.modifyEpgp).was.not_called()
        assert.spy(ns.printPublic).was.not_called()
        assert.same(expectedAwarded, ns.db.loot.awarded)
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory self no GP hide', function()
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

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

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

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window not self GP no hide different realm', function()
        awardeeEligible = true
        closeOnAward = false

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

        ldw:award('i2', 'p3-Atiesh', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 2, 'p3')

        assert.stub(ldw.successfulAward).was.not_called()
        assert.stub(ldw.markAsToTrade).was.not_called()

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p3_guid'}, 'gp', 100, '3:ms:2')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i2 was awarded to p3 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory not self GP hide different realm', function()
        awardeeEligible = true
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

        ldw:award('i4', 'p2-Atiesh', 'MS', '87%', 100)

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()

        assert.stub(ldw.successfulAward).was.not_called()

        assert.stub(ldw.markAsToTrade).was.called(1)
        assert.stub(ldw.markAsToTrade).was.called_with('i4', 'p2')

        assert.spy(ns.addon.modifyEpgp).was.called(1)
        assert.spy(ns.addon.modifyEpgp).was.called_with(ns.addon, {'p2_guid'}, 'gp', 100, '3:ms:4')

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('i4 was awarded to p2 for MS (87% GP: 100)')

        assert.same(expectedAwarded, ns.db.loot.awarded)

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)
end)


describe('disenchant', function()
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
    }

    local disenchanterEligible
    local closeOnAward

    before_each(function()
        ns = {}

        disenchanterEligible = nil
        closeOnAward = nil

        Util:loadModule('constants', ns)
        Util:loadModule('values', ns)
        Util:loadModule('lib', ns)
        Util:loadModule('window-loot-dist', ns)
        Util:loadModule('main', ns)

        ldw = ns.LootDistWindow

        ldw.disenchanter = nil
        ldw.itemLink = nil

        ldw.getLootItemIndex = function(_, itemLink)
            if itemInfo[itemLink] ~= nil then
                return itemInfo[itemLink].id
            end
        end

        ldw.giveLootFromLootWindow = spy.new(function(_, _itemIndex, _playerFullName)
            return disenchanterEligible
        end)

        ldw.mainFrame = mock({
            closeOnAwardCheck = mock({
                GetChecked = function(_) return closeOnAward end
            }),
            Hide = spy.new(),
        })

        ns.DeSelectWindow = mock({
            show = spy.new(),
        })

        stub(ns, 'printPublic')
    end)

    test('loot window disenchanter not chosen', function()
        ldw.itemLink = 'i1'

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.called(1)
        assert.spy(ns.printPublic).was.not_called()
        assert.spy(ldw.giveLootFromLootWindow).was.not_called()
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window disenchanter chosen eligible no hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i1'
        disenchanterEligible = true
        closeOnAward = false

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i1 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 1, 'p2')

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window disenchanter chosen eligible hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i1'
        disenchanterEligible = true
        closeOnAward = true

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i1 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 1, 'p2')

        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)

    test('loot window disenchanter chosen ineligible no hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i3'
        disenchanterEligible = false
        closeOnAward = false

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i3 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 3, 'p2')

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('loot window disenchanter chosen ineligible hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i3'
        disenchanterEligible = false
        closeOnAward = true

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i3 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.called(1)
        assert.spy(ldw.giveLootFromLootWindow).was.called_with(ldw, 3, 'p2')

        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory disenchanter not chosen', function()
        ldw.itemLink = 'i4'

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.called(1)
        assert.spy(ns.printPublic).was.not_called()
        assert.spy(ldw.giveLootFromLootWindow).was.not_called()
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory disenchanter chosen no hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i4'
        closeOnAward = false

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i4 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()
        assert.spy(ldw.mainFrame.Hide).was.not_called()
    end)

    test('inventory disenchanter chosen hide', function()
        ldw.disenchanter = 'p2'
        ldw.itemLink = 'i4'
        closeOnAward = true

        ldw:disenchant()

        assert.spy(ns.DeSelectWindow.show).was.not_called()

        assert.spy(ns.printPublic).was.called(1)
        assert.spy(ns.printPublic).was.called_with('Item i4 will be disenchanted by p2')

        assert.spy(ldw.giveLootFromLootWindow).was.not_called()
        assert.spy(ldw.mainFrame.Hide).was.called(1)
    end)
end)
