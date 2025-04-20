Config = {}

-- Configuração de recompensas
Config.Reward = {
    kryon = 50
}

-- Veículos perseguidores
Config.ChaseVehicles = {
    `xls2`,       -- SUV blindado poderoso
    `schafter4`,  -- Carro rápido e resistente
    `caracara2`,  -- Pickup monstruosa 
    `buffalo3`    -- Carro esportivo policial
}

-- Probabilidade do perseguidor ter arma (0.0 - 1.0)
Config.ArmedDriverChance = 0.5

-- Configurações de mensagens
Config.Messages = {
    start = "~r~VOCÊ ESTÁ SENDO PERSEGUIDO!\n~w~Fuja ou destrua-os antes que eles destroem você!",
    failed_exit = "~r~VOCÊ SAIU DO VEÍCULO\n~w~Perseguição perdida!",
    failed_destroyed = "~r~SEU VEÍCULO FOI DESTRUÍDO\n~w~Perseguição perdida!",
    success_distance = "~g~VOCÊ ESCAPOU!\n~w~Perseguição vencida!",
    success_destroyed = "~g~VOCÊ DESTRUIU TODOS OS PERSEGUIDORES!\n~w~Perseguição vencida!"
}

-- Configurações do evento
Config.PursuitSettings = {
    CHASE_CARS_COUNT = 4,         -- Número de carros perseguidores
    WIN_DISTANCE = 200.0,         -- Distância para considerar a fuga (em unidades)
    CHECK_INTERVAL = 1000,        -- Intervalo de verificação do estado da perseguição (em ms)
    CHASE_MAX_RANGE = 300.0,      -- Distância máxima para os carros perseguidores seguirem o jogador
    MESSAGE_DELAY = 10000,        -- Tempo para mostrar a mensagem inicial (em ms)
    PURSUIT_TIMEOUT = 1200000,    -- Timeout da perseguição (20 minutos em ms)
    WIN_CHECK_COUNT = 5,          -- Número de verificações consecutivas para considerar a vitória
    SPAWN_DISTANCE = 70.0,        -- Distância de spawn dos perseguidores
}
