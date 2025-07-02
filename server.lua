local QBCore = exports['qb-core']:GetCoreObject()

-- Spawn effect event
RegisterServerEvent('qb-spawn:server:spawnEffect', function(coords)
    TriggerClientEvent('qb-spawn:client:spawnEffect', -1, coords)
end)

-- Player spawned event
RegisterServerEvent('qb-spawn:server:playerSpawned', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMeta('spawned', true)
    end
end)

-- Admin command to reopen selector
QBCore.Commands.Add('respawn', 'Reopen spawn selector (Admin Only)', {}, false, function(source)
    TriggerClientEvent('qb-spawn:client:openUI', source)
end, 'admin')