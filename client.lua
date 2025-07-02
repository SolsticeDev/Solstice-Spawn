local QBCore = exports['qb-core']:GetCoreObject()
local spawned = false
local previewCam = nil
local selectedSpawn = 1
local favoriteSpawns = {}
local showUI = false
local lastLocation = nil

-- Configuration
local Config = {
    SpawnPoints = {
        {name = "Hotel", coords = vector4(-181.44, -1004.21, 29.29, 150.0)},
        {name = "Airport", coords = vector4(-1037.76, -2737.71, 20.17, 330.0)},
        {name = "Pillbox Hospital", coords = vector4(299.12, -584.49, 43.26, 70.0)},
        {name = "Vinewood Hills", coords = vector4(-841.55, 176.63, 70.51, 120.0)},
        {name = "Sandy Shores", coords = vector4(1962.91, 3826.88, 32.5, 220.0)},
        {name = "Paleto Bay", coords = vector4(-275.22, 6635.18, 7.48, 45.0)}
    },
    EnableFavorites = true,
    DefaultSpawn = vector4(-181.44, -1004.21, 29.29, 150.0),
    SpawnEffect = true,
    SpawnEffectTime = 3000,
    CameraHeight = 5.0,
    CameraDistance = 3.0,
    CameraRotation = 0.0
}

-- Debug print function
local function DebugPrint(message)
    print("^5[SPAWN DEBUG]^7 " .. message)
end

-- Load favorite spawns from local storage
local function LoadFavorites()
    local saved = GetResourceKvpString('favorite_spawns')
    if saved then
        favoriteSpawns = json.decode(saved)
        DebugPrint("Loaded favorites: " .. json.encode(favoriteSpawns))
    else
        DebugPrint("No favorites found")
    end
end

-- Save favorite spawns to local storage
local function SaveFavorites()
    SetResourceKvp('favorite_spawns', json.encode(favoriteSpawns))
    DebugPrint("Saved favorites: " .. json.encode(favoriteSpawns))
end

-- Load last location from local storage
local function LoadLastLocation()
    local saved = GetResourceKvpString('last_spawn_location')
    if saved then
        lastLocation = json.decode(saved)
        DebugPrint("Loaded last location: " .. json.encode(lastLocation))
    else
        DebugPrint("No last location found")
    end
end

-- Save last location to local storage
local function SaveLastLocation(coords)
    lastLocation = coords
    SetResourceKvp('last_spawn_location', json.encode(coords))
    DebugPrint("Saved last location: " .. json.encode(coords))
end

-- Check if spawn is favorite
local function IsFavorite(spawnName)
    for _, name in ipairs(favoriteSpawns) do
        if name == spawnName then
            return true
        end
    end
    return false
end

-- Toggle favorite status
local function ToggleFavorite(spawnName)
    local isFavorite = false
    for i, name in ipairs(favoriteSpawns) do
        if name == spawnName then
            table.remove(favoriteSpawns, i)
            isFavorite = true
            break
        end
    end
    
    if not isFavorite then
        table.insert(favoriteSpawns, spawnName)
    end
    
    SaveFavorites()
end

-- Create camera for spawn preview
local function CreateCamera(coords)
    if previewCam then
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    
    -- Calculate camera position using trigonometry
    local angle = Config.CameraRotation * (math.pi / 180.0)
    local camX = coords.x + Config.CameraDistance * math.cos(angle)
    local camY = coords.y + Config.CameraDistance * math.sin(angle)
    local camZ = coords.z + Config.CameraHeight
    
    previewCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
        camX, camY, camZ, 
        0.0, 0.0, Config.CameraRotation, 
        60.0, false, 0
    )
    
    PointCamAtCoord(previewCam, coords.x, coords.y, coords.z)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 1000, true, false)
    DebugPrint("Created camera at " .. camX .. ", " .. camY .. ", " .. camZ)
end

-- Clean up camera
local function CleanupCamera()
    if previewCam then
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(previewCam, false)
        previewCam = nil
        DebugPrint("Camera cleaned up")
    end
end

-- Spawn player with effect
local function SpawnPlayer(coords)
    showUI = false
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'hideUI'})
    
    CleanupCamera()
    
    SaveLastLocation(coords)
    
    if Config.SpawnEffect then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(10)
        end
        
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
        SetEntityHeading(PlayerPedId(), coords.w)
        FreezeEntityPosition(PlayerPedId(), false)
        spawned = true
        
        TriggerServerEvent('qb-spawn:server:spawnEffect', coords)
        
        Wait(Config.SpawnEffectTime - 1000)
        DoScreenFadeIn(1000)
    else
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
        SetEntityHeading(PlayerPedId(), coords.w)
        FreezeEntityPosition(PlayerPedId(), false)
    end
    
    TriggerServerEvent('qb-spawn:server:playerSpawned')
    TriggerEvent('qb-spawn:client:playerSpawned')
end

-- Spawn at last location
local function SpawnAtLastLocation()
    if lastLocation then
        SpawnPlayer(lastLocation)
    else
        SpawnPlayer(Config.DefaultSpawn)
    end
end

-- Open spawn selector UI
local function OpenSpawnSelector()
    if showUI then return end
    
    showUI = true
    
    -- Prepare data for UI
    local spawnData = {}
    for i, spawn in ipairs(Config.SpawnPoints) do
        table.insert(spawnData, {
            id = i,
            name = spawn.name,
            isFavorite = IsFavorite(spawn.name)
        })
    end
    
    -- Sort favorites to top if enabled
    if Config.EnableFavorites then
        table.sort(spawnData, function(a, b)
            if a.isFavorite and not b.isFavorite then
                return true
            elseif not a.isFavorite and b.isFavorite then
                return false
            else
                return a.name < b.name
            end
        end)
    end

    -- Send data to NUI and show UI
    SendNUIMessage({
        action = 'showUI',
        spawns = spawnData,
        enableFavorites = Config.EnableFavorites,
        hasLastLocation = lastLocation ~= nil
    })
    
    -- Initialize camera with first spawn point
    if #Config.SpawnPoints > 0 then
        selectedSpawn = 1
        local spawn = Config.SpawnPoints[selectedSpawn]
        CreateCamera(vector3(spawn.coords.x, spawn.coords.y, spawn.coords.z))
    end
    
    SetNuiFocus(true, true)
    DebugPrint("Spawn selector opened with NUI focus")
end

-- NUI Callbacks
RegisterNUICallback('selectSpawn', function(data, cb)
    selectedSpawn = data.index
    local spawn = Config.SpawnPoints[selectedSpawn]
    if spawn then
        CreateCamera(vector3(spawn.coords.x, spawn.coords.y, spawn.coords.z))
    end
    cb({})
end)

RegisterNUICallback('spawnPlayer', function(data, cb)
    local spawn = Config.SpawnPoints[selectedSpawn]
    if spawn then
        SpawnPlayer(spawn.coords)
    end
    cb({})
end)

RegisterNUICallback('spawnLastLocation', function(data, cb)
    SpawnAtLastLocation()
    cb({})
end)

RegisterNUICallback('toggleFavorite', function(data, cb)
    local spawn = Config.SpawnPoints[selectedSpawn]
    if spawn then
        ToggleFavorite(spawn.name)
        cb({isFavorite = IsFavorite(spawn.name)})
    end
end)

RegisterNUICallback('closeUI', function(data, cb)
    showUI = false
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'hideUI'})
    CleanupCamera()
    cb({})
end)

-- Events
RegisterNetEvent('qb-spawn:client:openUI', function()
    spawned = false
    OpenSpawnSelector()
end)

-- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadFavorites()
        LoadLastLocation()
    end
end)

-- Player loaded event
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    spawned = false
    OpenSpawnSelector()
end)

-- Resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupCamera()
        SetNuiFocus(false, false)
    end
end)