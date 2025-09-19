-- ============================================================================
-- Configuration file for FiveM-Admin-Mode
-- ============================================================================

Config = {}

Config.ResourceName = 'FiveM-Admin-Mode'
Config.Version = '1.0.0'

-- Language / Locale (set after loading locale.lua)
-- Examples: 'de', 'en'
Config.Locale = 'en'

-- Framework selection: 'esx' or 'qb'
-- AutoDetect = true tries preferred first, then the other. If both exist it keeps Preferred.
-- Set AutoDetect = false to force one.
Config.Framework = {
    AutoDetect = true,
    Preferred = 'esx' -- 'esx' or 'qb'
}

Config.StaticId = {
    Enabled = false,                 -- false = skip external export resource
    ExportResource = 'staticApi',    -- resource name providing the export
    ExportFunction = 'GetClientStaticID', -- export function
    UseServerIdWhenDisabled = true   -- if disabled show server id instead of 'N/A'
}

Config.AdminMode = {
    Command = 'admin',
    TransparentAlpha = 100,
    NormalAlpha = 255,
    EnableGodMode = true
}

Config.Admin3DText = {
    Enabled = true,
    Distance = 10.0,
    -- Locale keys instead of plain text. client.lua calls L(key, staticId).
    Lines = { 'admin3d_line1', 'admin3d_line2' },
    Color = { r = 245, g = 83, b = 83, a = 150 },
    ScaleBase = 0.35
}

Config.Scan = {
    IntervalMs = 1000,
    Radius = 100.0
}

Config.Teleport = {
    Command = 'tpto',
    PermissionGroups = { 'admin', 'superadmin' },
    -- Text now handled in locale: teleport_success, teleport_no_permission
    UseESXNotification = true
}

Config.Dimension = {
    Command = 'setdim',
    AllowedGroups = { 'superadmin', 'admin', 'mod' }
    -- Locale keys used:
    -- dimension_no_permission, dimension_self_error, dimension_success_admin, dimension_success_target,
    -- dimension_usage, player_not_found, dimension_header
}

-- Database logging (optional)
-- Supported adapters: 'oxmysql', 'mysql-async'
-- If Enabled = false -> No DB access
Config.Database = {
    Enabled = false,
    Adapter = 'oxmysql',            -- 'oxmysql' | 'mysql-async'
    Table = 'adminmode_logs',       -- table name
    AutoCreate = true,              -- auto create basic table if missing
    -- Column schema (only used for AutoCreate)
    Schema = [[
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `identifier` VARCHAR(64) NULL,
        `name` VARCHAR(64) NULL,
        `action` VARCHAR(32) NOT NULL,
        `details` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ]]
}

-- Discord Webhook mirror (optional)
-- Enabled = true + valid Url -> each LogAction mirrored.
-- Simple JSON POST. TimeoutMs sets HTTP timeout.
Config.Discord = {
    Enabled = false,
    Url = 'https://discord.com/api/webhooks/DEIN_WEBHOOK',
    Username = 'AdminMode Logger',
    AvatarUrl = '',
    TimeoutMs = 5000,
    -- Template function (can be overridden in code)
    Format = function(data)
        return string.format('**%s** `%s` (%s) -> %s\n```%s```', data.action, data.name or 'Unknown', data.identifier or 'n/a', os.date('%Y-%m-%d %H:%M:%S'), data.details or '-')
    end
}

-- Extended log flags (selective logging)
Config.LogFlags = {
    AdminToggle = true,
    Dimension = true,
    Teleport = true,       -- teleport events
    Godmode = true,        -- separate godmode toggle logs
    PlayerJoin = true,
    PlayerLeave = true
}

-- Unified notification system (server -> client event)
-- Change 'Event' if your framework uses another (e.g. 'ox:notify').
-- Disable by setting Enabled = false if you implement your own.
Config.Notification = {
    Enabled = true,
    Event = 'notify' -- generic event name
}

Config.Events = {
    CheckTransparency = 'checkPlayerTransparency',
    GetStaticId       = 'getStaticId',
    ReceiveStaticId   = 'receiveStaticId',
    SetTransparency   = 'setPlayerTransparency',
    SetGodMode        = 'setGodMode'
}

Config.Debug = {
    PrintStaticIdFetch = false,
    PrintAdminToggle = false
}

return Config
