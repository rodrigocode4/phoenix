# Plug

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia do ciclo de vida da requisição](request_lifecycle.html).

O Plug está no coração da camada HTTP do Phoenix, e o Phoenix coloca o Plug em destaque. Nós interagimos com plugs em cada etapa do ciclo de vida da requisição, e os componentes principais do Phoenix como endpoints, roteadores e controladores são internamente apenas plugs. Vamos mergulhar e descobrir o que torna o Plug tão especial.

[Plug](https://github.com/elixir-lang/plug) é uma especificação para módulos componíveis entre aplicações web. Também é uma camada de abstração para adaptadores de conexão de diferentes servidores web. A ideia básica do Plug é unificar o conceito de "conexão" com o qual operamos. Isso difere de outras camadas de middleware HTTP como o Rack, onde a requisição e a resposta são separadas na pilha de middleware.

No nível mais simples, a especificação Plug vem em dois sabores: *plugs de função* e *plugs de módulo*.

## Plugs de função

Para atuar como um plug, uma função precisa:

1. aceitar uma struct de conexão (`%Plug.Conn{}`) como seu primeiro argumento e opções de conexão como seu segundo;
2. retornar uma struct de conexão.

Qualquer função que atenda a esses dois critérios servirá. Aqui está um exemplo.

```elixir
def introspect(conn, _opts) do
  IO.puts """
  Verbo: #{inspect(conn.method)}
  Host: #{inspect(conn.host)}
  Cabeçalhos: #{inspect(conn.req_headers)}
  """

  conn
end
```

Esta função faz o seguinte:

  1. Ela recebe uma conexão e opções (que não utilizamos)
  2. Imprime algumas informações da conexão no terminal
  3. Retorna a conexão

Bem simples, certo? Vamos ver esta função em ação adicionando-a ao nosso endpoint em `lib/hello_web/endpoint.ex`. Podemos conectá-la em qualquer lugar, então vamos fazer isso inserindo `plug :introspect` logo antes de delegarmos a requisição ao roteador:

```elixir
defmodule HelloWeb.Endpoint do
  ...

  plug :introspect
  plug HelloWeb.Router

  def introspect(conn, _opts) do
    IO.puts """
    Verbo: #{inspect(conn.method)}
    Host: #{inspect(conn.host)}
    Cabeçalhos: #{inspect(conn.req_headers)}
    """

    conn
  end
end
```

Os plugs de função são conectados passando o nome da função como um átomo. Para testar o plug, volte ao seu navegador e acesse [http://localhost:4000](http://localhost:4000). Você deverá ver algo como isto impresso no seu terminal shell:

```console
Verbo: "GET"
Host: "localhost"
Cabeçalhos: [...]
```

Nosso plug simplesmente imprime informações da conexão. Embora nosso plug inicial seja muito simples, você pode fazer praticamente qualquer coisa que quiser dentro dele. Para aprender sobre todos os campos disponíveis na conexão e todas as funcionalidades associadas a ela, consulte a [documentação de `Plug.Conn`](https://hexdocs.pm/plug/Plug.Conn.html).

Agora vamos olhar a outra variante de plug, os plugs de módulo.

## Plugs de módulo

Plugs de módulo são outro tipo de plug que nos permite definir uma transformação de conexão em um módulo. O módulo só precisa implementar duas funções:

- [`init/1`] que inicializa quaisquer argumentos ou opções a serem passados para [`call/2`]
- [`call/2`] que realiza a transformação da conexão. [`call/2`] é apenas um plug de função que vimos anteriormente

Para ver isso em ação, vamos escrever um plug de módulo que coloca a chave e o valor `:locale` na conexão para uso downstream em outros plugs, ações do controlador e nossas views. Coloque o conteúdo abaixo em um arquivo chamado `lib/hello_web/plugs/locale.ex`:

```elixir
defmodule HelloWeb.Plugs.Locale do
  import Plug.Conn

  @locales ["en", "fr", "de"]

  def init(default), do: default

  def call(%Plug.Conn{params: %{"locale" => loc}} = conn, _default) when loc in @locales do
    assign(conn, :locale, loc)
  end

  def call(conn, default) do
    assign(conn, :locale, default)
  end
end
```

Para experimentá-lo, vamos adicionar este plug de módulo ao nosso roteador, anexando `plug HelloWeb.Plugs.Locale, "en"` ao nosso pipeline `:browser` em `lib/hello_web/router.ex`:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWeb.Plugs.Locale, "en"
  end
  ...
```

No callback [`init/1`], passamos um locale padrão para usar se nenhum estiver presente nos parâmetros. Também usamos pattern matching para definir múltiplas cabeças de função [`call/2`] para validar o locale nos parâmetros e recorrer a `"en"` se não houver uma correspondência. O [`assign/3`] é parte do módulo `Plug.Conn` e é como armazenamos valores na estrutura de dados `conn`.

Para ver a atribuição em ação, vá para o template em `lib/hello_web/controllers/page_html/home.html.heex` e adicione o seguinte código após o fechamento da tag `</h1>`:

```heex
<p>Locale: {@locale}</p>
```

Vá para [http://localhost:4000/](http://localhost:4000/) e você deverá ver o locale exibido. Visite [http://localhost:4000/?locale=fr](http://localhost:4000/?locale=fr) e deverá ver a atribuição alterada para `"fr"`. Alguém pode usar essa informação junto com [Gettext](https://hexdocs.pm/gettext/Gettext.html) para fornecer uma aplicação web totalmente internacionalizada.

Isso é tudo que há para o Plug. O Phoenix abraça o design de plug de transformações componíveis em toda a pilha. Vamos ver alguns exemplos!

## Onde conectar (plug)

O endpoint, o roteador e os controladores no Phoenix aceitam plugs.

### Plugs de endpoint

Os endpoints organizam todos os plugs comuns a cada requisição e os aplicam antes de despachar para o roteador com seus pipelines personalizados. Adicionamos um plug ao endpoint assim:

```elixir
defmodule HelloWeb.Endpoint do
  ...

  plug :introspect
  plug HelloWeb.Router
```

Os plugs de endpoint padrão fazem bastante trabalho. Aqui estão eles em ordem:

- `Plug.Static` - serve ativos estáticos. Como este plug vem antes do logger, as requisições de ativos estáticos não são registradas.

- `Phoenix.LiveDashboard.RequestLogger` - configura o *Request Logger* para o Phoenix LiveDashboard, isso permitirá que você tenha a opção de passar um parâmetro de consulta para transmitir logs de requisições ou ativar/desativar um cookie que transmite logs de requisições do seu painel.

- `Plug.RequestId` - gera um ID de requisição único para cada requisição.

- `Plug.Telemetry` - adiciona pontos de instrumentação para que o Phoenix possa registrar o caminho da requisição, código de status e tempo de requisição por padrão.

- `Plug.Parsers` - analisa o corpo da requisição quando um analisador conhecido está disponível. Por padrão, este plug pode lidar com conteúdo codificado em URL, multipart e JSON (com `Jason`). O corpo da requisição fica intocado se o tipo de conteúdo da requisição não puder ser analisado.

- `Plug.MethodOverride` - converte o método da requisição para PUT, PATCH ou DELETE para requisições POST com um parâmetro `_method` válido.

- `Plug.Head` - converte requisições HEAD para requisições GET.

- `Plug.Session` - um plug que configura o gerenciamento de sessão. Observe que `fetch_session/2` ainda deve ser explicitamente chamado antes de usar a sessão, pois este plug apenas configura como a sessão é buscada.

No meio do endpoint, há também um bloco condicional:

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :hello
  end
```

Este bloco é executado apenas em desenvolvimento. Ele habilita:

* recarregamento ao vivo - se você alterar um arquivo CSS, eles são atualizados no navegador sem atualizar a página;
* [recarregamento de código](`Phoenix.CodeReloader`) - para que possamos ver mudanças em nossa aplicação sem reiniciar o servidor;
* verificação do status do repositório - que garante que nosso banco de dados esteja atualizado, levantando um erro legível e acionável caso contrário.

### Plugs de roteador

No roteador, podemos declarar plugs dentro de pipelines:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWeb.Plugs.Locale, "en"
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
  end
```

As rotas são definidas dentro de escopos e os escopos podem passar por múltiplos pipelines. Uma vez que uma rota corresponde, o Phoenix invoca todos os plugs definidos em todos os pipelines associados a essa rota. Por exemplo, acessar "/" passará pelo pipeline `:browser`, consequentemente invocando todos os seus plugs.

Como veremos no [guia de roteamento](routing.html), os próprios pipelines são plugs. Lá, também discutiremos todos os plugs no pipeline `:browser`.

### Plugs de controlador

Finalmente, os controladores também são plugs, então podemos fazer:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  plug HelloWeb.Plugs.Locale, "en"
```

Em particular, os plugs de controlador fornecem um recurso que nos permite executar plugs apenas dentro de certas ações. Por exemplo, você pode fazer:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  plug HelloWeb.Plugs.Locale, "en" when action in [:index]
```

E o plug será executado apenas para a ação `index`.

## Plugs como composição

Ao aderir ao contrato de plug, transformamos uma requisição de aplicação em uma série de transformações explícitas. Não para por aí. Para realmente ver quão eficaz é o design do Plug, vamos imaginar um cenário onde precisamos verificar uma série de condições e então redirecionar ou parar se uma condição falhar. Sem plug, acabaríamos com algo como isso:

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  def show(conn, params) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        case find_message(params["id"]) do
          nil ->
            conn |> put_flash(:info, "Essa mensagem não foi encontrada") |> redirect(to: ~p"/")
          message ->
            if Authorizer.can_access?(user, message) do
              render(conn, :show, page: message)
            else
              conn |> put_flash(:info, "Você não pode acessar essa página") |> redirect(to: ~p"/")
            end
        end
      :error ->
        conn |> put_flash(:info, "Você deve estar logado") |> redirect(to: ~p"/")
    end
  end
end
```

Perceba como apenas alguns passos de autenticação e autorização requerem aninhamento e duplicação complicados? Vamos melhorar isso com alguns plugs.

```elixir
defmodule HelloWeb.MessageController do
  use HelloWeb, :controller

  plug :authenticate
  plug :fetch_message
  plug :authorize_message

  def show(conn, params) do
    render(conn, :show, page: conn.assigns[:message])
  end

  defp authenticate(conn, _) do
    case Authenticator.find_user(conn) do
      {:ok, user} ->
        assign(conn, :user, user)
      :error ->
        conn |> put_flash(:info, "Você deve estar logado") |> redirect(to: ~p"/") |> halt()
    end
  end

  defp fetch_message(conn, _) do
    case find_message(conn.params["id"]) do
      nil ->
        conn |> put_flash(:info, "Essa mensagem não foi encontrada") |> redirect(to: ~p"/") |> halt()
      message ->
        assign(conn, :message, message)
    end
  end

  defp authorize_message(conn, _) do
    if Authorizer.can_access?(conn.assigns[:user], conn.assigns[:message]) do
      conn
    else
      conn |> put_flash(:info, "Você não pode acessar essa página") |> redirect(to: ~p"/") |> halt()
    end
  end
end
```

Para fazer tudo isso funcionar, convertemos os blocos aninhados de código e usamos `halt(conn)` sempre que chegávamos a um caminho de falha. A funcionalidade `halt(conn)` é essencial aqui: ela diz ao Plug que o próximo plug não deve ser invocado.

No final do dia, ao substituir os blocos aninhados de código por uma série plana de transformações de plug, somos capazes de alcançar a mesma funcionalidade de uma maneira muito mais componível, clara e reutilizável.

Para saber mais sobre plugs, consulte a documentação do [projeto Plug](`Plug`), que fornece muitos plugs e funcionalidades integradas.

[`init/1`]: `c:Plug.init/1`
[`call/2`]: `c:Plug.call/2`
[`assign/3`]: `Plug.Conn.assign/3`
