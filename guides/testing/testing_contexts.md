# Testando Contextos

> **Requisito**: Este guia pressupõe que você tenha lido os [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia pressupõe que você tenha lido o [Guia de Introdução a Testes](testing.html).

> **Requisito**: Este guia pressupõe que você tenha lido o [Guia de Contextos](contexts.html).

No final do guia de Introdução a Testes, geramos um recurso HTML para posts usando o seguinte comando:

```console
$ mix phx.gen.html Blog Post posts title body:text
```

Isso nos deu vários módulos gratuitamente, incluindo um contexto Blog e um esquema Post, junto com seus respectivos arquivos de teste. Como aprendemos no guia de Contexto, o contexto Blog é simplesmente um módulo com funções para uma área específica do nosso domínio de negócios, enquanto o esquema Post mapeia para uma tabela específica em nosso banco de dados.

Neste guia, vamos explorar os testes gerados para nossos contextos e esquemas. Antes de fazer qualquer outra coisa, vamos executar `mix test` para garantir que nossa suíte de testes esteja funcionando sem problemas.

```console
$ mix test
................

Finished in 0.6 seconds
21 tests, 0 failures

Randomized with seed 638414
```

Ótimo. Temos vinte e um testes e todos estão passando!

## Testando posts

Se você abrir `test/hello/blog_test.exs`, verá um arquivo com o seguinte conteúdo:

```elixir
defmodule Hello.BlogTest do
  use Hello.DataCase

  alias Hello.Blog

  describe "posts" do
    alias Hello.Blog.Post

    import Hello.BlogFixtures

    @invalid_attrs %{body: nil, title: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Blog.list_posts() == [post]
    end

    ...
```

No topo do arquivo, importamos `Hello.DataCase`, que, como veremos em breve, é semelhante ao `HelloWeb.ConnCase`. Enquanto `HelloWeb.ConnCase` configura auxiliares para trabalhar com conexões, o que é útil ao testar controladores e visualizações, `Hello.DataCase` fornece funcionalidade para trabalhar com contextos e esquemas.

Em seguida, definimos um alias, para que possamos nos referir a `Hello.Blog` simplesmente como `Blog`.

Então começamos um bloco `describe "posts"`. Um bloco `describe` é um recurso no ExUnit que nos permite agrupar testes semelhantes. A razão pela qual agrupamos todos os testes relacionados a posts é porque os contextos no Phoenix são capazes de agrupar múltiplos esquemas. Por exemplo, se executarmos este comando:

```console
$ mix phx.gen.html Blog Comment comments post_id:references:posts body:text
```

Obteremos um monte de novas funções no contexto `Hello.Blog`, além de um novo bloco `describe "comments"` em nosso arquivo de teste.

Os testes definidos para nosso contexto são muito diretos. Eles chamam as funções em nosso contexto e afirmam sobre seus resultados. Como você pode ver, alguns desses testes até criam entradas no banco de dados:

```elixir
test "create_post/1 with valid data creates a post" do
  valid_attrs = %{body: "some body", title: "some title"}

  assert {:ok, %Post{} = post} = Blog.create_post(valid_attrs)
  assert post.body == "some body"
  assert post.title == "some title"
end
```

Neste ponto, você pode se perguntar: como o Phoenix pode garantir que os dados criados em um dos testes não afetem outros testes? Ficamos felizes que você tenha perguntado. Para responder a esta pergunta, vamos falar sobre o `DataCase`.

## O DataCase

Se você abrir `test/support/data_case.ex`, encontrará o seguinte:

```elixir
defmodule Hello.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Hello.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Hello.DataCase
    end
  end

  setup tags do
    Hello.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Hello.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    ...
  end
end
```

`Hello.DataCase` é outro `ExUnit.CaseTemplate`. No bloco `using`, podemos ver todos os aliases e importações que o `DataCase` traz para nossos testes. O trecho `setup` para `DataCase` é muito semelhante ao de `ConnCase`. Como podemos ver, a maior parte do bloco `setup` gira em torno da configuração de um SQL Sandbox.

O SQL Sandbox é precisamente o que permite que nossos testes escrevam no banco de dados sem afetar nenhum dos outros testes. Em resumo, no início de cada teste, iniciamos uma transação no banco de dados. Quando o teste termina, revertemos automaticamente a transação, efetivamente apagando todos os dados criados no teste.

Além disso, o SQL Sandbox permite que vários testes sejam executados simultaneamente, mesmo que se comuniquem com o banco de dados. Esse recurso é fornecido para bancos de dados PostgreSQL e pode ser usado para acelerar ainda mais seus testes de contextos e controladores, adicionando uma flag `async: true` ao usá-los:

```elixir
use Hello.DataCase, async: true
```

Existem algumas considerações que você precisa ter em mente ao executar testes assíncronos com o sandbox, então consulte [`Ecto.Adapters.SQL.Sandbox`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html) para mais informações.

Finalmente, no final do módulo `DataCase`, podemos encontrar uma função chamada `errors_on` com alguns exemplos de como usá-la. Esta função é usada para testar qualquer validação que possamos querer adicionar aos nossos esquemas. Vamos experimentá-la adicionando nossas próprias validações e depois testando-as.

## Testando esquemas

Quando geramos nosso recurso HTML Post, o Phoenix gerou um contexto Blog e um esquema Post. Ele gerou um arquivo de teste para o contexto, mas nenhum arquivo de teste para o esquema. No entanto, isso não significa que não precisamos testar o esquema, apenas significa que não tivemos que testar o esquema até agora.

Você pode estar se perguntando: quando testamos o contexto diretamente e quando testamos o esquema diretamente? A resposta a esta pergunta é a mesma resposta à pergunta de quando adicionamos código a um contexto e quando o adicionamos ao esquema?

A diretriz geral é manter todo o código livre de efeitos colaterais no esquema. Em outras palavras, se você está simplesmente trabalhando com estruturas de dados, esquemas e changesets, coloque-o no esquema. O contexto normalmente terá o código que cria e atualiza esquemas e depois os escreve em um banco de dados ou uma API.

Vamos adicionar validações adicionais ao módulo de esquema, o que é uma ótima oportunidade para escrever alguns testes específicos de esquema. Abra `lib/hello/blog/post.ex` e adicione a seguinte validação ao `def changeset`:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> validate_required([:title, :body])
  |> validate_length(:title, min: 2)
end
```

A nova validação diz que o título precisa ter pelo menos 2 caracteres. Vamos escrever um teste para isso. Crie um novo arquivo em `test/hello/blog/post_test.exs` com isto:

```elixir
defmodule Hello.Blog.PostTest do
  use Hello.DataCase, async: true
  alias Hello.Blog.Post

  test "title must be at least two characters long" do
    changeset = Post.changeset(%Post{}, %{title: "I"})
    assert %{title: ["should be at least 2 character(s)"]} = errors_on(changeset)
  end
end
```

E é isso. À medida que nosso domínio de negócios cresce, temos lugares bem definidos para testar nossos contextos e esquemas.
