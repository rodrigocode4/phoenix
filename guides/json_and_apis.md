# JSON e APIs

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia de Controladores](controllers.html).

Você também pode usar o Framework Phoenix para construir [APIs Web](https://en.wikipedia.org/wiki/Web_API). Por padrão, o Phoenix suporta JSON, mas você pode trazer qualquer outro formato de renderização que desejar.

## A API JSON

Para este guia, vamos criar uma API JSON simples para armazenar nossos links favoritos, que suportará todas as operações CRUD (Criar, Ler, Atualizar, Excluir) prontas para uso.

Para este guia, usaremos os geradores do Phoenix para estruturar nossa infraestrutura de API:

```console
mix phx.gen.json Urls Url urls link:string title:string
* creating lib/hello_web/controllers/url_controller.ex
* creating lib/hello_web/controllers/url_json.ex
* creating lib/hello_web/controllers/changeset_json.ex
* creating test/hello_web/controllers/url_controller_test.exs
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/urls/url.ex
* creating priv/repo/migrations/20221129120234_create_urls.exs
* creating lib/hello/urls.ex
* injecting lib/hello/urls.ex
* creating test/hello/urls_test.exs
* injecting test/hello/urls_test.exs
* creating test/support/fixtures/urls_fixtures.ex
* injecting test/support/fixtures/urls_fixtures.ex
```

Vamos dividir esses arquivos em quatro categorias:

  * Arquivos em `lib/hello_web` responsáveis por renderizar JSON efetivamente
  * Arquivos em `lib/hello` responsáveis por definir nosso contexto e lógica para persistir links no banco de dados
  * Arquivos em `priv/repo/migrations` responsáveis por atualizar nosso banco de dados
  * Arquivos em `test` para testar nossos controladores e contextos

Neste guia, exploraremos apenas a primeira categoria de arquivos. Para saber mais sobre como o Phoenix armazena e gerencia dados, confira [o guia do Ecto](ecto.md) e [o guia de Contextos](contexts.md) para mais informações. Também temos uma seção inteira dedicada a testes.

No final, o gerador nos pede para adicionar o recurso `/url` ao nosso escopo `:api` em `lib/hello_web/router.ex`:

```elixir
scope "/api", HelloWeb do
  pipe_through :api
  resources "/urls", UrlController, except: [:new, :edit]
end
```

O escopo da API usa o pipeline `:api`, que executará etapas específicas, como garantir que o cliente possa lidar com respostas JSON.

Em seguida, precisamos atualizar nosso repositório executando migrações:

```console
mix ecto.migrate
```

### Testando a API JSON

Antes de prosseguirmos e alterarmos esses arquivos, vamos dar uma olhada em como nossa API se comporta a partir da linha de comando.

Primeiro, precisamos iniciar o servidor:

```console
mix phx.server
```

Em seguida, vamos fazer um teste rápido para verificar se nossa API está funcionando:

```console
curl -i http://localhost:4000/api/urls
```

Se tudo correu conforme o planejado, devemos obter uma resposta `200`:

```console
HTTP/1.1 200 OK
cache-control: max-age=0, private, must-revalidate
content-length: 11
content-type: application/json; charset=utf-8
date: Fri, 06 May 2022 21:22:42 GMT
server: Cowboy
x-request-id: Fuyg-wMl4S-hAfsAAAUk

{"data":[]}
```

Não recebemos nenhum dado porque ainda não populamos o banco de dados. Então, vamos adicionar alguns links:

```console
curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {"link":"https://phoenixframework.org", "title":"Phoenix Framework"}}'

curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {"link":"https://elixir-lang.org", "title":"Elixir"}}'
```

Agora podemos recuperar todos os links:

```console
curl -i http://localhost:4000/api/urls
```

Ou podemos apenas recuperar um link por seu `id`:

```console
curl -i http://localhost:4000/api/urls/1
```

Em seguida, podemos atualizar um link com:

```console
curl -iX PUT http://localhost:4000/api/urls/2 \
   -H 'Content-Type: application/json' \
   -d '{"url": {"title":"Elixir Programming Language"}}'
```

A resposta deve ser um `200` com o link atualizado no corpo.

Por fim, precisamos testar a remoção de um link:

```console
curl -iX DELETE http://localhost:4000/api/urls/2 \
   -H 'Content-Type: application/json'
```

Uma resposta `204` deve ser retornada para indicar a remoção bem-sucedida do link.

## Renderizando JSON

Para entender como renderizar JSON, vamos começar com a ação `index` do `UrlController` definida em `lib/hello_web/controllers/url_controller.ex`:

```elixir
  def index(conn, _params) do
    urls = Urls.list_urls()
    render(conn, :index, urls: urls)
  end
```

Como podemos ver, isso não é diferente de como o Phoenix renderiza templates HTML. Chamamos `render/3`, passando a conexão, o template que queremos que nossas views renderizem (`:index`) e os dados que queremos disponibilizar para nossas views.

O Phoenix normalmente usa uma view por formato de renderização. Ao renderizar HTML, usaríamos `UrlHTML`. Agora que estamos renderizando JSON, encontraremos uma view `UrlJSON` colocada junto com o template em `lib/hello_web/controllers/url_json.ex`. Vamos abri-la:

```elixir
defmodule HelloWeb.UrlJSON do
  alias Hello.Urls.Url

  @doc """
  Renders a list of urls.
  """
  def index(%{urls: urls}) do
    %{data: for(url <- urls, do: data(url))}
  end

  @doc """
  Renders a single url.
  """
  def show(%{url: url}) do
    %{data: data(url)}
  end

  defp data(%Url{} = url) do
    %{
      id: url.id,
      link: url.link,
      title: url.title
    }
  end
end
```

Esta view é muito simples. A função `index` recebe todos os URLs e os converte em uma lista de mapas. Esses mapas são colocados dentro da chave data na raiz, exatamente como vimos ao interagir com nossa aplicação a partir do `cURL`. Em outras palavras, nossa view JSON converte nossos dados complexos em estruturas de dados Elixir simples. Uma vez que nossa camada de view retorna, o Phoenix usa a biblioteca `Jason` para codificar JSON e enviar a resposta ao cliente.

Se você explorar o restante do controlador, verá que a ação `show` é semelhante à `index`. Para as ações `create`, `update` e `delete`, o Phoenix usa outro recurso importante, chamado "Action fallback".

## Action fallback

O Action fallback nos permite centralizar o código de tratamento de erros em plugs, que são chamados quando uma ação do controlador falha em retornar uma estrutura [`%Plug.Conn{}`](`t:Plug.Conn.t/0`). Esses plugs recebem tanto a `conn` que foi originalmente passada para a ação do controlador quanto o valor de retorno da ação.

Digamos que temos uma ação `show` que usa [`with`](`with/1`) para buscar uma postagem de blog e, em seguida, autorizar o usuário atual a visualizar essa postagem. Neste exemplo, podemos esperar que `fetch_post/1` retorne `{:error, :not_found}` se a postagem não for encontrada e `authorize_user/3` pode retornar `{:error, :unauthorized}` se o usuário não estiver autorizado. Poderíamos usar nossas views `ErrorHTML` e `ErrorJSON`, que são geradas pelo Phoenix para cada nova aplicação, para lidar com esses caminhos de erro de acordo:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, :show, post: post)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
        |> render(:"404")

      {:error, :unauthorized} ->
        conn
        |> put_status(403)
        |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
        |> render(:"403")
    end
  end
end
```

Agora imagine que você pode precisar implementar uma lógica semelhante para cada controlador e ação tratada pela sua API. Isso resultaria em muita repetição.

Em vez disso, podemos definir um plug de módulo que sabe como lidar com esses casos de erro especificamente. Como os controladores são plugs de módulo, vamos definir nosso plug como um controlador:

```elixir
defmodule HelloWeb.MyFallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: HelloWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(403)
    |> put_view(json: HelloWeb.ErrorJSON)
    |> render(:"403")
  end
end
```

Então podemos referenciar nosso novo controlador como o `action_fallback` e simplesmente remover o bloco `else` do nosso `with`:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  action_fallback HelloWeb.MyFallbackController

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, :show, post: post)
    end
  end
end
```

Sempre que as condições do `with` não corresponderem, `HelloWeb.MyFallbackController` receberá o `conn` original, bem como o resultado da ação, e responderá de acordo.

## FallbackController e ChangesetJSON

Com esse conhecimento em mãos, podemos explorar o `FallbackController` (`lib/hello_web/controllers/fallback_controller.ex`) gerado por `mix phx.gen.json`. Em particular, ele lida com uma cláusula (a outra é gerada como exemplo):

```elixir
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HelloWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
```

O objetivo dessa cláusula é lidar com os tipos de retorno `{:error, changeset}` do contexto `HelloWeb.Urls` e transformá-los em erros renderizados através da view `ChangesetJSON`. Vamos abrir `lib/hello_web/controllers/changeset_json.ex` para saber mais:

```elixir
defmodule HelloWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end
end
```

Como podemos ver, ele converterá os erros em uma estrutura de dados, que será renderizada como JSON. O changeset é uma estrutura de dados responsável por converter e validar dados. Para nosso exemplo, ele é definido em `Hello.Urls.Url.changeset/1`. Vamos abrir `lib/hello/urls/url.ex` e ver sua definição:

```elixir
  @doc false
  def changeset(url, attrs) do
    url
    |> cast(attrs, [:link, :title])
    |> validate_required([:link, :title])
  end
```

Como você pode ver, o changeset requer que tanto o link quanto o título sejam fornecidos. Isso significa que podemos tentar postar um url sem link e título e ver como nossa API responde:

```console
curl -iX POST http://localhost:4000/api/urls \
   -H 'Content-Type: application/json' \
   -d '{"url": {}}'

{"errors": {"link": ["can't be blank"], "title": ["can't be blank"]}}
```

Sinta-se à vontade para modificar a função `changeset` e ver como sua API se comporta.

## Aplicações somente API

Caso você queira gerar uma aplicação Phoenix exclusivamente para APIs, você pode passar
várias opções ao invocar `mix phx.new`. Vamos verificar quais flags `--no-*` precisamos
usar para não gerar o scaffolding que não é necessário em nossa aplicação Phoenix
para a API REST.

Do seu terminal, execute:

```console
mix help phx.new
```

A saída deve conter o seguinte:

```text
  • --no-assets - equivalente a --no-esbuild e --no-tailwind
  • --no-dashboard - não incluir Phoenix.LiveDashboard
  • --no-ecto - não gerar arquivos Ecto
  • --no-esbuild - não incluir dependências e ativos do esbuild.
    Não recomendamos definir esta opção, exceto para aplicações
    somente API, pois isso exige que você adicione e rastreie
    manualmente as dependências JavaScript
  • --no-gettext - não gerar arquivos gettext
  • --no-html - não gerar views HTML
  • --no-live - comentar a configuração do socket LiveView em seu
    Endpoint e assets/js/app.js. Automaticamente desativado se
    --no-html for fornecido
  • --no-mailer - não gerar arquivos do mailer Swoosh
  • --no-tailwind - não incluir dependências e ativos do tailwind.
    O markup gerado ainda incluirá classes CSS do Tailwind, essas
    são mantidas como referência para o estilo subsequente do seu
    layout e componentes
```

O `--no-html` é o óbvio que queremos usar ao criar qualquer aplicação Phoenix para uma API, a fim de deixar de fora todo o scaffolding HTML desnecessário. Você também pode passar `--no-assets`, se não quiser nenhuma parte do gerenciamento de ativos, `--no-gettext` se não suportar internacionalização, e assim por diante.

Tenha em mente também que nada o impede de ter um backend que suporte simultaneamente a API REST e um aplicativo Web (HTML, ativos, internacionalização e sockets).
