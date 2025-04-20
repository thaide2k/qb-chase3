--[[
    qb-chase3 - Script de Perseguição Implacável
    Arquivo: server.lua
    Descrição: Gerencia o lado do servidor da perseguição de carros
]]

local QBCore = exports['qb-core']:GetCoreObject()
local activePursuits = {}
local debugging = true -- Ativar depuração

-- Função de debug
function DebugLog(message)
    if debugging then
        print("[qb-chase3:DEBUG:SERVER] " .. message)
    end
end

-- Carregar configurações do arquivo config.lua
local Config = Config or {}

-- Função para exibir mensagem grande na tela do jogador
function ShowNotification(player, message, time)
    DebugLog("Enviando notificação para " .. player .. ": " .. message)
    TriggerClientEvent('qb-chase3:client:ShowNotification', player, message, time or 5000)
end

-- Função para criar veículos perseguidores
function CreatePursuitVehicles(player, playerVehicle, playerCoords, heading)
    DebugLog("Criando veículos perseguidores para jogador " .. player)
    local vehicles = {}
    
    for i = 1, Config.PursuitSettings.CHASE_CARS_COUNT do
        local spawnPoint = GetSpawnPointAroundPlayer(playerCoords, Config.PursuitSettings.SPAWN_DISTANCE, playerVehicle)
        
        if spawnPoint then
            local modelHash = Config.ChaseVehicles[math.random(#Config.ChaseVehicles)]
            
            DebugLog("Enviando evento para criar perseguidor: " .. modelHash)
            TriggerClientEvent('qb-chase3:client:CreatePursuer', player, modelHash, spawnPoint, playerVehicle)
            table.insert(vehicles, {
                model = modelHash,
                spawnPoint = spawnPoint
            })
        else
            DebugLog("Falha ao encontrar ponto de spawn para perseguidor " .. i)
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
    if not activePursuits[playerId] then 
        DebugLog("Tentativa de encerrar perseguição inexistente para jogador " .. playerId)
        return 
    end
    
    DebugLog("Encerrando perseguição para jogador " .. playerId .. ", sucesso: " .. tostring(success))
    
    local pursuitData = activePursuits[playerId]
    
    -- Limpar temporizadores
    if pursuitData.checkTimer then
        DebugLog("Limpando timer de verificação")
        clearTimeout(pursuitData.checkTimer)
    end
    
    if pursuitData.timeout then
        DebugLog("Limpando timer de timeout")
        clearTimeout(pursuitData.timeout)
    end
    
    -- Recompensa em caso de vitória
    if success then
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            -- Adicionar kryon ao jogador
            DebugLog("Adicionando " .. Config.Reward.kryon .. " kryon ao jogador")
            xPlayer.Functions.AddItem('kryon', Config.Reward.kryon)
            TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items["kryon"], "add")
            
            -- Marcar evento como concluído para o tablet
            DebugLog("Marcando evento como concluído no tablet")
            exports['qb-tablet']:MarkEventCompleted(playerId, 'event_1')
        end
        
        -- Mostrar mensagem de sucesso
        ShowNotification(playerId, reason or Config.Messages.success_distance)
    else
        -- Mostrar mensagem de falha
        ShowNotification(playerId, reason or Config.Messages.failed_destroyed)
    end
    
    -- Limpar perseguidores que sobraram
    DebugLog("Enviando comando de limpeza para o cliente")
    TriggerClientEvent('qb-chase3:client:CleanupPursuit', playerId)
    
    -- Remover da lista de perseguições ativas
    activePursuits[playerId] = nil
    DebugLog("Perseguição encerrada com sucesso")
end

-- Verificar o estado da perseguição
function CheckPursuitStatus(playerId)
    local pursuitData = activePursuits[playerId]
    if not pursuitData then 
        DebugLog("CheckPursuitStatus: perseguição inexistente para jogador " .. playerId)
        return 
    end
    
    local player = QBCore.Functions.GetPlayer(playerId)
    if not player then
        DebugLog("CheckPursuitStatus: jogador " .. playerId .. " não encontrado")
        EndPursuit(playerId, false, "O jogador saiu do servidor")
        return
    end
    
    -- Solicitar verificação do cliente
    DebugLog("Solicitando verificação de status do cliente")
    TriggerClientEvent('qb-chase3:client:CheckStatus', playerId)
    
    -- Agendar próxima verificação
    pursuitData.checkTimer = setTimeout(function()
        CheckPursuitStatus(playerId)
    end, Config.PursuitSettings.CHECK_INTERVAL)
end

-- Iniciar perseguição
function StartPursuit(playerId)
    DebugLog("Tentando iniciar perseguição para jogador " .. playerId)
    
    local player = QBCore.Functions.GetPlayer(playerId)
    if not player then 
        DebugLog("StartPursuit: jogador " .. playerId .. " não encontrado")
        return false 
    end
    
    -- Verificar se o jogador já está em uma perseguição
    if activePursuits[playerId] then
        DebugLog("StartPursuit: jogador já está em uma perseguição")
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
    DebugLog("Enviando evento StartPursuit para o cliente")
    TriggerClientEvent('qb-chase3:client:StartPursuit', playerId, Config.PursuitSettings)
    
    -- Configurar timeout para a perseguição
    activePursuits[playerId].timeout = setTimeout(function()
        EndPursuit(playerId, false, "~r~TEMPO ESGOTADO!\n~w~Você não conseguiu escapar a tempo.")
    end, Config.PursuitSettings.PURSUIT_TIMEOUT)
    
    -- Iniciar verificações de status
    setTimeout(function()
        CheckPursuitStatus(playerId)
    end, Config.PursuitSettings.CHECK_INTERVAL)
    
    DebugLog("Perseguição iniciada com sucesso")
    return true
end

-- Eventos do Servidor

-- Evento para iniciar a perseguição (chamado pelo qb-tablet)
RegisterNetEvent('qb-chase3:server:startEvent')
AddEventHandler('qb-chase3:server:startEvent', function(playerId, eventData)
    DebugLog("Evento startEvent recebido do tablet para jogador " .. playerId)
    
    -- Se o evento for chamado sem especificar playerId, usar o source
    if not playerId then
        playerId = source
        DebugLog("Usando source como playerId: " .. playerId)
    end
    
    local success, errorMsg = StartPursuit(playerId)
    
    if not success and errorMsg then
        DebugLog("Falha ao iniciar perseguição: " .. errorMsg)
        ShowNotification(playerId, "~r~ERRO: " .. errorMsg)
    end
end)

-- Evento de teste manual
RegisterNetEvent('qb-chase3:server:TestStart')
AddEventHandler('qb-chase3:server:TestStart', function()
    local playerId = source
    DebugLog("Evento de teste manual recebido de " .. playerId)
    
    local success, errorMsg = StartPursuit(playerId)
    
    if not success and errorMsg then
        DebugLog("Falha ao iniciar perseguição de teste: " .. errorMsg)
        ShowNotification(playerId, "~r~ERRO: " .. errorMsg)
    end
end)

-- Eventos para comunicação com o cliente
RegisterNetEvent('qb-chase3:server:PursuitSetup')
AddEventHandler('qb-chase3:server:PursuitSetup', function(vehicleNetId, playerCoords, heading)
    local playerId = source
    DebugLog("PursuitSetup recebido do jogador " .. playerId)
    
    if not activePursuits[playerId] then 
        DebugLog("PursuitSetup: perseguição não encontrada para jogador " .. playerId)
        return 
    end
    
    activePursuits[playerId].playerVehicle = vehicleNetId
    activePursuits[playerId].vehicles = CreatePursuitVehicles(playerId, vehicleNetId, playerCoords, heading)
    
    -- Mostrar mensagem inicial após delay para dar tempo dos perseguidores se aproximarem
    setTimeout(function()
        if activePursuits[playerId] then
            DebugLog("Exibindo mensagem inicial de perseguição")
            ShowNotification(playerId, Config.Messages.start)
        end
    end, Config.PursuitSettings.MESSAGE_DELAY)
end)

RegisterNetEvent('qb-chase3:server:StatusUpdate')
AddEventHandler('qb-chase3:server:StatusUpdate', function(status)
    local playerId = source
    DebugLog("StatusUpdate recebido de " .. playerId .. ": " .. json.encode(status))
    
    if not activePursuits[playerId] then 
        DebugLog("StatusUpdate: perseguição não encontrada para jogador " .. playerId)
        return 
    end
    
    -- Verificar condições de derrota
    if status.leftVehicle then
        DebugLog("Jogador saiu do veículo - derrota")
        EndPursuit(playerId, false, Config.Messages.failed_exit)
        return
    end
    
    if status.vehicleDestroyed then
        DebugLog("Veículo do jogador destruído - derrota")
        EndPursuit(playerId, false, Config.Messages.failed_destroyed)
        return
    end
    
    -- Verificar condições de vitória
    if status.allPursuersDestroyed then
        DebugLog("Todos os perseguidores destruídos - vitória")
        EndPursuit(playerId, true, Config.Messages.success_destroyed)
        return
    end
    
    -- Verificar distância dos perseguidores
    if status.minDistance > Config.PursuitSettings.WIN_DISTANCE then
        activePursuits[playerId].distanceCounter = activePursuits[playerId].distanceCounter + 1
        DebugLog("Distância suficiente, contador = " .. activePursuits[playerId].distanceCounter)
        
        -- Vitória por distância após várias verificações consecutivas
        if activePursuits[playerId].distanceCounter >= Config.PursuitSettings.WIN_CHECK_COUNT then
            DebugLog("Distância mantida por tempo suficiente - vitória")
            EndPursuit(playerId, true, Config.Messages.success_distance)
        end
    else
        -- Resetar contador se algum perseguidor se aproximou
        if activePursuits[playerId].distanceCounter > 0 then
            DebugLog("Perseguidor se aproximou, resetando contador")
        end
        activePursuits[playerId].distanceCounter = 0
    end
end)

-- Limpar perseguição quando o jogador sair do servidor
AddEventHandler('playerDropped', function()
    local playerId = source
    DebugLog("Jogador " .. playerId .. " saiu do servidor")
    
    if activePursuits[playerId] then
        DebugLog("Limpando perseguição de jogador que saiu")
        EndPursuit(playerId, false, "Jogador saiu do servidor")
    end
end)

-- Inicialização
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    DebugLog("Recurso iniciado")
end)
