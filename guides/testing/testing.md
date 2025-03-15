# Introdução aos Testes

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

Testar tornou-se parte integral do processo de desenvolvimento de software, e a capacidade de escrever facilmente testes significativos é uma característica indispensável para qualquer framework web moderno. O Phoenix leva isso a sério, fornecendo arquivos de suporte para facilitar o teste de todos os principais componentes do framework. Ele também gera módulos de teste com exemplos do mundo real junto com quaisquer módulos gerados para nos ajudar a começar.

O Elixir vem com um framework de testes integrado chamado [ExUnit](https://hexdocs.pm/ex_unit). O ExUnit se esforça para ser claro e explícito, mantendo a mágica ao mínimo. O Phoenix usa o ExUnit para todos os seus testes, e nós também o usaremos aqui.

## Executando testes

Quando o Phoenix gera uma aplicação web para nós, ele também inclui testes. Para executá-los, simplesmente digite `mix test`:

```console
$ mix test
....

Finished in 0.09 seconds
5 tests, 0 failures

Randomized with seed 652656
```

Já temos cinco testes!

Na verdade, já temos uma estrutura de diretórios completamente configurada para testes, incluindo um helper de teste e arquivos de suporte.

```console
test
├── hello_web
│   └── controllers
│       ├── error_html_test.exs
│       ├── error_json_test.exs
│       └── page_controller_test.exs
├── support
│   ├── conn_case.ex
│   └── data_case.ex
└── test_helper.exs
```

Os casos de teste que obtemos gratuitamente incluem aqueles de `test/hello_web/controllers/`. Eles estão testando nossos controladores e views. Se você não leu os guias para controladores e views, agora é um bom momento.

## Entendendo os módulos de teste

Vamos usar as próximas seções para nos familiarizar com a estrutura de testes do Phoenix. Começaremos com os três arquivos de teste gerados pelo Phoenix.

O primeiro arquivo de teste que veremos é `test/hello_web/controllers/page_controller_test.exs`.

```elixir
defmodule HelloWeb.PageControllerTest do
  use HelloWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
```

Existem algumas coisas interessantes acontecendo aqui.

Nossos arquivos de teste simplesmente definem módulos. No topo de cada módulo, você encontrará uma linha como:

```elixir
use HelloWeb.ConnCase
```

Se você estivesse escrevendo uma biblioteca Elixir, fora do Phoenix, em vez de `use HelloWeb.ConnCase`, você escreveria `use ExUnit.Case`. No entanto, o Phoenix já vem com várias funcionalidades para testar controladores e `HelloWeb.ConnCase` constrói sobre `ExUnit.Case` para trazer essas funcionalidades. Exploraremos o módulo `HelloWeb.ConnCase` em breve.

Em seguida, definimos cada teste usando a macro `test/3`. A macro `test/3` recebe três argumentos: o nome do teste, o contexto de teste que estamos fazendo pattern matching e o conteúdo do teste. Neste teste, acessamos a página raiz de nossa aplicação através de uma requisição HTTP "GET" no caminho "/" com a macro `get/2`. Então nós **afirmamos** que a página renderizada contém a string "Peace of mind from prototype to production".

Ao escrever testes em Elixir, usamos asserções para verificar se algo é verdadeiro. Em nosso caso, `assert html_response(conn, 200) =~ "Peace of mind from prototype to production"` está fazendo algumas coisas:

  * Afirma que `conn` renderizou uma resposta
  * Afirma que a resposta tem o código de status 200 (que significa OK no jargão HTTP)
  * Afirma que o tipo da resposta é HTML
  * Afirma que o resultado de `html_response(conn, 200)`, que é uma resposta HTML, contém a string "Peace of mind from prototype to production"

No entanto, de onde vem o `conn` que usamos em `get` e `html_response`? Para responder a esta pergunta, vamos dar uma olhada em `HelloWeb.ConnCase`.

## O ConnCase

Se você abrir `test/support/conn_case.ex`, encontrará isto (com comentários removidos):

```elixir
defmodule HelloWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint HelloWeb.Endpoint

      use HelloWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import HelloWeb.ConnCase
    end
  end
  
  setup tags do
    Hello.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

Há muito para descompactar aqui.

A segunda linha diz que este é um template de caso. Esta é uma funcionalidade do ExUnit que permite aos desenvolvedores substituir o `use ExUnit.Case` integrado pelo seu próprio caso. Esta linha é basicamente o que nos permite escrever `use HelloWeb.ConnCase` no topo de nossos testes de controlador.

Agora que tornamos este módulo um template de caso, podemos definir callbacks que são invocados em certas ocasiões. O callback `using` define código a ser injetado em cada módulo que chama `use HelloWeb.ConnCase`. Neste caso, ele começa definindo o atributo de módulo `@endpoint` com o nome do nosso endpoint.

Em seguida, ele conecta `:verified_routes` para permitir que usemos caminhos baseados em `~p` em nosso teste, assim como fazemos no resto de nossa aplicação, para gerar facilmente caminhos e URLs em nossos testes.

Finalmente, importamos [`Plug.Conn`](https://hexdocs.pm/plug/Plug.Conn.html), para que todos os helpers de conexão disponíveis nos controladores também estejam disponíveis nos testes, e então importamos [`Phoenix.ConnTest`](https://hexdocs.pm/phoenix/Phoenix.ConnTest.html). Você pode consultar esses módulos para aprender todas as funcionalidades disponíveis.

Em seguida, nosso template de caso define um bloco `setup`. O bloco `setup` será chamado antes do teste. A maior parte do bloco de configuração está configurando o SQL Sandbox, sobre o qual falaremos mais tarde. Na última linha do bloco `setup`, encontraremos isto:

```elixir
{:ok, conn: Phoenix.ConnTest.build_conn()}
```

A última linha de `setup` pode retornar metadados de teste que estarão disponíveis em cada teste. Os metadados que estamos passando adiante aqui são uma conexão `Plug.Conn` recém-construída. Em nosso teste, extraímos a conexão desses metadados logo no início do nosso teste:

```elixir
test "GET /", %{conn: conn} do
```

E é daí que vem a conexão! No início, a estrutura de testes vem com um pouco de indireção, mas essa indireção compensa à medida que nossa suíte de testes cresce, pois nos permite reduzir a quantidade de código repetitivo.

## Testes de View

Os outros arquivos de teste em nossa aplicação são responsáveis por testar nossas views.

O caso de teste da view de erro, `test/hello_web/controllers/error_html_test.exs`, ilustra algumas coisas interessantes próprias.

```elixir
defmodule HelloWeb.ErrorHTMLTest do
  use HelloWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(HelloWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(HelloWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
```

`HelloWeb.ErrorHTMLTest` define `async: true`, o que significa que este caso de teste será executado em paralelo com outros casos de teste. Embora os testes individuais dentro do caso ainda sejam executados serialmente, isso pode aumentar bastante a velocidade geral dos testes.

Ele também importa `Phoenix.Template` para usar a função `render_to_string/4`. Com isso, todas as asserções podem ser simples testes de igualdade de strings.

## Executando testes por diretório/arquivo

Agora que temos uma ideia do que nossos testes estão fazendo, vamos olhar para diferentes maneiras de executá-los.

Como vimos perto do início deste guia, podemos executar toda a nossa suíte de testes com `mix test`.

```console
$ mix test
....

Finished in 0.2 seconds
5 tests, 0 failures

Randomized with seed 540755
```

Se quisermos executar todos os testes em um determinado diretório, `test/hello_web/controllers` por exemplo, podemos passar o caminho para esse diretório para `mix test`.

```console
$ mix test test/hello_web/controllers/
.

Finished in 0.2 seconds
5 tests, 0 failures

Randomized with seed 652376
```

Para executar todos os testes em um arquivo específico, podemos passar o caminho para esse arquivo para `mix test`.

```console
$ mix test test/hello_web/controllers/error_html_test.exs
...

Finished in 0.2 seconds
2 tests, 0 failures

Randomized with seed 220535
```

E podemos executar um único teste em um arquivo adicionando dois pontos e um número de linha ao nome do arquivo.

Digamos que só queremos executar o teste para a forma como `HelloWeb.ErrorHTML` renderiza `500.html`. O teste começa na linha 11 do arquivo, então é assim que faríamos:

```console
$ mix test test/hello_web/controllers/error_html_test.exs:11
Including tags: [line: "11"]
Excluding tags: [:test]

.

Finished in 0.1 seconds
2 tests, 0 failures, 1 excluded

Randomized with seed 288117
```

Escolhemos executar isso especificando a primeira linha do teste, mas na verdade, qualquer linha desse teste servirá. Esses números de linha funcionariam - `:11`, `:12` ou `:13`.

## Executando testes usando tags

O ExUnit nos permite marcar nossos testes individualmente ou para todo o módulo. Podemos então escolher executar apenas os testes com uma tag específica, ou podemos excluir testes com essa tag e executar todo o resto.

Vamos experimentar como isso funciona.

Primeiro, vamos adicionar um `@moduletag` a `test/hello_web/controllers/error_html_test.exs`.

```elixir
defmodule HelloWeb.ErrorHTMLTest do
  use HelloWeb.ConnCase, async: true

  @moduletag :error_view_case
  ...
end
```

Se usarmos apenas um átomo para nossa tag de módulo, o ExUnit assume que ele tem um valor de `true`. Também poderíamos especificar um valor diferente se quiséssemos.

```elixir
defmodule HelloWeb.ErrorHTMLTest do
  use HelloWeb.ConnCase, async: true

  @moduletag error_view_case: "some_interesting_value"
  ...
end
```

Por enquanto, vamos deixá-lo como um simples átomo `@moduletag :error_view_case`.

Podemos executar apenas os testes do caso de view de erro passando `--only error_view_case` para `mix test`.

```console
$ mix test --only error_view_case
Including tags: [:error_view_case]
Excluding tags: [:test]

...

Finished in 0.1 seconds
5 tests, 0 failures, 3 excluded

Randomized with seed 125659
```

> Nota: O ExUnit nos diz exatamente quais tags está incluindo e excluindo para cada execução de teste. Se olharmos de volta para a seção anterior sobre execução de testes, veremos que os números de linha especificados para testes individuais são realmente tratados como tags.

```console
$ mix test test/hello_web/controllers/error_html_test.exs:11
Including tags: [line: "11"]
Excluding tags: [:test]

.

Finished in 0.2 seconds
2 tests, 0 failures, 1 excluded

Randomized with seed 364723
```

Especificar um valor de `true` para `error_view_case` gera os mesmos resultados.

```console
$ mix test --only error_view_case:true
Including tags: [error_view_case: "true"]
Excluding tags: [:test]

...

Finished in 0.1 seconds
5 tests, 0 failures, 3 excluded

Randomized with seed 833356
```

Especificar `false` como valor para `error_view_case`, no entanto, não executará nenhum teste porque nenhuma tag em nosso sistema corresponde a `error_view_case: false`.

```console
$ mix test --only error_view_case:false
Including tags: [error_view_case: "false"]
Excluding tags: [:test]



Finished in 0.1 seconds
5 tests, 0 failures, 5 excluded

Randomized with seed 622422
The --only option was given to "mix test" but no test executed
```

Podemos usar a flag `--exclude` de maneira similar. Isso executará todos os testes, exceto aqueles no caso de view de erro.

```console
$ mix test --exclude error_view_case
Excluding tags: [:error_view_case]

.

Finished in 0.2 seconds
5 tests, 0 failures, 2 excluded

Randomized with seed 682868
```

Especificar valores para uma tag funciona da mesma maneira para `--exclude` como funciona para `--only`.

Podemos marcar testes individuais, assim como casos de teste completos. Vamos marcar alguns testes no caso de view de erro para ver como isso funciona.

```elixir
defmodule HelloWeb.ErrorHTMLTest do
  use HelloWeb.ConnCase, async: true

  @moduletag :error_view_case

  # Bring render/4 and render_to_string/4 for testing custom views
  import Phoenix.Template

  @tag individual_test: "yup"
  test "renders 404.html" do
    assert render_to_string(HelloWeb.ErrorView, "404", "html", []) ==
           "Not Found"
  end

  @tag individual_test: "nope"
  test "renders 500.html" do
    assert render_to_string(HelloWeb.ErrorView, "500", "html", []) ==
           "Internal Server Error"
  end
end
```

Se quisermos executar apenas testes marcados como `individual_test`, independentemente de seu valor, isso funcionará.

```console
$ mix test --only individual_test
Including tags: [:individual_test]
Excluding tags: [:test]

..

Finished in 0.1 seconds
5 tests, 0 failures, 3 excluded

Randomized with seed 813729
```

Também podemos especificar um valor e executar apenas testes com esse valor.

```console
$ mix test --only individual_test:yup
Including tags: [individual_test: "yup"]
Excluding tags: [:test]

.

Finished in 0.1 seconds
5 tests, 0 failures, 4 excluded

Randomized with seed 770938
```

Da mesma forma, podemos executar todos os testes, exceto aqueles marcados com um determinado valor.

```console
$ mix test --exclude individual_test:nope
Excluding tags: [individual_test: "nope"]

...

Finished in 0.2 seconds
5 tests, 0 failures, 1 excluded

Randomized with seed 539324
```

Podemos ser mais específicos e excluir todos os testes do caso de view de erro, exceto aquele marcado com `individual_test` que tem o valor "yup".

```console
$ mix test --exclude error_view_case --include individual_test:yup
Including tags: [individual_test: "yup"]
Excluding tags: [:error_view_case]

..

Finished in 0.2 seconds
5 tests, 0 failures, 1 excluded

Randomized with seed 61472
```

Finalmente, podemos configurar o ExUnit para excluir tags por padrão. A configuração padrão do ExUnit é feita no arquivo `test/test_helper.exs`:

```elixir
ExUnit.start(exclude: [error_view_case: true])

Ecto.Adapters.SQL.Sandbox.mode(Hello.Repo, :manual)
```

Agora, quando executamos `mix test`, ele executa apenas as especificações de `page_controller_test.exs` e `error_json_test.exs`.

```console
$ mix test
Excluding tags: [error_view_case: true]

.

Finished in 0.2 seconds
5 tests, 0 failures, 2 excluded

Randomized with seed 186055
```

Podemos substituir esse comportamento com a flag `--include`, informando ao `mix test` para incluir testes marcados com `error_view_case`.

```console
$ mix test --include error_view_case
Including tags: [:error_view_case]
Excluding tags: [error_view_case: true]

....

Finished in 0.2 seconds
5 tests, 0 failures

Randomized with seed 748424
```

Esta técnica pode ser muito útil para controlar testes de execução muito longa, os quais você pode querer executar apenas em CI ou em cenários específicos.

## Aleatorização

Executar testes em ordem aleatória é uma boa maneira de garantir que nossos testes estejam realmente isolados. Se notarmos que obtemos falhas esporádicas para um determinado teste, pode ser porque um teste anterior altera o estado do sistema de maneiras que não são limpas posteriormente, afetando assim os testes que seguem. Essas falhas podem se apresentar apenas se os testes forem executados em uma ordem específica.

O ExUnit aleatoriza a ordem dos testes por padrão, usando um número inteiro para semear a aleatorização. Se notarmos que uma semente aleatória específica desencadeia nossa falha intermitente, podemos reexecutar os testes com a mesma semente para recriar de forma confiável essa sequência de teste, a fim de nos ajudar a descobrir qual é o problema.

```console
$ mix test --seed 401472
....

Finished in 0.2 seconds
5 tests, 0 failures

Randomized with seed 401472
```

## Concorrência e particionamento

Como vimos, o ExUnit permite que os desenvolvedores executem testes simultaneamente. Isso permite que os desenvolvedores usem todo o poder em suas máquinas para executar suas suítes de teste o mais rápido possível. Junte isso ao desempenho do Phoenix, a maioria das suítes de teste compila e executa em uma fração do tempo em comparação com outros frameworks.

Embora os desenvolvedores geralmente tenham máquinas poderosas disponíveis para eles durante o desenvolvimento, esse pode nem sempre ser o caso em seus servidores de Integração Contínua. Por essa razão, o ExUnit também suporta o particionamento de testes nativamente em ambientes de teste. Se você abrir seu `config/test.exs`, encontrará o nome do banco de dados definido como:

```elixir
database: "hello_test#{System.get_env("MIX_TEST_PARTITION")}",
```

Por padrão, a variável de ambiente `MIX_TEST_PARTITION` não tem valor e, portanto, não tem efeito. Mas em seu servidor de CI, você pode, por exemplo, dividir sua suíte de testes entre máquinas usando quatro comandos distintos:

```console
$ MIX_TEST_PARTITION=1 mix test --partitions 4
$ MIX_TEST_PARTITION=2 mix test --partitions 4
$ MIX_TEST_PARTITION=3 mix test --partitions 4
$ MIX_TEST_PARTITION=4 mix test --partitions 4
```

Isso é tudo o que você precisa fazer e o ExUnit e o Phoenix cuidarão de todo o resto, incluindo a configuração do banco de dados para cada partição distinta com um nome distinto.

## Indo além

Embora o ExUnit seja um framework de teste simples, ele fornece um executor de teste realmente flexível e robusto através do comando `mix test`. Recomendamos que você execute `mix help test` ou [leia a documentação online](https://hexdocs.pm/mix/Mix.Tasks.Test.html)

Vimos o que o Phoenix nos dá com um aplicativo recém-gerado. Além disso, sempre que você gera um novo recurso, o Phoenix também gerará todos os testes apropriados para esse recurso. Por exemplo, você pode criar um scaffold completo com schema, contexto, controladores e views executando o seguinte comando na raiz de sua aplicação:

```console
$ mix phx.gen.html Blog Post posts title body:text
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/controllers/post_html/edit.html.heex
* creating lib/hello_web/controllers/post_html/index.html.heex
* creating lib/hello_web/controllers/post_html/new.html.heex
* creating lib/hello_web/controllers/post_html/show.html.heex
* creating lib/hello_web/controllers/post_html/post_form.html.heex
* creating lib/hello_web/controllers/post_html.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello/blog/post.ex
* creating priv/repo/migrations/20211001233016_create_posts.exs
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog_test.exs
* injecting test/hello/blog_test.exs
* creating test/support/fixtures/blog_fixtures.ex
* injecting test/support/fixtures/blog_fixtures.ex

Add the resource to your browser scope in lib/demo_web/router.ex:

    resources "/posts", PostController


Remember to update your repository by running migrations:

    $ mix ecto.migrate

```

Agora, vamos seguir as instruções e adicionar a nova rota de recursos ao nosso arquivo `lib/hello_web/router.ex` e executar as migrações.

Quando executamos `mix test` novamente, vemos que agora temos vinte e um testes!

```console
$ mix test
................

Finished in 0.1 seconds
21 tests, 0 failures

Randomized with seed 537537
```

Neste ponto, estamos em um ótimo lugar para transição para o resto dos guias de teste, nos quais examinaremos esses testes em muito mais detalhes e adicionaremos alguns dos nossos próprios.
