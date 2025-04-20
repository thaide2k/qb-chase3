--[[
    qb-chase3 - Script de Perseguição Implacável
    Arquivo: server.lua
    Descrição: Gerencia o lado do servidor da perseguição de carros
]]

local QBCore = exports['qb-core']:GetCoreObject()
local activePursuits = {}
local chaseCars = {
    `xls2`,   -- SUV blindado poderoso
    `schafter4`, -- Carro rápido e resistente
    `caracara2`,  -- Pickup monstruosa 
    `buffalo3` -- Carro esportivo policial
}

local messages = {
    start = "~r~VOCÊ ESTÁ SENDO PERSEGUIDO!\n~w~Fuja ou destrua-os antes que eles destroem você!",
    failed_exit = "~r~VOCÊ SAIU DO VEÍCULO\n~w~Perseguição perdida!",
    failed_destroyed = "~r~SEU VEÍCULO FOI DESTRUÍDO\n~w~Perseguição perdida!",
    success_distance = "~g~VOCÊ ESCAPOU!\n~w~Perseguição vencida!",
    success_destroyed = "~g~VOCÊ DESTRUIU TODOS OS PERSEGUIDORES!\n~w~Perseguição vencida!"
}

local CONFIG = {
    CHASE_CARS_COUNT = 4,         -- Número de carros perseguidores
    WIN_DISTANCE = 200.0,         -- Distância para considerar a fuga (em unidades)
    CHECK_INTERVAL = 1000,        -- Intervalo de verificação do estado da perseguição (em ms)
    CHASE_MAX_RANGE = 300.0,      -- Distância máxima para os carros perseguidores seguirem o jogador
    MESSAGE_DELAY = 10000,        -- Tempo para mostrar a mensagem inicial (em ms)
    PURSUIT_TIMEOUT = 1200000,    -- Timeout da perseguição (20 minutos em ms)
    WIN_CHECK_COUNT = 5,          -- Número de verificações consecutivas para considerar a vitória
    SPAWN_DISTANCE = 70.0,        -- Distância de spawn dos perseguidores
    REWARD_AMOUNT = 50            -- Quantidade de Kryon a ser premiada em caso de vitória
}

-- Função para exibir mensagem grande na tela do jogador
function ShowNotification(player, message, time)
    TriggerClientEvent('qb-chase3:client:ShowNotification', player, message, time or 5000)
end

-- Função para criar veículos perseguidores
function CreatePursuitVehicles(player, playerVehicle, playerCoords, heading)
    local vehicles = {}
    
    for i = 1, CONFIG.CHASE_CARS_COUNT do
        local spawnPoint = GetSpawnPointAroundPlayer(playerCoords, CONFIG.SPAWN_DISTANCE, playerVehicle)
        
        if spawnPoint then
            local modelHash = chaseCars[math.random(#chaseCars)]
            
            TriggerClientEvent('qb-chase3:client:CreatePursuer', player, modelHash, spawnPoint, playerVehicle)
            table.insert(vehicles, {
                model = modelHash,
                spawnPoint = spawnPoint
            })
        end
    end
    
    return vehicles
end

-- Função para obter um ponto de spawn válido
function GetSpawnPointAroundPlayer(playerCoords, distance, playerVehicle)
    -- Escolher ângulo aleatório, mas garantir que esteja atrás do jogador
    local angle = math.random(90, 270) -- 90° a 270° é a parte traseira
    local angleRad = math.rad(angle)
    
    -- Calcular posição baseado no ângulo e distância
    local spawnX = playerCoords.x + distance * math.cos(angleRad)
    local spawnY = playerCoords.y + distance * math.sin(angleRad)
    
    -- Obter o Z (altura) correto para o spawn
    local success, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, playerCoords.z + 10.0, true)
    
    if success then
        -- Verificar se a posição é válida
        if not IsPositionOccupied(spawnX, spawnY, groundZ, 5.0, false, true, false, false, false) then
            return {x = spawnX, y = spawnY, z = groundZ}
        end
    end
    
    -- Se não conseguir um ponto válido no ângulo escolhido, tenta outro
    return GetSpawnPointAroundPlayer(playerCoords, distance + 10.0, playerVehicle)
end

-- Terminar perseguição
function EndPursuit(playerId, success, reason)
    if not activePursuits[playerId] then return end
    
    local pursuitData = activePursuits[playerId]
    
    -- Limpar temporizadores
    if pursuitData.checkTimer then
        clearTimeout(pursuitData.checkTimer)
    end
    
    if pursuitData.timeout then
        clearTimeout(pursuitData.timeout)
    end
    
    -- Recompensa em caso de vitória
    if success then
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            -- Adicionar kryon ao jogador
            xPlayer.Functions.AddItem('kryon', CONFIG.REWARD_AMOUNT)
            TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items["kryon"], "add")
            
            -- Marcar evento como concluído para o tablet
            exports['qb-tablet']:MarkEventCompleted(playerId, 'event_1')
        end
        
        -- Mostrar mensagem de sucesso
        ShowNotification(playerId, reason or messages.success_distance)
    else
        -- Mostrar mensagem de falha
        ShowNotification(playerId, reason or messages.failed_destroyed)
    end
    
    -- Limpar perseguidores que sobraram
    TriggerClientEvent('qb-chase3:client:CleanupPursuit', playerId)
    
    -- Remover da lista de perseguições ativas
    activePursuits[playerId] = nil
end

-- Verificar o estado da perseguição
function CheckPursuitStatus(playerId)
    local pursuitData = activePursuits[playerId]
    if not pursuitData then return end
    
    local player = QBCore.Functions.GetPlayer(playerId)
    if not player then
        EndPursuit(playerId, false, "O jogador saiu do servidor")
        return
    end
    
    -- Solicitar verificação do cliente
    TriggerClientEvent('qb-chase3:client:CheckStatus', playerId)
    
    -- Agendar próxima verificação
    pursuitData.checkTimer = setTimeout(function()
        CheckPursuitStatus(playerId)
    end, CONFIG.CHECK_INTERVAL)
end

-- Iniciar perseguição
function StartPursuit(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    if not player then return false end
    
    -- Verificar se o jogador já está em uma perseguição
    if activePursuits[playerId] then
        return false, "Jogador já está em uma perseguição"
    end
    
    -- Inicializar dados da perseguição
    activePursuits[playerId] = {
        startTime = os.time(),
        vehicles = {},
        distanceCounter = 0,
        playerVehicle = nil
    }
    
    -- Solicitar ao cliente para iniciar a perseguição
    TriggerClientEvent('qb-chase3:client:StartPursuit', playerId, CONFIG)
    
    -- Configurar timeout para a perseguição
    activePursuits[playerId].timeout = setTimeout(function()
        EndPursuit(playerId, false, "~r~TEMPO ESGOTADO!\n~w~Você não conseguiu escapar a tempo.")
    end, CONFIG.PURSUIT_TIMEOUT)
    
    -- Iniciar verificações de status
    setTimeout(function()
        CheckPursuitStatus(playerId)
    end, CONFIG.CHECK_INTERVAL)
    
    return true
end

-- Eventos do Servidor

-- Evento para iniciar a perseguição (chamado pelo qb-tablet)
RegisterNetEvent('qb-chase3:server:startEvent')
AddEventHandler('qb-chase3:server:startEvent', function(playerId, eventData)
    local success, errorMsg = StartPursuit(playerId)
    
    if not success and errorMsg then
        ShowNotification(playerId, "~r~ERRO: " .. errorMsg)
    end
end)

-- Eventos para comunicação com o cliente
RegisterNetEvent('qb-chase3:server:PursuitSetup')
AddEventHandler('qb-chase3:server:PursuitSetup', function(vehicleNetId, playerCoords, heading)
    local playerId = source
    if not activePursuits[playerId] then return end
    
    activePursuits[playerId].playerVehicle = vehicleNetId
    activePursuits[playerId].vehicles = CreatePursuitVehicles(playerId, vehicleNetId, playerCoords, heading)
    
    -- Mostrar mensagem inicial após delay para dar tempo dos perseguidores se aproximarem
    setTimeout(function()
        if activePursuits[playerId] then
            ShowNotification(playerId, messages.start)
        end
    end, CONFIG.MESSAGE_DELAY)
end)

RegisterNetEvent('qb-chase3:server:StatusUpdate')
AddEventHandler('qb-chase3:server:StatusUpdate', function(status)
    local playerId = source
    if not activePursuits[playerId] then return end
    
    -- Verificar condições de derrota
    if status.leftVehicle then
        EndPursuit(playerId, false, messages.failed_exit)
        return
    end
    
    if status.vehicleDestroyed then
        EndPursuit(playerId, false, messages.failed_destroyed)
        return
    end
    
    -- Verificar condições de vitória
    if status.allPursuersDestroyed then
        EndPursuit(playerId, true, messages.success_destroyed)
        return
    end
    
    -- Verificar distância dos perseguidores
    if status.minDistance > CONFIG.WIN_DISTANCE then
        activePursuits[playerId].distanceCounter = activePursuits[playerId].distanceCounter + 1
        
        -- Vitória por distância após várias verificações consecutivas
        if activePursuits[playerId].distanceCounter >= CONFIG.WIN_CHECK_COUNT then
            EndPursuit(playerId, true, messages.success_distance)
        end
    else
        -- Resetar contador se algum perseguidor se aproximou
        activePursuits[playerId].distanceCounter = 0
    end
end)

-- Limpar perseguição quando o jogador sair do servidor
AddEventHandler('playerDropped', function()
    local playerId = source
    if activePursuits[playerId] then
        EndPursuit(playerId, false, "Jogador saiu do servidor")
    end
end)
