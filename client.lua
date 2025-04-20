--[[
    qb-chase3 - Script de Perseguição Implacável
    Arquivo: client.lua
    Descrição: Gerencia o lado do cliente da perseguição de carros
]]

local QBCore = exports['qb-core']:GetCoreObject()
local activePursuit = nil
local pursuitVehicles = {}
local playerVeh = nil

-- Função para exibir mensagem grande na tela
RegisterNetEvent('qb-chase3:client:ShowNotification')
AddEventHandler('qb-chase3:client:ShowNotification', function(message, time)
    time = time or 5000
    local scaleform = RequestScaleformMovie("mp_big_message_freemode")
    
    while not HasScaleformMovieLoaded(scaleform) do
        Citizen.Wait(0)
    end
    
    BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
    PushScaleformMovieMethodParameterString("~y~PERSEGUIÇÃO")
    PushScaleformMovieMethodParameterString(message)
    EndScaleformMovieMethod()
    
    local startTime = GetGameTimer()
    
    Citizen.CreateThread(function()
        while GetGameTimer() - startTime < time do
            Citizen.Wait(0)
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end
    end)
end)

-- Iniciar perseguição
RegisterNetEvent('qb-chase3:client:StartPursuit')
AddEventHandler('qb-chase3:client:StartPursuit', function(config)
    if activePursuit then
        TriggerEvent('QBCore:Notify', 'Você já está em uma perseguição!', 'error')
        return
    end
    
    activePursuit = {
        config = config,
        startTime = GetGameTimer(),
        pursuerBlips = {}
    }
    
    playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    
    -- Verificar se o jogador está em um veículo
    if playerVeh == 0 then
        TriggerEvent('QBCore:Notify', 'Você precisa estar em um veículo para iniciar a perseguição!', 'error')
        activePursuit = nil
        return
    end
    
    -- Obter informações do veículo e posição do jogador
    local netId = NetworkGetNetworkIdFromEntity(playerVeh)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(playerVeh)
    
    -- Enviar informações para o servidor
    TriggerServerEvent('qb-chase3:server:PursuitSetup', netId, playerCoords, heading)
    
    -- Iniciar thread de monitoramento
    StartPursuitMonitoring()
end)

-- Criar veículo perseguidor
RegisterNetEvent('qb-chase3:client:CreatePursuer')
AddEventHandler('qb-chase3:client:CreatePursuer', function(modelHash, spawnPoint, playerVehicleNetId)
    -- Carregar o modelo
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(10)
    end
    
    -- Criar veículo
    local vehicle = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, 0.0, true, true)
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Melhorar o veículo perseguidor
    SetVehicleEngineOn(vehicle, true, true, false)
    ModifyVehicleTopSpeed(vehicle, 1.5) -- 50% mais rápido
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", 2.0)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", 2.0)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", 2.0)
    
    -- Criar blip no mapa
    local blip = AddBlipForEntity(vehicle)
    SetBlipColour(blip, 1) -- Vermelho
    SetBlipAsShortRange(blip, false)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Perseguidor")
    EndTextCommandSetBlipName(blip)
    
    -- Criar motorista
    local driver = CreatePedInsideVehicle(vehicle, 26, `g_m_y_mexgang_01`, -1, true, true)
    SetDriverAbility(driver, 1.0) -- 0.0 ruim, 1.0 perfeito
    SetDriverAggressiveness(driver, 1.0) -- 0.0 calmo, 1.0 agressivo
    
    -- Armas para os motoristas tornarem a perseguição mais difícil
    if math.random() > 0.5 then
        GiveWeaponToPed(driver, `WEAPON_MICROSMG`, 1000, false, true)
        TaskShootAtEntity(driver, NetworkGetEntityFromNetworkId(playerVehicleNetId), -1, `FIRING_PATTERN_BURST_FIRE`)
    end
    
    -- Invulnerabilidade parcial para os motoristas (difícil de matar, mas não impossível)
    SetPedArmour(driver, 100)
    SetEntityHealth(driver, 200)
    
    -- Configurar IA para perseguir o jogador
    TaskVehicleChase(driver, PlayerPedId())
    SetTaskVehicleChaseIdealPursuitDistance(driver, 3.0) -- Distância ideal de perseguição era 10
    
    -- Adicionar à lista de veículos perseguidores
    table.insert(pursuitVehicles, {
        vehicle = vehicle,
        driver = driver,
        blip = blip
    })
end)

-- Monitorar o estado da perseguição
function StartPursuitMonitoring()
    Citizen.CreateThread(function()
        while activePursuit do
            Citizen.Wait(500)
            
            local playerPed = PlayerPedId()
            local inVehicle = IsPedInAnyVehicle(playerPed, false)
            local currentVeh = GetVehiclePedIsIn(playerPed, false)
            
            -- Verificar se o jogador saiu do veículo
            if not inVehicle and playerVeh ~= 0 then
                TriggerServerEvent('qb-chase3:server:StatusUpdate', {leftVehicle = true})
                break
            end
            
            -- Atualizar referência do veículo se o jogador trocar de veículo
            if inVehicle and currentVeh ~= playerVeh then
                playerVeh = currentVeh
            end
            
            -- Verificar estado do veículo do jogador
            if playerVeh ~= 0 and IsVehicleDestroyed(playerVeh) then
                TriggerServerEvent('qb-chase3:server:StatusUpdate', {vehicleDestroyed = true})
                break
            end
        end
    end)
end

-- Verificar status da perseguição quando solicitado pelo servidor
RegisterNetEvent('qb-chase3:client:CheckStatus')
AddEventHandler('qb-chase3:client:CheckStatus', function()
    if not activePursuit then return end
    
    local status = {
        leftVehicle = false,
        vehicleDestroyed = false,
        allPursuersDestroyed = true,
        minDistance = 999999.9
    }
    
    -- Verifica se o jogador está em um veículo
    local playerPed = PlayerPedId()
    status.leftVehicle = not IsPedInAnyVehicle(playerPed, false)
    
    -- Verifica se o veículo do jogador está destruído
    if playerVeh ~= 0 then
        status.vehicleDestroyed = IsVehicleDestroyed(playerVeh)
    end
    
    -- Verificar perseguidores
    local activePursuers = 0
    local playerCoords = GetEntityCoords(playerPed)
    
    for i, data in ipairs(pursuitVehicles) do
        if DoesEntityExist(data.vehicle) and not IsVehicleDestroyed(data.vehicle) then
            activePursuers = activePursuers + 1
            
            -- Atualizar comportamento do motorista
            if DoesEntityExist(data.driver) then
                TaskVehicleChase(data.driver, playerPed)
                SetTaskVehicleChaseIdealPursuitDistance(data.driver, 10.0)
            end
            
            -- Calcular distância
            local pursuersCoords = GetEntityCoords(data.vehicle)
            local distance = #(playerCoords - pursuersCoords)
            
            if distance < status.minDistance then
                status.minDistance = distance
            end
        else
            -- Limpar blip se o veículo foi destruído
            if data.blip and DoesBlipExist(data.blip) then
                RemoveBlip(data.blip)
                data.blip = nil
            end
        end
    end
    
    status.allPursuersDestroyed = (activePursuers == 0)
    
    -- Enviar status para o servidor
    TriggerServerEvent('qb-chase3:server:StatusUpdate', status)
end)

-- Limpeza ao finalizar perseguição
RegisterNetEvent('qb-chase3:client:CleanupPursuit')
AddEventHandler('qb-chase3:client:CleanupPursuit', function()
    if not activePursuit then return end
    
    -- Limpar veículos e motoristas
    for _, data in ipairs(pursuitVehicles) do
        if DoesEntityExist(data.vehicle) then
            DeleteEntity(data.vehicle)
        end
        
        if DoesEntityExist(data.driver) then
            DeleteEntity(data.driver)
        end
        
        if data.blip and DoesBlipExist(data.blip) then
            RemoveBlip(data.blip)
        end
    end
    
    pursuitVehicles = {}
    activePursuit = nil
    playerVeh = nil
end)

-- Função auxiliar para desenhar texto na tela
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local scale = 0.35
    
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end
