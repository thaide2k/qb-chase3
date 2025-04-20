--[[
    qb-chase3 - Script de Perseguição Implacável
    Arquivo: debug.lua
    Descrição: Comandos de depuração para ajudar a solucionar problemas
]]

local QBCore = exports['qb-core']:GetCoreObject()
local debugging = true

-- Comandos do cliente para depuração
RegisterCommand('chase_debug', function(source, args)
    if args[1] == 'on' then
        debugging = true
        TriggerEvent('QBCore:Notify', 'Debug ativado para qb-chase3', 'success')
        print("[qb-chase3:DEBUG] Debug ativado")
    elseif args[1] == 'off' then
        debugging = false
        TriggerEvent('QBCore:Notify', 'Debug desativado para qb-chase3', 'error')
        print("[qb-chase3:DEBUG] Debug desativado")
    elseif args[1] == 'test' then
        TriggerEvent('QBCore:Notify', 'Iniciando teste de perseguição', 'primary')
        print("[qb-chase3:DEBUG] Iniciando teste de perseguição")
        TriggerServerEvent('qb-chase3:server:TestStart')
    elseif args[1] == 'status' then
        local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        local status = {
            inVehicle = IsPedInAnyVehicle(PlayerPedId(), false),
            vehicleId = playerVeh,
            vehicleNetId = playerVeh ~= 0 and NetworkGetNetworkIdFromEntity(playerVeh) or 0,
            vehicleHealth = playerVeh ~= 0 and GetVehicleEngineHealth(playerVeh) or 0,
            coords = GetEntityCoords(PlayerPedId())
        }
        print("[qb-chase3:DEBUG] Status: " .. json.encode(status))
        TriggerEvent('QBCore:Notify', 'Status enviado para o console', 'primary')
    elseif args[1] == 'help' then
        print("[qb-chase3:DEBUG] Comandos disponíveis:")
        print("  /chase_debug on - Ativa debug")
        print("  /chase_debug off - Desativa debug")
        print("  /chase_debug test - Inicia teste de perseguição")
        print("  /chase_debug status - Mostra status atual")
        print("  /chase_debug help - Mostra esta ajuda")
        TriggerEvent('QBCore:Notify', 'Ajuda enviada para o console', 'primary')
    else
        TriggerEvent('QBCore:Notify', 'Uso: /chase_debug [on|off|test|status|help]', 'error')
    end
end, false)

-- Evento para testar notificações
RegisterNetEvent('qb-chase3:debug:TestNotification')
AddEventHandler('qb-chase3:debug:TestNotification', function(message)
    TriggerEvent('qb-chase3:client:ShowNotification', message or "Teste de notificação", 5000)
end)

-- Comandos do servidor para depuração
if IsDuplicityVersion() then
    RegisterCommand('chase_debug_server', function(source, args)
        local player = source
        
        if args[1] == 'test' then
            print("[qb-chase3:DEBUG:SERVER] Iniciando teste de perseguição para jogador " .. player)
            TriggerEvent('qb-chase3:server:startEvent', player)
        elseif args[1] == 'notify' then
            print("[qb-chase3:DEBUG:SERVER] Testando notificação para jogador " .. player)
            TriggerClientEvent('qb-chase3:debug:TestNotification', player, "Teste de notificação do servidor")
        elseif args[1] == 'active' then
            -- Verificar perseguições ativas
            local active = {}
            for playerId, _ in pairs(activePursuits or {}) do
                table.insert(active, playerId)
            end
            print("[qb-chase3:DEBUG:SERVER] Perseguições ativas: " .. json.encode(active))
        elseif args[1] == 'clear' then
            -- Limpar perseguições ativas para um jogador
            local targetPlayer = tonumber(args[2]) or player
            if activePursuits and activePursuits[targetPlayer] then
                TriggerEvent('qb-chase3:server:StatusUpdate', {leftVehicle = true})
                print("[qb-chase3:DEBUG:SERVER] Perseguição limpa para jogador " .. targetPlayer)
            else
                print("[qb-chase3:DEBUG:SERVER] Nenhuma perseguição ativa para jogador " .. targetPlayer)
            end
        elseif args[1] == 'help' then
            print("[qb-chase3:DEBUG:SERVER] Comandos disponíveis:")
            print("  /chase_debug_server test - Inicia teste de perseguição")
            print("  /chase_debug_server notify - Testa notificação")
            print("  /chase_debug_server active - Lista perseguições ativas")
            print("  /chase_debug_server clear [playerId] - Limpa perseguição para jogador")
            print("  /chase_debug_server help - Mostra esta ajuda")
        else
            print("[qb-chase3:DEBUG:SERVER] Uso: /chase_debug_server [test|notify|active|clear|help]")
        end
    end, true)  -- Requer permissão de admin
end
