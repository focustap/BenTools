# BenTools

BenTools is a World of Warcraft Retail quality-of-life addon suite.

Current modules:

- Auto Sell: safe merchant selling using explicit item lists and conservative rules.
- Mythic+ Finder: a dedicated Mythic+ search dashboard with filters, ranking, presets, and one-click legal apply actions.
- Queue Ringer: queue-ready detection with a desktop companion that sends Discord notifications to your phone.
- Repair Reminder: a customizable durability warning that can trigger earlier than Blizzard's default reminder.

## Install

1. Copy the `BenTools` folder into `_retail_\Interface\AddOns\`.
2. Restart World of Warcraft or run `/reload`.
3. Use `/bt` for the main control panel or `/bt help` for command help.

## Main Control Panel

- `/bt` toggles the BenTools control panel.
- `/bt help` prints the current working command list.
- The panel gives button access to the existing Auto Sell and Queue Ringer actions so you do not need to memorize most slash commands.

Main button groups:

- Auto Sell
  - `Scan Bags` prints the current Auto Sell scan
  - `Print Sell Preview` prints the same sell preview used by the scan flow
  - `Always Sell List` prints the saved Always Sell list
  - `Never Sell List` prints the saved Never Sell list
  - `Auto Sell Settings` opens the BenTools settings panel
- Mythic+ Finder
  - `Open Finder` opens the BenTools Mythic+ Finder dashboard
  - `Refresh Finder Search` triggers a fresh Group Finder search
- Queue Ringer
  - `Queue Status` prints the current Queue Ringer status
  - `Test Queue Notification` shows the in-game Queue Ringer test banner
  - `Enable/Disable Queue Ringer` toggles the module
  - `Toggle Queue Debug` toggles Queue Ringer debug logging
  - `Queue Ringer Settings` opens the BenTools settings panel
- General
  - `Open BenTools Settings`
  - `Reload UI`
  - `Show Version / Status`

## Mythic+ Finder

- Open it with `/bt mplus`, `/bt mythic`, `/bt finder`, or the BenTools control panel.
- Configure your allowed key range, preferred range, role, composition requirements, dungeon list, leader-score minimum, age cap, and desired application count.
- Press `Refresh Search` to run an explicit Mythic+ search. BenTools does not auto-refresh in the background.
- BenTools filters the current result set, ranks the survivors by Match Score, explains that score on hover, and prepares an application plan.
- `Apply` on a card and `Apply Next Best` both still require a real user click, because Blizzard protects `C_LFGList.ApplyToGroup`.
- Active applications are tracked in the Finder side panel and refreshed from current LFG application state.

## Auto Sell

- Open a merchant and use the `Sell Marked Items` button.
- Alt-right-click a normal bag item to toggle Always Sell for that itemID.
- Ctrl-Alt-right-click a normal bag item to toggle Never Sell for that itemID.
- `/bt scan` reports what would sell without selling.
- `/bt autosell scan` is the explicit Auto Sell scan alias.
- `/bt list` prints saved rules.
- `/bt clear` removes Always Sell and Never Sell entries.

## Queue Ringer

Queue Ringer is a notification bridge, not an automation tool.

Flow:

1. BenTools detects a queue-ready event in game.
2. BenTools shows a bright top-center Queue Ringer banner in game.
3. The Queue Ringer desktop companion watches the WoW window for that banner.
4. The companion sends a Discord webhook notification.
5. Discord notifies your phone.

The external Queue Ringer companion still must be running for Discord notifications to reach your phone.

### In-game commands

- `/bt`
- `/bt queue`
- `/bt queue status`
- `/bt queue test`
- `/bt queue on`
- `/bt queue off`
- `/bt queue debug`

### Supported queue sources

- Dungeon Finder / Raid Finder via `LFG_PROPOSAL_SHOW`
- Premade Group Finder application invites via `LFG_LIST_APPLICATION_STATUS_UPDATED`
- Ready checks via `READY_CHECK`
- Battleground and PvP queue confirmations via `UPDATE_BATTLEFIELD_STATUS`

Queue Ringer intentionally does not auto-accept queues, remote-control the game, or simulate clicks.

## Mythic+ Finder Test Checklist

1. `/reload`
2. `/bt mplus` opens the Finder
3. `Open Finder` works from the BenTools main window
4. allowed and preferred key ranges clamp into valid values
5. role switching updates composition rules correctly
6. dungeon select-all and clear work
7. group-size, leader-score, and age filters affect results
8. `Refresh Search` shows loading, empty, and ready states
9. result cards scroll correctly on larger result sets
10. Match Score tooltip explains the ranking
11. `Apply` works only from a real click
12. `Apply Next Best` skips already-applied or invalid results
13. application statuses update for invited, declined, cancelled, and expired states
14. preset save, load, rename, and delete persist across `/reload`
15. no regressions to Queue Ringer, Auto Sell, Ready Check alerts, or Repair Reminder

## Repair Reminder

- BenTools can show a repair reminder popup when your equipped durability falls to or below a custom threshold.
- The threshold is configurable in BenTools settings and can be set higher than Blizzard's built-in durability warning.

## Queue Ringer Companion

The companion lives in:

- `QueueRingerCompanion\queue_ringer.py`
- `QueueRingerCompanion\Start Queue Ringer.bat`
- `QueueRingerCompanion\Launch WoW with Queue Ringer.bat`

Use it like this:

```powershell
cd "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\BenTools\QueueRingerCompanion"
.\Start Queue Ringer.bat
python .\queue_ringer.py --test
```

The companion stores secrets only in its local `config.json`, never inside the WoW addon.

## Notes

- Queue Ringer needs WoW in windowed or borderless-windowed mode so the desktop companion can see the popup banner.
- The companion watches a distinctive beacon strip inside the Queue Ringer banner and only fires once per visible banner.
- Development stays source-first: the batch launcher always runs the current `queue_ringer.py`. Packaging an EXE can be added later when the companion is stable enough for release.
