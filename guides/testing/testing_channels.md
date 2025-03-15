# Testando Canais

> **Requisito**: Este guia pressupõe que você tenha lido os [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia pressupõe que você tenha lido o [Guia de Introdução a Testes](testing.html).

> **Requisito**: Este guia pressupõe que você tenha lido o [Guia de Canais](channels.html).

No guia de Canais, vimos que um "Canal" é um sistema em camadas com diferentes componentes. Sendo assim, haverá casos em que escrever testes unitários para nossas funções de Canal pode não ser o suficiente. Podemos querer verificar se suas diferentes partes estão funcionando juntas como esperamos. Este teste de integração nos asseguraria que definimos corretamente nossa rota de canal, o módulo do canal e seus callbacks; e que as camadas de nível inferior, como o PubSub e Transport, estão configuradas corretamente e funcionando conforme o esperado.

## Gerando canais

À medida que avançamos neste guia, seria útil ter um exemplo concreto para trabalharmos. O Phoenix vem com uma tarefa Mix para gerar um canal básico e seus testes. Esses arquivos gerados servem como uma boa referência para escrever canais e seus testes correspondentes. Vamos em frente e gerar nosso Canal:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs
* creating test/support/channel_case.ex

The default socket handler - HelloWeb.UserSocket - was not found.

Do you want to create it? [Yn]  
* creating lib/hello_web/channels/user_socket.ex
* creating assets/js/user_socket.js

Add the socket handler to your `lib/hello_web/endpoint.ex`, for example:

    socket "/socket", HelloWeb.UserSocket,
      websocket: true,
      longpoll: false

For the front-end integration, you need to import the `user_socket.js`
in your `assets/js/app.js` file:

    import "./user_socket.js"
```

Isso cria um canal, seu teste e nos instrui a adicionar uma rota de canal em `lib/hello_web/channels/user_socket.ex`. É importante adicionar a rota do canal, caso contrário, nosso canal não funcionará de forma alguma!

## O ChannelCase

Abra `test/hello_web/channels/room_channel_test.exs` e você encontrará isso:

```elixir
defmodule HelloWeb.RoomChannelTest do
  use HelloWeb.ChannelCase
```

Semelhante ao `ConnCase` e ao `DataCase`, agora temos um `ChannelCase`. Todos os três foram gerados para nós quando iniciamos nossa aplicação Phoenix. Vamos dar uma olhada nele. Abra `test/support/channel_case.ex`:

```elixir
defmodule HelloWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import HelloWeb.ChannelCase

      # The default endpoint for testing
      @endpoint HelloWeb.Endpoint
    end
  end

  setup _tags do
    Hello.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

É muito direto. Ele configura um template de caso que importa todo o `Phoenix.ChannelTest` ao usar. No bloco `setup`, ele inicia o SQL Sandbox, que discutimos no [guia de Testes de contextos](testing_contexts.html).

## Inscrevendo-se e entrando

Agora que sabemos que o Phoenix nos fornece um Caso de Teste personalizado apenas para canais e o que ele fornece, podemos seguir em frente para entender o resto de `test/hello_web/channels/room_channel_test.exs`.

Primeiro, temos o bloco de configuração:

```elixir
setup do
  {:ok, _, socket} =
    HelloWeb.UserSocket
    |> socket("user_id", %{some: :assign})
    |> subscribe_and_join(HelloWeb.RoomChannel, "room:lobby")

  %{socket: socket}
end
```

O bloco `setup` configura um `Phoenix.Socket` baseado no módulo `UserSocket`, que você pode encontrar em `lib/hello_web/channels/user_socket.ex`. Em seguida, ele diz que queremos nos inscrever e entrar no `RoomChannel`, acessível como `"room:lobby"` no `UserSocket`. No final do teste, retornamos o `%{socket: socket}` como metadados, para que possamos reutilizá-lo em cada teste.

Em resumo, `subscribe_and_join/3` emula o cliente entrando em um canal e inscreve o processo de teste no tópico fornecido. Este é um passo necessário, já que os clientes precisam entrar em um canal antes que possam enviar e receber eventos nesse canal.

## Testando uma resposta síncrona

O primeiro bloco de teste em nosso teste de canal gerado parece com:

```elixir
test "ping replies with status ok", %{socket: socket} do
  ref = push(socket, "ping", %{"hello" => "there"})
  assert_reply ref, :ok, %{"hello" => "there"}
end
```

Isso testa o seguinte código em nosso `HelloWeb.RoomChannel`:

```elixir
# Channels can be used in a request/response fashion
# by sending replies to requests from the client
def handle_in("ping", payload, socket) do
  {:reply, {:ok, payload}, socket}
end
```

Como é indicado no comentário acima, vemos que uma `reply` é síncrona, já que imita o padrão de solicitação/resposta com o qual estamos familiarizados no HTTP. Esta resposta síncrona é melhor utilizada quando queremos enviar um evento de volta ao cliente apenas quando terminamos de processar a mensagem no servidor. Por exemplo, quando salvamos algo no banco de dados e então enviamos uma mensagem ao cliente somente depois que isso for concluído.

Na linha `test "ping replies with status ok", %{socket: socket} do`, vemos que temos o mapa `%{socket: socket}`. Isso nos dá acesso ao `socket` no bloco de configuração.

Emulamos o cliente enviando uma mensagem para o canal com `push/3`. Na linha `ref = push(socket, "ping", %{"hello" => "there"})`, enviamos o evento `"ping"` com a carga útil `%{"hello" => "there"}` para o canal. Isso aciona o callback `handle_in/3` que temos para o evento `"ping"` em nosso canal. Observe que armazenamos a `ref` porque precisamos disso na próxima linha para afirmar a resposta. Com `assert_reply ref, :ok, %{"hello" => "there"}`, afirmamos que o servidor envia uma resposta síncrona `:ok, %{"hello" => "there"}`. É assim que verificamos que o callback `handle_in/3` para o `"ping"` foi acionado.

### Testando um Broadcast

É comum receber mensagens do cliente e transmiti-las para todos os inscritos em um tópico atual. Este padrão comum é simples de expressar no Phoenix e é um dos callbacks `handle_in/3` gerados em nosso `HelloWeb.RoomChannel`.

```elixir
def handle_in("shout", payload, socket) do
  broadcast(socket, "shout", payload)
  {:noreply, socket}
end
```

Seu teste correspondente parece com:

```elixir
test "shout broadcasts to room:lobby", %{socket: socket} do
  push(socket, "shout", %{"hello" => "all"})
  assert_broadcast "shout", %{"hello" => "all"}
end
```

Notamos que acessamos o mesmo `socket` que está no bloco de configuração. Que conveniente! Também fazemos o mesmo `push/3` que fizemos no teste de resposta síncrona. Então, enviamos o evento `"shout"` com a carga útil `%{"hello" => "all"}`.

Como o callback `handle_in/3` para o evento `"shout"` apenas transmite o mesmo evento e carga útil, todos os inscritos no `"room:lobby"` devem receber a mensagem. Para verificar isso, fazemos `assert_broadcast "shout", %{"hello" => "all"}`.

**NOTA:** `assert_broadcast/3` testa se a mensagem foi transmitida no sistema PubSub. Para testar se um cliente recebe uma mensagem, use `assert_push/3`.

### Testando um push assíncrono do servidor

O último teste em nosso `HelloWeb.RoomChannelTest` verifica que as transmissões do servidor são enviadas para o cliente. Diferentemente dos testes anteriores discutidos, estamos testando indiretamente se o callback `handle_out/3` do canal é acionado. Por padrão, `handle_out/3` é implementado para nós e simplesmente envia a mensagem para o cliente.

Como o evento `handle_out/3` só é acionado quando chamamos `broadcast/3` do nosso canal, precisaremos emular isso em nosso teste. Fazemos isso chamando `broadcast_from` ou `broadcast_from!`. Ambos servem ao mesmo propósito, com a única diferença de que `broadcast_from!` gera um erro quando a transmissão falha.

A linha `broadcast_from!(socket, "broadcast", %{"some" => "data"})` acionará o callback `handle_out/3`, que envia o mesmo evento e carga útil de volta para o cliente. Para testar isso, fazemos `assert_push "broadcast", %{"some" => "data"}`.

É isso. Agora você está pronto para desenvolver e testar completamente aplicações em tempo real. Para saber mais sobre outras funcionalidades fornecidas ao testar canais, consulte a documentação de [`Phoenix.ChannelTest`](https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html).
