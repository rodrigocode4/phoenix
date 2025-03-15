# Testando Controllers

> **Requisito**: Este guia pressupõe que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [instalada e funcionando](up_and_running.html).

> **Requisito**: Este guia pressupõe que você tenha passado pelo [Guia de Introdução a Testes](testing.html).

No final do guia de Introdução a Testes, geramos um recurso HTML para posts usando o seguinte comando:

```console
$ mix phx.gen.html Blog Post posts title body:text
```

Isso nos deu vários módulos gratuitamente, incluindo um PostController e os testes associados. Vamos explorar esses testes para aprender mais sobre como testar controllers em geral. No final do guia, vamos gerar um recurso JSON e explorar como são nossos testes de API.

## Testes de controller HTML

Se você abrir o arquivo `test/hello_web/controllers/post_controller_test.exs`, você encontrará o seguinte:

```elixir
defmodule HelloWeb.PostControllerTest do
  use HelloWeb.ConnCase

  import Hello.BlogFixtures

  @create_attrs %{body: "some body", title: "some title"}
  @update_attrs %{body: "some updated body", title: "some updated title"}
  @invalid_attrs %{body: nil, title: nil}
  
  describe "index" do
    test "lists all posts", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "Listing Posts"
    end
  end

  ...
```

Semelhante ao `PageControllerTest` que vem com nossa aplicação, este teste de controller usa `use HelloWeb.ConnCase` para configurar a estrutura de testes. Em seguida, como de costume, ele define alguns aliases, alguns atributos de módulo para usar durante os testes e, então, começa uma série de blocos `describe`, cada um deles para testar uma ação diferente do controller.

### A ação index

O primeiro bloco describe é para a ação `index`. A própria ação é implementada da seguinte forma em `lib/hello_web/controllers/post_controller.ex`:

```elixir
def index(conn, _params) do
  posts = Blog.list_posts()
  render(conn, :index, posts: posts)
end
```

Ela obtém todos os posts e renderiza o template "index.html". O template pode ser encontrado em `lib/hello_web/templates/page/index.html.heex`.

O teste se parece com isto:

```elixir
describe "index" do
  test "lists all posts", %{conn: conn} do
    conn = get(conn, ~p"/posts")
    assert html_response(conn, 200) =~ "Listing Posts"
  end
end
```

O teste para a página `index` é bastante direto. Ele usa o helper `get/2` para fazer uma requisição à página `"/posts"`, que é verificada em nosso router no teste graças ao `~p`, então verificamos se recebemos uma resposta HTML bem-sucedida e fazemos a correspondência com seu conteúdo.

### A ação create

O próximo teste que vamos analisar é o da ação `create`. A implementação da ação `create` é esta:

```elixir
def create(conn, %{"post" => post_params}) do
  case Blog.create_post(post_params) do
    {:ok, post} ->
      conn
      |> put_flash(:info, "Post created successfully.")
      |> redirect(to: ~p"/posts/#{post}")

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :new, changeset: changeset)
  end
end
```

Como existem dois possíveis resultados para o `create`, teremos pelo menos dois testes:

```elixir
describe "create post" do
  test "redirects to show when data is valid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @create_attrs)

    assert %{id: id} = redirected_params(conn)
    assert redirected_to(conn) == ~p"/posts/#{id}"

    conn = get(conn, ~p"/posts/#{id}")
    assert html_response(conn, 200) =~ "Post #{id}"
  end

  test "renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @invalid_attrs)
    assert html_response(conn, 200) =~ "New Post"
  end
end
```

O primeiro teste começa com uma requisição `post/2`. Isso ocorre porque, uma vez que o formulário na página `/posts/new` é enviado, ele se torna uma requisição POST para a ação create. Como fornecemos atributos válidos, o post deve ter sido criado com sucesso e devemos ter sido redirecionados para a ação show do novo post. Esta nova página terá um endereço como `/posts/ID`, onde ID é o identificador do post no banco de dados.

Em seguida, usamos `redirected_params(conn)` para obter o ID do post e, então, verificamos que realmente redirecionamos para a ação show. Finalmente, fazemos uma requisição `get` para a página para a qual redirecionamos, permitindo-nos verificar que o post foi realmente criado.

Para o segundo teste, simplesmente testamos o cenário de falha. Se qualquer atributo inválido for fornecido, ele deve renderizar novamente a página "New Post".

Uma pergunta comum é: quantos cenários de falha você testa no nível do controller? Por exemplo, no guia [Testando Contexts](testing_contexts.html), introduzimos uma validação para o campo `title` do post:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> validate_required([:title, :body])
  |> validate_length(:title, min: 2)
end
```

Em outras palavras, a criação de um post pode falhar pelas seguintes razões:

  * o título está faltando
  * o corpo está faltando
  * o título está presente, mas tem menos de 2 caracteres

Devemos testar todos esses possíveis resultados em nossos testes de controller?

A resposta é não. Todas as diferentes regras e resultados devem ser verificados em seus testes de contexto e schema. O controller funciona como a camada de integração. Nos testes de controller, simplesmente queremos verificar, em linhas gerais, que lidamos com cenários de sucesso e falha.

O teste para `update` segue uma estrutura semelhante ao `create`, então vamos pular para o teste de `delete`.

### A ação delete

A ação `delete` se parece com isto:

```elixir
def delete(conn, %{"id" => id}) do
  post = Blog.get_post!(id)
  {:ok, _post} = Blog.delete_post(post)

  conn
  |> put_flash(:info, "Post deleted successfully.")
  |> redirect(to: ~p"/posts")
end
```

O teste é escrito assim:

```elixir
  describe "delete post" do
    setup [:create_post]

    test "deletes chosen post", %{conn: conn, post: post} do
      conn = delete(conn, ~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/posts"

      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/#{post}")
      end
    end
  end

  defp create_post(_) do
    post = post_fixture()
    %{post: post}
  end
```

Primeiramente, `setup` é usado para declarar que a função `create_post` deve ser executada antes de cada teste neste bloco `describe`. A função `create_post` simplesmente cria um post e o armazena nos metadados do teste. Isso nos permite, na primeira linha do teste, fazer a correspondência tanto com o post quanto com a conexão:

```elixir
test "deletes chosen post", %{conn: conn, post: post} do
```

O teste usa `delete/2` para excluir o post e, em seguida, verifica que redirecionamos para a página de índice. Finalmente, verificamos que não é mais possível acessar a página de exibição do post excluído:

```elixir
assert_error_sent 404, fn ->
  get(conn, ~p"/posts/#{post}")
end
```

`assert_error_sent` é um auxiliar de teste fornecido por `Phoenix.ConnTest`. Neste caso, ele verifica que:

  1. Uma exceção foi levantada
  2. A exceção tem um código de status equivalente a 404 (que significa Not Found)

Isso imita bastante como o Phoenix lida com exceções. Por exemplo, quando acessamos `/posts/12345` onde `12345` é um ID que não existe, invocaremos nossa ação `show`:

```elixir
def show(conn, %{"id" => id}) do
  post = Blog.get_post!(id)
  render(conn, :show, post: post)
end
```

Quando um ID de post desconhecido é fornecido a `Blog.get_post!/1`, ele levanta um `Ecto.NotFoundError`. Se sua aplicação levantar qualquer exceção durante uma requisição web, o Phoenix traduz essas requisições em códigos de resposta HTTP adequados. Neste caso, 404.

Poderíamos, por exemplo, ter escrito este teste como:

```elixir
assert_raise Ecto.NotFoundError, fn ->
  get(conn, ~p"/posts/#{post}")
end
```

No entanto, você pode preferir a implementação que o Phoenix gera por padrão, pois ela ignora os detalhes específicos da falha e, em vez disso, verifica o que o navegador realmente receberia.

Os testes para as ações `new`, `edit` e `show` são variações mais simples dos testes que vimos até agora. Você pode verificar a implementação da ação e seus respectivos testes por conta própria. Agora estamos prontos para passar para os testes de controller JSON.

## Testes de controller JSON

Até agora, estávamos trabalhando com um recurso HTML gerado. No entanto, vamos dar uma olhada em como nossos testes se parecem quando geramos um recurso JSON.

Primeiro, execute este comando:

```console
$ mix phx.gen.json News Article articles title body
```

Escolhemos um conceito muito semelhante ao context Blog <-> schema Post, exceto que estamos usando um nome diferente, para que possamos estudar esses conceitos isoladamente.

Depois de executar o comando acima, não se esqueça de seguir as etapas finais geradas pelo gerador. Quando tudo estiver pronto, devemos executar `mix test` e agora ter 35 testes passando:

```console
$ mix test
................

Finished in 0.6 seconds
35 tests, 0 failures

Randomized with seed 618478
```

Você pode ter notado que desta vez o controller scaffold gerou menos testes. Anteriormente, ele gerou 16 (passamos de 5 para 21) e agora gerou 14 (passamos de 21 para 35). Isso porque as APIs JSON não precisam expor as ações `new` e `edit`. Podemos ver que é o caso no recurso que adicionamos ao router no final do comando `mix phx.gen.json`:

```elixir
resources "/articles", ArticleController, except: [:new, :edit]
```

`new` e `edit` só são necessários para HTML porque eles basicamente existem para ajudar os usuários a criar e atualizar recursos. Além de ter menos ações, vamos notar que os testes e implementações de controller e view para JSON são drasticamente diferentes dos HTML.

A única coisa que é praticamente a mesma entre HTML e JSON são os contexts e o schema, o que, uma vez que você pensa sobre isso, faz total sentido. Afinal, sua lógica de negócios deve permanecer a mesma, independentemente de você expô-la como HTML ou JSON.

Com as diferenças em mãos, vamos dar uma olhada nos testes de controller.

### A ação index

Abra `test/hello_web/controllers/article_controller_test.exs`. A estrutura inicial é bastante semelhante a `post_controller_test.exs`. Então, vamos dar uma olhada nos testes para a ação `index`. A ação `index` em si é implementada em `lib/hello_web/controllers/article_controller.ex` assim:

```elixir
def index(conn, _params) do
  articles = News.list_articles()
  render(conn, :index, articles: articles)
end
```

A ação obtém todos os artigos e renderiza o template de índice. Como estamos falando de JSON, não temos um template `index.json.heex`. Em vez disso, o código que converte `articles` em JSON pode ser encontrado diretamente no módulo ArticleJSON, definido em `lib/hello_web/controllers/article_json.ex` assim:

```elixir
defmodule HelloWeb.ArticleJSON do
  alias Hello.News.Article

  def index(%{articles: articles}) do
    %{data: for(article <- articles, do: data(article))}
  end

  def show(%{article: article}) do
    %{data: data(article)}
  end

  defp data(%Article{} = article) do
    %{
      id: article.id,
      title: article.title,
      body: article.body
    }
  end
end
```

Como um render de controller é uma chamada de função regular, não precisamos de recursos extras para renderizar JSON. Simplesmente definimos funções para nossas ações `index` e `show` que retornam o mapa de JSON para artigos.

Vamos dar uma olhada no teste para a ação `index` então:

```elixir
describe "index" do
  test "lists all articles", %{conn: conn} do
    conn = get(conn, ~p"/api/articles")
    assert json_response(conn, 200)["data"] == []
  end
end
```

Ele simplesmente acessa o caminho `index`, afirma que recebemos uma resposta JSON com status 200 e que ela contém uma chave "data" com uma lista vazia, já que não temos artigos para retornar.

Isso foi bastante monótono. Vamos olhar para algo mais interessante.

### A ação `create`

A ação `create` é definida assim:

```elixir
def create(conn, %{"article" => article_params}) do
  with {:ok, %Article{} = article} <- News.create_article(article_params) do
    conn
    |> put_status(:created)
    |> put_resp_header("location", ~p"/api/articles/#{article}")
    |> render(:show, article: article)
  end
end
```

Como podemos ver, ela verifica se um artigo pôde ser criado. Se sim, ela define o código de status como `:created` (que se traduz em 201), define um cabeçalho "location" com a localização do artigo e, em seguida, renderiza "show.json" com o artigo.

Isso é precisamente o que o primeiro teste para a ação `create` verifica:

```elixir
describe "create article" do
  test "renders article when data is valid", %{conn: conn} do
    conn = post(conn, ~p"/articles", article: @create_attrs)
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get(conn, ~p"/api/articles/#{id}")

    assert %{
             "id" => ^id,
             "body" => "some body",
             "title" => "some title"
           } = json_response(conn, 200)["data"]
  end
```

O teste usa `post/2` para criar um novo artigo e, em seguida, verificamos que o artigo retornou uma resposta JSON, com status 201, e que tinha uma chave "data" nela. Fazemos a correspondência de padrão da "data" em `%{"id" => id}`, o que nos permite extrair o ID do novo artigo. Em seguida, realizamos uma requisição `get/2` na rota `show` e verificamos se o artigo foi criado com sucesso.

Dentro de `describe "create article"`, encontraremos outro teste, que lida com o cenário de falha. Você consegue identificar o cenário de falha na ação `create`? Vamos recapitular:

```elixir
def create(conn, %{"article" => article_params}) do
  with {:ok, %Article{} = article} <- News.create_article(article_params) do
```

A forma especial `with` que vem como parte do Elixir nos permite verificar explicitamente os caminhos felizes. Neste caso, estamos interessados apenas nos cenários em que `News.create_article(article_params)` retorna `{:ok, article}`, se retornar qualquer outra coisa, o outro valor simplesmente será retornado diretamente e nenhum dos conteúdos dentro do bloco `do/end` será executado. Em outras palavras, se `News.create_article/1` retornar `{:error, changeset}`, simplesmente retornaremos `{:error, changeset}` da ação.

No entanto, isso introduz um problema. Nossas ações não sabem como lidar com o resultado `{:error, changeset}` por padrão. Felizmente, podemos ensinar Controllers Phoenix a lidar com isso com o controller Action Fallback. No topo de `ArticleController`, você encontrará:

```elixir
  action_fallback HelloWeb.FallbackController
```

Esta linha diz: se qualquer ação não retornar um `%Plug.Conn{}`, queremos invocar `FallbackController` com o resultado. Você encontrará `HelloWeb.FallbackController` em `lib/hello_web/controllers/fallback_controller.ex` e ele se parece com isto:

```elixir
defmodule HelloWeb.FallbackController do
  use HelloWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HelloWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: HelloWeb.ErrorHTML, json: HelloWeb.ErrorJSON)
    |> render(:"404")
  end
end
```

Você pode ver como a primeira cláusula da função `call/2` lida com o caso `{:error, changeset}`, definindo o código de status como unprocessable entity (422) e, em seguida, renderizando "error.json" da view changeset com o changeset com falha.

Com isso em mente, vamos olhar para nosso segundo teste para `create`:

```elixir
test "renders errors when data is invalid", %{conn: conn} do
  conn = post(conn, ~p"/api/articles", article: @invalid_attrs)
  assert json_response(conn, 422)["errors"] != %{}
end
```

Ele simplesmente faz um post para o caminho `create` com parâmetros inválidos. Isso faz com que retorne uma resposta JSON, com código de status 422, e uma resposta com uma chave "errors" não vazia.

O `action_fallback` pode ser extremamente útil para reduzir o código padrão ao projetar APIs. Você pode aprender mais sobre o "Action Fallback" no [guia de Controllers](controllers.html).

### A ação `delete`

Finalmente, a última ação que vamos estudar é a ação `delete` para JSON. Sua implementação se parece com isto:

```elixir
def delete(conn, %{"id" => id}) do
  article = News.get_article!(id)

  with {:ok, %Article{}} <- News.delete_article(article) do
    send_resp(conn, :no_content, "")
  end
end
```

A nova ação simplesmente tenta excluir o artigo e, se tiver sucesso, retorna uma resposta vazia com código de status `:no_content` (204).

O teste se parece com isto:

```elixir
describe "delete article" do
  setup [:create_article]

  test "deletes chosen article", %{conn: conn, article: article} do
    conn = delete(conn, ~p"/api/articles/#{article}")
    assert response(conn, 204)

    assert_error_sent 404, fn ->
      get(conn, ~p"/api/articles/#{article}")
    end
  end
end

defp create_article(_) do
  article = article_fixture()
  %{article: article}
end
```

Ele configura um novo artigo, então no teste invoca o caminho `delete` para excluí-lo, afirmando uma resposta 204, que não é nem JSON nem HTML. Depois, verifica que não podemos mais acessar o referido artigo.

É isso!

Agora que entendemos como o código gerado e seus testes funcionam para APIs HTML e JSON, estamos preparados para avançar na construção e manutenção de nossas aplicações web!
