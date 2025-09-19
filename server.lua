local transparentPlayers = {}
local cfg = Config

-- Framework detection & wrapper
local Framework = { name = nil, core = nil }

local function DetectFramework()
    if cfg.Framework and cfg.Framework.AutoDetect then
        local preferred = (cfg.Framework.Preferred or 'esx'):lower()
        local order = { preferred, preferred == 'esx' and 'qb' or 'esx' }
        for _, fw in ipairs(order) do
            if fw == 'esx' then
                local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
                if ok and obj then Framework.name = 'esx'; Framework.core = obj; return end
                -- Legacy event fallback
                local legacy
                TriggerEvent('esx:getSharedObject', function(esx) legacy = esx end)
                if legacy then Framework.name = 'esx'; Framework.core = legacy; return end
            elseif fw == 'qb' then
                if GetResourceState('qb-core') == 'started' then
                    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
                    if ok and obj then Framework.name = 'qb'; Framework.core = obj; return end
                end
            end
        end
    else
        local preferred = (cfg.Framework.Preferred or 'esx'):lower()
        if preferred == 'esx' then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok and obj then Framework.name = 'esx'; Framework.core = obj else
                local legacy
                TriggerEvent('esx:getSharedObject', function(esx) legacy = esx end)
                if legacy then Framework.name = 'esx'; Framework.core = legacy end
            end
        elseif preferred == 'qb' then
            if GetResourceState('qb-core') == 'started' then
                local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
                if ok and obj then Framework.name = 'qb'; Framework.core = obj end
            end
        end
    end
end

DetectFramework()

-- Auto notification event switch for QBCore
if Framework.name == 'qb' and cfg.Notification.Enabled and cfg.Notification.Event == 'notify' then
    -- Many QBCore scripts use client side event 'QBCore:Notify'
    cfg.Notification.Event = 'QBCore:Notify'
end

local function GetPlayerObject(src)
    if Framework.name == 'esx' then
        return Framework.core.GetPlayerFromId and Framework.core.GetPlayerFromId(src) or Framework.core.GetPlayerFromId(src)
    elseif Framework.name == 'qb' then
        if Framework.core.Functions and Framework.core.Functions.GetPlayer then
            return Framework.core.Functions.GetPlayer(src)
        end
    end
end

local function GetPlayerGroup(src)
    if Framework.name == 'esx' then
        local xPlayer = GetPlayerObject(src)
        return xPlayer and xPlayer.getGroup and xPlayer.getGroup() or 'user'
    elseif Framework.name == 'qb' then
        local p = GetPlayerObject(src)
        if p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name then
            return p.PlayerData.job.name
        end
        return 'citizen'
    end
    return 'user'
end

-- Routing bucket support detection
local routingBucketSupported = (SetPlayerRoutingBucket ~= nil) and (GetPlayerRoutingBucket ~= nil)

local function TeleportBucket(src, bucket)
    if not routingBucketSupported then
        return false, 'unsupported'
    end
    local ok, err = pcall(function()
        SetPlayerRoutingBucket(src, bucket)
    end)
    if not ok then
        return false, err or 'failed'
    end
    return true
end

-- DB Helper
local DB = {}
if cfg.Database and cfg.Database.Enabled then
    local adapter = cfg.Database.Adapter
    if adapter == 'oxmysql' then
        DB.insert = function(query, params, cb)
            exports.oxmysql:insert(query, params, cb)
        end
        DB.execute = function(query, params, cb)
            exports.oxmysql:execute(query, params, cb)
        end
    elseif adapter == 'mysql-async' then
        DB.insert = function(query, params, cb)
            MySQL.Async.insert(query, params, cb)
        end
        DB.execute = function(query, params, cb)
            MySQL.Async.execute(query, params, cb)
        end
    else
        print('[AdminMode] Unbekannter DB Adapter: '..tostring(adapter))
        cfg.Database.Enabled = false
    end
end

local function GetIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,5) == 'steam' or id:sub(1,6) == 'license' then
            return id
        end
    end
    return GetPlayerIdentifier(src, 0)
end

local function SendWebhook(payload)
    if not (cfg.Discord and cfg.Discord.Enabled and cfg.Discord.Url and cfg.Discord.Url ~= '') then return end
    PerformHttpRequest(cfg.Discord.Url, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

local function LogAction(src, action, details)
    local identifier = src and GetIdentifier(src) or 'server'
    local name = (src and GetPlayerName(src)) or 'Server'

    -- DB Logging
    if (cfg.Database and cfg.Database.Enabled) then
        local tableName = cfg.Database.Table
        local query = ('INSERT INTO `%s` (identifier, name, action, details) VALUES (?, ?, ?, ?)'):format(tableName)
        DB.insert(query, { identifier, name or 'Unknown', action, details }, function(id)
            if cfg.Debug.PrintAdminToggle then
                print(('[AdminMode][DB] Logged %s (row=%s)'):format(action, tostring(id)))
            end
        end)
    end

    -- Discord Webhook Mirror
    if cfg.Discord and cfg.Discord.Enabled then
        local formatFn = cfg.Discord.Format
        local content = formatFn and formatFn({
            action = action,
            name = name,
            identifier = identifier,
            details = details
        }) or (action .. ' - ' .. (details or ''))
        local payload = {
            username = cfg.Discord.Username or 'AdminMode Logger',
            avatar_url = cfg.Discord.AvatarUrl or nil,
            embeds = {
                {
                    description = content,
                    color = 16734296,
                    footer = { text = 'AdminMode' },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%S.000Z')
                }
            }
        }
        SendWebhook(payload)
    end
end

-- Auto create table (if enabled)
CreateThread(function()
    if cfg.Database and cfg.Database.Enabled and cfg.Database.AutoCreate then
        local tableName = cfg.Database.Table
        local schema = cfg.Database.Schema
        if schema and DB.execute then
            local createSql = ('CREATE TABLE IF NOT EXISTS `%s` (%s)'):format(tableName, schema)
            DB.execute(createSql, {}, function()
                print('[AdminMode] DB Tabelle geprüft: '..tableName)
            end)
        end
    end
end)

-- Admin toggle command
RegisterCommand(cfg.AdminMode.Command, function(source)
    local src = source
    if transparentPlayers[src] then
        transparentPlayers[src] = nil
        TriggerClientEvent(cfg.Events.SetTransparency, -1, src, cfg.AdminMode.NormalAlpha)
        TriggerClientEvent(cfg.Events.SetGodMode, src, false)
        if cfg.Debug.PrintAdminToggle then print(('[AdminMode] %s'):format(L('admin_disabled'))) end
        if cfg.LogFlags.AdminToggle then LogAction(src, 'admin_off', L('admin_disabled')) end
    else
        transparentPlayers[src] = true
        TriggerClientEvent(cfg.Events.SetTransparency, -1, src, cfg.AdminMode.TransparentAlpha)
        TriggerClientEvent(cfg.Events.SetGodMode, src, true)
        if cfg.Debug.PrintAdminToggle then print(('[AdminMode] %s'):format(L('admin_enabled'))) end
        if cfg.LogFlags.AdminToggle then LogAction(src, 'admin_on', L('admin_enabled')) end
    end
end, true)

RegisterNetEvent(cfg.Events.CheckTransparency)
AddEventHandler(cfg.Events.CheckTransparency, function(playerId)
    local src = source
    if transparentPlayers[playerId] then
        TriggerClientEvent(cfg.Events.SetTransparency, src, playerId, cfg.AdminMode.TransparentAlpha)
    else
        TriggerClientEvent(cfg.Events.SetTransparency, src, playerId, cfg.AdminMode.NormalAlpha)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if transparentPlayers[src] then
        transparentPlayers[src] = nil
        TriggerClientEvent(cfg.Events.SetTransparency, -1, src, cfg.AdminMode.NormalAlpha)
    end
end)

RegisterNetEvent(cfg.Events.GetStaticId)
AddEventHandler(cfg.Events.GetStaticId, function(targetPlayerId)
    if not cfg.StaticId.Enabled then return end
    local src = source
    if tonumber(targetPlayerId) then
        local staticId
        local success, result = pcall(function()
            return exports[cfg.StaticId.ExportResource][cfg.StaticId.ExportFunction](targetPlayerId)
        end)
        if success then
            staticId = result
            if cfg.Debug.PrintStaticIdFetch then
                print(('[StaticID] %s -> %s'):format(targetPlayerId, tostring(staticId)))
            end
        else
            if cfg.Debug.PrintStaticIdFetch then
                print('[StaticID] Fehler beim Abruf: '..tostring(result))
            end
        end
        TriggerClientEvent(cfg.Events.ReceiveStaticId, src, targetPlayerId, staticId)
    end
end)

-- Dimension Command
RegisterCommand(cfg.Dimension.Command, function(source, args)
    local targetId = tonumber(args[1])
    local dimension = tonumber(args[2])
    local xPlayer = GetPlayerObject(source)
    if not xPlayer then return end
    local group = GetPlayerGroup(source)
    local allowed = false
    for _, g in ipairs(cfg.Dimension.AllowedGroups) do
        if g == group then allowed = true break end
    end
    if not allowed then
        if cfg.Notification.Enabled then TriggerClientEvent(cfg.Notification.Event, source, 1, L('dimension_header'), L('dimension_no_permission')) end
        return
    end
    if not targetId or not dimension then
        if cfg.Notification.Enabled then TriggerClientEvent(cfg.Notification.Event, source, 1, L('dimension_header'), L('dimension_usage', cfg.Dimension.Command)) end
        return
    end
    if targetId == -1 then
        if cfg.Notification.Enabled then TriggerClientEvent(cfg.Notification.Event, source, 1, L('dimension_header'), L('dimension_self_error')) end
        return
    end
    local xTarget = GetPlayerObject(targetId)
    if not xTarget then
        if cfg.Notification.Enabled then TriggerClientEvent(cfg.Notification.Event, source, 1, L('dimension_header'), L('player_not_found')) end
        return
    end
    local ok, err = TeleportBucket(targetId, dimension)
    if not ok then
        if cfg.Notification.Enabled then
            if err == 'unsupported' then
                TriggerClientEvent(cfg.Notification.Event, source, 3, L('dimension_header'), L('routingbucket_not_supported'))
            else
                TriggerClientEvent(cfg.Notification.Event, source, 3, L('dimension_header'), L('routingbucket_failed', tostring(err)))
            end
        end
        return
    end
    local targetSrc = xTarget.source or targetId
    if cfg.Notification.Enabled then
        TriggerClientEvent(cfg.Notification.Event, source, 1, L('dimension_header'), L('dimension_success_admin', targetSrc))
        TriggerClientEvent(cfg.Notification.Event, targetSrc, 1, L('dimension_header'), L('dimension_success_target', GetPlayerRoutingBucket(targetSrc)))
    end
    if cfg.LogFlags.Dimension then LogAction(source, 'set_dimension', ('Player %s -> Bucket %s'):format(targetSrc, tostring(dimension))) end
end)

-- Godmode specific logs (separate from toggle if granular)
RegisterNetEvent('adminmode:godmodeChange')
AddEventHandler('adminmode:godmodeChange', function(enabled)
    local src = source
    if cfg.LogFlags.Godmode then
        LogAction(src, enabled and 'godmode_on' or 'godmode_off', 'Godmode via client event')
    end
end)

-- Teleport logging (client sends coordinates)
RegisterNetEvent('adminmode:teleportLog')
AddEventHandler('adminmode:teleportLog', function(x,y,z)
    local src = source
    if cfg.LogFlags.Teleport then
        LogAction(src, 'teleport', string.format('Teleport to: %.2f %.2f %.2f', x, y, z))
    end
end)

-- Player join/leave logging
AddEventHandler('playerConnecting', function(name, setKick, def)
    if cfg.LogFlags.PlayerJoin then
        local src = source
        LogAction(src, 'player_join', 'connect')
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if transparentPlayers[src] then
        transparentPlayers[src] = nil
        TriggerClientEvent(cfg.Events.SetTransparency, -1, src, cfg.AdminMode.NormalAlpha)
    end
    if cfg.LogFlags.PlayerLeave then
        LogAction(src, 'player_leave', reason or 'disconnect')
    end
end)

-- Exports for external resources
exports('LogAction', function(src, action, details)
    LogAction(src, action, details)
end)

exports('GetAdminState', function(playerId)
    return transparentPlayers[playerId] == true
end)




















