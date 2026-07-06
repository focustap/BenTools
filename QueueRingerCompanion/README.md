# Queue Ringer Companion

This companion watches the World of Warcraft window for the BenTools Queue Ringer banner and sends a Discord webhook notification.

## Why this bridge exists

World of Warcraft addons cannot make arbitrary HTTP requests. Queue Ringer therefore uses a two-part design:

1. BenTools detects a queue-ready event in game.
2. BenTools shows a bright top-center banner with a distinctive color beacon.
3. This companion watches the WoW window for that banner.
4. The companion sends a Discord webhook notification.

SavedVariables are not used as the real-time bridge because WoW does not continuously flush them to disk while you play.

## Files

- `queue_ringer.py` - watcher UI and Discord sender
- `Start Queue Ringer.bat` - double-click launcher for the live Python source
- `Launch WoW with Queue Ringer.bat` - convenience launcher for Queue Ringer plus WoW/Battle.net
- `config.example.json` - sample configuration
- `config.json` - your real local configuration
- `state.json` - watcher state and last notification time

## Setup

1. Copy `config.example.json` to `config.json`.
2. Fill in your Discord webhook URL.
3. Double-click `Start Queue Ringer.bat`.

That batch file:

- uses its own folder as the working directory
- launches the current `queue_ringer.py`
- works if the folder is moved somewhere else
- shows a clear error if Python or `queue_ringer.py` is missing

You can also start it manually:

```powershell
python .\queue_ringer.py
```

4. Test the webhook:

```powershell
python .\queue_ringer.py --test
```

## Start With Windows

Queue Ringer has a companion checkbox:

- `Start Queue Ringer with Windows`

When enabled:

- the companion creates a shortcut in the current user's Windows Startup folder
- no administrator permissions are required
- the shortcut points at `Start Queue Ringer.bat`
- paths with spaces are handled correctly

When disabled:

- the startup shortcut is removed

The checkbox reflects the actual shortcut state on launch, so if the shortcut was deleted manually, the UI will show it as disabled the next time the companion starts.

## Start Watching Automatically

Queue Ringer also has:

- `Start watching automatically`

When enabled:

- opening the companion automatically starts the watcher
- you do not need to press `Start Watching` every time

When disabled:

- manual `Start Watching` and `Stop` keep working normally

## Start Minimized

Queue Ringer also has:

- `Start minimized`

When enabled:

- the companion opens hidden to the system tray when tray support is available
- otherwise it falls back to normal taskbar minimize
- the full GUI is still available by reopening it from the tray icon

## System Tray

Queue Ringer can now live in the Windows system tray.

- closing the main window hides it to the tray instead of exiting
- double-clicking or using `Show Queue Ringer` from the tray restores the window
- the tray menu includes:
  - `Show Queue Ringer`
  - `Start Watching`
  - `Stop Watching`
  - `Launch WoW / Battle.net`
  - `Exit`

`Exit` from the tray fully closes the companion.

## Single-Instance Protection

The companion prevents duplicate GUI instances.

- If you double-click `Start Queue Ringer.bat` twice, the first instance keeps running.
- The second instance exits cleanly.
- This prevents duplicate watchers and duplicate Discord notifications from multiple GUI copies.

## Launch WoW With Queue Ringer

You can use:

- `Launch WoW with Queue Ringer.bat`

That launcher:

1. starts Queue Ringer if needed
2. asks `queue_ringer.py` to launch WoW or Battle.net
3. avoids duplicate Queue Ringer GUI instances through the companion's single-instance guard

Path resolution order:

1. `WoW / Battle.net path` from the companion UI
2. common default Battle.net and WoW install locations
3. clear error if nothing valid is found

## Development Workflow

The normal development workflow stays source-based:

1. edit `queue_ringer.py`
2. double-click `Start Queue Ringer.bat`
3. the newest Python source runs immediately

An EXE can be packaged later for public release once the companion is stable, but this project is intentionally still using the live Python source during development.

## Notes

- WoW should be in windowed or borderless-windowed mode so the desktop capture can see the queue banner.
- The watcher looks only at the top-center region of the WoW window where BenTools places the Queue Ringer banner.
- The companion masks the webhook URL in its startup log.
