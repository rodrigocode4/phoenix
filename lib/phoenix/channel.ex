defmodule Phoenix.Channel do
@moduledoc ~S"""
  Define um Canal Phoenix.

  Canais fornecem um meio de comunicação bidirecional a partir de clientes que
  se integram com a camada `Phoenix.PubSub` para funcionalidade em tempo quase real.

  Para uma visão conceitual, consulte o [guia de Canais](channels.html).

  ## Tópicos e Callbacks

  Cada vez que você se conecta a um canal, precisa escolher qual tópico específico
  deseja ouvir. O tópico é apenas um identificador, mas por convenção é
  frequentemente composto por duas partes: `"tópico:subtópico"`. Usar a abordagem
  `"tópico:subtópico"` combina bem com o `Phoenix.Socket.channel/3`, permitindo
  corresponder a todos os tópicos que começam com um determinado prefixo usando um
  curinga (o caractere `*`) como o último caractere no padrão do tópico:

      channel "room:*", MyAppWeb.RoomChannel

  Qualquer tópico que chegue ao roteador com o prefixo `"room:"` seria encaminhado
  para `MyAppWeb.RoomChannel` no exemplo acima. Os tópicos também podem ser combinados
  por padrão no callback `join/3` dos seus canais para extrair o padrão de escopo:

      # trata o subtópico especial `"lobby"`
      def join("room:lobby", _payload, socket) do
        {:ok, socket}
      end

      # trata qualquer outro subtópico como o ID da sala, por exemplo `"room:12"`, `"room:34"`
      def join("room:" <> room_id, _payload, socket) do
        {:ok, socket}
      end

  ## Autorização

  Os clientes devem se juntar a um canal para enviar e receber eventos PubSub nesse canal.
  Seus canais devem implementar um callback `join/3` que autoriza o socket
  para o tópico específico. Por exemplo, você poderia verificar se o usuário tem permissão
  para entrar naquela sala específica.

  Para autorizar um socket em `join/3`, retorne `{:ok, socket}`.
  Para recusar a autorização em `join/3`, retorne `{:error, reply}`.

  ## Eventos de Entrada

  Depois que um cliente se conectou com sucesso a um canal, os eventos de entrada do
  cliente são roteados através dos callbacks `handle_in/3` do canal. Dentro desses
  callbacks, você pode executar qualquer ação. Os callbacks de entrada devem retornar o
  `socket` para manter o estado efêmero.

  Normalmente, você encaminhará uma mensagem para todos os ouvintes com
  `broadcast!/3` ou responderá diretamente a um evento do cliente para mensagens
  no estilo de requisição/resposta.

  As cargas úteis de mensagens gerais são recebidas como mapas:

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        ...
        {:reply, :ok, socket}
      end

  Cargas úteis de dados binários são passadas como uma tupla `{:binary, data}`:

      def handle_in("file_chunk", {:binary, chunk}, socket) do
        ...
        {:reply, :ok, socket}
      end

  ## Broadcasts

  Aqui está um exemplo de receber um evento `"new_msg"` de entrada de um cliente,
  e transmitir a mensagem para todos os assinantes do tópico deste socket.

      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        broadcast!(socket, "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

  ## Respostas

  Respostas são úteis para confirmar a mensagem de um cliente ou responder com
  os resultados de uma operação. Uma resposta é enviada apenas para o cliente conectado ao
  processo atual do canal. Nos bastidores, elas incluem a `ref` da mensagem do cliente,
  o que permite ao cliente correlacionar a resposta que recebe
  com a mensagem que enviou.

  Por exemplo, imagine criar um recurso e responder com o registro criado:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          post = Repo.insert!(changeset)
          response = MyAppWeb.PostView.render("show.json", %{post: post})
          {:reply, {:ok, response}, socket}
        else
          response = MyAppWeb.ChangesetView.render("errors.json", %{changeset: changeset})
          {:reply, {:error, response}, socket}
        end
      end

  Ou você pode simplesmente querer confirmar que a operação foi bem-sucedida:

      def handle_in("create:post", attrs, socket) do
        changeset = Post.changeset(%Post{}, attrs)

        if changeset.valid? do
          Repo.insert!(changeset)
          {:reply, :ok, socket}
        else
          {:reply, :error, socket}
        end
      end

  Dados binários também são suportados com respostas através de uma tupla `{:binary, data}`:

      {:reply, {:ok, {:binary, bin}}, socket}

  Se você não quiser enviar uma resposta ao cliente, pode retornar:

      {:noreply, socket}

  Uma situação em que você pode fazer isso é se precisar responder mais tarde; veja
  `reply/2`.

  ## Pushes

  Chamar `push/3` permite que você envie uma mensagem ao cliente que não é uma
  resposta a uma mensagem específica do cliente. Como não é uma resposta, uma mensagem
  enviada por push não contém uma `ref` da mensagem do cliente; não há mensagem prévia
  do cliente à qual relacioná-la.

  Possíveis casos de uso incluem notificar um cliente que:
  - Você salvou automaticamente o documento do usuário
  - O jogo do usuário está terminando em breve
  - As configurações do dispositivo IoT devem ser atualizadas

  Por exemplo, você poderia usar `push/3` para enviar uma mensagem ao cliente em `handle_info/3`
  após receber uma mensagem `PubSub` relevante para ele.

      alias Phoenix.Socket.Broadcast
      def handle_info(%Broadcast{topic: _, event: event, payload: payload}, socket) do
        push(socket, event, payload)
        {:noreply, socket}
      end

  Os dados de push podem ser fornecidos na forma de um mapa ou uma tupla marcada `{:binary, data}`:

      # o cliente pergunta sua classificação atual. a resposta contém isso, e o cliente
      # também recebe um quadro de líderes e uma imagem de distintivo
      def handle_in("current_rank", _, socket) do
        push(socket, "leaders", %{leaders: Game.get_leaders(socket.assigns.game_id)})
        push(socket, "badge", {:binary, File.read!(socket.assigns.badge_path)})
        {:reply, %{val: Game.get_rank(socket.assigns[:user])}, socket}
      end

  Observe que, neste exemplo, `push/3` é chamado a partir de `handle_in/3`; desta forma,
  você pode essencialmente responder N vezes a uma única mensagem do cliente. Veja
  `reply/2` para entender por que isso pode ser desejável.

  ## Interceptando Eventos de Saída

  Quando um evento é transmitido com `broadcast/3`, cada assinante do canal pode
  optar por interceptar o evento e ter seu callback `handle_out/3` acionado.
  Isso permite que a carga útil do evento seja personalizada em uma base socket por socket
  para anexar informações extras, ou filtrar condicionalmente a mensagem de ser
  entregue. Se o evento não for interceptado com `Phoenix.Channel.intercept/1`,
  então a mensagem é enviada diretamente para o cliente:

      intercept ["new_msg", "user_joined"]

      # para cada socket assinando este tópico, anexe um valor `is_editable`
      # para metadados do cliente.
      def handle_out("new_msg", msg, socket) do
        push(socket, "new_msg", Map.merge(msg,
          %{is_editable: User.can_edit_message?(socket.assigns[:user], msg)}
        ))
        {:noreply, socket}
      end

      # não envie eventos `"user_joined"` transmitidos se o usuário deste socket
      # estiver ignorando o usuário que entrou.
      def handle_out("user_joined", msg, socket) do
        unless User.ignoring?(socket.assigns[:user], msg.user_id) do
          push(socket, "user_joined", msg)
        end
        {:noreply, socket}
      end

  ## Transmitindo para um tópico externo

  Em alguns casos, você vai querer transmitir mensagens sem o contexto de
  um `socket`. Isso poderia ser para transmitir de dentro do seu canal para um
  tópico externo, ou transmitir de outro lugar em sua aplicação como um
  controlador ou outro processo. Isso pode ser feito através do seu endpoint:

      # dentro do canal
      def handle_in("new_msg", %{"uid" => uid, "body" => body}, socket) do
        ...
        broadcast_from!(socket, "new_msg", %{uid: uid, body: body})
        MyAppWeb.Endpoint.broadcast_from!(self(), "room:superadmin",
          "new_msg", %{uid: uid, body: body})
        {:noreply, socket}
      end

      # dentro do controlador
      def create(conn, params) do
        ...
        MyAppWeb.Endpoint.broadcast!("room:" <> rid, "new_msg", %{uid: uid, body: body})
        MyAppWeb.Endpoint.broadcast!("room:superadmin", "new_msg", %{uid: uid, body: body})
        redirect(conn, to: "/")
      end

  ## Terminar

  Na terminação, o callback `terminate/2` do canal será invocado com
  o motivo do erro e o socket.

  Se estivermos terminando porque o cliente saiu, o motivo será
  `{:shutdown, :left}`. De forma similar, se estivermos terminando porque a
  conexão do cliente foi fechada, o motivo será `{:shutdown, :closed}`.

  Se qualquer dos callbacks retornar uma tupla `:stop`, isso também
  acionará o término com o motivo fornecido na tupla.

  No entanto, `terminate/2` não será invocado em caso de erros nem em
  caso de saídas. Este é o mesmo comportamento que você encontra em abstrações
  Elixir como `GenServer` e outros. Semelhante ao `GenServer`,
  também seria possível usar `:trap_exit` para garantir que `terminate/2`
  seja invocado. No entanto, essa prática não é encorajada.

  De maneira geral, se você quiser limpar algo, é melhor
  monitorar seu processo de canal e fazer a limpeza a partir de outro processo.
  Todos os callbacks de canal, incluindo `join/3`, são chamados de dentro do
  processo do canal. Portanto, `self()` em qualquer um deles retorna o PID a
  ser monitorado.

  ## Motivos de saída ao parar um canal

  Quando os callbacks do canal retornam uma tupla `:stop`, como:

      {:stop, :shutdown, socket}
      {:stop, {:error, :enoent}, socket}

  o segundo argumento é o motivo da saída, que segue o mesmo comportamento que
  saídas padrão do `GenServer`.

  Você tem três opções para escolher ao encerrar um canal:

    * `:normal` - nestes casos, a saída não será registrada e processos vinculados
      não são encerrados

    * `:shutdown` ou `{:shutdown, term}` - nestes casos, a saída não será
      registrada e processos vinculados são encerrados com o mesmo motivo, a menos que estejam
      capturando saídas

    * qualquer outro termo - nestes casos, a saída será registrada e processos vinculados
      são encerrados com o mesmo motivo, a menos que estejam capturando saídas

  ## Assinando tópicos externos

  Às vezes, você pode precisar programaticamente assinar um socket a tópicos
  externos, além do `socket.topic` interno. Por exemplo,
  imagine que você tem um sistema de licitação onde um cliente remoto define dinamicamente
  preferências em produtos sobre os quais deseja receber notificações de licitação.
  Em vez de exigir um processo de canal único e um tópico por
  preferência, uma abordagem mais eficiente e simples seria assinar um
  único canal para notificações relevantes através do seu endpoint. Por exemplo:

      defmodule MyAppWeb.Endpoint.NotificationChannel do
        use Phoenix.Channel

        def join("notification:" <> user_id, %{"ids" => ids}, socket) do
          topics = for product_id <- ids, do: "product:#{product_id}"

          {:ok, socket
                |> assign(:topics, [])
                |> put_new_topics(topics)}
        end

        def handle_in("watch", %{"product_id" => id}, socket) do
          {:reply, :ok, put_new_topics(socket, ["product:#{id}"])}
        end

        def handle_in("unwatch", %{"product_id" => id}, socket) do
          {:reply, :ok, MyAppWeb.Endpoint.unsubscribe("product:#{id}")}
        end

        defp put_new_topics(socket, topics) do
          Enum.reduce(topics, socket, fn topic, acc ->
            topics = acc.assigns.topics
            if topic in topics do
              acc
            else
              :ok = MyAppWeb.Endpoint.subscribe(topic)
              assign(acc, :topics, [topic | topics])
            end
          end)
        end
      end

  Observação: o chamador deve ser responsável por evitar assinaturas duplicadas.
  Após chamar `subscribe/1` do seu endpoint, o mesmo fluxo se aplica a
  lidar com mensagens Elixir regulares dentro do seu canal. Na maioria das vezes, você
  simplesmente retransmitirá o evento e a carga útil `%Phoenix.Socket.Broadcast{}`:

      alias Phoenix.Socket.Broadcast
      def handle_info(%Broadcast{topic: _, event: event, payload: payload}, socket) do
        push(socket, event, payload)
        {:noreply, socket}
      end

  ## Hibernação

  A partir do Erlang/OTP 20, os canais hibernam automaticamente para economizar memória
  após 15.000 milissegundos de inatividade. Isso pode ser personalizado
  passando a opção `:hibernate_after` para `use Phoenix.Channel`:

      use Phoenix.Channel, hibernate_after: 60_000

  Você também pode definir como `:infinity` para desativá-lo completamente.

  ## Desligamento

  Você pode configurar o comportamento de desligamento de cada canal usado quando sua
  aplicação está sendo encerrada, definindo o valor `:shutdown` no uso:

      use Phoenix.Channel, shutdown: 5_000

  O padrão é 5_000. Os valores suportados são descritos
  na documentação do módulo `Supervisor`.

  ## Logging

  Por padrão, os eventos `"join"` e `"handle_in"` do canal são logados, usando
  os níveis `:info` e `:debug`, respectivamente. Você pode mudar o nível usado
  para cada evento, ou desabilitar logs, por tipo de evento, definindo as opções `:log_join`
  e `:log_handle_in` ao usar `Phoenix.Channel`. Por exemplo, a
  configuração a seguir registra eventos de join como `:info`, mas desativa o logging para
  eventos de entrada:

      use Phoenix.Channel, log_join: :info, log_handle_in: false

  Observe que mudar o nível de um tipo de evento não afeta o que é registrado,
  a menos que você o defina como `false`, isso afeta o nível associado.
  """
  alias Phoenix.Socket
  alias Phoenix.Channel.Server

  @type payload :: map | term | {:binary, binary}
  @type reply :: status :: atom | {status :: atom, response :: payload}
  @type socket_ref ::
          {transport_pid :: Pid, serializer :: module, topic :: binary, ref :: binary,
           join_ref :: binary}

@doc """
  Manipula entradas em canais por `topic`.

  Para autorizar um socket, retorne `{:ok, socket}` ou `{:ok, reply, socket}`. Para
  recusar autorização, retorne `{:error, reason}`.

  Os payloads são serializados antes do envio com o serializador configurado.

  ## Exemplo

      def join("room:lobby", payload, socket) do
        if authorized?(payload) do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

  """
  @callback join(topic :: binary, payload :: payload, socket :: Socket.t()) ::
              {:ok, Socket.t()}
              | {:ok, reply :: payload, Socket.t()}
              | {:error, reason :: map}

@doc """
  Manipula `event`os de entrada.

  Os payloads são serializados antes do envio com o serializador configurado.

  ## Exemplo

      def handle_in("ping", payload, socket) do
        {:reply, {:ok, payload}, socket}
      end
  """
  @callback handle_in(event :: String.t(), payload :: payload, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:noreply, Socket.t(), timeout | :hibernate}
              | {:reply, reply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}
              | {:stop, reason :: term, reply, Socket.t()}

 @doc """
  Intercepta `event`os de saída.

  Veja `intercept/1`.
  """
  @callback handle_out(event :: String.t(), payload :: payload, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:noreply, Socket.t(), timeout | :hibernate}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Manipula mensagens regulares de processos Elixir.

  Veja `c:GenServer.handle_info/2`.
  """
  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Manipula mensagens regulares de chamada GenServer.

  Veja `c:GenServer.handle_call/3`.
  """
  @callback handle_call(msg :: term, from :: {pid, tag :: term}, socket :: Socket.t()) ::
              {:reply, response :: term, Socket.t()}
              | {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc """
  Manipula mensagens regulares de cast GenServer.

  Veja `c:GenServer.handle_cast/2`.
  """
  @callback handle_cast(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:stop, reason :: term, Socket.t()}

  @doc false
  @callback code_change(old_vsn, Socket.t(), extra :: term) ::
              {:ok, Socket.t()}
              | {:error, reason :: term}
            when old_vsn: term | {:down, term}

  @doc """
  Invocado quando o processo do canal está prestes a encerrar.

  Veja `c:GenServer.terminate/2`.
  """
  @callback terminate(
              reason :: :normal | :shutdown | {:shutdown, :left | :closed | term},
              Socket.t()
            ) ::
              term

  @optional_callbacks handle_in: 3,
                      handle_out: 3,
                      handle_info: 2,
                      handle_call: 3,
                      handle_cast: 2,
                      code_change: 3,
                      terminate: 2

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)
      @behaviour unquote(__MODULE__)
      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @phoenix_intercepts []
      @phoenix_log_join Keyword.get(opts, :log_join, :info)
      @phoenix_log_handle_in Keyword.get(opts, :log_handle_in, :debug)
      @phoenix_hibernate_after Keyword.get(opts, :hibernate_after, 15_000)
      @phoenix_shutdown Keyword.get(opts, :shutdown, 5000)

      import unquote(__MODULE__)
      import Phoenix.Socket, only: [assign: 3, assign: 2]

      def child_spec(init_arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]},
          shutdown: @phoenix_shutdown,
          restart: :temporary
        }
      end

      def start_link(triplet) do
        GenServer.start_link(Phoenix.Channel.Server, triplet,
          hibernate_after: @phoenix_hibernate_after
        )
      end

      def __socket__(:private) do
        %{log_join: @phoenix_log_join, log_handle_in: @phoenix_log_handle_in}
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def __intercepts__, do: @phoenix_intercepts
    end
  end

  @doc """
  Define quais eventos de Canal interceptar para callbacks `handle_out/3`.

  Por padrão, eventos transmitidos são enviados diretamente ao cliente, mas
  interceptar eventos dá ao seu canal a oportunidade de personalizar o evento
  para o cliente, anexando informações extras ou filtrando a mensagem para que
  não seja entregue.

  *Nota*: interceptar eventos pode introduzir uma sobrecarga significativamente maior se um
  grande número de assinantes precisar personalizar uma mensagem, já que a transmissão será
  codificada N vezes em vez de uma única codificação compartilhada entre todos os assinantes.

  ## Exemplos

      intercept ["new_msg"]

      def handle_out("new_msg", payload, socket) do
        push(socket, "new_msg", Map.merge(payload,
          is_editable: User.can_edit_message?(socket.assigns[:user], payload)
        ))
        {:noreply, socket}
      end

  Callbacks `handle_out/3` devem retornar um dos seguintes:

      {:noreply, Socket.t} |
      {:noreply, Socket.t, timeout | :hibernate} |
      {:stop, reason :: term, Socket.t}

  """
  defmacro intercept(events) do
    quote do
      @phoenix_intercepts unquote(events)
    end
  end

  @doc false
  def __on_definition__(env, :def, :handle_out, [event, _payload, _socket], _, _)
      when is_binary(event) do
    unless event in Module.get_attribute(env.module, :phoenix_intercepts) do
      IO.write(
        "#{Path.relative_to(env.file, File.cwd!())}:#{env.line}: [warning] " <>
          "An intercept for event \"#{event}\" has not yet been defined in #{env.module}.handle_out/3. " <>
          "Add \"#{event}\" to your list of intercepted events with intercept/1"
      )
    end
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body) do
    :ok
  end

  @doc """
  Transmite um evento para todos os assinantes do tópico do socket.

  A mensagem do evento deve ser um mapa serializável ou uma tupla marcada `{:binary, data}`
  onde `data` é um dado binário.

  ## Exemplos

      iex> broadcast(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> broadcast(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def broadcast(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast(pubsub_server, topic, event, message)
  end

  @doc """
  O mesmo que `broadcast/3`, mas lança uma exceção se o broadcast falhar.
  """
  def broadcast!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic} = assert_joined!(socket)
    Server.broadcast!(pubsub_server, topic, event, message)
  end

  @doc """
  Transmite evento de um pid para todos os assinantes do tópico do socket.

  O canal que possui o socket não receberá a mensagem publicada.
  A mensagem do evento deve ser um mapa serializável ou uma tupla marcada
  `{:binary, data}` onde `data` é um dado binário.

  ## Exemplos

      iex> broadcast_from(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> broadcast_from(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def broadcast_from(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} =
      assert_joined!(socket)

    Server.broadcast_from(pubsub_server, channel_pid, topic, event, message)
  end

  @doc """
  O mesmo que `broadcast_from/3`, mas lança uma exceção se o broadcast falhar.
  """
  def broadcast_from!(socket, event, message) do
    %{pubsub_server: pubsub_server, topic: topic, channel_pid: channel_pid} =
      assert_joined!(socket)

    Server.broadcast_from!(pubsub_server, channel_pid, topic, event, message)
  end

  @doc """
  Envia um evento diretamente ao cliente conectado sem exigir uma mensagem
  prévia do cliente.

  A mensagem do evento deve ser um mapa serializável ou uma tupla marcada `{:binary, data}`
  onde `data` é um dado binário.

  Observe que, diferentemente de algumas bibliotecas de cliente, este `push/3` do lado do servidor não
  retorna uma referência. Se você precisar obter uma resposta do cliente e
  correlacionar essa resposta com a mensagem que você enviou, precisará incluir um
  identificador único na mensagem, rastreá-lo no estado do Canal, fazer com que o
  cliente o inclua em sua resposta e examinar a referência quando a resposta chegar a
  `handle_in/3`.

  ## Exemplos

      iex> push(socket, "new_message", %{id: 1, content: "hello"})
      :ok

      iex> push(socket, "new_message", {:binary, "hello"})
      :ok

  """
  def push(socket, event, message) do
    %{transport_pid: transport_pid, topic: topic} = assert_joined!(socket)
    Server.push(transport_pid, socket.join_ref, topic, event, message, socket.serializer)
  end

 @doc """
  Responde de forma assíncrona a um push do socket.

  A forma usual de responder à mensagem de um cliente é retornar uma tupla de `handle_in/3`
  como:

      {:reply, {status, payload}, socket}

  Mas às vezes você precisa responder a um push assincronamente - ou seja, depois que
  seu callback `handle_in/3` é concluído. Por exemplo, você pode precisar realizar
  trabalho em outro processo e responder quando estiver finalizado.

  Você pode fazer isso gerando uma referência ao socket com `socket_ref/1`
  e chamando `reply/2` com essa referência quando estiver pronto para responder.

  *Nota*: Um `socket_ref` é necessário para que o próprio `socket` não seja vazado
  para fora do canal. O `socket` contém informações como atribuições e
  configuração de transporte, então é importante não copiar essas informações
  para fora do canal que as possui.

  Tecnicamente, `reply/2` permitirá que você responda várias vezes à mesma
  mensagem do cliente, e cada resposta incluirá a `ref` da mensagem do cliente. Mas o
  cliente pode esperar apenas uma resposta; nesse caso, `push/3` seria preferível
  para as mensagens adicionais.

  Os payloads são serializados antes do envio com o serializador configurado.

  ## Exemplos

      def handle_in("work", payload, socket) do
        Worker.perform(payload, socket_ref(socket))
        {:noreply, socket}
      end

      def handle_info({:work_complete, result, ref}, socket) do
        reply(ref, {:ok, result})
        {:noreply, socket}
      end

  """
  @spec reply(socket_ref, reply) :: :ok
  def reply(socket_ref, status) when is_atom(status) do
    reply(socket_ref, {status, %{}})
  end

  def reply({transport_pid, serializer, topic, ref, join_ref}, {status, payload}) do
    Server.reply(transport_pid, join_ref, ref, topic, {status, payload}, serializer)
  end

  @doc """
  Gera um `socket_ref` para uma resposta assíncrona.

  Veja `reply/2` para um exemplo de uso.
  """
  @spec socket_ref(Socket.t()) :: socket_ref
  def socket_ref(%Socket{joined: true, ref: ref} = socket) when not is_nil(ref) do
    {socket.transport_pid, socket.serializer, socket.topic, ref, socket.join_ref}
  end

  def socket_ref(_socket) do
    raise ArgumentError, """
    socket refs can only be generated for a socket that has joined with a push ref
    """
  end

  defp assert_joined!(%Socket{joined: true} = socket) do
    socket
  end

  defp assert_joined!(%Socket{joined: false}) do
    raise """
    push/3, reply/2, and broadcast/3 can only be called after the socket has finished joining.
    To push a message on join, send to self and handle in handle_info/2. For example:

        def join(topic, auth_msg, socket) do
          ...
          send(self, :after_join)
          {:ok, socket}
        end

        def handle_info(:after_join, socket) do
          push(socket, "feed", %{list: feed_items(socket)})
          {:noreply, socket}
        end

    """
  end
end
