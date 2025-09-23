local cfg = Config

local Framework = {
    name = nil,
    core = nil
}

-- Detect framework
local function DetectFramework()
    if cfg.Framework and cfg.Framework.AutoDetect then
    -- Try preferred first
        local preferred = (cfg.Framework.Preferred or 'esx'):lower()
        local tried = {}
        local order = { preferred, preferred == 'esx' and 'qb' or 'esx' }
        for _, fw in ipairs(order) do
            if fw == 'esx' and not tried['esx'] then
                tried['esx'] = true
                -- First try export, then legacy event fallback
                local exportOk, exportObj = pcall(function() return exports['es_extended']:getSharedObject() end)
                if exportOk and exportObj then
                    Framework.name = 'esx'
                    Framework.core = exportObj
                    return
                else
                    local legacy
                    TriggerEvent('esx:getSharedObject', function(obj) legacy = obj end)
                    if legacy then
                        Framework.name = 'esx'
                        Framework.core = legacy
                        return
                    end
                end
            elseif fw == 'qb' and not tried['qb'] then
                tried['qb'] = true
                if GetResourceState('qb-core') == 'started' then
                    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
                    if ok and obj then
                        Framework.name = 'qb'
                        Framework.core = obj
                        return
                    end
                end
            end
        end
    else
        local preferred = (cfg.Framework.Preferred or 'esx'):lower()
        if preferred == 'esx' then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok and obj then Framework.name = 'esx'; Framework.core = obj end
        elseif preferred == 'qb' then
            if GetResourceState('qb-core') == 'started' then
                local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
                if ok and obj then Framework.name = 'qb'; Framework.core = obj end
            end
        end
    end
end

DetectFramework()

-- Wrapper Funktionen
local function GetPlayerGroup()
    if Framework.name == 'esx' then
        local data = Framework.core.GetPlayerData and Framework.core:GetPlayerData() or Framework.core.GetPlayerData()
        return (data and data.group) or 'user'
    elseif Framework.name == 'qb' then
        local data = Framework.core.Functions and Framework.core.Functions.GetPlayerData and Framework.core.Functions.GetPlayerData()
        if data and data.job and data.job.name then
            return data.job.name -- QBCore has no native group concept; use job
        end
        return 'citizen'
    end
    return 'user'
end

local function TeleportPlayer(coords)
    if Framework.name == 'esx' then
        if Framework.core.Game and Framework.core.Game.Teleport then
            Framework.core.Game.Teleport(PlayerPedId(), coords)
        else
            SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
        end
    else
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    end
end

local function Notify(msg)
    if Framework.name == 'esx' and cfg.Teleport.UseESXNotification then
        if Framework.core.ShowNotification then
            Framework.core.ShowNotification(msg)
        elseif Framework.core.ShowAdvancedNotification then
            Framework.core.ShowAdvancedNotification('Info','',msg,'CHAR_DEFAULT',1)
        else
            print('[Notify] '..msg)
        end
    elseif Framework.name == 'qb' then
    -- QBCore standard notify
        TriggerEvent('QBCore:Notify', msg, 'primary')
    else
        print('[Notify] '..msg)
    end
end

local adminPlayers = {}
local staticIds = {}
local checkedPlayers = {}
local pendingPlayers = {} -- stores server ids that entered scope and are awaiting initial transparency fetch

-- Request current admin transparency states after player fully loads
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        -- small delay to ensure network ids exist
        CreateThread(function()
            Wait(2000)
            TriggerServerEvent('adminmode:requestSync')
        end)
    end
end)

-- Scope-based detection (OneSync Infinity/legacy) reduces constant distance scanning
if cfg.Performance and cfg.Performance.UseScopeEvents then
    AddEventHandler('playerEnteredScope', function(data)
        local serverId = data and data.player or data -- depending on build
        if type(serverId) ~= 'number' then return end
        pendingPlayers[serverId] = true
        TriggerServerEvent(cfg.Events.CheckTransparency, serverId)
        if cfg.StaticId.Enabled then
            TriggerServerEvent(cfg.Events.GetStaticId, serverId)
        end
    end)

    AddEventHandler('playerLeftScope', function(data)
        local serverId = data and data.player or data
        if type(serverId) ~= 'number' then return end
        pendingPlayers[serverId] = nil
        checkedPlayers[serverId] = nil
        adminPlayers[serverId] = nil
        staticIds[serverId] = nil
    end)
else
    -- Fallback to legacy radius scan loop if scope events disabled
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(cfg.Scan.IntervalMs)
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            for _, playerId in ipairs(GetActivePlayers()) do
                local otherPed = GetPlayerPed(playerId)
                local otherPos = GetEntityCoords(otherPed)
                if #(playerPos - otherPos) <= cfg.Scan.Radius then
                    if not checkedPlayers[playerId] then
                        TriggerServerEvent(cfg.Events.CheckTransparency, GetPlayerServerId(playerId))
                        if cfg.StaticId.Enabled then
                            TriggerServerEvent(cfg.Events.GetStaticId, GetPlayerServerId(playerId))
                        end
                        checkedPlayers[playerId] = true
                    end
                else
                    checkedPlayers[playerId] = nil
                    adminPlayers[playerId] = nil
                    staticIds[playerId] = nil
                end
            end
        end
    end)
end

RegisterNetEvent(cfg.Events.SetTransparency)
AddEventHandler(cfg.Events.SetTransparency, function(playerId, alpha)
    local localServerId = GetPlayerServerId(PlayerId())
    local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
    if DoesEntityExist(ped) then
        -- If you want the admin to see themselves fully opaque while others see them transparent,
        -- add a config flag AdminMode.SelfOpaque and handle here
        if cfg.AdminMode.SelfOpaque and playerId == localServerId and alpha < 255 then
            SetEntityAlpha(ped, cfg.AdminMode.NormalAlpha, false)
        else
            SetEntityAlpha(ped, alpha, false)
        end
        if alpha < 255 then
            adminPlayers[playerId] = ped
        else
            adminPlayers[playerId] = nil
        end
    end
end)


RegisterNetEvent(cfg.Events.ReceiveStaticId)
AddEventHandler(cfg.Events.ReceiveStaticId, function(playerId, staticId)
    staticIds[playerId] = staticId
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPos = GetEntityCoords(PlayerPedId())
        if cfg.Admin3DText.Enabled then
            for playerId, ped in pairs(adminPlayers) do -- playerId here = server id
                local pedPos = GetEntityCoords(ped)
                local staticId
                if cfg.StaticId.Enabled then
                    staticId = staticIds[playerId] or 'N/A'
                else
                    if cfg.StaticId.UseServerIdWhenDisabled then
                        staticId = tostring(playerId)
                    else
                        staticId = 'N/A'
                    end
                end
                if #(playerPos - pedPos) <= cfg.Admin3DText.Distance then
                    local textLines = {}
                    for _, lineKey in ipairs(cfg.Admin3DText.Lines) do
                        table.insert(textLines, L(lineKey, staticId))
                    end
                    DrawText3D(pedPos.x, pedPos.y, pedPos.z+1, table.concat(textLines, '\n'))
                end
            end
        end
    end
end)

RegisterNetEvent(cfg.Events.SetGodMode)
AddEventHandler(cfg.Events.SetGodMode, function(bool)
    if cfg.AdminMode.EnableGodMode then
        SetEntityOnlyDamagedByRelationshipGroup(PlayerPedId(), bool, 69420)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = GetDistanceBetweenCoords(p.x, p.y, p.z, x, y, z, 1)
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov
    if onScreen then
    SetTextScale(0.0, (cfg.Admin3DText.ScaleBase or 0.35) * scale)
        SetTextFont(0)
        SetTextProportional(1)
    SetTextColour(cfg.Admin3DText.Color.r, cfg.Admin3DText.Color.g, cfg.Admin3DText.Color.b, cfg.Admin3DText.Color.a)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end


RegisterCommand(cfg.Teleport.Command, function(source, args)
    local group = GetPlayerGroup()
    local allowed = true
    if cfg.Teleport.PermissionGroups and #cfg.Teleport.PermissionGroups > 0 then
        allowed = false
        for _, g in ipairs(cfg.Teleport.PermissionGroups) do
            if g == group then
                allowed = true
                break
            end
        end
    end
    if not allowed then
        local msg = L('teleport_no_permission')
        if cfg.Teleport.UseESXNotification and ESX and ESX.ShowNotification then
            ESX.ShowNotification(msg)
        else
            print('[Teleport] '..msg)
        end
        return
    end
    if tonumber(args[1]) and tonumber(args[2]) and tonumber(args[3]) then
        local posx, posy, posz = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
        TeleportPlayer({ x = posx, y = posy, z = posz })
    -- Send logging event to server (if LogFlags.Teleport active server logs it)
        TriggerServerEvent('adminmode:teleportLog', posx, posy, posz)
        Notify(L('teleport_success', posx, posy, posz))
    end
end)