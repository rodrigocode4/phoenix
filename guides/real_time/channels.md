# Canais

> **Requisito**: Este guia pressupõe que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

Canais são uma parte empolgante do Phoenix que permitem comunicação em tempo real com e entre milhões de clientes conectados.

Alguns casos de uso possíveis incluem:

- Salas de chat e APIs para aplicativos de mensagens
- Notícias de última hora, como "um gol foi marcado" ou "um terremoto está chegando"
- Rastreamento de trens, caminhões ou participantes de corridas em um mapa
- Eventos em jogos multiplayer
- Monitoramento de sensores e controle de luzes
- Notificando um navegador que o CSS ou JavaScript de uma página mudou (isso é útil no desenvolvimento)

Conceitualmente, os Canais são bastante simples.

Primeiro, os clientes se conectam ao servidor usando algum transporte, como WebSocket. Uma vez conectados, eles se juntam a um ou mais tópicos. Por exemplo, para interagir com uma sala de chat pública, os clientes podem se juntar a um tópico chamado `public_chat`, e para receber atualizações de um produto com ID 7, eles podem precisar se juntar a um tópico chamado `product_updates:7`.

Os clientes podem enviar mensagens para os tópicos aos quais se juntaram e também podem receber mensagens deles. No sentido inverso, os servidores de Canais recebem mensagens de seus clientes conectados e também podem enviar mensagens para eles.

Os servidores são capazes de transmitir mensagens para todos os clientes inscritos em um determinado tópico. Isso é ilustrado no seguinte diagrama:

```plaintext
                                                                          +-----------------+
                                                            +--Tópico X-->| Cliente Móvel   |
                                                            |             +-----------------+
                                  +----------------------+  |
+-------------------+             |                      |  |             +-----------------+
| Cliente Navegador |--Tópico X-->| Servidor(es) Phoenix |--+--Tópico X-->| Cliente Desktop |
+-------------------+             |                      |  |             +-----------------+
                                  +----------------------+  |
                                                            |             +-----------------+
                                                            +--Tópico X-->| Cliente IoT     |
                                                                          +-----------------+
```

As transmissões funcionam mesmo se a aplicação estiver em execução em vários nós/computadores. Ou seja, se dois clientes tiverem seu socket conectado a diferentes nós da aplicação e estiverem inscritos no mesmo tópico `T`, ambos receberão mensagens transmitidas para `T`. Isso é possível graças a um mecanismo interno de PubSub.

Os Canais podem suportar qualquer tipo de cliente: um navegador, aplicativo nativo, smartwatch, dispositivo integrado ou qualquer outra coisa que possa se conectar a uma rede.
Tudo o que o cliente precisa é de uma biblioteca adequada; veja a seção [Bibliotecas de Cliente](#bibliotecas-de-cliente) abaixo.
Cada biblioteca cliente se comunica usando um dos "transportes" que os Canais entendem.
Atualmente, isso é WebSockets ou long polling, mas outros transportes podem ser adicionados no futuro.

Ao contrário das conexões HTTP sem estado, os Canais suportam conexões de longa duração, cada uma apoiada por um processo BEAM leve, trabalhando em paralelo e mantendo seu próprio estado.

Essa arquitetura escala bem; Phoenix Channels [pode suportar milhões de assinantes com latência razoável em uma única máquina](https://phoenixframework.org/blog/the-road-to-2-million-websocket-connections), passando centenas de milhares de mensagens por segundo.
E essa capacidade pode ser multiplicada adicionando mais nós ao cluster.

## As Partes em Movimento

Embora os Canais sejam simples de usar do ponto de vista do cliente, há vários componentes envolvidos no roteamento de mensagens para clientes em um cluster de servidores.
Vamos dar uma olhada neles.

### Visão Geral

Para começar a se comunicar, um cliente se conecta a um nó (um servidor Phoenix) usando um transporte (por exemplo, Websockets ou long polling) e se junta a um ou mais canais usando essa única conexão de rede.
Um processo servidor de canal leve é criado por cliente, por tópico. Cada canal mantém o `%Phoenix.Socket{}` e pode manter qualquer estado necessário dentro de seu `socket.assigns`.

Uma vez estabelecida a conexão, cada mensagem recebida de um cliente é roteada, com base em seu tópico, para o servidor de canal correto.
Se o servidor de canal pedir para transmitir uma mensagem, essa mensagem é enviada para o PubSub local, que a envia para quaisquer clientes conectados ao mesmo servidor e inscritos nesse tópico.

Se houver outros nós no cluster, o PubSub local também encaminha a mensagem para seus PubSubs, que a enviam para seus próprios assinantes.
Como apenas uma mensagem precisa ser enviada por nó adicional, o custo de desempenho de adicionar nós é insignificante, enquanto cada novo nó suporta muito mais assinantes.

O fluxo de mensagens é mais ou menos assim:

```plaintext
                                    Rota do   +-----------------------------+      +--------+
                                     Canal    | Cliente Enviando, Tópico 1  |      | PubSub |
                                 +----------->|     Canal.Servidor          |----->| Local  |--+
+------------------+             |            +-----------------------------+      +--------+  |
| Cliente Enviando |-Transporte--+                                                      |      |
+------------------+                          +-----------------------------+           |      |
                                              | Cliente Enviando, Tópico 2  |           |      |
                                              |     Canal.Servidor          |           |      |
                                              +-----------------------------+           |      |
                                                                                        |      |
                                              +-----------------------------+           |      |
+-------------------+                         | Cliente Navegador, Tópico 1 |           |      |
| Cliente Navegador |<-------Transporte-------|     Canal.Servidor          |<----------+      |
+-------------------+                         +-----------------------------+                  |
                                                                                               |
                                                                                               |
                                                                                               |
                                              +-----------------------------+                  |
+------------------+                          |  Cliente Telefone, Tópico 1 |                  |
| Cliente Telefone |<-------Transporte--------|     Canal.Servidor          |<-+               |
+------------------+                          +-----------------------------+  |   +--------+  |
                                                                               |   | PubSub |  |
                                              +-----------------------------+  +---| Remoto |<-+
+------------------+                          |  Cliente Relógio, Tópico 1  |  |   +--------+  |
| Cliente Relógio  |<-------Transporte--------|     Canal.Servidor          |<-+               |
+------------------+                          +-----------------------------+                  |
                                                                                               |
                                                                                               |
                                              +-----------------------------+      +--------+  |
+------------------+                          |   Cliente IoT, Tópico 1     |      | PubSub |  |
| Cliente IoT      |<-------Transporte--------|     Canal.Servidor          |<-----| Remoto |<-+
+------------------+                          +-----------------------------+      +--------+
```

### Endpoint

No módulo `Endpoint` do seu aplicativo Phoenix, uma declaração `socket` especifica qual manipulador de socket receberá conexões em uma determinada URL.

```elixir
socket "/socket", HelloWeb.UserSocket,
  websocket: true,
  longpoll: false
```

O Phoenix vem com dois transportes padrão: websocket e longpoll. Você pode configurá-los diretamente através da declaração `socket`.

### Manipuladores de Socket

No lado do cliente, você estabelecerá uma conexão de socket para a rota acima:

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
```

No servidor, o Phoenix invocará `HelloWeb.UserSocket.connect/2`, passando seus parâmetros e o estado inicial do socket. Dentro do socket, você pode autenticar e identificar uma conexão de socket e definir atribuições padrão do socket. O socket também é onde você define suas rotas de canal.

### Rotas de Canal

As rotas de canal correspondem à string do tópico e enviam solicitações correspondentes para o módulo Channel fornecido.

O caractere estrela `*` atua como um curinga, então no exemplo de rota a seguir, solicitações para `room:lobby` e `room:123` seriam ambas enviadas para o `RoomChannel`. No seu `UserSocket`, você teria:

```elixir
channel "room:*", HelloWeb.RoomChannel
```

### Canais

Os Canais lidam com eventos dos clientes, então são semelhantes aos Controllers, mas há duas diferenças principais. Os eventos do Canal podem ir em ambas as direções - de entrada e saída. As conexões do Canal também persistem além de um único ciclo de solicitação/resposta. Os Canais são o nível mais alto de abstração para componentes de comunicação em tempo real no Phoenix.

Cada Canal implementará uma ou mais cláusulas de cada uma dessas quatro funções de callback - `join/3`, `terminate/2`, `handle_in/3` e `handle_out/3`.

### Tópicos

Tópicos são identificadores de string - nomes que as várias camadas usam para garantir que as mensagens acabem no lugar certo. Como vimos acima, os tópicos podem usar curingas. Isso permite uma convenção útil de `"tópico:subtópico"`. Frequentemente, você compõe tópicos usando IDs de registros da sua camada de aplicação, como `"users:123"`.

### Mensagens

O módulo `Phoenix.Socket.Message` define uma struct com as seguintes chaves que denota uma mensagem válida. Da [documentação do Phoenix.Socket.Message](https://hexdocs.pm/phoenix/Phoenix.Socket.Message.html).

- `topic` - O tópico de string ou par de namespace `"tópico:subtópico"`, como `"messages"` ou `"messages:123"`
- `event` - O nome do evento em string, por exemplo `"phx_join"`
- `payload` - A carga útil da mensagem
- `ref` - A string de referência única

### PubSub

O PubSub é fornecido pelo módulo `Phoenix.PubSub`. Partes interessadas podem receber eventos se inscrevendo em tópicos. Outros processos podem transmitir eventos para determinados tópicos.

Isso é útil para transmitir mensagens em canal e também para o desenvolvimento de aplicativos em geral. Por exemplo, permitindo que todas as [views ao vivo](https://github.com/phoenixframework/phoenix_live_view) conectadas saibam que um novo comentário foi adicionado a uma postagem.

O sistema PubSub cuida de obter mensagens de um nó para outro para que possam ser enviadas a todos os assinantes do cluster.
Por padrão, isso é feito usando [Phoenix.PubSub.PG2](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.PG2.html), que usa mensagens BEAM nativas.

Se seu ambiente de implantação não suporta Elixir distribuído ou comunicação direta entre servidores, o Phoenix também vem com um [Adaptador Redis](https://hexdocs.pm/phoenix_pubsub_redis/Phoenix.PubSub.Redis.html) que usa o Redis para trocar dados PubSub. Por favor, veja a [documentação do Phoenix.PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) para mais informações.

### Bibliotecas de Cliente

Qualquer dispositivo em rede pode se conectar aos Phoenix Channels, desde que tenha uma biblioteca cliente.
As seguintes bibliotecas existem hoje, e novas são sempre bem-vindas; para escrever a sua própria, veja nosso guia [Escrevendo um Cliente de Canais](writing_a_channels_client.md).

#### Oficial

O Phoenix vem com um cliente JavaScript que está disponível ao gerar um novo projeto Phoenix. A documentação para o módulo JavaScript está disponível em [https://hexdocs.pm/phoenix/js/](https://hexdocs.pm/phoenix/js/); o código está em [múltiplos arquivos js](https://github.com/phoenixframework/phoenix/blob/main/assets/js/phoenix/).

#### Terceiros

+ Swift (iOS)
  - [SwiftPhoenix](https://github.com/davidstump/SwiftPhoenixClient)
+ Java (Android)
  - [JavaPhoenixChannels](https://github.com/eoinsha/JavaPhoenixChannels)
+ Kotlin (Android)
  - [JavaPhoenixClient](https://github.com/dsrees/JavaPhoenixClient)
+ C#
  - [PhoenixSharp](https://github.com/Mazyod/PhoenixSharp)
+ Elixir
  - [phoenix_gen_socket_client](https://github.com/Aircloak/phoenix_gen_socket_client)
  - [slipstream](https://hexdocs.pm/slipstream/Slipstream.html)
+ GDScript (Motor de Jogo Godot)
  - [GodotPhoenixChannels](https://github.com/alfredbaudisch/GodotPhoenixChannels)

## Juntando tudo

Vamos unir todas essas ideias construindo um aplicativo de chat simples. Certifique-se de que [você criou uma nova aplicação Phoenix](https://hexdocs.pm/phoenix/up_and_running.html) e agora estamos prontos para gerar o `UserSocket`.

### Gerando um socket

Vamos invocar o gerador de socket para começar:

```console
$ mix phx.gen.socket User
```

Ele criará dois arquivos, o código do cliente em `assets/js/user_socket.js` e a contraparte do servidor em `lib/hello_web/channels/user_socket.ex`. Após a execução, o gerador também pedirá para adicionar a seguinte linha a `lib/hello_web/endpoint.ex`:

```elixir
defmodule HelloWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello

  socket "/socket", HelloWeb.UserSocket,
    websocket: true,
    longpoll: false

  ...
end
```

O gerador também nos pede para importar o código do cliente, faremos isso mais tarde.

Em seguida, vamos configurar nosso socket para garantir que as mensagens sejam roteadas para o canal correto. Para isso, vamos descomentar a definição do canal `"room:*"`:

```elixir
defmodule HelloWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "room:*", HelloWeb.RoomChannel
  ...
```

Agora, sempre que um cliente enviar uma mensagem cujo tópico começa com `"room:"`, ela será roteada para nosso RoomChannel. Em seguida, definiremos um módulo `HelloWeb.RoomChannel` para gerenciar nossas mensagens de sala de chat.

### Juntando-se aos Canais

A primeira prioridade de seus canais é autorizar os clientes a se juntarem a um determinado tópico. Para autorização, devemos implementar `join/3` em `lib/hello_web/channels/room_channel.ex`.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
```

Para nosso aplicativo de chat, permitiremos que qualquer pessoa se junte ao tópico `"room:lobby"`, mas qualquer outra sala será considerada privada e autorização especial, digamos de um banco de dados, será necessária.
(Não vamos nos preocupar com salas de chat privadas para este exercício, mas fique à vontade para explorar depois que terminarmos.)

Com nosso canal em vigor, vamos fazer o cliente e o servidor conversarem.

O arquivo `assets/js/user_socket.js` gerado define um cliente simples baseado na implementação de socket que vem com o Phoenix.

Podemos usar essa biblioteca para nos conectar ao nosso socket e nos juntar ao nosso canal, só precisamos definir o nome da nossa sala como `"room:lobby"` nesse arquivo.

```javascript
// assets/js/user_socket.js
// ...
socket.connect()

// Agora que você está conectado, você pode se juntar a canais com um tópico:
let channel = socket.channel("room:lobby", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

Depois disso, precisamos garantir que `assets/js/user_socket.js` seja importado para nosso arquivo JavaScript da aplicação. Para fazer isso, descomente esta linha em `assets/js/app.js`.

```javascript
// ...
import "./user_socket.js"
```

Salve o arquivo e seu navegador deve atualizar automaticamente, graças ao recarregador ao vivo do Phoenix. Se tudo funcionou, devemos ver "Joined successfully" no console JavaScript do navegador. Nosso cliente e servidor agora estão conversando por uma conexão persistente. Agora vamos torná-lo útil habilitando o chat.

Em `lib/hello_web/controllers/page_html/home.html.heex`, substituiremos o código existente por um container para conter nossas mensagens de chat e um campo de entrada para enviá-las:

```heex
<div id="messages" role="log" aria-live="polite"></div>
<input id="chat-input" type="text">
```

Agora vamos adicionar alguns ouvintes de eventos para `assets/js/user_socket.js`:

```javascript
// ...
let channel           = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")

chatInput.addEventListener("keypress", event => {
  if(event.key === 'Enter'){
    channel.push("new_msg", {body: chatInput.value})
    chatInput.value = ""
  }
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

Tudo o que tivemos que fazer é detectar que Enter foi pressionado e então `push` um evento pelo canal com o corpo da mensagem. Nomeamos o evento `"new_msg"`. Com isso em vigor, vamos lidar com a outra parte de um aplicativo de chat, onde ouvimos novas mensagens e as adicionamos ao nosso container de mensagens.

```javascript
// ...
let channel           = socket.channel("room:lobby", {})
let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")

chatInput.addEventListener("keypress", event => {
  if(event.key === 'Enter'){
    channel.push("new_msg", {body: chatInput.value})
    chatInput.value = ""
  }
})

channel.on("new_msg", payload => {
  let messageItem = document.createElement("p")
  messageItem.innerText = `[${Date()}] ${payload.body}`
  messagesContainer.appendChild(messageItem)
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

Ouvimos o evento `"new_msg"` usando `channel.on`, e então anexamos o corpo da mensagem ao DOM. Agora vamos lidar com os eventos de entrada e saída no servidor para completar o quadro.

### Eventos de Entrada

Lidamos com eventos de entrada com `handle_in/3`. Podemos fazer pattern matching nos nomes dos eventos, como `"new_msg"`, e então pegar a carga útil que o cliente passou pelo canal. Para nosso aplicativo de chat, simplesmente precisamos notificar todos os outros assinantes de `room:lobby` sobre a nova mensagem com `broadcast!/3`.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body})
    {:noreply, socket}
  end
end
```

`broadcast!/3` notificará todos os clientes conectados neste tópico do `socket` e invocará seus callbacks `handle_out/3`. `handle_out/3` não é um callback obrigatório, mas nos permite personalizar e filtrar transmissões antes que elas cheguem a cada cliente. Por padrão, `handle_out/3` é implementado para nós e simplesmente envia a mensagem para o cliente. Conectar-se a eventos de saída permite uma poderosa personalização e filtragem de mensagens. Vamos ver como.

### Interceptando Eventos de Saída

Não implementaremos isso para nossa aplicação, mas imagine que nosso aplicativo de chat permitisse aos usuários ignorar mensagens sobre novos usuários se juntando a uma sala. Poderíamos implementar esse comportamento assim, onde explicitamente dizemos ao Phoenix qual evento de saída queremos interceptar e então definimos um callback `handle_out/3` para esses eventos. (É claro, isso pressupõe que temos um contexto `Accounts` com uma função `ignoring_user?/2`, e que passamos um usuário através do mapa `assigns`). É importante notar que o callback `handle_out/3` será chamado para cada destinatário de uma mensagem, então operações mais caras como acessar o banco de dados devem ser consideradas cuidadosamente antes de serem incluídas em `handle_out/3`.

```elixir
intercept ["user_joined"]

def handle_out("user_joined", msg, socket) do
  if Accounts.ignoring_user?(socket.assigns[:user], msg.user_id) do
    {:noreply, socket}
  else
    push(socket, "user_joined", msg)
    {:noreply, socket}
  end
end
```

É tudo o que existe para nosso aplicativo de chat básico. Abra múltiplas abas do navegador e você deve ver suas mensagens sendo enviadas e transmitidas para todas as janelas!

## Usando Autenticação por Token

Quando nos conectamos, muitas vezes precisamos autenticar o cliente. Felizmente, este é um processo de 4 etapas com [Phoenix.Token](https://hexdocs.pm/phoenix/Phoenix.Token.html).

### Etapa 1 - Atribuir um Token na Conexão

Vamos dizer que temos um plug de autenticação em nosso aplicativo chamado `OurAuth`. Quando `OurAuth` autentica um usuário, ele define um valor para a chave `:current_user` em `conn.assigns`. Como o `current_user` existe, podemos simplesmente atribuir o token do usuário na conexão para uso no layout. Podemos empacotar esse comportamento em um plug de função privada, `put_user_token/2`. Isso também poderia ser colocado em seu próprio módulo. Para fazer isso funcionar, basta adicionar `OurAuth` e `put_user_token/2` ao pipeline do navegador.

```elixir
pipeline :browser do
  ...
  plug OurAuth
  plug :put_user_token
end

defp put_user_token(conn, _) do
  if current_user = conn.assigns[:current_user] do
    token = Phoenix.Token.sign(conn, "user socket", current_user.id)
    assign(conn, :user_token, token)
  else
    conn
  end
end
```

Agora nosso `conn.assigns` contém o `current_user` e `user_token`.

### Etapa 2 - Passar o Token para o JavaScript

Em seguida, precisamos passar esse token para o JavaScript. Podemos fazer isso dentro de uma tag de script em `lib/hello_web/components/layouts/app.html.heex` logo acima do script app.js, da seguinte forma:

```heex
<script>window.userToken = "<%= assigns[:user_token] %>";</script>
<script src={~p"/assets/app.js"}></script>
```

### Etapa 3 - Passar o Token para o Construtor do Socket e Verificar

Também precisamos passar os `:params` para o construtor do socket e verificar o token do usuário na função `connect/3`. Para fazer isso, edite `lib/hello_web/channels/user_socket.ex`, da seguinte forma:

```elixir
def connect(%{"token" => token}, socket, _connect_info) do
  # max_age: 1209600 é equivalente a duas semanas em segundos
  case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
    {:ok, user_id} ->
      {:ok, assign(socket, :current_user, user_id)}
    {:error, reason} ->
      :error
  end
end
```

Em nosso JavaScript, podemos usar o token definido anteriormente ao construir o Socket:

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
```

Usamos `Phoenix.Token.verify/4` para verificar o token do usuário fornecido pelo cliente. `Phoenix.Token.verify/4` retorna ou `{:ok, user_id}` ou `{:error, reason}`. Podemos fazer pattern matching nesse retorno em uma declaração `case`. Com um token verificado, definimos o id do usuário como o valor para `:current_user` no socket. Caso contrário, retornamos `:error`.

### Etapa 4 - Conectar ao socket em JavaScript

Com a autenticação configurada, podemos nos conectar a sockets e canais a partir do JavaScript.

```javascript
let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()
```

Agora que estamos conectados, podemos nos juntar a canais com um tópico:

```javascript
let channel = socket.channel("topic:subtopic", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
```

Observe que a autenticação por token é preferível, uma vez que é agnóstica em relação ao transporte e adequada para conexões de longa duração como canais, em contraste com o uso de sessões ou outras abordagens de autenticação.

## Tolerância a Falhas e Garantias de Confiabilidade

Servidores reiniciam, redes se dividem e clientes perdem conectividade. Para projetar sistemas robustos, precisamos entender como o Phoenix responde a esses eventos e quais garantias ele oferece.

### Lidando com Reconexão

Os clientes se inscrevem em tópicos, e o Phoenix armazena essas inscrições em uma tabela ETS em memória. Se um canal falhar, os clientes precisarão se reconectar aos tópicos aos quais haviam se inscrito anteriormente. Felizmente, o cliente JavaScript do Phoenix sabe como fazer isso. O servidor notificará todos os clientes da falha. Isso acionará o callback `Channel.onError` de cada cliente. Os clientes tentarão se reconectar ao servidor usando uma estratégia de recuo exponencial. Uma vez reconectados, eles tentarão se juntar novamente aos tópicos aos quais haviam se inscrito anteriormente. Se forem bem-sucedidos, eles começarão a receber mensagens desses tópicos como antes.

### Reenviando Mensagens do Cliente

Os clientes de canal enfileiram mensagens de saída em um `PushBuffer` e as enviam para o servidor quando há uma conexão. Se nenhuma conexão estiver disponível, o cliente mantém as mensagens até que possa estabelecer uma nova conexão. Sem conexão, o cliente manterá as mensagens na memória até estabelecer uma conexão, ou até receber um evento de `timeout`. O timeout padrão é definido como 5000 milissegundos. O cliente não persistirá as mensagens no armazenamento local do navegador, então se a aba do navegador fechar, as mensagens serão perdidas.

### Reenviando Mensagens do Servidor

O Phoenix usa uma estratégia de no máximo uma vez ao enviar mensagens para os clientes. Se o cliente estiver offline e perder a mensagem, o Phoenix não a reenviará. O Phoenix não persiste mensagens no servidor. Se o servidor reiniciar, mensagens não enviadas serão perdidas. Se nossa aplicação precisa de garantias mais fortes em torno da entrega de mensagens, precisaremos escrever esse código nós mesmos. Abordagens comuns envolvem persistir mensagens no servidor e ter clientes solicitando mensagens perdidas. Para um exemplo, veja o treinamento de Phoenix do Chris McCord: [código do cliente](https://github.com/chrismccord/elixirconf_training/blob/master/web/static/js/app.js#L38-L39) e [código do servidor](https://github.com/chrismccord/elixirconf_training/blob/master/web/channels/document_channel.ex#L13-L19).

## Aplicação de Exemplo

Para ver um exemplo da aplicação que acabamos de construir, confira o projeto [phoenix_chat_example](https://github.com/chrismccord/phoenix_chat_example).
