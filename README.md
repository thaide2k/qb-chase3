# QB-Chase3 - Script de Perseguição Implacável

Este script adiciona eventos de perseguição ao seu servidor QBCore, onde os jogadores precisam fugir ou destruir veículos perseguidores para ganhar recompensas.

## Instalação

1. Faça download de todos os arquivos e coloque-os em uma pasta chamada `qb-chase3` dentro do diretório `resources` do seu servidor.
2. Adicione `ensure qb-chase3` ao seu `server.cfg`.
3. Reinicie o servidor ou execute `refresh` seguido de `ensure qb-chase3` no console do servidor.

## Arquivos Incluídos

- `client.lua` - Gerencia o lado do cliente da perseguição.
- `server.lua` - Gerencia o lado do servidor da perseguição.
- `config.lua` - Configurações do script.
- `debug.lua` - Ferramentas de depuração para solucionar problemas.
- `fxmanifest.lua` - Manifesto do recurso.

## Resolução de Problemas

Se o evento não estiver iniciando corretamente, siga estes passos para diagnóstico:

### 1. Ative o Modo de Depuração

Execute o comando `/chase_debug on` no jogo para ativar mensagens de depuração. Isso mostrará informações detalhadas sobre o que está acontecendo no script.

### 2. Teste a Perseguição Manualmente

Use o comando `/chase_debug test` para iniciar manualmente uma perseguição. Isso ignora a necessidade do tablet e pode ajudar a identificar se o problema está no sistema de tablet ou no script de perseguição em si.

### 3. Verifique Mensagens de Console

As mensagens de depuração serão exibidas no console do servidor e no console F8 do cliente. Analise essas mensagens para identificar onde o script está falhando.

### 4. Problemas Comuns e Soluções

- **Problema**: O evento não inicia quando acionado pelo tablet.
  - **Solução**: Verifique se o tablet está chamando o evento correto `qb-chase3:server:startEvent`. Adicione um evento de teste no qb-tablet para verificar a comunicação:
  ```lua
  -- Adicione isso ao código do tablet onde ele inicia eventos
  RegisterCommand('test_chase_event', function()
      TriggerServerEvent('qb-chase3:server:startEvent', source)
  end, false)
  ```

- **Problema**: O evento inicia, mas os veículos perseguidores não aparecem.
  - **Solução**: Verifique se os modelos de veículos na configuração existem no seu servidor. Use `/chase_debug status` para verificar a posição do jogador e se ele está em um veículo válido.

- **Problema**: Os veículos perseguidores aparecem, mas não perseguem o jogador.
  - **Solução**: Pode haver um problema com as funções de IA. Verifique se as funções `TaskVehicleChase` e `SetTaskVehicleChaseIdealPursuitDistance` estão funcionando corretamente.

- **Problema**: O evento não termina corretamente.
  - **Solução**: Use `/chase_debug_server clear` para limpar manualmente uma perseguição travada.

### 5. Comandos de Depuração

#### Comandos do Cliente
- `/chase_debug on` - Ativa a depuração
- `/chase_debug off` - Desativa a depuração
- `/chase_debug test` - Inicia teste de perseguição
- `/chase_debug status` - Mostra status atual
- `/chase_debug help` - Mostra ajuda

#### Comandos do Servidor (requer admin)
- `/chase_debug_server test` - Inicia teste de perseguição
- `/chase_debug_server notify` - Testa notificação
- `/chase_debug_server active` - Lista perseguições ativas
- `/chase_debug_server clear [playerId]` - Limpa perseguição para jogador
- `/chase_debug_server help` - Mostra ajuda

## Requisitos

- QBCore Framework
- qb-core
- qb-tablet (para iniciar o evento)

## Integração com qb-tablet

Para integrar este script com o qb-tablet, certifique-se de que o tablet está chamando o evento 'qb-chase3:server:startEvent' quando o jogador seleciona o evento de perseguição.

## Suporte

Se você encontrar problemas adicionais, utilize os comandos de depuração para coletar informações antes de buscar suporte.
