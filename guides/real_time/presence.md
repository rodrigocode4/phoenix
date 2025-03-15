# Presença

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia de Canais](channels.html).

Phoenix Presence é um recurso que permite registrar informações de processos em um tópico e replicá-las de forma transparente em um cluster. É uma combinação de uma biblioteca do lado do servidor e do cliente, o que torna simples sua implementação. Um caso de uso simples seria mostrar quais usuários estão atualmente online em uma aplicação.

Phoenix Presence é especial por várias razões. Não possui ponto único de falha, não possui fonte única de verdade, depende inteiramente da biblioteca padrão sem dependências operacionais e se autocura.

## Configuração

Vamos usar o Presence para rastrear quais usuários estão conectados no servidor e enviar atualizações para o cliente à medida que os usuários entram e saem. Entregaremos essas atualizações via Phoenix Channels. Portanto, vamos criar um `RoomChannel`, como fizemos nos guias de canais:

```console
$ mix phx.gen.channel Room
```

Siga os passos após o gerador e você estará pronto para começar a rastrear a presença.

## O gerador de Presence

Para começar com o Presence, primeiro precisamos gerar um módulo de presença. Podemos fazer isso com a tarefa `mix phx.gen.presence`:

```console
$ mix phx.gen.presence
* creating lib/hello_web/channels/presence.ex

Adicione seu novo módulo à sua árvore de supervisão,
em lib/hello/application.ex:

    children = [
      ...
      HelloWeb.Presence,
    ]

Você está pronto! Veja a documentação do Phoenix.Presence para mais detalhes:
https://hexdocs.pm/phoenix/Phoenix.Presence.html
```

Se abrirmos o arquivo `lib/hello_web/channels/presence.ex`, veremos a seguinte linha:

```elixir
use Phoenix.Presence,
  otp_app: :hello,
  pubsub_server: Hello.PubSub
```

Isso configura o módulo para presença, definindo as funções que precisamos para rastrear presenças. Como mencionado na tarefa do gerador, devemos adicionar este módulo à nossa árvore de supervisão em
`application.ex`:

```elixir
children = [
  ...
  HelloWeb.Presence,
]
```

## Uso com Canais e JavaScript

Em seguida, criaremos o canal pelo qual comunicaremos a presença. Depois que um usuário se juntar, podemos enviar a lista de presenças pelo canal e depois rastrear a conexão. Também podemos fornecer um mapa de informações adicionais para rastrear.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel
  alias HelloWeb.Presence

  def join("room:lobby", %{"name" => name}, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :name, name)}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.name, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
```

Finalmente, podemos usar a biblioteca de Presence do lado do cliente incluída em `phoenix.js` para gerenciar o estado e as diferenças de presença que vêm pelo socket. Ela escuta os eventos `"presence_state"` e `"presence_diff"` e fornece um callback simples para você lidar com os eventos à medida que acontecem, com o callback `onSync`.

O callback `onSync` permite que você reaja facilmente às mudanças de estado de presença, o que geralmente resulta em uma nova renderização de uma lista atualizada de usuários ativos. Você pode usar o método `list` para formatar e retornar cada presença individual com base nas necessidades de sua aplicação.

Para iterar sobre os usuários, usamos a função `presences.list()` que aceita um callback. O callback será chamado para cada item de presença com 2 argumentos, o id de presença e uma lista de metas (uma para cada presença para esse id de presença). Usamos isso para exibir os usuários e o número de dispositivos com os quais eles estão online.

Podemos ver a presença funcionando adicionando o seguinte a `assets/js/app.js`:

```javascript
import {Socket, Presence} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})
let channel = socket.channel("room:lobby", {name: window.location.search.split("=")[1]})
let presence = new Presence(channel)

function renderOnlineUsers(presence) {
  let response = ""

  presence.list((id, {metas: [first, ...rest]}) => {
    let count = rest.length + 1
    response += `<br>${id} (count: ${count})</br>`
  })

  document.querySelector("main").innerHTML = response
}

socket.connect()

presence.onSync(() => renderOnlineUsers(presence))

channel.join()
```

Podemos garantir que isso esteja funcionando abrindo 3 abas do navegador. Se navegarmos para <http://localhost:4000/?name=Alice> em duas abas do navegador e <http://localhost:4000/?name=Bob>, então deveríamos ver:

```plaintext
Alice (count: 2)
Bob (count: 1)
```

Se fecharmos uma das abas da Alice, então a contagem deve diminuir para 1. Se fecharmos outra aba, o usuário deve desaparecer completamente da lista.

### Tornando seguro

Em nossa implementação inicial, estamos passando o nome do usuário como parte da URL. No entanto, em muitos sistemas, você deseja permitir que apenas usuários logados acessem a funcionalidade de presença. Para fazer isso, você deve configurar a autenticação por token, [conforme detalhado na seção de autenticação por token do guia de canais](channels.html#using-token-authentication).

Com a autenticação por token, você deve acessar `socket.assigns.user_id`, definido em `UserSocket`, em vez de `socket.assigns.name` definido a partir de parâmetros.

## Uso com LiveView

Embora o Phoenix venha com uma API JavaScript para lidar com a presença, também é possível estender o módulo `HelloWeb.Presence` para suportar [LiveView](https://hexdocs.pm/phoenix_live_view).

Uma coisa a ter em mente ao lidar com LiveView é que cada LiveView é um processo com estado, então se mantivermos o estado de presença no LiveView, cada processo LiveView conterá a lista completa de usuários online na memória. Em vez disso, podemos rastrear os usuários online dentro do processo `Presence` e passar eventos separados para o LiveView, que pode usar um stream para atualizar a lista online.

Para começar, precisamos atualizar o arquivo `lib/hello_web/channels/presence.ex` para adicionar alguns callbacks opcionais ao módulo `HelloWeb.Presence`.

Primeiro, adicionamos o callback `init/1`. Isso nos permite rastrear o estado de presença dentro do processo.

```elixir
  def init(_opts) do
    {:ok, %{}}
  end
```

O módulo de presença também permite um callback `fetch/2`, isso permite que os dados obtidos da presença sejam modificados, permitindo que definamos a forma da resposta. Neste caso, estamos adicionando um `id` e um mapa `user`.

```elixir
  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      # o usuário pode ser populado aqui a partir do banco de dados; aqui populamos
      # o nome para fins de demonstração
      {key, %{metas: [meta | metas], id: meta.id, user: %{name: meta.id}}}
    end
  end
```

A última coisa a adicionar é o callback `handle_metas/4`. Este callback atualiza o estado que rastreamos em `HelloWeb.Presence` com base nas saídas e entradas dos usuários.

```elixir
  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{id: user_id, user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(Hello.PubSub, "proxy:#{topic}", msg)
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.local_broadcast(Hello.PubSub, "proxy:#{topic}", msg)
    end

    {:ok, state}
  end
```

Você pode ver que estamos transmitindo eventos para as entradas e saídas. Estes serão ouvidos pelo processo LiveView. Você também verá que usamos um canal "proxy" ao transmitir as entradas e saídas. Isso porque não queremos que nosso processo LiveView receba os eventos de presença diretamente. Podemos adicionar algumas funções auxiliares para que esse detalhe específico de implementação seja abstraído do módulo LiveView.

```elixir
  def list_online_users(), do: list("online_users") |> Enum.map(fn {_id, presence} -> presence end)

  def track_user(name, params), do: track(self(), "online_users", name, params)

  def subscribe(), do: Phoenix.PubSub.subscribe(Hello.PubSub, "proxy:online_users")
```

Agora que temos nosso módulo de presença configurado e transmitindo eventos, podemos criar um LiveView. Crie um novo arquivo `lib/hello_web/live/online/index.ex` com o seguinte conteúdo:

```elixir
defmodule HelloWeb.OnlineLive do
  use HelloWeb, :live_view

  def mount(params, _session, socket) do
    socket = stream(socket, :presences, [])
    socket =
    if connected?(socket) do
      HelloWeb.Presence.track_user(params["name"], %{id: params["name"]})
      HelloWeb.Presence.subscribe()
      stream(socket, :presences, HelloWeb.Presence.list_online_users())
    else
       socket
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ul id="online_users" phx-update="stream">
      <li :for={{dom_id, %{id: id, metas: metas}} <- @streams.presences} id={dom_id}>{id} ({length(metas)})</li>
    </ul>
    """
  end

  def handle_info({HelloWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({HelloWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end
end
```

Se adicionarmos esta rota ao `lib/hello_web/router.ex`:

```elixir
    live "/online/:name", OnlineLive, :index
```

Então podemos navegar para http://localhost:4000/online/Alice em uma aba e http://localhost:4000/online/Bob em outra, você verá que as presenças são rastreadas, junto com o número de presenças por usuário. Abrir e fechar abas com vários usuários atualizará a lista de presença em tempo real.
