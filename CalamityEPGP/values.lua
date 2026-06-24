local _, ns = ...  -- Namespace

ns.values = {}

ns.values.epgpReasons = {
    MANUAL_SINGLE = 0,
    MANUAL_MULTIPLE = 1,
    DECAY = 2,
    AWARD = 3,
    BOSS_KILL = 4,
    CLEAR = 5,
}

ns.values.gpDefaults = {
    base = 1,
    -- https://wowpedia.fandom.com/wiki/Enum.InventoryType
    slotModifiers = {
        INVTYPE_HEAD = {
            base = 1,
        },
        INVTYPE_NECK = {
            base = 0.5,
        },
        INVTYPE_SHOULDER = {
            base = 0.75,
        },
        INVTYPE_CLOAK = {
            base = 0.5,
        },
        INVTYPE_CHEST = {
            base = 1,
        },
        INVTYPE_WRIST = {
            base = 0.5,
        },
        INVTYPE_HAND = {
            base = 0.75,
        },
        INVTYPE_WAIST = {
            base = 0.75,
        },
        INVTYPE_LEGS = {
            base = 1,
        },
        INVTYPE_FEET = {
            base = 0.75,
        },
        INVTYPE_FINGER = {
            base = 0.5,
        },
        INVTYPE_TRINKET = {
            base = 1.25,
        },
        INVTYPE_WEAPON = {  -- one handed weapon
            base = 1,  -- [increase to 1.5 for casters]
            overrides = {
                DRUID = {
                    [ns.consts.SPEC_DRUID_BALANCE] = 1.5,
                    [ns.consts.SPEC_DRUID_RESTO] = 1.5,
                },
                MAGE = 1.5,
                PALADIN = {
                    [ns.consts.SPEC_PALADIN_HOLY] = 1.5,
                },
                PRIEST = 1.5,
                SHAMAN = {
                    [ns.consts.SPEC_SHAMAN_ELE] = 1.5,
                    [ns.consts.SPEC_SHAMAN_RESTO] = 1.5,
                },
                WARLOCK = 1.5,
            },
        },
        -- unused in mop pve?
        INVTYPE_WEAPONMAINHAND = {
            base = 1,  -- [increase to 1.5 for casters]
            overrides = {
                DRUID = {
                    [ns.consts.SPEC_DRUID_BALANCE] = 1.5,
                    [ns.consts.SPEC_DRUID_RESTO] = 1.5,
                },
                MAGE = 1.5,
                PALADIN = {
                    [ns.consts.SPEC_PALADIN_HOLY] = 1.5,
                },
                PRIEST = 1.5,
                SHAMAN = {
                    [ns.consts.SPEC_SHAMAN_ELE] = 1.5,
                    [ns.consts.SPEC_SHAMAN_RESTO] = 1.5,
                },
                WARLOCK = 1.5,
            },
        },
        -- unused in mop pve?
        INVTYPE_WEAPONOFFHAND = {
            base = 1,
        },
        INVTYPE_2HWEAPON = {
            base = 2,  -- [decrease to 1 for fury warriors]
            overrides = {
                WARRIOR = {
                    [ns.consts.SPEC_WARRIOR_FURY] = 1,
                },
            },
        },
        INVTYPE_SHIELD = {
            base = 0.5,  -- [increase to 1 for prot warriors and prot paladins]
            overrides = {
                PALADIN = {
                    [ns.consts.SPEC_PALADIN_PROT] = 1,
                },
                WARRIOR = {
                    [ns.consts.SPEC_WARRIOR_PROT] = 1,
                },
            },
        },
        INVTYPE_RANGED = {
            base = 0.5,  -- [increase to 2 for hunters]
            overrides = {
                HUNTER = 2,
            },
        },
        INVTYPE_RANGEDRIGHT = {  -- wand and some other ranged
            base = 1,  -- [increase to 1.5 for casters and 2 for hunters]
            overrides = {
                DRUID = {
                    [ns.consts.SPEC_DRUID_BALANCE] = 1.5,
                    [ns.consts.SPEC_DRUID_RESTO] = 1.5,
                },
                HUNTER = 2,
                MAGE = 1.5,
                PALADIN = {
                    [ns.consts.SPEC_PALADIN_HOLY] = 1.5,
                },
                PRIEST = 1.5,
                SHAMAN = {
                    [ns.consts.SPEC_SHAMAN_ELE] = 1.5,
                    [ns.consts.SPEC_SHAMAN_RESTO] = 1.5,
                },
                WARLOCK = 1.5,
            },
        },
        INVTYPE_HOLDABLE = {  -- held in off hand
            base = 0.5,
        },
        -- unused in mop?
        INVTYPE_RELIC = {
            base = 0.5,
        },
        -- unused in mop?
        INVTYPE_THROWN = {
            base = 0.5,
        },
    },
}

ns.values.epDefaults = {
    {
        'Vanilla',  -- expansion name
        {
            {
                'Zul\'Gurub',  -- instance name
                {
                    -- boss, encounterID, default EP
                    {'High Priest Venoxis', 784, 2},
                    {'High Priestess Jeklik', 785, 2},
                    {"High Priestess Mar'li", 786, 2},
                    {"High Priest Thekal", 789, 2},
                    {"High Priestess Arlokk", 791, 2},
                    {"Edge of Madness", 788, 2},
                    {"Bloodlord Mandokir", 787, 2},
                    {"Jin'do the Hexxer", 792, 2},
                    {"Gahz'ranka", 790, 2},
                    {"Hakkar", 793, 3},
                },
            },
        },
    },
    {
        'WotLK',
        {
            {
                "Naxxramas",
                {
                    {"Anub'Rekhan", 1107, 26},
                    {"Grand Widow Faerlina", 1110, 26},
                    {"Maexxna", 1116, 26},
                    {"Noth the Plaguebringer", 1117, 26},
                    {"Heigan the Unclean", 1112, 26},
                    {"Loatheb", 1115, 26},
                    {"Instructor Razuvious", 1113, 26},
                    {"Gothik the Harvester", 1109, 26},
                    {"The Four Horsemen", 1121, 26},
                    {"Patchwerk", 1118, 26},
                    {"Grobbulus", 1111, 26},
                    {"Gluth", 1108, 26},
                    {"Thaddius", 1120, 26},
                    {"Sapphiron", 1119, 28},
                    {"Kel'Thuzad", 1114, 28},
                },
            },
            {
                "Obsidian Sanctum",
                {
                    {"Sartharion", 742, 26},
                },
            },
            {
                "Eye of Eternity",
                {
                    {"Malygos", 734, 26},
                },
            },
            {
                "Ulduar",
                {
                    {"Flame Leviathan", 744, 28},
                    {"Ignis the Furnace Master", 745, 28},
                    {"Razorscale", 746, 28},
                    {"XT-002 Deconstructor", 747, 28},
                    {"The Iron Council", 748, 28},
                    {"Kologarn", 749, 28},
                    {"Auriaya", 750, 28},
                    {"Hodir", 751, 28},
                    {"Thorim", 752, 28},
                    {"Freya", 753, 28},
                    {"Mimiron", 754, 28},
                    {"General Vezax", 755, 28},
                    {"Algalon the Observer", 757, 30},
                    {"Yogg-Saron", 756, 30},
                },
            },
            {
                "Trial of the Crusader",
                {
                    {"Northrend Beasts", 629, 30},
                    {"Lord Jaraxxus", 633, 30},
                    {"Faction Champions", 637, 30},
                    {"Val'kyr Twins", 641, 30},
                    {"Anub'arak", 645, 32},
                },
            },
            {
                "Icecrown Citadel",
                {
                    {"Lord Marrowgar", 845, 75},
                    {"Lady Deathwhisper", 846, 75},
                    {"Icecrown Gunship Battle", 847, 75},
                    {"Deathbringer Saurfang", 848, 75},
                    {"Festergut", 849, 75},
                    {"Rotface", 850, 75},
                    {"Professor Putricide", 851, 75},
                    {"Blood Council", 852, 75},
                    {"Queen Lana'thel", 853, 75},
                    {"Valithria Dreamwalker", 854, 75},
                    {"Sindragosa", 855, 75},
                    {"The Lich King", 856, 75},
                },
            },
            {
                "Ruby Sanctum",
                {
                    {"Halion", 887, 75},
                },
            },
            {
                "Vault of Archavon",
                {
                    {"Archavon the Stone Watcher", 772, 26},
                    {"Emalon the Storm Watcher", 774, 28},
                    {"Koralon the Flame Watcher", 776, 30},
                    {"Toravon the Ice Watcher", 885, 75},
                },
            },
            {
                "Onyxias Lair",
                {
                    {"Onyxia", 1084, 30},
                },
            },
        },
    },
    {
        'Cataclysm',
        {
            {
                "Bastion of Twilight",
                {
                    {"Halfus Wyrmbreaker", 1030, 95},
                    {"Therelion & Valiona", 1032, 95},
                    {"Ascendant Council", 1028, 95},
                    {"Cho'gall", 1029, 95},
                    {"Sinestra", 1082, 97},
                    {"Sinestra", 1083, 97},  -- ?
                },
            },
            {
                "Throne of the Four Winds",
                {
                    {"Conclave of Wind", 1035, 95},
                    {"Al'Akir", 1034, 95},
                },
            },
            {
                "Blackwing Descent",
                {
                    {"Magmaw", 1024, 95},
                    {"Omnotron Defense System", 1027, 95},
                    {"Maloriak", 1025, 95},
                    {"Atramedes", 1022, 95},
                    {"Chimaeron", 1023, 95},
                    {"Nefarian", 1026, 95},
                },
            },
            {
                "Firelands",
                {
                    {"Beth'tilac", 1197, 100},
                    {"Lord Rhyolith", 1204, 100},
                    {"Alysrazor", 1206, 100},
                    {"Shannox", 1205, 100},
                    {"Baleroc", 1200, 100},
                    {"Majordomo Staghelm", 1185, 100},
                    {"Ragnaros", 1203, 102},
                },
            },
            {
                "Dragon Soul",
                {
                    {"Morchok", 1292, 105},
                    {"Warlord Zon'ozz", 1294, 105},
                    {"Yor'sahj the Unsleeping", 1295, 105},
                    {"Hagara the Stormbinder", 1296, 105},
                    {"Ultraxion", 1297, 105},
                    {"Warmaster Blackhorn", 1298, 105},
                    {"Spine of Deathwing", 1291, 107},
                    {"Madness of Deathwing", 1299, 107},
                },
            },
            {
                "Baradin Hold",
                {
                    {"Argaloth", 1033, 92},
                    {"Occu'thar", 1250, 97},
                    {"Alizabal", 1332, 102},
                },
            },
        },
    },
    {
        'Mists of Pandaria',
        {
            -- the boss IDs for the commented bosses aren't correct
            -- {
            --     "Mogu'shan Vaults",
            --     {
            --         {"The Stone Guard", 1395, 110},
            --         {"Feng the Accursed", 1390, 110},
            --         {"Gara'jal the Spiritbinder", 1446, 110},
            --         {"The Spirit Kings", 1445, 110},
            --         {"Elegon", 1449, 110},
            --         {"Will of the Emperor", 1450, 110},
            --     },
            -- },
            -- {
            --     "Heart of Fear",
            --     {
            --         {"Imperial Vizier Zor'lok", 1518, 115},
            --         {"Blade Lord Ta'yak", 1519, 115},
            --         {"Garalon", 1520, 115},
            --         {"Wind Lord Mel'jarak", 1521, 115},
            --         {"Amber-Shaper Un'sok", 1522, 115},
            --         {"Grand Empress Shek'zeer", 1523, 115},
            --     },
            -- },
            -- {
            --     "Terrace of Endless Spring",
            --     {
            --         {"Protectors of the Endless", 1530, 115},
            --         {"Tsulong", 1531, 115},
            --         {"Lei Shi", 1532, 115},
            --     },
            -- },
            -- {
            --     "Throne of Thunder",
            --     {
            --         {"Jin'rokh the Breaker", 1571, 120},
            --         {"Horridon", 1572, 120},
            --         {"Council of Elders", 1573, 120},
            --         {"Tortos", 1574, 120},
            --         {"Megaera", 1575, 120},
            --         {"Ji-Kun", 1576, 120},
            --         {"Durumu the Forgotten", 1577, 120},
            --         {"Primordius", 1578, 120},
            --         {"Dark Animus", 1579, 120},
            --         {"Iron Qon", 1580, 120},
            --         {"Twin Consorts", 1581, 120},
            --         {"Lei Shen", 1582, 120},
            --     },
            -- },
            {
                "Siege of Orgrimmar",
                {
                    {"Immerseus", 1602, 125},
                    {"Fallen Protectors", 1598, 125},
                    {"Norushen", 1624, 125},
                    {"Sha of Pride", 1604, 125},
                    {"Galakras", 1622, 125},
                    {"Iron Juggernaut", 1600, 125},
                    {"Kor'kron Dark Shaman", 1606, 125},
                    {"General Nazgrim", 1603, 125},
                    {"Malkorok", 1595, 125},
                    {"Spoils of Pandaria", 1594, 125},
                    {"Thok the Bloodthirsty", 1599, 125},
                    {"Siegecrafter Blackfuse", 1601, 125},
                    {"Paragons of the Klaxxi", 1593, 125},
                    {"Garrosh Hellscream", 1623, 125},
                },
            },
        },
    },
}

ns.values.encounters = {}

for _, expansion in ipairs(ns.values.epDefaults) do
    for _, instance in ipairs(expansion[2]) do
        for _, encounter in ipairs(instance[2]) do
            local encounterName = encounter[1]
            local encounterId = encounter[2]
            local encounterEp = encounter[3]

            ns.values.encounters[encounterId] = {
                name = encounterName,
                defaultEp = encounterEp,
                instance = instance[1],
                expansion = expansion[1],
            }
        end
    end
end

ns.values.tokenGp = {
    --- WOTLK ---
    -- Onyxia's Layer
    -- head
    [49644] = 245,

    -- T7
    -- head
    [40631] = 213,
    [40632] = 213,
    [40633] = 213,
    [40616] = 200,
    [40617] = 200,
    [40618] = 200,
    -- legs
    [40634] = 213,
    [40635] = 213,
    [40636] = 213,
    [40619] = 200,
    [40620] = 200,
    [40621] = 200,
    -- chest
    [40625] = 213,
    [40626] = 213,
    [40627] = 213,
    [40610] = 200,
    [40611] = 200,
    [40612] = 200,
    -- shoulder
    [40637] = 213,
    [40638] = 213,
    [40639] = 213,
    [40622] = 200,
    [40623] = 200,
    [40624] = 200,

    -- OS
    -- hand
    [40628] = 213,
    [40629] = 213,
    [40630] = 213,
    [40613] = 200,
    [40614] = 200,
    [40615] = 200,

    -- T8
    -- chest
    [45635] = 225, -- Chestguard of the Wayward Conqueror
    [45636] = 225,
    [45637] = 225,
    [45632] = 232, -- Breastplate of the Wayward Conqueror
    [45633] = 232,
    [45634] = 232,
    -- shoulder
    [45659] = 225,
    [45660] = 225,
    [45661] = 225,
    [45656] = 232,
    [45657] = 232,
    [45658] = 232,
    -- legs
    [45650] = 225,
    [45651] = 225,
    [45652] = 225,
    [45653] = 232,
    [45654] = 232,
    [45655] = 232,
    -- head
    [45647] = 225,
    [45648] = 225,
    [45649] = 225,
    [45638] = 232,
    [45639] = 232,
    [45640] = 232,
    -- hand
    [45644] = 225,
    [45645] = 225,
    [45646] = 225,
    [45641] = 232,
    [45642] = 232,
    [45643] = 232,
    -- reply-code alpha
    [46052] = 239,
    [46053] = 252,

    -- T9
    -- trophy
    [47242] = 245,  -- Trophy of the Crusade
    -- tokens
    [47559] = 258,  -- Regalia of the Grand Vanquisher
    [47558] = 258,  -- Regalia of the Grand Protector
    [47557] = 258,  -- Regalia of the Grand Conqueror

    -- T10
    -- marks
    [52025] = 264, -- Vanquisher's Mark of Sanctification
    [52027] = 264, -- Conqueror's Mark of Sanctification
    [52026] = 264, -- Protector's Mark of Sanctification
    [52030] = 277, -- Conqueror's Mark of Sanctification (heroic)
    [52028] = 277, -- Vanquisher's Mark of Sanctification (heroic)
    [52029] = 277,  -- Protector's Mark of Sanctification (heroic)

    -- Cataclysm
    -- T11
    -- helm
    -- normal
    [63683] = 359,  -- Conq
    [63684] = 359,  -- Prot
    [63682] = 359,  -- Vanq
    -- heroic
    [65001] = 372,  -- Conq
    [65000] = 372,  -- Prot
    [65002] = 372,  -- Vanq

    -- shoulders
    -- normal
    [64315] = 359,  -- Conq
    [64316] = 359,  -- Prot
    [64314] = 359,  -- Vanq
    -- heroic
    [65088] = 372,  -- Conq
    [65087] = 372,  -- Prot
    [65089] = 372,  -- Vanq

    -- chest
    -- heroic
    [67423] = 372,  -- Conq
    [67424] = 372,  -- Prot
    [67425] = 372,  -- Vanq

    -- gloves
    -- heroic
    [67429] = 372,  -- Conq
    [67430] = 372,  -- Prot
    [67431] = 372,  -- Vanq

    -- legs
    -- heroic
    [67428] = 372,  -- Conq
    [67427] = 372,  -- Prot
    [67426] = 372,  -- Vanq

    -- Essence of the Forlorn (used to buy heroic tier)
    [66998] = 372,

    -- MoP
    -- T16
    -- helm
    -- normal
    [99689] = 553,  -- Conq
    [99694] = 553,  -- Prot
    [99683] = 553,  -- Vanq
    -- heroic
    [99724] = 566,  -- Conq
    [99725] = 566,  -- Prot
    [99723] = 566,  -- Vanq

    -- shoulders
    -- normal
    [99690] = 553,  -- Conq
    [99695] = 553,  -- Prot
    [99685] = 553,  -- Vanq
    -- heroic
    [99718] = 566,  -- Conq
    [99719] = 566,  -- Prot
    [99717] = 566,  -- Vanq

    -- chest
    -- normal
    [99686] = 553,  -- Conq
    [99691] = 553,  -- Prot
    [99696] = 553,  -- Vanq
    -- heroic
    [99715] = 566,  -- Conq
    [99716] = 566,  -- Prot
    [99714] = 566,  -- Vanq

    -- gloves
    -- normal
    [99687] = 553,  -- Conq
    [99692] = 553,  -- Prot
    [99682] = 553,  -- Vanq
    -- heroic
    [99721] = 566,  -- Conq
    [99722] = 566,  -- Prot
    [99720] = 566,  -- Vanq

    -- legs
    -- normal
    [99688] = 553,  -- Conq
    [99693] = 553,  -- Prot
    [99684] = 553,  -- Vanq
    -- heroic
    [99712] = 566,  -- Conq
    [99713] = 566,  -- Prot
    [99726] = 566,  -- Vanq

    -- essences
    -- normal
    [105858] = 553,  -- Conq
    [105857] = 553,  -- Prot
    [105859] = 553,  -- Vanq
    -- heroic
    [105867] = 566,  -- Conq
    [105866] = 566,  -- Prot
    [105868] = 566,  -- Vanq
}


    -- ['Vanilla'] = {
    --     ['Onyxia\'s Lair'] = {
	-- 	    ["Onyxia"] = {1084, 5}
    --     },
    --     ['Molten Core'] = {
    --         ["Lucifron"] = {663, 5},
    --         ["Magmadar"] = {664, 5},
    --         ["Gehennas"] = {665, 5},
    --         ["Garr"] = {666, 5},
    --         ["Baron Geddon"] = {668, 5},
    --         ["Shazzrah"] = {667, 5},
    --         ["Sulfuron Harbinger"] = {669, 5},
    --         ["Golemagg the Incinerator"] = {670, 5},
    --         ["Majordomo Executus"] = {671, 5},
    --         ["Ragnaros"] = {672, 7},
    --     },
    --     ['Blackwing Lair'] = {
    --         ["Razorgore the Untamed"] = {610, 7},
    --         ["Vaelastrasz the Corrupt"] = {611, 7},
    --         ["Broodlord Lashlayer"] = {612, 7},
    --         ["Firemaw"] = {613, 7},
    --         ["Ebonroc"] = {614, 7},
    --         ["Flamegor"] = {615, 7},
    --         ["Chromaggus"] = {616, 7},
    --         ["Nefarian"] = {617, 10},
    --     },
    --     ['Zul\'Gurub'] = {
    --         ["High Priest Venoxis"] = 2,
    --         ["High Priestess Jeklik"] = 2,
    --         ["High Priestess Mar'li"] = 2,
    --         ["High Priest Thekal"] = 2,
    --         ["High Priestess Arlokk"] = 2,
    --         ["Edge of Madness"] = 2,
    --         ["Bloodlord Mandokir"] = 2,
    --         ["Jin'do the Hexxer"] = 2,
    --         ["Gahz'ranka"] = 2,
    --         ["Hakkar"] = 3,
    --     },
    --     ['Ruins of Ahn\'Qiraj'] = {
    --         ["Kurinnaxx"] = 3,
    --         ["General Rajaxx"] = 3,
    --         ["Moam"] = 3,
    --         ["Buru the Gorger"] = 3,
    --         ["Ayamiss the Hunter"] = 3,
    --         ["Ossirian the Unscarred"] = 4,
    --     },
    --     ['Ahn\'Qiraj'] = {
    --         ["The Prophet Skeram"] = 10,
    --         ["Battleguard Sartura"] = 10,
    --         ["Fankriss the Unyielding"] = 10,
    --         ["Princess Huhuran"] = 10,
    --         ["The Silithid Royalty"] = 10,
    --         ["Viscidus"] = 10,
    --         ["Ouro"] = 10,
    --         ["The Twin Emperors"] = 10,
    --         ["C'Thun"] = 12,
    --     },
    --     ['Naxxramas'] = {
    --         ["Anub'Rekhan"] = 12,
    --         ["Grand Widow Faerlina"] = 12,
    --         ["Maexxna"] = 15,

    --         ["Noth the Plaguebringer"] = 12,
    --         ["Heigan the Unclean"] = 12,
    --         ["Loatheb"] = 15,

    --         ["Instructor Razuvious"] = 12,
    --         ["Gothik the Harvester"] = 12,
    --         ["The Four Horsemen"] = 15,

    --         ["Patchwerk"] = 12,
    --         ["Grobbulus"] = 12,
    --         ["Gluth"] = 12,
    --         ["Thaddius"] = 15,

    --         ["Sapphiron"] = 15,
    --         ["Kel'Thuzad"] = 15,
    --     },
    --     ['Other'] = {
    --         ["Lord Kazzak"] = 7,
    --         ["Azuregos"] = 7,
    --         ["Emeriss"] = 7,
    --         ["Lethon"] = 7,
    --         ["Ysondre"] = 7,
    --         ["Taerar"] = 7,
    --     },
	-- },
