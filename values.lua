local _, ns = ...  -- Namespace

ns.values = {}

ns.values.gpDefaults = {
    initial = 1,
    -- https://wowpedia.fandom.com/wiki/Enum.InventoryType
    slotModifiers = {
        INVTYPE_HEAD = 1,
        INVTYPE_NECK = 0.5,
        INVTYPE_SHOULDER = 0.75,
        INVTYPE_CLOAK = 0.5,
        INVTYPE_CHEST = 1,
        INVTYPE_WRIST = 0.5,
        INVTYPE_HAND = 0.75,
        INVTYPE_WAIST = 0.75,
        INVTYPE_LEGS = 1,
        INVTYPE_FEET = 0.75,
        INVTYPE_FINGER = 0.5,
        INVTYPE_TRINKET = 0.75,
        INVTYPE_WEAPONMAINHAND = 1.5,
        INVTYPE_WEAPONOFFHAND = 0.5,
        INVTYPE_HOLDABLE = 0.5,  -- holdable off hand
        INVTYPE_WEAPON = 1.5,  -- one handed weapon
        INVTYPE_2HWEAPON = 2,
        INVTYPE_SHIELD = 0.5,
        INVTYPE_RANGED = 2,
        INVTYPE_RELIC = 0.5,
        INVTYPE_THROWN = 0.5,
        INVTYPE_RANGEDRIGHT = 0.5,  -- wand
    },
}

ns.values.tokenGp = {
    -- Onyxia's Layer
    -- head
    [49644] = 245,

    -- Naxx
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

    -- Ulduar
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

    -- TOGC
    -- trophy
    [47242] = 245,  -- Trophy of the Crusade
    -- tokens
    [47559] = 258,  -- Regalia of the Grand Vanquisher
    [47558] = 258,  -- Regalia of the Grand Protector
    [47557] = 258,  -- Regalia of the Grand Conqueror

    -- ICC
    -- marks
    [52025] = 264, -- Vanquisher's Mark of Sanctification
    [52027] = 264, -- Conqueror's Mark of Sanctification
    [52026] = 264, -- Protector's Mark of Sanctification
    [52030] = 277, -- Conqueror's Mark of Sanctification (heroic)
    [52028] = 277, -- Vanquisher's Mark of Sanctification (heroic)
    [52029] = 277,  -- Protector's Mark of Sanctification (heroic)
}
