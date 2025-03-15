# Contextos

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia de ciclo de vida da requisição](request_lifecycle.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia do Ecto](ecto.html).

Até agora, construímos páginas, conectamos ações do controlador através de nossos roteadores e aprendemos como o Ecto permite que os dados sejam validados e persistidos. Agora é hora de amarrar tudo isso escrevendo recursos voltados para a web que interagem com nossa aplicação Elixir mais ampla.

Ao construir um projeto Phoenix, estamos, antes de tudo, construindo uma aplicação Elixir. O trabalho do Phoenix é fornecer uma interface web para nossa aplicação Elixir. Naturalmente, compomos nossas aplicações com módulos e funções, mas frequentemente atribuímos responsabilidades específicas a certos módulos e lhes damos nomes: como controladores, roteadores e live views.

Como todo o resto, contextos no Phoenix são módulos, mas com a responsabilidade distinta de estabelecer limites e agrupar funcionalidades. Em outras palavras, eles nos permitem raciocinar e discutir sobre o design da aplicação.

## Pensando sobre contextos

Contextos são módulos dedicados que expõem e agrupam funcionalidades relacionadas. Por exemplo, sempre que você chama a biblioteca padrão do Elixir, seja `Logger.info/1` ou `Stream.map/2`, você está acessando diferentes contextos. Internamente, o logger do Elixir é composto por vários módulos, mas nunca interagimos com esses módulos diretamente. Chamamos o módulo `Logger` de contexto, exatamente porque ele expõe e agrupa toda a funcionalidade de logging.

Ao dar aos módulos que expõem e agrupam funcionalidades relacionadas o nome de **contextos**, ajudamos os desenvolvedores a identificar esses padrões e falar sobre eles. No final das contas, contextos são apenas módulos, assim como seus controladores, views, etc.

No Phoenix, contextos frequentemente encapsulam acesso a dados e validação de dados. Eles frequentemente se comunicam com um banco de dados ou APIs. Em geral, pense neles como limites para desacoplar e isolar partes de sua aplicação. Vamos usar essas ideias para construir nossa aplicação web. Nosso objetivo é construir um sistema de e-commerce onde possamos mostrar produtos, permitir que os usuários adicionem produtos ao carrinho e completem seus pedidos.

### Adicionando um Contexto de Catálogo

Uma plataforma de e-commerce tem acoplamento de amplo alcance em todo o código, por isso é importante pensar em escrever módulos bem definidos. Com isso em mente, nosso objetivo é construir uma API de catálogo de produtos que lide com a criação, atualização e exclusão dos produtos disponíveis em nosso sistema. Começaremos com os recursos básicos de exibição de nossos produtos, e adicionaremos recursos de carrinho de compras mais tarde. Veremos como começar com uma base sólida com limites isolados nos permite crescer nossa aplicação naturalmente à medida que adicionamos funcionalidades.

O Phoenix inclui os geradores `mix phx.gen.html`, `mix phx.gen.json`, `mix phx.gen.live`, e `mix phx.gen.context` que aplicam as ideias de isolar funcionalidades em nossas aplicações em contextos. Esses geradores são uma ótima maneira de começar rapidamente enquanto o Phoenix nos orienta na direção certa para crescer nossa aplicação. Vamos usar essas ferramentas para nosso novo contexto de catálogo de produtos.

Para executar os geradores de contexto, precisamos criar um nome de módulo que agrupe a funcionalidade relacionada que estamos construindo. No [guia do Ecto](ecto.html), vimos como podemos usar Changesets e Repos para validar e persistir esquemas de usuário, mas não integramos isso com nossa aplicação como um todo. Na verdade, não pensamos sobre onde um "usuário" em nossa aplicação deveria viver. Vamos dar um passo atrás e pensar nas diferentes partes do nosso sistema. Sabemos que teremos produtos para mostrar nas páginas para venda, junto com descrições, preços, etc. Junto com a venda de produtos, sabemos que precisaremos suportar carrinhos, checkout de pedidos e assim por diante. Embora os produtos que estão sendo comprados estejam relacionados aos processos de carrinho e checkout, exibir um produto e gerenciar a *exibição* de nossos produtos é claramente diferente de rastrear o que um usuário colocou em seu carrinho ou como um pedido é feito. Um contexto `Catalog` é um lugar natural para o gerenciamento dos detalhes de nosso produto e a exibição desses produtos que temos à venda.

> #### Uma nota sobre escopos {: .info}
>
> Muitos geradores suportam a opção `--scope` para gerar recursos com escopo. Por exemplo, um escopo pode ser a conta de usuário logada da sua aplicação. Recursos com escopo são úteis quando diferentes entidades devem ver diferentes recursos. Se um recurso tiver escopo por usuário, o usuário só poderá gerenciar e ver seus próprios recursos. Para nosso catálogo, queremos que todos vejam os mesmos produtos, portanto usamos `--no-scope`. Note que se nenhum escopo for configurado, `--no-scope` é o padrão. Veremos escopos em usuário mais tarde neste guia. Você também pode aprender mais sobre escopos no guia [Escopos](scopes.html).

Para iniciar nosso contexto de catálogo, usaremos `mix phx.gen.html` que cria um módulo de contexto que envolve o acesso ao Ecto para criar, atualizar e excluir produtos, junto com arquivos web como controladores e templates para a interface web em nosso contexto. Execute o seguinte comando na raiz do seu projeto:

```console
$ mix phx.gen.html Catalog Product products title:string \
description:string price:decimal views:integer --no-scope

* creating lib/hello_web/controllers/product_controller.ex
* creating lib/hello_web/controllers/product_html/edit.html.heex
* creating lib/hello_web/controllers/product_html/index.html.heex
* creating lib/hello_web/controllers/product_html/new.html.heex
* creating lib/hello_web/controllers/product_html/show.html.heex
* creating lib/hello_web/controllers/product_html/product_form.html.heex
* creating lib/hello_web/controllers/product_html.ex
* creating test/hello_web/controllers/product_controller_test.exs
* creating lib/hello/catalog/product.ex
* creating priv/repo/migrations/20250201185747_create_products.exs
* creating lib/hello/catalog.ex
* injecting lib/hello/catalog.ex
* creating test/hello/catalog_test.exs
* injecting test/hello/catalog_test.exs
* creating test/support/fixtures/catalog_fixtures.ex
* injecting test/support/fixtures/catalog_fixtures.ex

Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/products", ProductController

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

O Phoenix gerou os arquivos web conforme esperado em `lib/hello_web/`. Também podemos ver que nossos arquivos de contexto foram gerados dentro de um arquivo `lib/hello/catalog.ex` e nosso esquema de produto no diretório de mesmo nome. Observe a diferença entre `lib/hello` e `lib/hello_web`. Temos um módulo `Catalog` para servir como API pública para a funcionalidade do catálogo de produtos, bem como uma estrutura `Catalog.Product`, que é um esquema Ecto para lançar e validar dados de produtos. O Phoenix também forneceu testes web e de contexto para nós, incluiu auxiliares de teste para criar entidades via contexto `Hello.Catalog`, que veremos mais tarde. Por enquanto, vamos seguir as instruções e adicionar a rota de acordo com as instruções do console, em `lib/hello_web/router.ex`:

```diff
  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
+   resources "/products", ProductController
  end
```

Com a nova rota no lugar, o Phoenix nos lembra de atualizar nosso repositório executando `mix ecto.migrate`, mas primeiro precisamos fazer alguns ajustes na migração gerada em `priv/repo/migrations/*_create_products.exs`:

```diff
  def change do
    create table(:products) do
      add :title, :string
      add :description, :string
-     add :price, :decimal
+     add :price, :decimal, precision: 15, scale: 6, null: false
-     add :views, :integer
+     add :views, :integer, default: 0, null: false

      timestamps()
    end
```

Modificamos nossa coluna de preço para uma precisão específica de 15, escala de 6, junto com uma restrição não-nula. Isso garante que armazenemos moeda com precisão adequada para quaisquer operações matemáticas que possamos realizar. Em seguida, adicionamos um valor padrão e restrição não-nula para nossa contagem de visualizações. Com nossas mudanças no lugar, estamos prontos para migrar nosso banco de dados. Vamos fazer isso agora:

```console
$ mix ecto.migrate
14:09:02.260 [info] == Running 20250201185747 Hello.Repo.Migrations.CreateProducts.change/0 forward

14:09:02.262 [info] create table products

14:09:02.273 [info] == Migrated 20250201185747 in 0.0s
```

Antes de mergulharmos no código gerado, vamos iniciar o servidor com `mix phx.server` e visitar [http://localhost:4000/products](http://localhost:4000/products). Vamos seguir o link "New Product" e clicar no botão "Save" sem fornecer nenhum input. Devemos ser recebidos com a seguinte saída:

```text
Oops, something went wrong! Please check the errors below.
```

Quando enviamos o formulário, podemos ver todos os erros de validação em linha com os inputs. Legal! De cara, o gerador de contexto incluiu os campos do esquema em nosso template de formulário e podemos ver que nossas validações padrão para inputs obrigatórios estão em vigor. Vamos inserir alguns dados de exemplo do produto e reenviar o formulário:

```text
Product created successfully.

Title: Metaprogramming Elixir
Description: Write Less Code, Get More Done (and Have Fun!)
Price: 15.000000
Views: 0
```

Se seguirmos o link "Back", obteremos uma lista de todos os produtos, que deve conter o que acabamos de criar. Da mesma forma, podemos atualizar este registro ou excluí-lo. Agora que vimos como funciona no navegador, é hora de dar uma olhada no código gerado.

> #### Nomear coisas é difícil {: .tip}
>
> Ao iniciar uma aplicação web, pode ser difícil traçar linhas ou nomear seus diferentes contextos, especialmente quando o domínio com o qual você está trabalhando não é tão bem estabelecido quanto o e-commerce.
>
> Se você está preso ao definir ou nomear um contexto, você pode simplesmente criar um novo contexto usando a forma plural do recurso que está criando. Por exemplo, um contexto `Products` para gerenciar produtos. Você descobrirá que, mesmo nesses casos, você descobrirá organicamente outros recursos que pertencem ao contexto `Products`, como categorias ou galerias de imagens.
>
> À medida que suas aplicações crescem e as diferentes partes do seu sistema se tornam claras, você pode simplesmente renomear o contexto ou mover recursos. A beleza dos módulos Elixir é que eles são stateless, então movê-los deve ser simplesmente uma questão de renomear os nomes dos módulos (e renomear os arquivos para consistência).

## Começando com geradores

Aquele pequeno comando `mix phx.gen.html` trouxe uma surpresa. Obtivemos muita funcionalidade pronta para uso para criar, atualizar e excluir produtos em nosso catálogo. Isso está longe de ser um aplicativo completo, mas lembre-se, geradores são, antes de tudo, ferramentas de aprendizado e um ponto de partida para você começar a construir recursos reais. A geração de código não pode resolver todos os seus problemas, mas ensinará a você os pormenores do Phoenix e o orientará para a mentalidade adequada ao projetar sua aplicação.

Vamos primeiro verificar o `ProductController` que foi gerado em `lib/hello_web/controllers/product_controller.ex`:

```elixir
defmodule HelloWeb.ProductController do
  use HelloWeb, :controller

  alias Hello.Catalog
  alias Hello.Catalog.Product

  def index(conn, _params) do
    products = Catalog.list_products()
    render(conn, :index, products: products)
  end

  def new(conn, _params) do
    changeset = Catalog.change_product(%Product{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"product" => product_params}) do
    case Catalog.create_product(product_params) do
      {:ok, product} ->
        conn
        |> put_flash(:info, "Product created successfully.")
        |> redirect(to: ~p"/products/#{product}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    product = Catalog.get_product!(id)
    render(conn, :show, product: product)
  end
  ...
end
```

Vimos como os controladores funcionam em nosso [guia de controladores](controllers.html), então o código provavelmente não é muito surpreendente. O que vale a pena notar é como nosso controlador chama o contexto `Catalog`. Podemos ver que a ação `index` busca uma lista de produtos com `Catalog.list_products/0`, e como os produtos são persistidos na ação `create` com `Catalog.create_product/1`. Ainda não olhamos para o contexto do catálogo, então ainda não sabemos como a busca e a criação de produtos estão acontecendo sob o capô – *mas esse é o ponto*. Nosso controlador Phoenix é a interface web para nossa aplicação maior. Ele não deve se preocupar com os detalhes de como os produtos são buscados do banco de dados ou persistidos no armazenamento. Só nos preocupamos em dizer à nossa aplicação para realizar algum trabalho para nós. Isso é ótimo porque nossa lógica de negócios e detalhes de armazenamento estão desacoplados da camada web de nossa aplicação. Se mudarmos mais tarde para um mecanismo de armazenamento de texto completo para buscar produtos em vez de uma consulta SQL, nosso controlador não precisa ser alterado. Da mesma forma, podemos reutilizar nosso código de contexto de qualquer outra interface em nossa aplicação, seja um canal, uma tarefa de mix ou um processo de longa duração importando dados CSV.

No caso de nossa ação `create`, quando criamos um produto com sucesso, usamos `Phoenix.Controller.put_flash/3` para mostrar uma mensagem de sucesso e, em seguida, redirecionamos para a página de exibição do produto no roteador. Por outro lado, se `Catalog.create_product/1` falhar, renderizamos nosso template `"new.html"` e passamos o changeset do Ecto para que o template extraia mensagens de erro.

Em seguida, vamos nos aprofundar e verificar nosso contexto `Catalog` em `lib/hello/catalog.ex`:

```elixir
defmodule Hello.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias Hello.Repo

  alias Hello.Catalog.Product

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products do
    Repo.all(Product)
  end
  ...
end
```

Este módulo será a API pública para todas as funcionalidades do catálogo de produtos em nosso sistema. Por exemplo, além do gerenciamento de detalhes do produto, também podemos lidar com a classificação de categorias de produtos e variantes de produtos para coisas como dimensionamento opcional, acabamentos, etc. Se olharmos para a função `list_products/0`, podemos ver os detalhes privados da busca de produtos. E é super simples. Temos uma chamada para `Repo.all(Product)`. Vimos como as consultas do repo Ecto funcionavam no [guia do Ecto](ecto.html), então esta chamada deve parecer familiar. Nossa função `list_products` é um nome de função generalizado especificando a *intenção* do nosso código – ou seja, listar produtos. Os detalhes dessa intenção, onde usamos nosso Repo para buscar os produtos do nosso banco de dados PostgreSQL, estão ocultos de nossos chamadores. Este é um tema comum que veremos reiterado ao usar os geradores do Phoenix. O Phoenix nos empurrará a pensar sobre onde temos diferentes responsabilidades em nossa aplicação e, em seguida, a envolver essas diferentes áreas com módulos e funções bem nomeados que tornam a intenção do nosso código clara, ao mesmo tempo em que encapsulam os detalhes.

Agora sabemos como os dados são buscados, mas como os produtos são persistidos? Vamos dar uma olhada na função `Catalog.create_product/1`:

```elixir
  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end
```

Há mais documentação do que código aqui, mas algumas coisas são importantes de destacar. Primeiro, podemos ver novamente que nosso Ecto Repo é usado sob o capô para acesso ao banco de dados. Você provavelmente também notou a chamada para `Product.changeset/2`. Falamos sobre changesets antes, e agora os vemos em ação em nosso contexto.

Se abrirmos o esquema `Product` em `lib/hello/catalog/product.ex`, ele parecerá imediatamente familiar:

```elixir
defmodule Hello.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :description, :string
    field :price, :decimal
    field :title, :string
    field :views, :integer

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :description, :price, :views])
    |> validate_required([:title, :description, :price, :views])
  end
end
```

Isso é exatamente o que vimos antes quando executamos `mix phx.gen.schema`, exceto que aqui vemos um `@doc false` acima da nossa função `changeset/2`. Isso nos diz que, embora esta função seja publicamente chamável, ela não faz parte da API pública do contexto. Os chamadores que constroem changesets o fazem através da API de contexto. Por exemplo, `Catalog.create_product/1` chama nosso `Product.changeset/2` para construir o changeset a partir da entrada do usuário. Os chamadores, como nossas ações de controlador, não acessam `Product.changeset/2` diretamente. Toda interação com nossos changesets de produto é feita através do contexto público `Catalog`.

## Adicionando funções ao Catálogo

Como vimos, seus módulos de contexto são módulos dedicados que expõem e agrupam funcionalidades relacionadas. O Phoenix gera funções genéricas, como `list_products` e `update_product`, mas elas servem apenas como base para você desenvolver sua lógica de negócios e aplicação. Vamos adicionar uma das características básicas do nosso catálogo, rastreando a contagem de visualizações de páginas de produtos.

Para qualquer sistema de e-commerce, a capacidade de rastrear quantas vezes uma página de produto foi visualizada é essencial para marketing, sugestões, classificação, etc. Embora pudéssemos tentar usar a função `Catalog.update_product` existente, algo como `Catalog.update_product(product, %{views: product.views + 1})`, isso não só seria propenso a condições de corrida, mas também exigiria que o chamador soubesse demais sobre nosso sistema de Catálogo. Para ver por que a condição de corrida existe, vamos percorrer a possível execução de eventos:

Intuitivamente, você assumiria os seguintes eventos:

  1. Usuário 1 carrega a página do produto com contagem de 13
  2. Usuário 1 salva a página do produto com contagem de 14
  3. Usuário 2 carrega a página do produto com contagem de 14
  4. Usuário 2 salva a página do produto com contagem de 15

Enquanto na prática isso aconteceria:

  1. Usuário 1 carrega a página do produto com contagem de 13
  2. Usuário 2 carrega a página do produto com contagem de 13
  3. Usuário 1 salva a página do produto com contagem de 14
  4. Usuário 2 salva a página do produto com contagem de 14

As condições de corrida tornariam essa uma maneira não confiável de atualizar a tabela existente, uma vez que vários chamadores podem estar atualizando valores de visualização desatualizados. Há uma maneira melhor.

Vamos pensar em uma função que descreva o que queremos realizar. Veja como gostaríamos de usá-la:

```elixir
product = Catalog.inc_page_views(product)
```

Isso parece ótimo. Nossos chamadores não terão nenhuma confusão sobre o que essa função faz, e podemos envolver o incremento em uma operação atômica para evitar condições de corrida.

Abra seu contexto de catálogo (`lib/hello/catalog.ex`) e adicione esta nova função:

```elixir
  def inc_page_views(%Product{} = product) do
    {1, [%Product{views: views}]} =
      from(p in Product, where: p.id == ^product.id, select: [:views])
      |> Repo.update_all(inc: [views: 1])

    put_in(product.views, views)
  end
```

Construímos uma consulta para buscar o produto atual dado seu ID, que passamos para `Repo.update_all`. O `Repo.update_all` do Ecto nos permite realizar atualizações em lote no banco de dados, e é perfeito para atualizar atomicamente valores, como incrementar nossa contagem de visualizações. O resultado da operação do repo retorna o número de registros atualizados, junto com os valores do esquema selecionados especificados pela opção `select`. Quando recebemos as novas visualizações do produto, usamos `put_in(product.views, views)` para colocar a nova contagem de visualizações dentro da estrutura do produto.

Com nossa função de contexto no lugar, vamos utilizá-la em nosso controlador de produto. Atualize sua ação `show` em `lib/hello_web/controllers/product_controller.ex` para chamar nossa nova função:

```elixir
  def show(conn, %{"id" => id}) do
    product =
      id
      |> Catalog.get_product!()
      |> Catalog.inc_page_views()

    render(conn, :show, product: product)
  end
```

Modificamos nossa ação `show` para canalizar nosso produto buscado para `Catalog.inc_page_views/1`, que retornará o produto atualizado. Em seguida, renderizamos nosso template como antes. Vamos tentar. Atualize uma de suas páginas de produto algumas vezes e observe o contador de visualizações aumentar.

Também podemos ver nossa atualização atômica em ação nos logs de depuração do ecto:

```text
[debug] QUERY OK source="products" db=0.5ms idle=834.5ms
UPDATE "products" AS p0 SET "views" = p0."views" + $1 WHERE (p0."id" = $2) RETURNING p0."views" [1, 1]
```

Bom trabalho!

Como vimos, projetar com contextos dá a você uma base sólida para crescer sua aplicação. Usar APIs discretas e bem definidas que expõem a intenção do seu sistema permite que você escreva aplicações mais fáceis de manter com código reutilizável. Agora que sabemos como começar a estender nossa API de contexto, vamos explorar o tratamento de relacionamentos dentro de um contexto.

## Relacionamentos dentro do contexto

Nossos recursos básicos de catálogo são bons, mas vamos elevar o nível categorizando produtos. Muitas soluções de e-commerce permitem que os produtos sejam categorizados de diferentes maneiras, como um produto ser marcado para moda, ferramentas elétricas e assim por diante. Começar com um relacionamento um-para-um entre produto e categorias causará grandes mudanças de código mais tarde se precisarmos começar a suportar várias categorias. Vamos configurar uma associação de categoria que nos permitirá começar rastreando uma única categoria por produto, mas facilmente suportar mais depois, à medida que expandimos nossos recursos.

Por enquanto, as categorias conterão apenas informações textuais. Nossa primeira ordem de negócios é decidir onde as categorias vivem na aplicação. Temos nosso contexto `Catalog`, que gerencia a exibição de nossos produtos. A categorização de produtos é um encaixe natural aqui. O Phoenix também é inteligente o suficiente para gerar código dentro de um contexto existente, o que facilita a adição de novos recursos a um contexto. Execute o seguinte comando na raiz do seu projeto:

> Às vezes pode ser complicado determinar se dois recursos pertencem ao mesmo contexto ou não. Nesses casos, prefira contextos distintos por recurso e refatore mais tarde, se necessário. Caso contrário, você pode facilmente acabar com grandes contextos de entidades vagamente relacionadas. Tenha em mente também que o fato de dois recursos estarem relacionados não significa necessariamente que eles pertençam ao mesmo contexto, caso contrário, você rapidamente acabaria com um grande contexto, já que a maioria dos recursos em uma aplicação está conectada entre si. Resumindo: se você não tem certeza, deve preferir módulos separados (contextos).

```console
$ mix phx.gen.context Catalog Category categories \
title:string:unique --no-scope

You are generating into an existing context.
...
Would you like to proceed? [Yn] y
* creating lib/hello/catalog/category.ex
* creating priv/repo/migrations/20250203192325_create_categories.exs
* injecting lib/hello/catalog.ex
* injecting test/hello/catalog_test.exs
* injecting test/support/fixtures/catalog_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Desta vez, usamos `mix phx.gen.context`, que é como `mix phx.gen.html`, exceto que não gera os arquivos web para nós. Como já temos controladores e templates para gerenciar produtos, podemos integrar os novos recursos de categoria em nosso formulário web existente e página de exibição de produto. Podemos ver que agora temos um novo esquema `Category` ao lado do nosso esquema de produto em `lib/hello/catalog/category.ex`, e o Phoenix nos disse que estava *injetando* novas funções em nosso contexto Catalog existente para a funcionalidade de categoria. As funções injetadas parecerão muito familiares com nossas funções de produto, com novas funções como `create_category`, `list_categories` e assim por diante. Antes de migrar, precisamos fazer um segundo bit de geração de código. Nosso esquema de categoria é ótimo para representar uma categoria individual no sistema, mas precisamos suportar um relacionamento muitos-para-muitos entre produtos e categorias. Felizmente, o ecto nos permite fazer isso simplesmente com uma tabela de junção, então vamos gerar isso agora com o comando `ecto.gen.migration`:

```console
$ mix ecto.gen.migration create_product_categories

* creating priv/repo/migrations/20250203192958_create_product_categories.exs
```

Em seguida, vamos abrir o novo arquivo de migração e adicionar o seguinte código à função `change`:

```elixir
defmodule Hello.Repo.Migrations.CreateProductCategories do
  use Ecto.Migration

  def change do
    create table(:product_categories, primary_key: false) do
      add :product_id, references(:products, on_delete: :delete_all)
      add :category_id, references(:categories, on_delete: :delete_all)
    end

    create index(:product_categories, [:product_id])
    create unique_index(:product_categories, [:category_id, :product_id])
  end
end
```

Criamos uma tabela `product_categories` e usamos a opção `primary_key: false` já que nossa tabela de junção não precisa de uma chave primária. Em seguida, definimos nossos campos de chave estrangeira `:product_id` e `:category_id`, e passamos `on_delete: :delete_all` para garantir que o banco de dados elimine nossos registros de tabela de junção se um produto ou categoria vinculado for excluído. Ao usar uma restrição de banco de dados, impomos a integridade dos dados no nível do banco de dados, em vez de confiar em lógica de aplicação ad-hoc e propensa a erros.

Em seguida, criamos índices para nossas chaves estrangeiras, um dos quais é um índice único para garantir que um produto não possa ter categorias duplicadas. Observe que não precisamos necessariamente de um índice de coluna única para `category_id` porque ele está no prefixo mais à esquerda do índice multicoluna, o que é suficiente para o otimizador do banco de dados. Adicionar um índice redundante, por outro lado, apenas adiciona sobrecarga na escrita.

Com nossas migrações no lugar, podemos migrar.

```console
$ mix ecto.migrate

18:20:36.489 [info] == Running 20250222231834 Hello.Repo.Migrations.CreateCategories.change/0 forward

18:20:36.493 [info] create table categories

18:20:36.508 [info] create index categories_title_index

18:20:36.512 [info] == Migrated 20250222231834 in 0.0s

18:20:36.547 [info] == Running 20250222231930 Hello.Repo.Migrations.CreateProductCategories.change/0 forward

18:20:36.547 [info] create table product_categories

18:20:36.557 [info] create index product_categories_product_id_index

18:20:36.560 [info]  create index product_categories_category_id_product_id_index

18:20:36.562 [info] == Migrated 20250222231930 in 0.0s
```

Agora que temos um esquema `Catalog.Product` e uma tabela de junção para associar produtos e categorias, estamos quase prontos para começar a implementar nossos novos recursos. Antes de mergulharmos, primeiro precisamos de categorias reais para selecionar em nossa interface de usuário web. Vamos rapidamente semear algumas novas categorias na aplicação. Adicione o seguinte código ao seu arquivo de sementes em `priv/repo/seeds.exs`:

```elixir
for title <- ["Home Improvement", "Power Tools", "Gardening", "Books", "Education"] do
  {:ok, _} = Hello.Catalog.create_category(%{title: title})
end
```

Simplesmente enumeramos sobre uma lista de títulos de categorias e usamos a função gerada `create_category/1` do nosso contexto de catálogo para persistir os novos registros. Podemos executar as sementes com `mix run`:

```console
$ mix run priv/repo/seeds.exs

[debug] QUERY OK db=3.1ms decode=1.1ms queue=0.7ms idle=2.2ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Home Improvement", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=1.2ms queue=1.3ms idle=12.3ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Power Tools", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=1.1ms queue=1.1ms idle=15.1ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Gardening", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=2.4ms queue=1.0ms idle=17.6ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Books", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
```

Perfeito. Antes de integrarmos categorias na camada web, precisamos informar ao nosso contexto como associar produtos e categorias. Primeiro, abra `lib/hello/catalog/product.ex` e adicione a seguinte associação:

```diff
+ alias Hello.Catalog.Category

  schema "products" do
    field :description, :string
    field :price, :decimal
    field :title, :string
    field :views, :integer

+   many_to_many :categories, Category, join_through: "product_categories", on_replace: :delete

    timestamps()
  end

```

Usamos a macro `many_to_many` do `Ecto.Schema` para permitir que o Ecto saiba como associar nosso produto a múltiplas categorias através da tabela de junção `"product_categories"`. Também usamos a opção `on_replace: :delete` para declarar que quaisquer registros de junção existentes devem ser excluídos quando estamos mudando nossas categorias.

Com nossas associações de esquema configuradas, podemos implementar a seleção de categorias em nosso formulário de produto. Para fazer isso, precisamos traduzir a entrada do usuário de IDs de catálogo da interface para nossa associação muitos-para-muitos. Felizmente, o Ecto torna isso muito fácil agora que nosso esquema está configurado. Abra seu contexto de catálogo e faça as seguintes alterações:

```diff
+ alias Hello.Catalog.Category

- def get_product!(id), do: Repo.get!(Product, id)
+ def get_product!(id) do
+   Product |> Repo.get!(id) |> Repo.preload(:categories)
+ end

  def create_product(attrs \\ %{}) do
    %Product{}
-   |> Product.changeset(attrs)
+   |> change_product(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
-   |> Product.changeset(attrs)
+   |> change_product(attrs)
    |> Repo.update()
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
-   Product.changeset(product, attrs)
+   categories = list_categories_by_id(attrs["category_ids"])

+   product
+   |> Repo.preload(:categories)
+   |> Product.changeset(attrs)
+   |> Ecto.Changeset.put_assoc(:categories, categories)
  end

+ def list_categories_by_id(nil), do: []
+ def list_categories_by_id(category_ids) do
+   Repo.all(from c in Category, where: c.id in ^category_ids)
+ end
```

Primeiro, adicionamos `Repo.preload` para pré-carregar nossas categorias quando buscamos um produto. Isso nos permitirá referenciar `product.categories` em nossos controladores, templates e em qualquer outro lugar onde quisermos fazer uso de informações de categoria. Em seguida, modificamos nossas funções `create_product` e `update_product` para chamar nossa função `change_product` existente para produzir um changeset. Dentro de `change_product`, adicionamos uma busca para encontrar todas as categorias se o atributo `"category_ids"` estiver presente. Em seguida, pré-carregamos categorias e chamamos `Ecto.Changeset.put_assoc` para colocar as categorias buscadas no changeset. Finalmente, implementamos a função `list_categories_by_id/1` para consultar as categorias que correspondem aos IDs de categoria, ou retornar uma lista vazia se nenhum atributo `"category_ids"` estiver presente. Agora nossas funções `create_product` e `update_product` recebem um changeset com as associações de categoria todas prontas para ir uma vez que tentamos uma inserção ou atualização em nosso repo.

Em seguida, vamos expor nosso novo recurso para a web, adicionando a entrada de categoria ao nosso formulário de produto. Para manter nosso template de formulário organizado, vamos escrever uma nova função para envolver os detalhes de renderização de uma entrada select de categoria para nosso produto. Abra sua view `ProductHTML` em `lib/hello_web/controllers/product_html.ex` e digite isso:

```elixir
  def category_opts(changeset) do
    existing_ids =
      changeset
      |> Ecto.Changeset.get_change(:categories, [])
      |> Enum.map(& &1.data.id)

    for cat <- Hello.Catalog.list_categories() do
      [key: cat.title, value: cat.id, selected: cat.id in existing_ids]
    end
  end
```

Adicionamos uma nova função `category_opts/1` que gera as opções de seleção para uma tag de seleção múltipla que adicionaremos em breve. Calculamos os IDs de categoria existentes do nosso changeset, e então usamos esses valores quando geramos as opções de seleção para a tag de input. Fizemos isso enumerando sobre todas as nossas categorias e retornando os valores apropriados de `key`, `value` e `selected`. Marcamos uma opção como selecionada se o ID da categoria foi encontrado nesses IDs de categoria em nosso changeset.

Com nossa função `category_opts` no lugar, podemos abrir `lib/hello_web/controllers/product_html/product_form.html.heex` e adicionar:

```diff
  ...
  <.input field={f[:views]} type="number" label="Views" />

+ <.input field={f[:category_ids]} type="select" multiple options={category_opts(@changeset)} />

  <:actions>
    <.button>Save Product</.button>
  </:actions>
```

Adicionamos um `category_select` acima do nosso botão de salvar. Agora vamos experimentá-lo. Em seguida, vamos mostrar as categorias do produto no template de exibição do produto. Adicione o seguinte código à lista em `lib/hello_web/controllers/product_html/show.html.heex`:

```diff
<.list>
  ...
+ <:item title="Categories">
+   <ul>
+     <li :for={cat <- @product.categories}>{cat.title}</li>
+   </ul>
+ </:item>
</.list>
```

Agora, se iniciarmos o servidor com `mix phx.server` e visitarmos [http://localhost:4000/products/new](http://localhost:4000/products/new), veremos a nova entrada de seleção múltipla de categoria. Digite alguns detalhes válidos do produto, selecione uma categoria ou duas e clique em salvar.

```text
Title: Elixir Flashcards
Description: Flash card set for the Elixir programming language
Price: 5.000000
Views: 0
Categories:
Education
Books
```

Ainda não parece grande coisa, mas funciona! Adicionamos relacionamentos dentro do nosso contexto com integridade de dados imposta pelo banco de dados. Nada mal. Vamos continuar construindo!

## Dependências entre contextos

Agora que temos o início das funcionalidades do nosso catálogo de produtos, vamos começar a trabalhar nas outras funcionalidades principais da nossa aplicação – adicionar produtos do catálogo ao carrinho. Para rastrear adequadamente os produtos que foram adicionados ao carrinho de um usuário, precisaremos de um novo local para persistir essas informações, juntamente com informações pontuais do produto, como o preço no momento da adição ao carrinho. Isso é necessário para que possamos detectar alterações de preço do produto no futuro. Sabemos o que precisamos construir, mas agora precisamos decidir onde a funcionalidade do carrinho vai ficar em nossa aplicação.

Se dermos um passo atrás e pensarmos sobre o isolamento da nossa aplicação, a exibição de produtos em nosso catálogo difere claramente das responsabilidades de gerenciar o carrinho de um usuário. Um catálogo de produtos não deveria se preocupar com as regras do nosso sistema de carrinho de compras, e vice-versa. Existe uma clara necessidade aqui de um contexto separado para lidar com as novas responsabilidades do carrinho. Vamos chamá-lo de `ShoppingCart`.

Vamos criar um contexto `ShoppingCart` para lidar com as tarefas básicas do carrinho. Antes de escrevermos código, vamos imaginar que temos os seguintes requisitos de funcionalidade:

  1. Adicionar produtos ao carrinho de um usuário a partir da página de exibição do produto
  2. Armazenar informações pontuais de preço do produto no momento da adição ao carrinho
  3. Armazenar e atualizar quantidades no carrinho
  4. Calcular e exibir a soma dos preços do carrinho

Pela descrição, está claro que precisamos de um recurso `Cart` para armazenar o carrinho do usuário, junto com um `CartItem` para rastrear produtos no carrinho. Com nosso plano definido, vamos começar a trabalhar.

Inicialmente, mencionamos que os geradores suportam escopo para recursos. Para nosso carrinho, queremos fazer o escopo por usuário. Um usuário só deve ser capaz de gerenciar seu próprio carrinho. Em nossa aplicação, não há sistema de autenticação e também nenhum escopo definido ainda. Embora seja possível criar um escopo do zero, usaremos o gerador de autenticação `mix phx.gen.auth` que criará um escopo de usuário para nós:

```console
mix phx.gen.auth Accounts User user

Um sistema de autenticação pode ser criado de duas maneiras diferentes:
- Usando Phoenix.LiveView (padrão)
- Usando apenas Phoenix.Controller
Você quer criar um sistema de autenticação baseado em LiveView? [Yn] n

...
* criando lib/hello/accounts/scope.ex
...
* injetando config/config.exs
...

Por favor, busque novamente suas dependências com o seguinte comando:

    $ mix deps.get

Lembre-se de atualizar seu repositório executando migrações:

    $ mix ecto.migrate

Quando estiver pronto, visite "/user/register"
para criar sua conta e depois acesse "/dev/mailbox" para
ver o e-mail de confirmação da conta.
```

Depois de seguir as instruções para buscar novamente as dependências e migrar o banco de dados, podemos iniciar o servidor com `mix phx.server` e revisitar a página inicial [`http://localhost:4000/`](http://localhost:4000/) e deveríamos ver novos links de registro e login no topo da página. Na página de registro, crie um novo usuário. No desenvolvimento, um e-mail de confirmação é enviado para a caixa de correio de desenvolvimento, que é acessível em [`http://localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox). Depois de clicar no link de confirmação, você deve estar logado com sucesso.

Examinando o arquivo de escopo gerado `lib/hello/accounts/scope.ex`:

```elixir
defmodule Hello.Accounts.Scope do
  ...
  alias Hello.Accounts.User

  defstruct user: nil

  @doc """
  Cria um escopo para o usuário fornecido.

  Retorna nil se nenhum usuário for fornecido.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
```

podemos ver que é simplesmente uma struct com um campo `user`. O sistema de autenticação garante que o assign `current_scope` seja definido como uma struct `%Scope{}` que identifica o usuário atual e nossos geradores podem contar com a struct para fazer o escopo adequado dos recursos.

Vamos gerar nosso novo contexto:

```console
$ mix phx.gen.context ShoppingCart Cart carts

* criando lib/hello/shopping_cart/cart.ex
* criando priv/repo/migrations/20250205203128_create_carts.exs
* criando lib/hello/shopping_cart.ex
* injetando lib/hello/shopping_cart.ex
* criando test/hello/shopping_cart_test.exs
* injetando test/hello/shopping_cart_test.exs
* criando test/support/fixtures/shopping_cart_fixtures.ex
* injetando test/support/fixtures/shopping_cart_fixtures.ex

Lembre-se de atualizar seu repositório executando migrações:

    $ mix ecto.migrate
```

Geramos nosso novo contexto `ShoppingCart`, com um novo esquema `ShoppingCart.Cart` para vincular um usuário ao seu carrinho que contém itens do carrinho. Com nosso carrinho no lugar, vamos gerar nossos itens do carrinho:

```console
$ mix phx.gen.context ShoppingCart CartItem cart_items \
cart_id:references:carts product_id:references:products \
price_when_carted:decimal quantity:integer --no-scope

Você está gerando em um contexto existente.
...
Gostaria de prosseguir? [Yn] y
* criando lib/hello/shopping_cart/cart_item.ex
* criando priv/repo/migrations/20250205213410_create_cart_items.exs
* injetando lib/hello/shopping_cart.ex
* injetando test/hello/shopping_cart_test.exs
* injetando test/support/fixtures/shopping_cart_fixtures.ex

Lembre-se de atualizar seu repositório executando migrações:

    $ mix ecto.migrate
```

Geramos um novo recurso dentro do nosso `ShoppingCart` chamado `CartItem`. Este esquema e tabela conterão referências a um carrinho e produto, junto com o preço no momento em que adicionamos o item ao nosso carrinho, e a quantidade que o usuário deseja comprar. Vamos retocar o arquivo de migração gerado em `priv/repo/migrations/*_create_cart_items.ex`:

```diff
    create table(:cart_items) do
-     add :price_when_carted, :decimal
+     add :price_when_carted, :decimal, precision: 15, scale: 6, null: false
      add :quantity, :integer
-     add :cart_id, references(:carts, on_delete: :nothing)
+     add :cart_id, references(:carts, on_delete: :delete_all)
-     add :product_id, references(:products, on_delete: :nothing)
+     add :product_id, references(:products, on_delete: :delete_all)

      timestamps()
    end

-   create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
+   create unique_index(:cart_items, [:cart_id, :product_id])
```

Usamos a estratégia `:delete_all` novamente para garantir a integridade dos dados. Dessa forma, quando um carrinho ou produto é excluído da aplicação, não precisamos confiar no código da aplicação em nossos contextos `ShoppingCart` ou `Catalog` para se preocupar com a limpeza dos registros. Isso mantém nosso código de aplicação desacoplado e a aplicação da integridade de dados onde ela pertence – no banco de dados. Também adicionamos uma restrição única para garantir que um produto duplicado não possa ser adicionado a um carrinho. Assim como na tabela `product_categories`, usar um índice de várias colunas nos permite remover o índice separado para o campo mais à esquerda (`cart_id`). Com nossas tabelas de banco de dados no lugar, agora podemos migrar:

```console
$ mix ecto.migrate

16:59:51.941 [info] == Executando 20250205203342 Hello.Repo.Migrations.CreateCarts.change/0 para frente

16:59:51.945 [info] create table carts

16:59:51.952 [info] == Migrado 20250205203342 em 0.0s

16:59:51.988 [info] == Executando 20250205213410 Hello.Repo.Migrations.CreateCartItems.change/0 para frente

16:59:51.988 [info] create table cart_items

16:59:51.998 [info] create index cart_items_cart_id_index

16:59:52.000 [info] create index cart_items_product_id_index

16:59:52.001 [info] create index cart_items_cart_id_product_id_index

16:59:52.002 [info] == Migrado 20250205213410 em 0.0s
```

Nosso banco de dados está pronto para funcionar com as novas tabelas `carts` e `cart_items`, mas agora precisamos mapear isso de volta para o código da aplicação. Você pode estar se perguntando como podemos misturar chaves estrangeiras de banco de dados entre diferentes tabelas e como isso se relaciona com o padrão de contexto de funcionalidade isolada e agrupada. Vamos entrar nisso e discutir as abordagens e suas compensações.

### Dados entre contextos

Até agora, fizemos um ótimo trabalho isolando os dois principais contextos de nossa aplicação um do outro, mas agora temos uma dependência necessária para lidar.

Nosso recurso `Catalog.Product` serve para manter as responsabilidades de representar um produto dentro do catálogo, mas, em última análise, para que um item exista no carrinho, um produto do catálogo deve estar presente. Dado isso, nosso contexto `ShoppingCart` terá uma dependência de dados no contexto `Catalog`. Com isso em mente, temos duas opções. Uma é expor APIs no contexto `Catalog` que nos permitem buscar dados de produtos de forma eficiente para uso no sistema `ShoppingCart`, que uniríamos manualmente. Ou podemos usar joins de banco de dados para buscar os dados dependentes. Ambas são opções válidas dadas suas compensações e tamanho da aplicação, mas juntar dados do banco de dados quando você tem uma dependência de dados forte é perfeitamente adequado para uma grande classe de aplicações e é a abordagem que tomaremos aqui.

Agora que sabemos onde existem nossas dependências de dados, vamos adicionar nossas associações de esquema para que possamos vincular itens do carrinho de compras a produtos. Primeiro, vamos fazer uma pequena alteração em nosso esquema de carrinho em `lib/hello/shopping_cart/cart.ex` para associar um carrinho aos seus itens:

```diff
  schema "carts" do
-   field :user_id, :id
+   belongs_to :user, Hello.Accounts.User
+   has_many :items, Hello.ShoppingCart.CartItem

    timestamps()
  end
```

Agora que nosso carrinho está associado aos itens que colocamos nele, vamos configurar as associações de itens do carrinho dentro de `lib/hello/shopping_cart/cart_item.ex`:

```diff
  schema "cart_items" do
    field :price_when_carted, :decimal
    field :quantity, :integer
-   field :cart_id, :id
-   field :product_id, :id

+   belongs_to :cart, Hello.ShoppingCart.Cart
+   belongs_to :product, Hello.Catalog.Product

    timestamps()
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:price_when_carted, :quantity])
    |> validate_required([:price_when_carted, :quantity])
+   |> validate_number(:quantity, greater_than_or_equal_to: 0, less_than: 100)
  end
```

Primeiro, substituímos o campo `cart_id` por um `belongs_to` padrão apontando para nosso esquema `ShoppingCart.Cart`. Em seguida, substituímos nosso campo `product_id` adicionando nossa primeira dependência de dados entre contextos com um `belongs_to` para o esquema `Catalog.Product`. Aqui, intencionalmente acoplamos os limites de dados porque ele fornece exatamente o que precisamos: uma API de contexto isolada com o mínimo de conhecimento necessário para referenciar um produto em nosso sistema. Em seguida, adicionamos uma nova validação ao nosso changeset. Com `validate_number/3`, garantimos que qualquer quantidade fornecida pela entrada do usuário esteja entre 0 e 100.

Com nossos esquemas no lugar, podemos começar a integrar as novas estruturas de dados e APIs do contexto `ShoppingCart` em nossas funcionalidades voltadas para a web.

### Adicionando funções ao Carrinho de Compras

Como mencionamos anteriormente, os geradores de contexto são apenas um ponto de partida para nossa aplicação. Podemos e devemos escrever funções bem nomeadas e com propósitos específicos para atingir os objetivos do nosso contexto. Temos alguns novos recursos para implementar. Primeiro, precisamos garantir que cada usuário de nossa aplicação receba um carrinho caso ainda não exista um. A partir daí, podemos permitir que os usuários adicionem itens ao carrinho, atualizem as quantidades dos itens e calculem os totais do carrinho. Vamos começar!

Não vamos focar em um sistema de autenticação de usuário real neste momento, mas quando terminarmos, você poderá integrar naturalmente um com o que escrevemos aqui. Para simular uma sessão de usuário atual, abra seu arquivo `lib/hello_web/router.ex` e insira o seguinte:

Como usamos `mix phx.gen.auth`, já temos um sistema de autenticação real implementado. Podemos usar o assign `current_scope` para acessar o usuário autenticado no momento. Vamos adicionar um novo plug que atribui um carrinho se houver um usuário autenticado:

```diff
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
+   plug :fetch_current_cart
  end

+ alias Hello.ShoppingCart
+
+ defp fetch_current_cart(%{assigns: %{current_scope: scope}} = conn, _opts) when not is_nil(scope) do
+   if cart = ShoppingCart.get_cart(scope) do
+     assign(conn, :cart, cart)
+   else
+     {:ok, new_cart} = ShoppingCart.create_cart(scope)
+     assign(conn, :cart, new_cart)
+   end
+ end
+
+ defp fetch_current_cart(conn, _opts), do: conn
```

Adicionamos um novo plug `:fetch_current_cart` que encontra um carrinho para o UUID do usuário ou cria um carrinho para o usuário atual e atribui o resultado nos assigns da conexão. Precisaremos implementar nosso `ShoppingCart.get_cart/1`, mas vamos adicionar nossas rotas primeiro.

Precisaremos implementar um controlador de carrinho para lidar com operações de carrinho como visualizar um carrinho, atualizar quantidades e iniciar o processo de checkout, além de um controlador de itens de carrinho para adicionar e remover itens individuais ao e do carrinho. O sistema de autenticação já gerou diferentes escopos de roteador que têm diferentes requisitos de autenticação:

```elixir
...
  ## Rotas de autenticação

  scope "/", HelloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/user/register", UserRegistrationController, :new
    post "/user/register", UserRegistrationController, :create
  end

  scope "/", HelloWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/user/settings", UserSettingsController, :edit
    put "/user/settings", UserSettingsController, :update
    get "/user/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end
...
```

Como você pode ver, a rota de registro tem um plug `:redirect_if_user_is_authenticated`, o que significa que redirecionará para a página inicial se o usuário já estiver autenticado. As rotas de configurações do usuário usam um plug `:require_authenticated_user`, o que significa que redirecionarão para a página de login se o usuário não estiver autenticado. Esses plugs são definidos no módulo `lib/hello_web/user_auth.ex`.

Para nossas rotas de carrinho, queremos permitir acesso apenas a usuários autenticados. Adicione as seguintes rotas ao seu roteador em `lib/hello_web/router.ex`:

```diff
   scope "/", HelloWeb do
     pipe_through :browser

     get "/", PageController, :index
     resources "/products", ProductController
   end

+  scope "/", HelloWeb do
+    pipe_through [:browser, :require_authenticated_user]
+
+    resources "/cart_items", CartItemController, only: [:create, :delete]
+
+    get "/cart", CartController, :show
+    put "/cart", CartController, :update
+  end
```

Adicionamos uma declaração `resources` para um `CartItemController`, que irá conectar as rotas para uma ação de criar e excluir para adicionar e remover itens individuais do carrinho. Em seguida, adicionamos duas novas rotas apontando para um `CartController`. A primeira rota, uma requisição GET, será mapeada para nossa ação de exibição, para mostrar o conteúdo do carrinho. A segunda rota, uma requisição PUT, irá lidar com o envio de um formulário para atualizar as quantidades do nosso carrinho.

Com nossas rotas em vigor, vamos adicionar a capacidade de adicionar um item ao nosso carrinho a partir da página de exibição do produto. Crie um novo arquivo em `lib/hello_web/controllers/cart_item_controller.ex` e insira o seguinte:

```elixir
defmodule HelloWeb.CartItemController do
  use HelloWeb, :controller

  alias Hello.ShoppingCart

  def create(conn, %{"product_id" => product_id}) do
    case ShoppingCart.add_item_to_cart(conn.assigns.current_scope, conn.assigns.cart, product_id) do
      {:ok, _item} ->
        conn
        |> put_flash(:info, "Item adicionado ao seu carrinho")
        |> redirect(to: ~p"/cart")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Ocorreu um erro ao adicionar o item ao seu carrinho")
        |> redirect(to: ~p"/cart")
    end
  end

  def delete(conn, %{"id" => product_id}) do
    {:ok, _cart} = ShoppingCart.remove_item_from_cart(conn.assigns.current_scope, conn.assigns.cart, product_id)
    redirect(conn, to: ~p"/cart")
  end
end
```

Definimos um novo `CartItemController` com as ações de criar e excluir que declaramos em nosso roteador. Para `create`, chamamos uma função `ShoppingCart.add_item_to_cart/2` que implementaremos em breve. Se bem-sucedido, mostramos uma mensagem flash de sucesso e redirecionamos para a página de exibição do carrinho; caso contrário, mostramos uma mensagem flash de erro e redirecionamos para a página de exibição do carrinho. Para `delete`, chamaremos uma função `remove_item_from_cart` que implementaremos em nosso contexto `ShoppingCart` e depois redirecionaremos de volta para a página de exibição do carrinho. Ainda não implementamos essas duas funções de carrinho de compras, mas observe como seus nomes expressam claramente sua intenção: `add_item_to_cart` e `remove_item_from_cart` deixam óbvio o que estamos realizando aqui. Isso também nos permite especificar nossa camada web e APIs de contexto sem pensar em todos os detalhes de implementação de uma vez.

Vamos implementar a nova interface para a API de contexto do `ShoppingCart` em `lib/hello/shopping_cart.ex`:

```diff
+  alias Hello.Catalog
-  alias Hello.ShoppingCart.Cart
+  alias Hello.ShoppingCart.{Cart, CartItem}
   alias Hello.Accounts.Scope

+  def get_cart(%Scope{} = scope) do
+    Repo.one(
+      from(c in Cart,
+        where: c.user_id == ^scope.user.id,
+        left_join: i in assoc(c, :items),
+        left_join: p in assoc(i, :product),
+        order_by: [asc: i.inserted_at],
+        preload: [items: {i, product: p}]
+      )
+    )
+  end

   def create_cart(%Scope{} = scope, attrs \\ %{}) do
     with {:ok, cart = %Cart{}} <-
            %Cart{}
            |> Cart.changeset(attrs, scope)
            |> Repo.insert() do
       broadcast(scope, {:created, cart})
-      {:ok, cart}
+      {:ok, get_cart!(scope, cart.id)}
     end
   end
+
+  def add_item_to_cart(%Scope{} = scope, %Cart{} = cart, product_id) do
+    true = cart.user_id == scope.user.id
+    product = Catalog.get_product!(product_id)
+
+    %CartItem{quantity: 1, price_when_carted: product.price}
+    |> CartItem.changeset(%{})
+    |> Ecto.Changeset.put_assoc(:cart, cart)
+    |> Ecto.Changeset.put_assoc(:product, product)
+    |> Repo.insert(
+      on_conflict: [inc: [quantity: 1]],
+      conflict_target: [:cart_id, :product_id]
+    )
+  end
+
+  def remove_item_from_cart(%Scope{} = scope, %Cart{} = cart, product_id) do
+    true = cart.user_id == scope.user.id
+
+    {1, _} =
+      Repo.delete_all(
+        from(i in CartItem,
+          where: i.cart_id == ^cart.id,
+          where: i.product_id == ^product_id
+        )
+      )
+
+    {:ok, get_cart(scope)}
+  end
```

Começamos implementando `get_cart/1`, que busca nosso carrinho e une os itens do carrinho e seus produtos para que tenhamos o carrinho completo preenchido com todos os dados pré-carregados. Em seguida, modificamos nossa função `create_cart` para usar `get_cart` para recarregar o conteúdo do carrinho.

Em seguida, escrevemos nossa nova função `add_item_to_cart/3`, que aceita um escopo, uma estrutura de carrinho e um ID de produto. Procedemos para buscar o produto com `Catalog.get_product!/1`, mostrando como os contextos podem naturalmente invocar outros contextos, se necessário. Você também poderia ter optado por receber o produto como argumento e obteria resultados semelhantes. Em seguida, usamos uma operação de upsert contra nosso repositório para inserir um novo item de carrinho no banco de dados ou aumentar a quantidade em um se ele já existir no carrinho. Isso é realizado através das opções `on_conflict` e `conflict_target`, que informa ao nosso repositório como lidar com um conflito de inserção.

Finalmente, implementamos `remove_item_from_cart/3`, onde simplesmente emitimos uma chamada `Repo.delete_all` com uma consulta para excluir o item do carrinho em nosso carrinho que corresponde ao ID do produto. Por fim, recarregamos o conteúdo do carrinho chamando `get_cart/1`.

Com nossas novas funções de carrinho em vigor, agora podemos expor o botão "Adicionar ao carrinho" na página de exibição do catálogo de produtos. Abra seu modelo em `lib/hello_web/controllers/product_html/show.html.heex` e faça as seguintes alterações:

```diff
...
     <.link href={~p"/products/#{@product}/edit"}>
       <.button>Editar produto</.button>
     </.link>
+    <.link href={~p"/cart_items?product_id=#{@product.id}"} method="post">
+      <.button>Adicionar ao carrinho</.button>
+    </.link>
...
```

O componente de função `link` de `Phoenix.Component` aceita um atributo `:method` para emitir um verbo HTTP quando clicado, em vez da solicitação GET padrão. Com este link em vigor, o link "Adicionar ao carrinho" emitirá uma solicitação POST, que será correspondida pela rota que definimos no roteador que despacha para a função `CartItemController.create/2`.

Vamos testá-lo. Inicie seu servidor com `mix phx.server` e visite uma página de produto. Se tentarmos clicar no link de adicionar ao carrinho, seremos recebidos por uma página de erro. Se você estiver autenticado, os seguintes logs devem estar visíveis no console:

```text
[info] POST /cart_items
[debug] Processing with HelloWeb.CartItemController.create/2
  Parameters: %{"_method" => "post", "product_id" => "1", ...}
  Pipelines: [:browser, :require_authenticated_user]
[debug] QUERY OK source="user_tokens" db=2.4ms idle=1340.8ms
...
[debug] QUERY OK source="cart_items" db=2.5ms
INSERT INTO "cart_items" ...
[info] Sent 302 in 24ms
[info] GET /cart
[debug] Processing with HelloWeb.CartController.show/2
  Parameters: %{}
  Pipelines: [:browser, :require_authenticated_user]
[debug] QUERY OK source="user_tokens" db=1.6ms idle=430.2ms
...
[debug] QUERY OK source="carts" db=1.9ms idle=1798.5ms
...
[info] Sent 500 in 18ms
[error] ** (UndefinedFunctionError) function HelloWeb.CartController.init/1 is undefined (module HelloWeb.CartController is not available)
    ...
```

Está funcionando! Mais ou menos. Se seguirmos os logs, veremos nosso POST para o caminho `/cart_items`. Em seguida, podemos ver que nossa função `ShoppingCart.add_item_to_cart` inseriu com sucesso uma linha na tabela `cart_items`, e então emitimos um redirecionamento para `/cart`. Antes do nosso erro, também vemos uma consulta à tabela `carts`, o que significa que estamos buscando o carrinho do usuário atual. Até agora, tudo bem. Sabemos que nosso controlador `CartItem` e as novas funções de contexto `ShoppingCart` estão fazendo seus trabalhos, mas encontramos nosso próximo recurso não implementado quando o roteador tenta despachar para um controlador de carrinho inexistente. Vamos criar o controlador de carrinho, view e template para exibir e gerenciar carrinhos de usuários.

Crie um novo arquivo em `lib/hello_web/controllers/cart_controller.ex` e insira o seguinte:

```elixir
defmodule HelloWeb.CartController do
  use HelloWeb, :controller

  alias Hello.ShoppingCart

  def show(conn, _params) do
    render(conn, :show, changeset: ShoppingCart.change_cart(conn.assigns.current_scope, conn.assigns.cart))
  end
end
```

Definimos um novo controlador de carrinho para lidar com a rota `get "/cart"`. Para mostrar um carrinho, renderizamos um template `"show.html"` que criaremos em breve. Sabemos que precisamos permitir que os itens do carrinho sejam alterados por atualizações de quantidade, então já sabemos que precisaremos de um changeset de carrinho. Felizmente, o gerador de contexto incluiu uma função `ShoppingCart.change_cart/1`, que usaremos. Passamos a nossa estrutura de carrinho que já está nos assigns da conexão graças ao plug `fetch_current_cart` que definimos no roteador.

Em seguida, podemos implementar a view e o template. Crie um novo arquivo de view em `lib/hello_web/controllers/cart_html.ex` com o seguinte conteúdo:

```elixir
defmodule HelloWeb.CartHTML do
  use HelloWeb, :html

  alias Hello.ShoppingCart

  embed_templates "cart_html/*"

  def currency_to_str(%Decimal{} = val), do: "$#{Decimal.round(val, 2)}"
end
```

Criamos uma view para renderizar nosso template `show.html` e criamos um alias para nosso contexto `ShoppingCart` para que esteja no escopo do nosso template. Precisaremos exibir os preços do carrinho, como preço do item do produto, total do carrinho, etc., então definimos um `currency_to_str/1` que pega nossa estrutura decimal, arredonda-a adequadamente para exibição e adiciona um cifrão USD.

Em seguida, podemos criar o template em `lib/hello_web/controllers/cart_html/show.html.heex`:

```heex
<.header>
  Meu Carrinho
  <:subtitle :if={@cart.items == []}>Seu carrinho está vazio</:subtitle>
</.header>

<div :if={@cart.items !== []}>
  <.simple_form :let={f} for={@changeset} action={~p"/cart"}>
    <.inputs_for :let={%{data: item} = item_form} field={f[:items]}>
      <.input field={item_form[:quantity]} type="number" label={item.product.title} />
      {currency_to_str(ShoppingCart.total_item_price(item))}
    </.inputs_for>
    <:actions>
      <.button>Atualizar carrinho</.button>
    </:actions>
  </.simple_form>
  <b>Total</b>: {currency_to_str(ShoppingCart.total_cart_price(@cart))}
</div>

<.back navigate={~p"/products"}>Voltar aos produtos</.back>
```

Começamos mostrando a mensagem de carrinho vazio se nossos `cart.items` pré-carregados estiverem vazios. Se tivermos itens, usamos o componente `simple_form` fornecido pelo nosso `HelloWeb.CoreComponents` para pegar nosso changeset de carrinho que atribuímos na ação `CartController.show/2` e criar um formulário que mapeia para nossa ação `update/2` do controlador de carrinho. Dentro do formulário, usamos o componente [`inputs_for`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1) para renderizar entradas para os itens de carrinho aninhados. Isso nos permitirá mapear as entradas de itens de volta quando o formulário for enviado. Em seguida, exibimos uma entrada numérica para a quantidade do item e a rotulamos com o título do produto. Terminamos o formulário do item convertendo o preço do item para string. Ainda não escrevemos a função `ShoppingCart.total_item_price/1`, mas novamente empregamos a ideia de interfaces públicas claras e descritivas para nossos contextos. Depois de renderizar entradas para todos os itens do carrinho, mostramos um botão de envio "atualizar carrinho", junto com o preço total de todo o carrinho. Isso é realizado com outra nova função `ShoppingCart.total_cart_price/1` que implementaremos em breve. Finalmente, adicionamos um componente `back` para voltar à nossa página de produtos.

Estamos quase prontos para experimentar nossa página de carrinho, mas primeiro precisamos implementar nossas novas funções de cálculo de moeda. Abra seu contexto de carrinho de compras em `lib/hello/shopping_cart.ex` e adicione estas novas funções:

```elixir
  def total_item_price(%CartItem{} = item) do
    Decimal.mult(item.product.price, item.quantity)
  end

  def total_cart_price(%Cart{} = cart) do
    Enum.reduce(cart.items, 0, fn item, acc ->
      item
      |> total_item_price()
      |> Decimal.add(acc)
    end)
  end
```

Implementamos `total_item_price/1`, que aceita uma estrutura `%CartItem{}`. Para calcular o preço total, simplesmente pegamos o preço do produto pré-carregado e o multiplicamos pela quantidade do item. Usamos `Decimal.mult/2` para pegar nossa estrutura de moeda decimal e multiplicá-la com a precisão adequada. De maneira semelhante, para calcular o preço total do carrinho, implementamos uma função `total_cart_price/1` que aceita o carrinho e soma os preços dos produtos pré-carregados para os itens no carrinho. Novamente fazemos uso das funções `Decimal` para adicionar nossas estruturas decimais.

Agora que podemos calcular os totais de preços, vamos testá-los! Visite [`http://localhost:4000/cart`](http://localhost:4000/cart) e você já deve ver seu primeiro item no carrinho. Voltando ao mesmo produto e clicando em "adicionar ao carrinho" mostrará nossa operação de upsert em ação. Sua quantidade agora deve ser dois. Bom trabalho!

Nossa página de carrinho está quase completa, mas enviar o formulário produzirá mais um erro.

```text
[info] POST /cart
...
[error] ** (UndefinedFunctionError) function HelloWeb.CartController.update/2 is undefined or private
```

Vamos voltar ao nosso `CartController` em `lib/hello_web/controllers/cart_controller.ex` e implementar a ação de atualização:

```elixir
  def update(conn, %{"cart" => cart_params}) do
    case ShoppingCart.update_cart(conn.assigns.current_scope, conn.assigns.cart, cart_params) do
      {:ok, _cart} ->
        redirect(conn, to: ~p"/cart")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Ocorreu um erro ao atualizar seu carrinho")
        |> redirect(to: ~p"/cart")
    end
  end
```

Começamos extraindo os parâmetros do carrinho do envio do formulário. Em seguida, chamamos nossa função existente `ShoppingCart.update_cart/2` que foi adicionada pelo gerador de contexto. Precisaremos fazer algumas alterações nesta função, mas a interface está boa como está. Se a atualização for bem-sucedida, redirecionamos de volta à página do carrinho, caso contrário, mostramos uma mensagem de erro flash e enviamos o usuário de volta à página do carrinho para corrigir quaisquer erros. De imediato, nossa função `ShoppingCart.update_cart/2` só se preocupava em moldar os parâmetros do carrinho em um changeset e atualizá-lo contra nosso repositório. Para nossos propósitos, agora precisamos que ele lide com associações de itens de carrinho aninhadas e, o mais importante, lógica de negócios para como lidar com atualizações de quantidade, como itens de quantidade zero sendo removidos do carrinho.

Volte ao seu contexto de carrinho de compras em `lib/hello/shopping_cart.ex` e substitua sua função `update_cart/2` pela seguinte implementação:

```elixir
  def update_cart(%Scope{} = scope, %Cart{} = cart, attrs) do
    true = cart.user_id == scope.user.id
    
    changeset =
      cart
      |> Cart.changeset(attrs, scope)
      |> Ecto.Changeset.cast_assoc(:items, with: &CartItem.changeset/2)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:cart, changeset)
    |> Ecto.Multi.delete_all(:discarded_items, fn %{cart: cart} ->
      from(i in CartItem, where: i.cart_id == ^cart.id and i.quantity == 0)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{cart: cart}} ->
        broadcast(scope, {:updated, cart})
        {:ok, cart}
  
      {:error, :cart, changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end
```

Começamos muito parecido com o código inicial - pegamos a estrutura do carrinho e moldamos a entrada do usuário para um changeset de carrinho, exceto que desta vez usamos `Ecto.Changeset.cast_assoc/3` para moldar os dados de itens aninhados em changesets de `CartItem`. Lembra-se da chamada [`<.inputs_for />`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1) em nosso template de formulário de carrinho? Esses dados de ID ocultos é o que permite que o `cast_assoc` do Ecto mapeie os dados do item de volta para as associações de itens existentes no carrinho. Em seguida, usamos `Ecto.Multi.new/0`, que você pode não ter visto antes. O `Multi` do Ecto é um recurso que permite definir preguiçosamente uma cadeia de operações nomeadas para eventualmente executar dentro de uma transação de banco de dados. Cada operação na cadeia multi recebe os valores das etapas anteriores e executa até que uma etapa com falha seja encontrada. Quando uma operação falha, a transação é revertida e um erro é retornado, caso contrário, a transação é confirmada.

Para nossas operações multi, começamos emitindo uma atualização do nosso carrinho, que nomeamos como `:cart`. Após a atualização do carrinho ser emitida, realizamos uma operação multi `delete_all`, que pega o carrinho atualizado e aplica nossa lógica de quantidade zero. Podamos quaisquer itens no carrinho com quantidade zero retornando uma consulta ecto que encontra todos os itens de carrinho para este carrinho com uma quantidade vazia. Chamar `Repo.transaction/1` com nosso multi executará as operações em uma nova transação e retornaremos o resultado de sucesso ou falha para o chamador, assim como a função original.

Vamos voltar ao navegador e experimentá-lo. Adicione alguns produtos ao seu carrinho, atualize as quantidades e observe as mudanças de valores junto com os cálculos de preço. Definir qualquer quantidade como 0 também removerá o item. Você também pode tentar sair e registrar um novo usuário para ver como os carrinhos são limitados ao usuário atual. Muito legal!

## Adicionando um contexto de Pedidos

Com nossos contextos `Catalog` e `ShoppingCart`, estamos vendo em primeira mão como nossos módulos e nomes de funções bem considerados estão resultando em código claro e fácil de manter. Nossa última tarefa é permitir que o usuário inicie o processo de checkout. Não iremos tão longe quanto integrar o processamento de pagamentos ou o cumprimento de pedidos, mas vamos iniciá-lo nessa direção. Como antes, precisamos decidir onde o código para completar um pedido deve ficar. É parte do catálogo? Claramente não, mas e quanto ao carrinho de compras? Os carrinhos de compras estão relacionados a pedidos – afinal, o usuário precisa adicionar itens para comprar produtos – mas o processo de checkout do pedido deveria ser agrupado aqui?

Se pararmos para considerar o processo de pedido, veremos que os pedidos envolvem dados relacionados, mas distintamente diferentes dos conteúdos do carrinho. Além disso, as regras de negócio em torno do processo de checkout são muito diferentes das do carrinho. Por exemplo, podemos permitir que um usuário adicione um item em espera ao seu carrinho, mas não poderíamos permitir que um pedido sem estoque seja concluído. Adicionalmente, precisamos capturar informações do produto em tempo real quando um pedido é concluído, como o preço dos itens *no momento da transação de pagamento*. Isso é essencial porque o preço de um produto pode mudar no futuro, mas os itens de linha em nosso pedido devem sempre registrar e exibir o que cobramos no momento da compra. Por essas razões, podemos começar a ver que o processo de pedidos pode existir por si só, com suas próprias preocupações de dados e regras de negócio.

Em termos de nomenclatura, `Orders` define claramente nosso contexto, então vamos começar aproveitando novamente os geradores de contexto. Observe que o escopo `user` gerado por `mix phx.gen.auth` está marcado como escopo padrão (no seu `config/config.exs`), portanto não precisamos especificá-lo em nosso comando. Pode haver diferentes escopos em uma aplicação, caso em que a opção `--scope` pode ser usada ao executar os geradores. Execute o seguinte comando no seu console:

```console
$ mix phx.gen.context Orders Order orders total_price:decimal

* creating lib/hello/orders/order.ex
* creating priv/repo/migrations/20250209214612_create_orders.exs
* creating lib/hello/orders.ex
* injecting lib/hello/orders.ex
* creating test/hello/orders_test.exs
* injecting test/hello/orders_test.exs
* creating test/support/fixtures/orders_fixtures.ex
* injecting test/support/fixtures/orders_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Geramos um contexto `Orders`. O pedido é automaticamente vinculado ao usuário atual e adicionamos uma coluna `total_price`. Com nosso ponto de partida no lugar, vamos abrir a nova migração criada em `priv/repo/migrations/*_create_orders.exs` e fazer as seguintes alterações:

```diff
  def change do
    create table(:orders) do
-     add :total_price, :decimal
+     add :total_price, :decimal, precision: 15, scale: 6, null: false
      add :user_id, references(:user, type: :id, on_delete: :delete_all)

      timestamps()
    end
  end
```

Como fizemos anteriormente, demos opções apropriadas de precisão e escala para nossa coluna decimal, o que nos permitirá armazenar moeda sem perda de precisão. Também adicionamos uma restrição não-nula para garantir que todos os pedidos tenham um preço.

A tabela de pedidos sozinha não contém muita informação, mas sabemos que precisaremos armazenar informações de preço do produto em tempo real de todos os itens no pedido. Para isso, adicionaremos uma estrutura adicional para este contexto chamada `LineItem`. Os itens de linha capturarão o preço do produto *no momento da transação de pagamento*. Execute o seguinte comando:

```console
$ mix phx.gen.context Orders LineItem order_line_items \
price:decimal quantity:integer \
order_id:references:orders product_id:references:products --no-scope

You are generating into an existing context.
...
Would you like to proceed? [Yn] y
* creating lib/hello/orders/line_item.ex
* creating priv/repo/migrations/20250209215050_create_order_line_items.exs
* injecting lib/hello/orders.ex
* injecting test/hello/orders_test.exs
* injecting test/support/fixtures/orders_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

Usamos o comando `phx.gen.context` para gerar o esquema Ecto `LineItem` e injetar funções de suporte em nosso contexto de pedidos. Como antes, vamos modificar a migração em `priv/repo/migrations/*_create_order_line_items.exs` e fazer as seguintes alterações no campo decimal:

```diff
  def change do
    create table(:order_line_items) do
-     add :price, :decimal
+     add :price, :decimal, precision: 15, scale: 6, null: false
      add :quantity, :integer
      add :order_id, references(:orders, on_delete: :nothing)
      add :product_id, references(:products, on_delete: :nothing)

      timestamps()
    end

    create index(:order_line_items, [:order_id])
    create index(:order_line_items, [:product_id])
  end
```

Com nossa migração no lugar, vamos conectar nossas associações de pedidos e itens de linha em `lib/hello/orders/order.ex`:

```diff
  schema "orders" do
    field :total_price, :decimal
-   field :user_id, :id

+   belongs_to :user, Hello.Accounts.User
+   has_many :line_items, Hello.Orders.LineItem
+   has_many :products, through: [:line_items, :product]

    timestamps()
  end
```

Usamos `has_many :line_items` para associar pedidos e itens de linha, assim como vimos antes. Em seguida, usamos o recurso `:through` de `has_many`, que nos permite instruir o ecto sobre como associar recursos através de outro relacionamento. Neste caso, podemos associar produtos de um pedido encontrando todos os produtos através dos itens de linha associados. Agora, vamos conectar a associação na outra direção em `lib/hello/orders/line_item.ex`:

```diff
  schema "order_line_items" do
    field :price, :decimal
    field :quantity, :integer
-   field :order_id, :id
-   field :product_id, :id

+   belongs_to :order, Hello.Orders.Order
+   belongs_to :product, Hello.Catalog.Product

    timestamps()
  end
```

Usamos `belongs_to` para associar itens de linha a pedidos e produtos. Com nossas associações no lugar, podemos começar a integrar a interface web no nosso processo de pedidos. Abra seu roteador `lib/hello_web/router.ex` e adicione a seguinte linha:

```diff
  scope "/", HelloWeb do
    pipe_through [:browser, :require_authenticated_user]

    resources "/cart_items", CartItemController, only: [:create, :delete]

    get "/cart", CartController, :show
    put "/cart", CartController, :update

+   resources "/orders", OrderController, only: [:create, :show]
  end
```

Configuramos as rotas `create` e `show` para nosso `OrderController` gerado, já que estas são as únicas ações que precisamos no momento. Com nossas rotas no lugar, agora podemos migrar:

```console
$ mix ecto.migrate

17:14:37.715 [info] == Running 20250209214612 Hello.Repo.Migrations.CreateOrders.change/0 forward

17:14:37.720 [info] create table orders

17:14:37.755 [info] == Migrated 20250209214612 in 0.0s

17:14:37.784 [info] == Running 20250209215050 Hello.Repo.Migrations.CreateOrderLineItems.change/0 forward

17:14:37.785 [info] create table order_line_items

17:14:37.795 [info] create index order_line_items_order_id_index

17:14:37.796 [info] create index order_line_items_product_id_index

17:14:37.798 [info] == Migrated 20250209215050 in 0.0s
```

Antes de renderizar informações sobre nossos pedidos, precisamos garantir que nossos dados de pedido estejam totalmente preenchidos e possam ser consultados por um usuário atual. Abra seu contexto de pedidos em `lib/hello/orders.ex` e ajuste seu `get_order!/2` para incluir um preload:

```diff
   def get_order!(%Scope{} = scope, id) do
-    Repo.get_by!(Order, id: id, user_id: scope.user.id)
+    Order
+    |> Repo.get_by!(id: id, user_id: scope.user.id)
+    |> Repo.preload([line_items: [:product]])
   end
```

Para completar um pedido, nossa página de carrinho pode emitir um POST para a ação `OrderController.create`, mas precisamos implementar as operações e lógica para realmente completar um pedido. Como antes, começaremos pela interface web. Crie um novo arquivo em `lib/hello_web/controllers/order_controller.ex` e insira isto:

```elixir
defmodule HelloWeb.OrderController do
  use HelloWeb, :controller

  alias Hello.Orders

  def create(conn, _) do
    case Orders.complete_order(conn.assigns.current_scope, conn.assigns.cart) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order created successfully.")
        |> redirect(to: ~p"/orders/#{order}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "There was an error processing your order")
        |> redirect(to: ~p"/cart")
    end
  end
end
```

Escrevemos a ação `create` para chamar uma função `Orders.complete_order/2` que ainda não implementamos. Nosso código está tecnicamente "criando" um pedido, mas é importante recuar e considerar a nomenclatura de suas interfaces. O ato de *completar* um pedido é extremamente importante em nosso sistema. Dinheiro muda de mãos em uma transação, bens físicos podem ser enviados automaticamente, etc. Tal operação merece um nome de função melhor e mais óbvio, como `complete_order`. Se o pedido for concluído com sucesso, redirecionamos para a página de exibição, caso contrário, um erro flash é mostrado e redirecionamos de volta para a página do carrinho.

Aqui também é uma boa oportunidade para destacar que os contextos podem naturalmente trabalhar com dados definidos por outros contextos também. Isso será especialmente comum com dados que são usados em toda a aplicação, como o carrinho aqui (mas também pode ser o usuário atual ou o projeto atual, e assim por diante, dependendo do seu projeto).

Agora podemos implementar nossa função `Orders.complete_order/2`. Para completar um pedido, nosso trabalho exigirá algumas operações:

  1. Um novo registro de pedido deve ser persistido com o preço total do pedido
  2. Todos os itens no carrinho devem ser transformados em novos registros de itens de linha de pedido
    com informações de quantidade e preço do produto em tempo real
  3. Após a inserção bem-sucedida do pedido (e eventual pagamento), os itens devem ser removidos
    do carrinho

Apenas com nossos requisitos, podemos começar a ver por que uma função genérica `create_order` não é suficiente. Vamos implementar esta nova função em `lib/hello/orders.ex`:

```elixir
  alias Hello.Orders.LineItem
  alias Hello.ShoppingCart

  def complete_order(%Scope{} = scope, %ShoppingCart.Cart{} = cart) do
    true = cart.user_id == scope.user.id

    line_items =
      Enum.map(cart.items, fn item ->
        %{product_id: item.product_id, price: item.product.price, quantity: item.quantity}
      end)

    order =
      Ecto.Changeset.change(%Order{},
        user_id: scope.user.id,
        total_price: ShoppingCart.total_cart_price(cart),
        line_items: line_items
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:order, order)
    |> Ecto.Multi.run(:prune_cart, fn _repo, _changes ->
      ShoppingCart.prune_cart_items(scope, cart)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} ->
        broadcast(scope, {:created, order})
        {:ok, order}

      {:error, name, value, _changes_so_far} ->
        {:error, {name, value}}
    end
  end
```

Começamos mapeando os `%ShoppingCart.CartItem{}` em nosso carrinho de compras para um mapa de estruturas de itens de linha de pedido. O trabalho do registro de item de linha de pedido é capturar o preço do produto *no momento da transação de pagamento*, então referenciamos o preço do produto aqui. Em seguida, criamos um changeset de pedido básico com `Ecto.Changeset.change/2` e associamos nosso UUID de usuário, definimos nosso cálculo de preço total e colocamos nossos itens de linha de pedido no changeset. Com um changeset de pedido novo pronto para ser inserido, podemos novamente fazer uso de `Ecto.Multi` para executar nossas operações em uma transação de banco de dados. Começamos inserindo o pedido, seguido por uma operação `run`. A função `Ecto.Multi.run/3` nos permite executar qualquer código na função que deve ter sucesso com `{:ok, result}` ou erro, o que interrompe e reverte a transação. Aqui, simplesmente chamamos nosso contexto de carrinho de compras e pedimos para limpar todos os itens em um carrinho. Executar a transação executará o multi como antes e retornamos o resultado ao chamador.

Para finalizar nossa conclusão de pedido, precisamos implementar a função `ShoppingCart.prune_cart_items/1` em `lib/hello/shopping_cart.ex`:

```elixir
  def prune_cart_items(%Scope{} = scope, %Cart{} = cart) do
    {_, _} = Repo.delete_all(from(i in CartItem, where: i.cart_id == ^cart.id))
    {:ok, get_cart(scope)}
  end
```

Nossa nova função aceita a estrutura do carrinho e emite um `Repo.delete_all` que aceita uma consulta de todos os itens para o carrinho fornecido. Retornamos um resultado de sucesso simplesmente recarregando o carrinho limpo para o chamador. Com nosso contexto completo, agora precisamos mostrar ao usuário seu pedido concluído. Volte ao seu controlador de pedidos e adicione a ação `show/2`:

```elixir
  def show(conn, %{"id" => id}) do
    order = Orders.get_order!(conn.assigns.current_scope, id)
    render(conn, :show, order: order)
  end
```

Adicionamos a ação de exibição para passar nosso `conn.assigns.current_scope` para `get_order!` que autoriza que os pedidos sejam visualizáveis apenas pelo proprietário do pedido. Em seguida, podemos implementar a view e o template. Crie um novo arquivo de view em `lib/hello_web/controllers/order_html.ex` com o seguinte conteúdo:

```elixir
defmodule HelloWeb.OrderHTML do
  use HelloWeb, :html

  embed_templates "order_html/*"
end
```
Em seguida, podemos criar o template em `lib/hello_web/controllers/order_html/show.html.heex`:

```heex
<.header>
  Obrigado pelo seu pedido!
  <:subtitle>
     <strong>Email: </strong>{@current_scope.user.email}
  </:subtitle>
</.header>

<.table id="items" rows={@order.line_items}>
  <:col :let={item} label="Título">{item.product.title}</:col>
  <:col :let={item} label="Quantidade">{item.quantity}</:col>
  <:col :let={item} label="Preço">
    {HelloWeb.CartHTML.currency_to_str(item.price)}
  </:col>
</.table>

<strong>Preço total:</strong>
{HelloWeb.CartHTML.currency_to_str(@order.total_price)}

<.back navigate={~p"/products"}>Voltar aos produtos</.back>
```

Para mostrar nosso pedido concluído, exibimos o usuário do pedido, seguido pela listagem de itens de linha com título do produto, quantidade e o preço que "transacionamos" ao completar o pedido, juntamente com o preço total.

Nossa última adição será adicionar o botão "completar pedido" à nossa página do carrinho para permitir a conclusão de um pedido. Adicione o seguinte botão ao <.header> do template de exibição do carrinho em `lib/hello_web/controllers/cart_html/show.html.heex`:

```diff
  <.header>
    Meu Carrinho
+   <:actions>
+     <.link href={~p"/orders"} method="post">
+       <.button>Completar pedido</.button>
+     </.link>
+   </:actions>
  </.header>
```

Adicionamos um link com `method="post"` para enviar uma requisição POST para nossa ação `OrderController.create`. Se voltarmos à nossa página do carrinho em [`http://localhost:4000/cart`](http://localhost:4000/cart) e completarmos um pedido, seremos recebidos pelo nosso template renderizado:

```text
Obrigado pelo seu pedido!

UUID do usuário: 08964c7c-908c-4a55-bcd3-9811ad8b0b9d
Título                   Quantidade Preço
Metaprogramming Elixir  2          R$15,00

Preço total: R$30,00
```

Bom trabalho! Não adicionamos pagamentos, mas já podemos ver como nossa divisão de contextos `ShoppingCart` e `Orders` está nos levando a uma solução sustentável. Com nossos itens de carrinho separados de nossos itens de linha de pedido, estamos bem equipados no futuro para adicionar transações de pagamento, detecção de preço do carrinho e muito mais.

Excelente trabalho!

## FAQ

### Quando usar geradores de código?

Neste guia, usamos geradores de código para esquemas, contextos, controladores e mais. Se você estiver satisfeito em avançar com os padrões do Phoenix, sinta-se à vontade para confiar nos geradores para estruturar grandes partes da sua aplicação. Ao usar geradores do Phoenix, a principal pergunta que você precisa responder é: esta nova funcionalidade (com seu esquema, tabela e campos) pertence a um dos contextos existentes ou a um novo?

Desta forma, os geradores do Phoenix o orientam a usar contextos para agrupar funcionalidades relacionadas, em vez de ter várias dezenas de esquemas espalhados sem qualquer estrutura. E lembre-se: se você estiver preso ao tentar criar um nome de contexto, você pode simplesmente usar a forma plural do recurso que está criando.

### Como estruturar código dentro de contextos?

Você pode se perguntar como organizar o código dentro dos contextos. Por exemplo, você deve definir um módulo para changesets (como ProductChangesets) e outro módulo para consultas (como ProductQueries)?

Um benefício importante dos contextos é que essa decisão não importa muito. O contexto é sua API pública, os outros módulos são privados. Os contextos isolam esses módulos em pequenos grupos, de modo que a área de superfície de sua aplicação é o contexto e não _todo o seu código_.

Então, embora você e sua equipe possam estabelecer padrões para organizar esses módulos privados, também é nossa opinião que é completamente aceitável que eles sejam diferentes. O foco principal deve ser em como os contextos são definidos e como interagem entre si (e com sua aplicação web).

Pense nisso como um bairro bem conservado. Seus contextos são casas, você quer mantê-las bem preservadas, bem conectadas, etc. Dentro das casas, todas podem ser um pouco diferentes, e isso é bom.

### Retornando estruturas Ecto das APIs de contexto

Ao explorar a API de contexto, você pode ter se perguntado:

> Se um dos objetivos do nosso contexto é encapsular o acesso ao Ecto Repo, por que `create_user/1` retorna uma estrutura `Ecto.Changeset` quando falhamos em criar um usuário?

Embora os Changesets sejam parte do Ecto, eles não estão vinculados ao banco de dados e podem ser usados para mapear dados de e para qualquer fonte, o que o torna uma estrutura de dados geral e útil para rastrear alterações de campo, realizar validações e gerar mensagens de erro.

Por essas razões, `%Ecto.Changeset{}` é uma boa escolha para modelar as mudanças de dados entre seus contextos e sua camada web - independentemente se você está falando com uma API ou com o banco de dados.

Finalmente, note que seus controladores e views não são codificados para trabalhar exclusivamente com Ecto. Em vez disso, o Phoenix define protocolos como `Phoenix.Param` e `Phoenix.HTML.FormData`, que permitem que qualquer biblioteca estenda como o Phoenix gera parâmetros de URL ou renderiza formulários. Convenientemente para nós, o projeto `phoenix_ecto` implementa esses protocolos, mas você também poderia trazer suas próprias estruturas de dados e implementá-las você mesmo.