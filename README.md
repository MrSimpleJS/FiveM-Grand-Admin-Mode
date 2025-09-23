## FiveM-Admin-Mode
*Admin Mode in Grand RP Style*

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.1.0-green.svg)

A lightweight admin mode script for ESX or QBCore (FiveM) featuring:

Core Features:
- Toggleable admin mode (transparency + optional godmode)
- New: Admin sees self opaque while others see transparency (`SelfOpaque`)
- 3D text above active admins (locale-based, multi-language auto-loading)
- Efficient sync: scope-based (playerEnteredScope) transparency updates (fallback radius scan)
- Static ID display (optional external resource) or server id fallback
- Teleport & Dimension (routing bucket) management commands
- Permission group restrictions for admin, teleport & dimension commands
- Logging: DB (optional), Discord webhook, granular LogFlags
- Locale fallback chain: `Config.LocaleFallback = { 'de', 'en' }`
- New sync event for late joiners (`adminmode:requestSync`)

Performance Enhancements (1.1.0):
- Optional OneSync scope event usage instead of continuous distance loop
- Reduced redundant alpha updates & improved cleanup on disconnect

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
The locale system now auto-loads every `locales/<code>.lua` file it finds (common codes). You just drop a new file (e.g. `fr.lua`) – no fxmanifest edit required.

Basics:
- Loader: `locale.lua` provides global `L(key, ...)`.
- Files: `locales/en.lua`, `locales/de.lua`, plus any you add.
- Primary language: `Config.Locale = 'en'`.
- Fallback chain: `Config.LocaleFallback = { 'de', 'en' }` tries in order.
- Missing key → tries chain → falls back to key string.
- Keys with accidental double underscores (`admin3d__line1`) are normalized.

Example entry (`locales/en.lua`):
```
teleport_success = 'Teleported to: X: %s Y: %s Z: %s'
```
Usage:
```
L('teleport_success', x, y, z)
```

Adding a new language:
1. Create `locales/fr.lua`:
    ```lua
    return {
       admin3d_line1 = 'Administrateur',
       admin3d_line2 = 'ID: %s'
    }
    ```
2. Set `Config.Locale = 'fr'` (and optionally a fallback list).
3. Restart resource.

3D Text: Controlled via `Config.Admin3DText.Lines` (default: `admin3d_line1`, `admin3d_line2`). Second line formats the ID with `%s`.


### Default Commands
| Command | Description |
|---------|-------------|
| `/admin` | Toggle admin mode (transparent + godmode optional) |
| `/tpto x y z` | Teleport to coordinates |
| `/setdim id bucket` | Set player routing bucket |
| (internal) `adminmode:requestSync` | Client → server, resyncs current transparent admins (auto called) |

### Notes
- Set `Config.StaticId.Enabled = false` if you do not have the static ID resource installed.
- To keep admin fully visible to self: keep `SelfOpaque = true`.
- To let admin also see own transparency: set `SelfOpaque = false`.
- Restrict who can toggle admin: adjust `Config.AdminMode.AllowedGroups`.
-- Performance: If OneSync scope events misbehave, set `Config.Performance.UseScopeEvents = false` to revert to radius scan.

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


### Upgrading 1.0.x → 1.1.0
Minimal changes required. New optional config entries (add if missing):
```
Config.AdminMode.SelfOpaque = true
Config.AdminMode.AllowedGroups = { 'admin', 'superadmin' }
Config.Performance = { UseScopeEvents = true, LegacyScanFallback = true }
Config.LocaleFallback = { 'en' }
```
`locale.lua` auto-load now; you can remove explicit locale file lines from `fxmanifest.lua` if desired (kept for backward compatibility).

Good luck & have fun!

