## FiveM-Admin-Mode
*Admin Mode in Grand Style*

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.1-green.svg)

Suggested GitHub Topics: `fivem` `lua` `admin` `esx` `qbcore`

A lightweight admin mode script for ESX or QBCore (FiveM) featuring:

- Toggleable admin mode (transparency + optional godmode)
- Visible 3D text above active admins (configurable / disableable)
- Automatic nearby player scan (transparency sync)
- Static ID display (if `staticApi` resource is present)
- Simple coordinate teleport command
- Dimension (routing bucket) management command
- Fully configurable through `config.lua`

### Installation
1. Place the folder into your `resources` directory (e.g. `FiveM-Admin-Mode`).
2. Add to your `server.cfg`: `ensure FiveM-Admin-Mode`.
3. Ensure one of the supported frameworks is running:
   - ESX (`es_extended`) or
   - QBCore (`qb-core`)
   Optional: `staticApi` for static IDs.

### Framework Selection (ESX / QBCore)
In `config.lua` you can control which framework is used:

```
Config.Framework = {
   AutoDetect = true,   -- tries preferred first, then the other
   Preferred = 'esx'     -- 'esx' or 'qb'
}
```

If `AutoDetect = true`:
1. Tries the preferred framework.
2. Falls back to the other if not available.

QBCore specifics:
- Permissions: Because QBCore has no native group field like ESX, the job name is used (e.g. `admin`, `police`). Adjust `Config.Dimension.AllowedGroups` / `Config.Teleport.PermissionGroups` as needed.
- Notifications: If your `Config.Notification.Event` is still `notify` and QBCore is detected it will automatically switch to `QBCore:Notify`.

### ESX Legacy Compatibility
The script supports older `es_extended` versions without the export interface. Detection order:
1. Try: `exports['es_extended']:getSharedObject()`
2. Fallback: `TriggerEvent('esx:getSharedObject', function(obj) ... end)`

No extra configuration needed – fallback is automatic if the export is missing.

### Configuration
All settings live in `config.lua`.

| Section | Purpose |
|---------|---------|
| `StaticId` | Enables static ID display |
| `AdminMode` | Transparency / godmode parameters & command |
| `Admin3DText` | 3D text above admins |
| `Scan` | Loop interval & radius |
| `Teleport` | Teleport command & permissions |
| `Dimension` | Routing bucket management |
| `Events` | Event name overrides |
| `Debug` | Debug prints |
| `Framework` | ESX/QBCore selection & autodetect |
| `Database` | Optional MySQL logging |

### Locale / i18n
The script uses a simple locale system.

Files:
- `locale.lua` (loader & function `L(key, ...)`)
- `locales/en.lua`, `locales/de.lua`

Set the active language in `config.lua`:
```
Config.Locale = 'en' -- or 'de'
```

Example locale entry (`locales/en.lua`):
```
teleport_no_permission = 'You do not have permission to use this command.'
```
Usage in code:
```
L('teleport_no_permission')
```

Placeholders use `string.format`:
```
teleport_success = 'Teleported to: X: %s Y: %s Z: %s'
-- Call: L('teleport_success', x, y, z)
```

Fallback: If the key is missing in the selected locale, it falls back to English (`en`). If still missing, the key name itself is returned.

Add a new language:
1. Create `locales/fr.lua` returning a table: `return { key = 'Text', ... }`.
2. Add it to `fxmanifest.lua` under `shared_scripts`.
3. Set `Config.Locale = 'fr'`.

3D text uses keys from `Config.Admin3DText.Lines` (e.g. `admin3d_line1`, `admin3d_line2`). The second line receives `%s` for the ID.


### Default Commands
| Command | Description |
|---------|-------------|
| `/admin` | Toggle admin mode |
| `/tpto x y z` | Teleport to coordinates |
| `/setdim id bucket` | Set player routing bucket |

### Notes
Set `Config.StaticId.Enabled = false` if you do not have the static ID resource installed.

### Database Logging (optional)
Enable log entries (admin on/off, dimension changes, teleport, etc.) in MySQL.

In `config.lua`:
```
Config.Database = {
   Enabled = true,
   Adapter = 'oxmysql',        -- oder 'mysql-async'
   Table = 'adminmode_logs',
   AutoCreate = true
}
```

AutoCreate (if enabled) ensures the table exists with columns:
id | identifier | name | action | details | created_at

Supported action values (base + extended via LogFlags):
- admin_on / admin_off
- set_dimension
- teleport
- godmode_on / godmode_off
- player_join / player_leave

To log custom events call `LogAction(source, action, details)` (server) – also exposed as export.

### Discord Webhook Mirror (optional)
Enable in `config.lua`:
```
Config.Discord = {
   Enabled = true,
   Url = 'https://discord.com/api/webhooks/DEIN_WEBHOOK',
   Username = 'AdminMode Logger',
   AvatarUrl = ''
}
```
Each logged action is mirrored as an embed. Adjust formatting via the `Format` function.

### Extended Log Flags
Selectively control what is logged:
```
Config.LogFlags = {
   AdminToggle = true,
   Dimension = true,
   Teleport = true,
   Godmode = true,
   PlayerJoin = true,
   PlayerLeave = true
}
```

### Teleport / Godmode / Join / Leave Logging
- Teleport: Client triggers `adminmode:teleportLog`
- Godmode: Client triggers `adminmode:godmodeChange`
- Player Join/Leave: Automatic via `playerConnecting` / `playerDropped`

### Export
Other resources can log directly:
```
exports['FiveM-Admin-Mode']:LogAction(source, 'custom_event', 'Beliebige Details')
```
Example:
```
exports['FiveM-Admin-Mode']:LogAction(src, 'revive_player', ('Revive durchgeführt für %s'):format(targetId))
```


Good luck & have fun!
