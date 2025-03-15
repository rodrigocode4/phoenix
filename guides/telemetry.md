# Telemetria

Neste guia, mostraremos como instrumentar e reportar eventos `:telemetry` em sua aplicação Phoenix.

> `telemetria` - o processo de registrar e transmitir as leituras de um instrumento.

Conforme você segue este guia, apresentaremos os conceitos principais da Telemetria, você inicializará um reporter para capturar os eventos da sua aplicação à medida que ocorrem, e o guiaremos pelos passos para instrumentar adequadamente suas próprias funções usando `:telemetry`. Vamos olhar mais de perto como a Telemetria funciona em sua aplicação.

## Visão Geral

A biblioteca `[:telemetry]` permite emitir eventos em vários estágios do ciclo de vida de uma aplicação. Você pode então responder a esses eventos, entre outras coisas, agregando-os como métricas e enviando os dados de métricas para um destino de relatório.

A Telemetria armazena eventos pelo seu nome em uma tabela ETS, junto com o handler para cada evento. Então, quando um determinado evento é executado, a Telemetria procura seu handler e o invoca.

As ferramentas de Telemetria do Phoenix fornecem um supervisor que usa `Telemetry.Metrics` para definir a lista de eventos de Telemetria a serem tratados e como tratá-los, ou seja, como estruturá-los como um certo tipo de métrica. Este supervisor trabalha em conjunto com os reporters de Telemetria para responder aos eventos especificados de Telemetria, agregando-os como a métrica apropriada e enviando-os para o destino de relatório correto.

## O supervisor de Telemetria

Desde a v1.5, novas aplicações Phoenix são geradas com um supervisor de Telemetria. Este módulo é responsável por gerenciar o ciclo de vida dos seus processos de Telemetria. Ele também define uma função `metrics/0`, que retorna uma lista de [`Telemetry.Metrics`](https://hexdocs.pm/telemetry_metrics) que você define para sua aplicação.

Por padrão, o supervisor também inicia o [`:telemetry_poller`](https://hexdocs.pm/telemetry_poller). Simplesmente adicionando `:telemetry_poller` como uma dependência, você pode receber eventos relacionados à VM em um intervalo especificado.

Se você está vindo de uma versão mais antiga do Phoenix, instale os pacotes `:telemetry_metrics` e `:telemetry_poller`:

```elixir
{:telemetry_metrics, "~> 1.0"},
{:telemetry_poller, "~> 1.0"}
```

e crie seu supervisor de Telemetria em `lib/my_app_web/telemetry.ex`:

```elixir
# lib/my_app_web/telemetry.ex
defmodule MyAppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Adicione reporters como filhos da sua árvore de supervisão.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # Um módulo, função e argumentos a serem invocados periodicamente.
      # Esta função deve chamar :telemetry.execute/3 e uma métrica deve ser adicionada acima.
      # {MyApp, :count_users, []}
    ]
  end
end
```

Certifique-se de substituir MyApp pelo nome real da sua aplicação.

Em seguida, adicione à árvore de supervisão da sua aplicação principal (geralmente em `lib/my_app/application.ex`):

```elixir
children = [
  MyAppWeb.Telemetry,
  MyApp.Repo,
  MyAppWeb.Endpoint,
  ...
]
```

## Eventos de Telemetria

Muitas bibliotecas Elixir (incluindo Phoenix) já estão usando o pacote [`:telemetry`](https://hexdocs.pm/telemetry) como uma maneira de fornecer aos usuários mais insights sobre o comportamento de suas aplicações, emitindo eventos em momentos-chave do ciclo de vida da aplicação.

Um evento de Telemetria é composto pelo seguinte:

  * `name` - Uma string (ex: `"my_app.worker.stop"`) ou uma lista de átomos que identifica unicamente o evento.

  * `measurements` - Um mapa de chaves atom (ex: `:duration`) e valores numéricos.

  * `metadata` - Um mapa de pares chave-valor que podem ser usados para a marcação de métricas.

### Um Exemplo do Phoenix

Aqui está um exemplo de um evento do seu endpoint:

* `[:phoenix, :endpoint, :stop]` - despachado por `Plug.Telemetry`, um dos plugs padrão no seu endpoint, sempre que a resposta é enviada

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t}`

Isso significa que após cada requisição, `Plug`, via `:telemetry`, emitirá um evento "stop", com uma medição de quanto tempo levou para obter a resposta:

```elixir
:telemetry.execute([:phoenix, :endpoint, :stop], %{duration: duration}, %{conn: conn})
```

### Eventos de Telemetria do Phoenix

Uma lista completa de todos os eventos de telemetria do Phoenix pode ser encontrada em `Phoenix.Logger`

## Métricas

> Métricas são agregações de eventos de Telemetria com um nome específico, fornecendo uma visão do comportamento do sistema ao longo do tempo.
>
> ― `Telemetry.Metrics`

O pacote Telemetry.Metrics fornece uma interface comum para definir métricas. Ele expõe um conjunto de [cinco funções de tipo de métrica](https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-metrics) que são responsáveis por estruturar um determinado evento de Telemetria como uma medição específica.

O próprio pacote não realiza nenhuma agregação das medições. Em vez disso, ele fornece a um reporter a definição do evento de Telemetria como medição, e o reporter usa essa definição para realizar agregações e reportá-las.

Discutiremos os reporters na próxima seção.

Vamos olhar alguns exemplos.

Usando `Telemetry.Metrics`, você pode definir uma métrica contador, que conta quantas requisições HTTP foram completadas:

```elixir
Telemetry.Metrics.counter("phoenix.endpoint.stop.duration")
```

ou você poderia usar uma métrica de distribuição para ver quantas requisições foram completadas em faixas de tempo específicas:

```elixir
Telemetry.Metrics.distribution("phoenix.endpoint.stop.duration")
```

Esta capacidade de introspecção de requisições HTTP é realmente poderosa -- e este é apenas um de _muitos_ eventos de telemetria emitidos pelo framework Phoenix! Discutiremos mais desses eventos, bem como padrões específicos para extrair dados valiosos de eventos Phoenix/Plug na seção [Métricas do Phoenix](#phoenix-metrics) mais adiante neste guia.

> A lista completa de eventos `:telemetry` emitidos pelo Phoenix, junto com suas medições e metadados, está disponível na seção "Instrumentação" da documentação do módulo `Phoenix.Logger`.

### Um Exemplo do Ecto

Assim como o Phoenix, o Ecto vem com eventos de Telemetria integrados. Isso significa que você pode obter introspecção nas suas camadas web e de banco de dados usando as mesmas ferramentas.

Aqui está um exemplo de um evento de Telemetria executado pelo Ecto quando um repositório Ecto inicia:

* `[:ecto, :repo, :init]` - despachado por `Ecto.Repo`

  * Measurement: `%{system_time: native_time}`

  * Metadata: `%{repo: Ecto.Repo, opts: Keyword.t()}`

Isso significa que sempre que o `Ecto.Repo` inicia, ele emitirá um evento, via `:telemetry`, com uma medição do tempo no início.

```elixir
:telemetry.execute([:ecto, :repo, :init], %{system_time: System.system_time()}, %{repo: repo, opts: opts})
```

Eventos adicionais de Telemetria são executados pelos adaptadores do Ecto.

Um desses eventos específicos do adaptador é o evento `[:my_app, :repo, :query]`. 
Por exemplo, se você quiser graficar o tempo de execução de consultas, pode usar a função `Telemetry.Metrics.summary/2` para instruir seu reporter a calcular estatísticas do evento `[:my_app, :repo, :query]`, como máximo, média, percentis, etc.:

```elixir
Telemetry.Metrics.summary("my_app.repo.query.query_time",
  unit: {:native, :millisecond}
)
```

Ou você poderia usar a função `Telemetry.Metrics.distribution/2` para definir um histograma para outro evento específico do adaptador: `[:my_app, :repo, :query, :queue_time]`, visualizando assim quanto tempo as consultas passam na fila:

```elixir
Telemetry.Metrics.distribution("my_app.repo.query.queue_time",
  unit: {:native, :millisecond}
)
```

> Você pode aprender mais sobre a Telemetria do Ecto na seção "Eventos de Telemetria" da documentação do módulo [`Ecto.Repo`](https://hexdocs.pm/ecto/Ecto.Repo.html).

Até agora, vimos alguns dos eventos de Telemetria comuns às aplicações Phoenix, juntamente com alguns exemplos de suas várias medições e metadados. Com todos esses dados apenas esperando para serem consumidos, vamos falar sobre reporters.

## Reporters

Os reporters se inscrevem em eventos de Telemetria usando a interface comum fornecida por `Telemetry.Metrics`. Eles então agregam as medições (dados) em métricas para fornecer informações significativas sobre sua aplicação.

Por exemplo, se a seguinte chamada `Telemetry.Metrics.summary/2` for adicionada à função `metrics/0` do seu supervisor de Telemetria:

```elixir
summary("phoenix.endpoint.stop.duration",
  unit: {:native, :millisecond}
)
```

Então o reporter anexará um listener para o evento `"phoenix.endpoint.stop.duration"` e responderá a este evento calculando uma métrica sumária com os metadados do evento fornecidos e relatando sobre essa métrica para a fonte apropriada.

### Phoenix.LiveDashboard

Para desenvolvedores interessados em visualizações em tempo real para suas métricas de Telemetria, você pode estar interessado em instalar o [`LiveDashboard`](https://hexdocs.pm/phoenix_live_dashboard). O LiveDashboard atua como um reporter de Telemetry.Metrics para renderizar seus dados como belos gráficos em tempo real no dashboard.

### Telemetry.Metrics.ConsoleReporter

`Telemetry.Metrics` vem com um `ConsoleReporter` que pode ser usado para imprimir eventos e métricas no terminal. Você pode usar este reporter para experimentar as métricas discutidas neste guia.

Descomente ou adicione o seguinte à lista de filhos na sua árvore de supervisão de Telemetria (geralmente em `lib/my_app_web/telemetry.ex`):

```elixir
{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
```

> Existem numerosos reporters disponíveis, para serviços como StatsD, Prometheus e mais. Você pode encontrá-los pesquisando por "telemetry_metrics" em [hex.pm](https://hex.pm/packages?search=telemetry_metrics).

## Métricas do Phoenix

Anteriormente, examinamos o evento "stop" emitido por `Plug.Telemetry` e o usamos para contar o número de requisições HTTP. Na realidade, é apenas um pouco útil poder ver apenas o número total de requisições. E se você quisesse ver o número de requisições por rota, ou por rota _e_ método?

Vamos dar uma olhada em outro evento emitido durante o ciclo de vida da requisição HTTP, desta vez do `Phoenix.Router`:

* `[:phoenix, :router_dispatch, :stop]` - despachado por Phoenix.Router após despachar com sucesso para uma rota correspondente

  * Measurement: `%{duration: native_time}`

  * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom]}`

Vamos começar agrupando esses eventos por rota. Adicione o seguinte (se ainda não existir) à função `metrics/0` do seu supervisor de Telemetria (geralmente em `lib/my_app_web/telemetry.ex`):

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    ...metrics...
    summary("phoenix.router_dispatch.stop.duration",
      tags: [:route],
      unit: {:native, :millisecond}
    )
  ]
end
```

Reinicie seu servidor e, em seguida, faça requisições para uma ou duas páginas. No seu terminal, você deve ver o ConsoleReporter imprimir logs para os eventos de Telemetria que recebeu como resultado das definições de métricas que você forneceu.

A linha de log para cada requisição contém a rota específica para essa requisição. Isso se deve à especificação da opção `:tags` para a métrica summary, que cuida do nosso primeiro requisito; podemos usar `:tags` para agrupar métricas por rota. Observe que os reporters necessariamente lidarão com tags de maneira diferente, dependendo do serviço subjacente em uso.

Olhando mais de perto o evento "stop" do Router, você pode ver que a estrutura `Plug.Conn` que representa a requisição está presente nos metadados, mas como você acessa as propriedades em `conn`?

Felizmente, `Telemetry.Metrics` fornece as seguintes opções para ajudá-lo a classificar seus eventos:

* `:tags` - Uma lista de chaves de metadados para agrupamento;

* `:tag_values` - Uma função que transforma os metadados na forma desejada; Observe que esta função é chamada para cada evento, então é importante mantê-la rápida se a taxa de eventos for alta.

> Saiba mais sobre todas as opções de métricas disponíveis na documentação do módulo `Telemetry.Metrics`.

Vamos descobrir como extrair mais tags de eventos que incluem um `conn` em seus metadados.

### Extraindo valores de tags de Plug.Conn

Vamos adicionar outra métrica para o evento de rota, desta vez para agrupar por rota e método:

```elixir
summary("phoenix.router_dispatch.stop.duration",
  tags: [:method, :route],
  tag_values: &get_and_put_http_method/1,
  unit: {:native, :millisecond}
)
```

Introduzimos a opção `:tag_values` aqui, porque precisamos realizar uma transformação nos metadados do evento para obter os valores que precisamos.

Adicione a seguinte função privada ao seu módulo de Telemetria para elevar o valor `:method` da estrutura `Plug.Conn`:

```elixir
# lib/my_app_web/telemetry.ex
defp get_and_put_http_method(%{conn: %{method: method}} = metadata) do
  Map.put(metadata, :method, method)
end
```

Reinicie seu servidor e faça mais algumas requisições. Você deve começar a ver logs com tags para o método HTTP e a rota.

Observe que as opções `:tags` e `:tag_values` podem ser aplicadas a todos os tipos de `Telemetry.Metrics`.

### Renomeando rótulos de valor usando valores de tag

Às vezes, ao exibir uma métrica, o rótulo do valor pode precisar ser transformado para melhorar a legibilidade. Tome como exemplo a seguinte métrica que exibe a duração do callback `mount/3` de cada LiveView por status `connected?`.

```elixir
summary("phoenix.live_view.mount.stop.duration",
  unit: {:native, :millisecond},
  tags: [:view, :connected?],
  tag_values: &live_view_metric_tag_values/1
)
```

A seguinte função eleva `metadata.socket.view` e `metadata.socket.connected?` para serem chaves de nível superior em `metadata`, como fizemos no exemplo anterior.

```elixir
# lib/my_app_web/telemetry.ex
defp live_view_metric_tag_values(metadata) do
  metadata
  |> Map.put(:view, metadata.socket.view)
  |> Map.put(:connected?, Phoenix.LiveView.connected?(metadata.socket))
end
```

No entanto, ao renderizar essas métricas no LiveDashboard, o rótulo do valor é exibido como `"Elixir.Phoenix.LiveDashboard.MetricsLive true"`.

Para tornar o rótulo do valor mais fácil de ler, podemos atualizar nossa função privada para gerar nomes mais amigáveis. Passaremos o valor de `:view` através de `inspect/1` para remover o prefixo `Elixir.` e chamaremos outra função privada para converter o booleano `connected?` em texto legível por humanos.

```elixir
# lib/my_app_web/telemetry.ex
defp live_view_metric_tag_values(metadata) do
  metadata
  |> Map.put(:view, inspect(metadata.socket.view))
  |> Map.put(:connected?, get_connection_status(Phoenix.LiveView.connected?(metadata.socket)))
end

defp get_connection_status(true), do: "Connected"
defp get_connection_status(false), do: "Disconnected"
```

Agora o rótulo do valor será renderizado como `"Phoenix.LiveDashboard.MetricsLive Connected"`.

Esperamos que isso lhe dê alguma inspiração sobre como usar a opção `:tag_values`. Apenas lembre-se de manter esta função rápida, já que ela é chamada em cada evento.

## Medições periódicas

Você pode querer medir periodicamente pares de chave-valor dentro da sua aplicação. Felizmente, o pacote [`:telemetry_poller`](https://hexdocs.pm/telemetry_poller) fornece um mecanismo para medições personalizadas, que é útil para recuperar informações de processos ou para realizar medições personalizadas periodicamente.

Adicione o seguinte à lista na função `periodic_measurements/0` do seu supervisor de Telemetria, que é uma função privada que retorna uma lista de medições a serem realizadas em um intervalo especificado.

```elixir
# lib/my_app_web/telemetry.ex
defp periodic_measurements do
  [
    {MyApp, :measure_users, []},
    {:process_info,
      event: [:my_app, :my_server],
      name: MyApp.MyServer,
      keys: [:message_queue_len, :memory]}
  ]
end
```

onde `MyApp.measure_users/0` poderia ser escrito assim:

```elixir
# lib/my_app.ex
defmodule MyApp do
  def measure_users do
    :telemetry.execute([:my_app, :users], %{total: MyApp.users_count()}, %{})
  end
end
```

Agora, com as medições no lugar, você pode definir as métricas para os eventos acima:

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    ...metrics...
    # MyApp Metrics
    last_value("my_app.users.total"),
    last_value("my_app.my_server.memory", unit: :byte),
    last_value("my_app.my_server.message_queue_len")
    summary("my_app.my_server.call.stop.duration"),
    counter("my_app.my_server.call.exception")
  ]
end
```

> Você implementará MyApp.MyServer na seção [Eventos Personalizados](#custom-events).

## Bibliotecas usando Telemetria

A Telemetria está rapidamente se tornando o padrão de facto para instrumentação de pacotes em Elixir. Aqui está uma lista de bibliotecas que atualmente emitem eventos `:telemetry`.

Os autores de bibliotecas são ativamente encorajados a enviar um PR adicionando as suas próprias (em ordem alfabética, por favor):

* [Absinthe](https://hexdocs.pm/absinthe) - [Events](https://hexdocs.pm/absinthe/telemetry.html)
* [Ash Framework](https://hexdocs.pm/ash) - [Events](https://hexdocs.pm/ash/monitoring.html)
* [Broadway](https://hexdocs.pm/broadway) - [Events](https://hexdocs.pm/broadway/Broadway.html#module-telemetry)
* [Ecto](https://hexdocs.pm/ecto) - [Events](https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events)
* [Oban](https://hexdocs.pm/oban) - [Events](https://hexdocs.pm/oban/Oban.Telemetry.html)
* [Phoenix](https://hexdocs.pm/phoenix) - [Events](https://hexdocs.pm/phoenix/Phoenix.Logger.html#module-instrumentation)
* [Plug](https://hexdocs.pm/plug) - [Events](https://hexdocs.pm/plug/Plug.Telemetry.html)
* [Tesla](https://hexdocs.pm/tesla) - [Events](https://hexdocs.pm/tesla/Tesla.Middleware.Telemetry.html)

## Eventos Personalizados

Se você precisa de métricas e instrumentação personalizadas em sua aplicação, você pode utilizar o pacote `:telemetry` (<https://hexdocs.pm/telemetry>) assim como seus frameworks e bibliotecas favoritos.

Aqui está um exemplo de um GenServer simples que emite eventos de telemetria. Crie este arquivo em sua aplicação em `lib/my_app/my_server.ex`:

```elixir
# lib/my_app/my_server.ex
defmodule MyApp.MyServer do
  @moduledoc """
  Um exemplo de GenServer que executa funções arbitrárias e emite eventos de telemetria quando chamado.
  """
  use GenServer

  # Um prefixo comum para eventos :telemetry
  @prefix [:my_app, :my_server, :call]

  def start_link(fun) do
    GenServer.start_link(__MODULE__, fun, name: __MODULE__)
  end

  @doc """
  Executa a função contida neste servidor.

  ## Eventos

  Os seguintes eventos podem ser emitidos:

    * `[:my_app, :my_server, :call, :start]` - Despachado
      imediatamente antes de invocar a função. Este evento
      é sempre emitido.

      * Measurement: `%{system_time: system_time}`

      * Metadata: `%{}`

    * `[:my_app, :my_server, :call, :stop]` - Despachado
      imediatamente após invocar com sucesso a função.

      * Measurement: `%{duration: native_time}`

      * Metadata: `%{}`

    * `[:my_app, :my_server, :call, :exception]` - Despachado
      imediatamente após invocar a função, no caso
      de a função lançar ou levantar uma exceção.

      * Measurement: `%{duration: native_time}`

      * Metadata: `%{kind: kind, reason: reason, stacktrace: stacktrace}`
  """
  def call!, do: GenServer.call(__MODULE__, :called)

  @impl true
  def init(fun) when is_function(fun, 0), do: {:ok, fun}

  @impl true
  def handle_call(:called, _from, fun) do
    # Embrulhe a invocação da função em um "span"
    result = telemetry_span(fun)

    {:reply, result, fun}
  end

  # Emite eventos de telemetria relacionados à invocação da função
  defp telemetry_span(fun) do
    start_time = emit_start()

    try do
      fun.()
    catch
      kind, reason ->
        stacktrace = System.stacktrace()
        duration = System.monotonic_time() - start_time
        emit_exception(duration, kind, reason, stacktrace)
        :erlang.raise(kind, reason, stacktrace)
    else
      result ->
        duration = System.monotonic_time() - start_time
        emit_stop(duration)
        result
    end
  end

  defp emit_start do
    start_time_mono = System.monotonic_time()

    :telemetry.execute(
      @prefix ++ [:start],
      %{system_time: System.system_time()},
      %{}
    )

    start_time_mono
  end

  defp emit_stop(duration) do
    :telemetry.execute(
      @prefix ++ [:stop],
      %{duration: duration},
      %{}
    )
  end

  defp emit_exception(duration, kind, reason, stacktrace) do
    :telemetry.execute(
      @prefix ++ [:exception],
      %{duration: duration},
      %{
        kind: kind,
        reason: reason,
        stacktrace: stacktrace
      }
    )
  end
end
```

e adicione-o à árvore de supervisão da sua aplicação (geralmente em `lib/my_app/application.ex`), dando a ele uma função para invocar quando chamado:

```elixir
# lib/my_app/application.ex
children = [
  # Inicie um servidor que saúda o mundo
  {MyApp.MyServer, fn -> "Olá, mundo!" end},
]
```

Agora inicie uma sessão IEx e chame o servidor:

```elixir
iex> MyApp.MyServer.call!
```

e você deve ver algo como a seguinte saída:

```text
[Telemetry.Metrics.ConsoleReporter] Got new event!
Event name: my_app.my_server.call.stop
All measurements: %{duration: 4000}
All metadata: %{}

Metric measurement: #Function<2.111777250/1 in Telemetry.Metrics.maybe_convert_measurement/2> (summary)
With value: 0.004 millisecond
Tag values: %{}

"Olá, mundo!"
```
