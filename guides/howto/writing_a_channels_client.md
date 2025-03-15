# Escrevendo um Cliente para Channels

Bibliotecas cliente para Phoenix Channels já existem em [várias linguagens](https://hexdocs.pm/phoenix/channels.html#client-libraries), mas se você quiser escrever a sua própria, este guia deve ajudá-lo a começar.
Também pode ser útil como um guia para testes manuais com um cliente WebSocket.

## Visão Geral

Como os WebSockets são bidirecionais, as mensagens podem fluir em qualquer direção a qualquer momento.
Por esta razão, os clientes geralmente usam callbacks para lidar com mensagens recebidas sempre que elas chegam.

Um cliente deve ingressar em pelo menos um tópico para começar a enviar e receber mensagens, e pode ingressar em qualquer número de tópicos usando a mesma conexão.

## Conectando

Para estabelecer uma conexão WebSocket com Phoenix Channels, primeiro observe a declaração `socket` no módulo `Endpoint` da aplicação.
Por exemplo, se você vê: `socket "/mobile", MyAppWeb.MobileSocket`, o caminho para a requisição HTTP inicial é:

    [host]:[porta]/mobile/websocket?vsn=2.0.0

Passar `&vsn=2.0.0` especifica `Phoenix.Socket.V2.JSONSerializer`, que é incorporado ao Phoenix, e que espera e retorna mensagens na forma de listas.

Você também precisa incluir [os campos de cabeçalho padrão para atualizar uma requisição HTTP para uma conexão WebSocket](https://developer.mozilla.org/en-US/docs/Web/HTTP/Protocol_upgrade_mechanism) ou usar uma biblioteca HTTP que lide com isso para você; em Elixir, [mint_web_socket](https://hex.pm/packages/mint_web_socket) é um exemplo.

Outros parâmetros ou cabeçalhos podem ser esperados ou exigidos pela função específica `connect/3` no módulo socket da aplicação (no exemplo acima, `MyAppWeb.MobileSocket.connect/3`).

## Formato da Mensagem

O formato da mensagem é determinado pelo serializador configurado para a aplicação.
Para estes exemplos, `Phoenix.Socket.V2.JSONSerializer` é assumido.

O formato geral para mensagens que um cliente envia para um Phoenix Channel é o seguinte:

```
[referência_ingresso, referência_mensagem, nome_tópico, nome_evento, payload]
```

- A `referência_ingresso` também é escolhida pelo cliente e também deve ser um valor único. Só precisa ser enviada para um evento `"phx_join"`; para outras mensagens, pode ser `null`. É usada como referência de mensagem para mensagens `push` do servidor, ou seja, aquelas que não são respostas a uma mensagem específica do cliente. Por exemplo, imagine algo como "um novo usuário acabou de entrar na sala de chat".
- A `referência_mensagem` é escolhida pelo cliente e deve ser um valor único. O servidor a inclui em sua resposta para que o cliente saiba a qual mensagem a resposta se refere.
- O `nome_tópico` deve ser um tópico conhecido para o endpoint do socket, e um cliente deve ingressar nesse tópico antes de enviar qualquer mensagem nele.
- O `nome_evento` deve corresponder ao primeiro argumento de uma função `handle_in` no módulo do canal do servidor.
- O `payload` deve ser um mapa e é passado como o segundo argumento para essa função `handle_in`.

Existem três eventos que são compreendidos por todas as aplicações Phoenix.

Primeiro, `phx_join` é usado para ingressar em um canal. Por exemplo, para ingressar no canal `miami:weather`:

```json
["0", "0", "miami:weather", "phx_join", {"some": "param"}]
```

Segundo, `phx_leave` é usado para sair de um canal. Por exemplo, para sair do canal `miami:weather`:

```json
[null, "1", "miami:weather", "phx_leave", {}]
```

Terceiro, `heartbeat` é usado para manter a conexão WebSocket. Por exemplo:

```json
[null, "2", "phoenix", "heartbeat", {}]
```

A mensagem de `heartbeat` só é necessária quando nenhuma outra mensagem está sendo enviada e impede que o Phoenix feche a conexão; o `:timeout` exato é configurado no módulo `Endpoint` da aplicação.

Outras mensagens permitidas dependem da aplicação Phoenix.

Por exemplo, se o Canal que serve o `miami:weather` pode lidar com um evento `report_emergency`:

```elixir
def handle_in("report_emergency", payload, socket) do
  MyApp.Emergencies.report(payload) # ou o que for
  {:reply, :ok, socket}
end
```

...um cliente poderia enviar:

```json
[null, "3", "miami:weather", "report_emergency", {"category": "sharknado"}]
```
