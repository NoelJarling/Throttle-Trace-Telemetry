# Throttle Trace Telemetry

An unofficial mod for [Throttle Trace](https://store.steampowered.com/app/4535730/) that records your laps, plus a page that compares them in the browser.

- **`mods/telemetry/mod.gd`** records your car on every physics step: inputs, speed, slip angle, wheel spin, traction, control, grip, position, gear, rpm and more. Each session becomes one log file in the `telemetry/` folder. Only completed laps are saved, with their lap time, sector times and wing setup.
- **`mods/telemetry/analysis.html`** reads that folder and shows, per track: a lap table with sector times, a time delta chart against a reference lap, one chart per channel you choose, a track map of the selected laps and the values at the mouse position.

Built for Throttle Trace v0.40.0 (Godot 4.6). Game updates may break it.

## Install

### 1. Install the mod loader

The game has no built-in mod support. Install the [Throttle Trace Mod Loader](https://github.com/NoelJarling/Throttle-Trace-Mod-Loader) first, including the `--enable-mods` launch option.

### 2. Copy `mods/` into the game's user data folder

| OS      | User data folder                                    |
|---------|-----------------------------------------------------|
| Linux   | `~/.local/share/godot/app_userdata/Throttle Trace/` |
| Windows | `%APPDATA%\Godot\app_userdata\Throttle Trace\`      |

Afterwards the user data folder should look like this:

```
Throttle Trace/            (user data folder)
├── mod_loader/
│   └── mod_loader.gd
├── mods/
│   └── telemetry/
│       ├── mod.gd
│       └── analysis.html
└── telemetry/             (created by the mod on first start)
    └── <date>_<track>_<session>_<driver>.ttlog
```

## Usage

1. Drive. Every completed lap is written to the session's log when you cross the line.
2. Open `mods/telemetry/analysis.html` in your browser and click **Choose folder**. Pick the `telemetry/` folder in the user data folder.
3. Pick a track, then select laps in the sidebar. The fastest selected lap is lap A and the reference for the delta; click a lap's tag in the table to use another lap as the reference.
4. Drag across a chart to zoom into part of the lap, double-click to zoom out.
5. The map and cursor panels can be unpinned to float at the top of the page making it easier to read and compare values from the charts

The page reads the folder once. To see laps driven since then, click **Change folder** or reload the page.

Chrome, Edge and other Chromium browsers remember the folder between visits. Other browsers ask for it every time. The page needs an internet connection to load its libraries.

Telemetry is recorded in sessions. Every race or time trial session will create a new session file after the first lap is completed. Restarting a session will not write a new session file. Session files can be shared with others. Drop session files from other people into your `telemetry/` folder to compare.

Only completed laps will be recorded. Resetting during time trial will discard all data recorded for that lap. Rewinding during a race will cause data to be recorded twice but the analysis page will not show the rewinded data.

### Throttle and brake channels

Throttle and brake have multiple channels. The following examples are based on the throttle input but brake input works the same.

Each channel takes more configuration options from the settings menu into account.

`throttle raw → throttle after sensitivity → throttle after damping → throttle`

| Channel                | Value                                                                                                   |
|------------------------|---------------------------------------------------------------------------------------------------------|
| Throttle raw           | The raw throttle value read from the input device                                                       |
| Throttle after sensitivity | The throttle value after the "Throttle Sensitivity" setting is applied                                  |
| Throttle after damping | The throttle value after the "Throttle Sensitivity" and "Throttle Dampening" settings are applied       |
| Throttle               | The final throttle value used by the game. Includes sensitivity, dampening, traction control and pedal assist |

## Uninstall

Delete `mods/telemetry/` from the user data folder. Your logs stay in `telemetry/` until you delete that folder too.
