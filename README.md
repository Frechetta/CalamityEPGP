CalamityEPGP handles all functions of your guild's EPGP loot system. This addon **does not** use your guild's officer notes to store standings. Therefore, it can handle standings for PUGs as well as guild members.

## Features

- Maintains your guild's EPGP standings
- Assists in distributing loot
- Auto awards EP for boss kills
- Maintains table of mains to alts
- Syncs EP and/or GP between characters depending on settings
- Keeps a history of EP/GP modifications for auditing
- GP value and awarded information in an item's tooltip
- Base GP to prevent new raiders and returning raiders from winning gear over consistent raiders
- Different GP value when awarding item for OS

## Functionality

**Chat commands**

- `/ce` - get a list of commands
- `/ce show` - show the main window
- `/ce history` - show the history window
- `/ce cfg` - show the configuration menu

**Main window**

- Add EP to the selected roster
- Decay EP/GP for the entire roster
- Modify EP/GP of a single player

**Distributing loot**

- Shift+Click on an item (in the loot window or your inventory) to open the loot distribution window
- Click the "Start" button to start accepting rolls
- Raiders `/roll` for MS and `/roll 99` for OS
- Select the awardee and click the "Award" button to automatically send the item to the player and increase their GP
- If you are distributing the loot from your inventory, the awarded items will automatically populate the trade window when opened

**Getting standings**

Whisper the loot master

- `!ceinfo` to get your standings and rank within entire roster, guild, and raid
- `!ceinfo {player}` to get `player`'s standings and rank within entire roster, guild, and raid

## Definitions

- EP: Effort Points - points gained through various things like attending raids and downing bosses
- GP: Gear Points - points gained by receiving gear
- PR: Priority - Calculated using `EP / GP`
- Decay: Reduces the EP and/or GP (typically both) of the entire roster by some percentage
- Base GP: Minimum GP value for all raiders. Also used as the initial value for new raiders

## Comments, questions, concerns?

Please submit an issue on Github: https://github.com/Frechetta/CalamityEPGP.