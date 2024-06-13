# 0.22.2

- fix encounter EP

# 0.22.1

- fix bug :)

# 0.22.0

- add capability to clear data for guild

# 0.21.3

- add Cataclysm encounter EP
- add Cataclysm token GP
- normalize GP for Cataclysm items

# 0.21.2

- Only recompute standings out of combat

# 0.21.1

- Designate as for Cataclysm classic

# 0.21.0

- add raid roster history recording in prep of new raid feature
- update for Cataclysm (4.0.4)

# 0.20.2

- fix issue where only portion of raid shows in roster
- minor improvements for integration with CalamityWeb

# 0.20.1

- move knownPlayers to db
- fix knownPlayers bug

# 0.20.0

- fix minimum GP controls
- add EP/GP filters to history window

# 0.19.5

- lessen frequency of freezes due to computing standings

# 0.19.4

- fix sync

# 0.19.3

- bandaid fix for duplicate events

# 0.19.2

- bug fix

# 0.19.1

- minor bug fixes

# 0.19.0

- treat history as source of truth
- calculate standings based on history
- sync history only
- sync all history, not just most recent events

# 0.18.0

- add capability to decay EP and GP independently

# 0.17.1

- update to patch 3.4.3
- add addon out-of-date message

# 0.17.0

- add "Guildie" column to loot distribution window
- add capability to loot distribution window to sort by roll over PR
- change boss kill EP values for P4 to 75

# 0.16.0

- Add class/spec GP overrides

# 0.15.2

- fix communication bug

# 0.15.1

- fix hashing algorithm

# 0.15.0

- make history events and their transmission more efficient

# 0.14.4

- added AceGUI back in for AceConfigDialog

# 0.14.3

- reduce debug messages for heartbeat
- improve officerReq

# 0.14.2

- fix bug in Comm
- add heartbeat

# 0.14.1

- fix bug :)

# 0.14.0

- fix Comm by using a single prefix for addon messages and encoding the message
  type in the message

# 0.13.0

- only send sync data if officer
- only receive sync data if sender is an officer

# 0.12.4

- fix bug in automatic trading of awarded items

# 0.12.3

- fix bug in history window
- fix bug in addon loading
- fix bug in alt ep/gp syncing

# 0.12.2

- fix important things
- improve window management

# 0.12.1

- hopefully fix loading item data

# 0.12.0

- fix several issues
- lots of under-the-hood improvements
- add bench feature

# 0.11.1

- fix players in history not existing in standings
- passing now cancels roll

# 0.11.0

- change loot distribution click combo to Alt+Click
- fix raid warning not working when group leader
- add feature to award items from inventory without rolling
- fix auto-filling trade window with an item that person has been given previously
- fix adding multiple items of the same type to trade window when only one item was won
- improve aesthetics of all scroll windows
- fix loot timer not closing when timer ends
- fix history window dropdown filter remaining active after turning off detail mode
- various big fixes

# 0.10.1

- fix loot dist bug

# 0.10.0

- add alt management within CalamityEPGP

# 0.9.3

- fix modifying EP/GP manually

# 0.9.2

- fix EP/GP modification
- fix alt EP/GP syncing

# 0.9.1

- fix old history not following expected format

# 0.9.0

- store history much more efficiently
- view history in less detail (summary events) or more detail (events by player)

# 0.8.1

- fix LM settings being overwritten
- change loot roll click combo to alt+click

# 0.8.0

- add free award option

# 0.7.13

- fix message prefixes

# 0.7.12

- further improved efficiency of syncing history

# 0.7.11

- improve efficiency of syncing

# 0.7.10

- fix handling of nil raid member names
- various fixes

# 0.7.9

- fix history sync

# 0.7.8

- fix history window loading non-guildie data
- clean up history window boss kill entries

# 0.7.7

- fix settings sync

# 0.7.6

- fix nil reference in comm.lua
- fix Lib:getVersionNum

# 0.7.5

- respond to sync message with version

# 0.7.4

- fix Dict:toTable()

# 0.7.3

- fix?

# 0.7.2

- further fix incorrect sync data

# 0.7.1

- handle incorrect sync data

# 0.7.0

- various improvements

# 0.6.2

- fix roll window not closing

# 0.6.1

- fix loot distribution

# 0.6.0

- disable loot dist window when not master looter unless debug mode is on
- add debug mode

# 0.5.0

- disable some options from non LM mode users

# 0.4.2

- fix bug and notify game options when change is synced

# 0.4.1

- fix bug and remove unnecessary prints

# 0.4.0

- sync loot master settings

# 0.3.2

- bug fixes

# 0.3.1

- bug fixes

# 0.3.0

- sync with guildies when updates happen

# 0.2.0

- roll window
- data sync
- fix loading raid roster
- other stuff?

# 0.1.0

- initial beta version
