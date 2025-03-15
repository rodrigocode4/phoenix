# Ecto

> **Requisito**: Este guia pressupõe que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

A maioria das aplicações web atuais necessita de alguma forma de validação e persistência de dados. No ecossistema Elixir, temos o `Ecto` para permitir isso. Antes de mergulharmos na construção de recursos web com banco de dados, vamos nos concentrar nos detalhes do Ecto para estabelecer uma base sólida sobre a qual construiremos nossos recursos web. Vamos começar!

O Phoenix usa o Ecto para fornecer suporte integrado aos seguintes bancos de dados:

* PostgreSQL (via [`postgrex`](https://github.com/elixir-ecto/postgrex))
* MySQL (via [`myxql`](https://github.com/elixir-ecto/myxql))
* MSSQL (via [`tds`](https://github.com/livehelpnow/tds))
* ETS (via [`etso`](https://github.com/evadne/etso))
* SQLite3 (via [`ecto_sqlite3`](https://github.com/elixir-sqlite/ecto_sqlite3))

Novos projetos Phoenix incluem o Ecto com o adaptador PostgreSQL por padrão. Você pode passar a opção `--database` para alterar ou a flag `--no-ecto` para excluir isso.

O Ecto também fornece suporte para outros bancos de dados e tem muitos recursos de aprendizado disponíveis. Por favor, consulte o [README do Ecto](https://github.com/elixir-ecto/ecto) para informações gerais.

Este guia presume que geramos nossa nova aplicação com integração do Ecto e que usaremos PostgreSQL. Os guias introdutórios explicam como fazer sua primeira aplicação funcionar. Para usar outros bancos de dados, consulte a seção [Usando outros bancos de dados](#usando-outros-bancos-de-dados).

## Usando o gerador de schema e migração

Uma vez que temos o Ecto e o PostgreSQL instalados e configurados, a maneira mais fácil de usar o Ecto é gerar um *schema* do Ecto através da tarefa `phx.gen.schema`. Os schemas do Ecto são uma maneira de especificarmos como os tipos de dados do Elixir mapeiam para e de fontes externas, como tabelas de banco de dados. Vamos gerar um schema `User` com os campos `name`, `email`, `bio` e `number_of_pets`.

```console
$ mix phx.gen.schema User users name:string email:string \
bio:string number_of_pets:integer

* creating ./lib/hello/user.ex
* creating priv/repo/migrations/20170523151118_create_users.exs

Remember to update your repository by running migrations:

   $ mix ecto.migrate
```

Alguns arquivos foram gerados com esta tarefa. Primeiro, temos um arquivo `user.ex`, contendo nosso schema do Ecto com nossa definição de schema dos campos que passamos para a tarefa. Em seguida, um arquivo de migração foi gerado dentro de `priv/repo/migrations/` que criará nossa tabela de banco de dados para a qual nosso schema mapeia.

Com nossos arquivos criados, vamos seguir as instruções e executar nossa migração:

```console
$ mix ecto.migrate
Compiling 1 file (.ex)
Generated hello app

[info] == Running Hello.Repo.Migrations.CreateUsers.change/0 forward

[info] create table users

[info] == Migrated in 0.0s
```

O Mix assume que estamos no ambiente de desenvolvimento, a menos que digamos o contrário com `MIX_ENV=prod mix ecto.migrate`.

Se fizermos login no nosso servidor de banco de dados e nos conectarmos ao nosso banco de dados `hello_dev`, deveremos ver nossa tabela `users`. O Ecto assume que queremos uma coluna de inteiros chamada `id` como nossa chave primária, então devemos ver uma sequência gerada para isso também.

```console
$ psql -U postgres

Type "help" for help.

postgres=# \connect hello_dev
You are now connected to database "hello_dev" as user "postgres".
hello_dev=# \d
                List of relations
 Schema |       Name        |   Type   |  Owner
--------+-------------------+----------+----------
 public | schema_migrations | table    | postgres
 public | users             | table    | postgres
 public | users_id_seq      | sequence | postgres
(3 rows)
hello_dev=# \q
```

Se olharmos a migração gerada por `phx.gen.schema` em `priv/repo/migrations/`, veremos que ela adicionará as colunas que especificamos. Também adicionará colunas de timestamp para `inserted_at` e `updated_at` que vêm da função [`timestamps/1`].

```elixir
defmodule Hello.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :email, :string
      add :bio, :string
      add :number_of_pets, :integer

      timestamps()
    end
  end
end
```

E aqui está como isso se traduz na tabela real `users`.

```console
$ psql
hello_dev=# \d users
Table "public.users"
Column         |            Type             | Modifiers
---------------+-----------------------------+----------------------------------------------------
id             | bigint                      | not null default nextval('users_id_seq'::regclass)
name           | character varying(255)      |
email          | character varying(255)      |
bio            | character varying(255)      |
number_of_pets | integer                     |
inserted_at    | timestamp without time zone | not null
updated_at     | timestamp without time zone | not null
Indexes:
"users_pkey" PRIMARY KEY, btree (id)
```

Observe que obtemos uma coluna `id` como nossa chave primária por padrão, mesmo que não esteja listada como um campo em nossa migração.

## Configuração do Repo

Nosso módulo `Hello.Repo` é a base de que precisamos para trabalhar com bancos de dados em uma aplicação Phoenix. O Phoenix o gerou para nós em `lib/hello/repo.ex`, e é assim que ele se parece.

```elixir
defmodule Hello.Repo do
  use Ecto.Repo,
    otp_app: :hello,
    adapter: Ecto.Adapters.Postgres
end
```

Ele começa definindo o módulo do repositório. Em seguida, configura o nome do nosso `otp_app` e o `adapter` - `Postgres`, no nosso caso.

Nosso repo tem três tarefas principais - trazer todas as funções de consulta comuns de [`Ecto.Repo`], definir o nome do `otp_app` igual ao nome da nossa aplicação e configurar nosso adaptador de banco de dados. Falaremos mais sobre como usar o `Hello.Repo` em breve.

Quando `phx.new` gerou nossa aplicação, ele incluiu também alguma configuração básica do repositório. Vamos olhar o `config/dev.exs`.

```elixir
...
# Configure your database
config :hello, Hello.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hello_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
...
```

Também temos configuração similar em `config/test.exs` e `config/runtime.exs` (anteriormente `config/prod.secret.exs`) que também podem ser alterados para corresponder às suas credenciais reais.

## O schema

Os schemas do Ecto são responsáveis por mapear valores do Elixir para fontes de dados externas, bem como mapear dados externos de volta para estruturas de dados do Elixir. Também podemos definir relacionamentos com outros schemas em nossas aplicações. Por exemplo, nosso schema `User` pode ter muitos posts, e cada post pertenceria a um usuário. O Ecto também lida com validação de dados e conversão de tipos com changesets, o que discutiremos em breve.

Aqui está o schema `User` que o Phoenix gerou para nós.

```elixir
defmodule Hello.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :bio, :string
    field :email, :string
    field :name, :string
    field :number_of_pets, :integer

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :bio, :number_of_pets])
    |> validate_required([:name, :email, :bio, :number_of_pets])
  end
end
```

Os schemas do Ecto, em seu núcleo, são simplesmente structs do Elixir. Nosso bloco `schema` é o que diz ao Ecto como converter os campos do nosso struct `%User{}` para e da tabela externa `users`. Muitas vezes, a capacidade de simplesmente converter dados para e do banco de dados não é suficiente e é necessária uma validação de dados adicional. É aí que os changesets do Ecto entram. Vamos mergulhar!

## Changesets e validações

Changesets definem um pipeline de transformações pelos quais nossos dados precisam passar antes de estarem prontos para serem usados por nossa aplicação. Essas transformações podem incluir conversão de tipo, validação de entrada do usuário e filtragem de parâmetros estranhos. Frequentemente usaremos changesets para validar entradas do usuário antes de gravá-las no banco de dados. Os repositórios do Ecto também estão cientes dos changesets, o que lhes permite não apenas recusar dados inválidos, mas também realizar as atualizações mínimas possíveis no banco de dados ao inspecionar o changeset para saber quais campos foram alterados.

Vamos dar uma olhada mais detalhada em nossa função de changeset padrão.

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email, :bio, :number_of_pets])
  |> validate_required([:name, :email, :bio, :number_of_pets])
end
```

No momento, temos duas transformações em nosso pipeline. Na primeira chamada, invocamos `Ecto.Changeset.cast/3`, passando nossos parâmetros externos e marcando quais campos são necessários para validação.

[`cast/3`] primeiro recebe um struct, depois os parâmetros (as atualizações propostas) e, em seguida, o campo final é a lista de colunas a serem atualizadas. [`cast/3`] também só aceitará campos que existam no schema.

Em seguida, `Ecto.Changeset.validate_required/3` verifica se esta lista de campos está presente no changeset que [`cast/3`] retorna. Por padrão, com o gerador, todos os campos são obrigatórios.

Podemos verificar essa funcionalidade no `IEx`. Vamos iniciar nossa aplicação dentro do IEx executando `iex -S mix`. Para minimizar a digitação e tornar isso mais fácil de ler, vamos criar um alias para nosso struct `Hello.User`.

```console
$ iex -S mix

iex> alias Hello.User
Hello.User
```

Em seguida, vamos construir um changeset a partir do nosso schema com um struct `User` vazio e um mapa vazio de parâmetros.

```elixir
iex> changeset = User.changeset(%User{}, %{})
#Ecto.Changeset<
  action: nil,
  changes: %{},
  errors: [
    name: {"can't be blank", [validation: :required]},
    email: {"can't be blank", [validation: :required]},
    bio: {"can't be blank", [validation: :required]},
    number_of_pets: {"can't be blank", [validation: :required]}
  ],
  data: #Hello.User<>,
  valid?: false
>
```

Uma vez que temos um changeset, podemos verificar se ele é válido.

```elixir
iex> changeset.valid?
false
```

Como este não é válido, podemos perguntar quais são os erros.

```elixir
iex> changeset.errors
[
  name: {"can't be blank", [validation: :required]},
  email: {"can't be blank", [validation: :required]},
  bio: {"can't be blank", [validation: :required]},
  number_of_pets: {"can't be blank", [validation: :required]}
]
```

Agora, vamos tornar `number_of_pets` opcional. Para fazer isso, simplesmente o removemos da lista na função `changeset/2`, em `Hello.User`.

```elixir
    |> validate_required([:name, :email, :bio])
```

Agora, ao criar o changeset, ele deve nos dizer que apenas `name`, `email` e `bio` não podem estar em branco. Podemos testar isso executando `recompile()` dentro do IEx e depois reconstruindo nosso changeset.

```elixir
iex> recompile()
Compiling 1 file (.ex)
:ok

iex> changeset = User.changeset(%User{}, %{})
#Ecto.Changeset<
  action: nil,
  changes: %{},
  errors: [
    name: {"can't be blank", [validation: :required]},
    email: {"can't be blank", [validation: :required]},
    bio: {"can't be blank", [validation: :required]}
  ],
  data: #Hello.User<>,
  valid?: false
>

iex> changeset.errors
[
  name: {"can't be blank", [validation: :required]},
  email: {"can't be blank", [validation: :required]},
  bio: {"can't be blank", [validation: :required]}
]
```

O que acontece se passarmos um par chave-valor que não está definido no schema nem é obrigatório?

Dentro do nosso shell IEx existente, vamos criar um mapa `params` com valores válidos mais um `random_key: "random value"` extra.

```elixir
iex> params = %{name: "Joe Example", email: "joe@example.com", bio: "An example to all", number_of_pets: 5, random_key: "random value"}
%{
  bio: "An example to all",
  email: "joe@example.com",
  name: "Joe Example",
  number_of_pets: 5,
  random_key: "random value"
}
```

Em seguida, vamos usar nosso novo mapa `params` para criar outro changeset.

```elixir
iex> changeset = User.changeset(%User{}, params)
#Ecto.Changeset<
  action: nil,
  changes: %{
    bio: "An example to all",
    email: "joe@example.com",
    name: "Joe Example",
    number_of_pets: 5
  },
  errors: [],
  data: #Hello.User<>,
  valid?: true
>
```

Nosso novo changeset é válido.

```elixir
iex> changeset.valid?
true
```

Também podemos verificar as alterações do changeset - o mapa que obtemos após todas as transformações serem concluídas.

```elixir
iex(9)> changeset.changes
%{bio: "An example to all", email: "joe@example.com", name: "Joe Example",
  number_of_pets: 5}
```

Observe que nossa chave `random_key` e o valor `"random value"` foram removidos do changeset final. Os changesets nos permitem converter dados externos, como entrada do usuário em um formulário web ou dados de um arquivo CSV, em dados válidos para nosso sistema. Parâmetros inválidos serão removidos e dados incorretos que não podem ser convertidos de acordo com nosso schema serão destacados nos erros do changeset.

Podemos validar mais do que apenas se um campo é obrigatório ou não. Vamos dar uma olhada em algumas validações mais refinadas.

E se tivéssemos um requisito de que todas as biografias em nosso sistema devem ter pelo menos dois caracteres? Podemos fazer isso facilmente adicionando outra transformação ao pipeline em nosso changeset que valida o comprimento do campo `bio`.

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email, :bio, :number_of_pets])
  |> validate_required([:name, :email, :bio, :number_of_pets])
  |> validate_length(:bio, min: 2)
end
```

Agora, se tentarmos converter dados contendo um valor de `"A"` para o `bio` do nosso usuário, deveríamos ver a validação falhar nos erros do changeset.

```elixir
iex> recompile()

iex> changeset = User.changeset(%User{}, %{bio: "A"})

iex> changeset.errors[:bio]
{"should be at least %{count} character(s)",
 [count: 2, validation: :length, kind: :min, type: :string]}
```

Se também tivermos um requisito para o comprimento máximo que uma bio pode ter, podemos simplesmente adicionar outra validação.

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email, :bio, :number_of_pets])
  |> validate_required([:name, :email, :bio, :number_of_pets])
  |> validate_length(:bio, min: 2)
  |> validate_length(:bio, max: 140)
end
```

Digamos que queremos realizar pelo menos alguma validação de formato rudimentar no campo `email`. Tudo o que queremos verificar é a presença do `@`. A função `Ecto.Changeset.validate_format/3` é exatamente o que precisamos.

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email, :bio, :number_of_pets])
  |> validate_required([:name, :email, :bio, :number_of_pets])
  |> validate_length(:bio, min: 2)
  |> validate_length(:bio, max: 140)
  |> validate_format(:email, ~r/@/)
end
```

Se tentarmos converter um usuário com um email de `"example.com"`, devemos ver uma mensagem de erro como a seguinte:

```elixir
iex> recompile()

iex> changeset = User.changeset(%User{}, %{email: "example.com"})

iex> changeset.errors[:email]
{"has invalid format", [validation: :format]}
```

Existem muitas mais validações e transformações que podemos realizar em um changeset. Consulte a [documentação do Ecto Changeset](https://hexdocs.pm/ecto/Ecto.Changeset.html) para mais informações.

## Persistência de dados

Exploramos migrações e schemas, mas ainda não persistimos nenhum de nossos schemas ou changesets. Olhamos brevemente para nosso módulo de repositório em `lib/hello/repo.ex` anteriormente, e agora é hora de colocá-lo em uso.

Os repositórios do Ecto são a interface para um sistema de armazenamento, seja um banco de dados como PostgreSQL ou um serviço externo como uma API RESTful. O propósito do módulo `Repo` é cuidar dos detalhes mais finos da persistência e consulta de dados para nós. Como chamadores, só nos preocupamos em buscar e persistir dados. O módulo `Repo` cuida da comunicação do adaptador de banco de dados subjacente, do pool de conexões e da tradução de erros para violações de restrições do banco de dados.

Vamos voltar ao IEx com `iex -S mix`, e inserir alguns usuários no banco de dados.

```elixir
iex> alias Hello.{Repo, User}
[Hello.Repo, Hello.User]

iex> Repo.insert(%User{email: "user1@example.com"})
[debug] QUERY OK db=6.5ms queue=0.5ms idle=1358.3ms
INSERT INTO "users" ("email","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["user1@example.com", ~N[2021-02-25 01:58:55], ~N[2021-02-25 01:58:55]]
{:ok,
 %Hello.User{
   __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
   bio: nil,
   email: "user1@example.com",
   id: 1,
   inserted_at: ~N[2021-02-25 01:58:55],
   name: nil,
   number_of_pets: nil,
   updated_at: ~N[2021-02-25 01:58:55]
 }}

iex> Repo.insert(%User{email: "user2@example.com"})
[debug] QUERY OK db=1.3ms idle=1402.7ms
INSERT INTO "users" ("email","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["user2@example.com", ~N[2021-02-25 02:03:28], ~N[2021-02-25 02:03:28]]
{:ok,
 %Hello.User{
   __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
   bio: nil,
   email: "user2@example.com",
   id: 2,
   inserted_at: ~N[2021-02-25 02:03:28],
   name: nil,
   number_of_pets: nil,
   updated_at: ~N[2021-02-25 02:03:28]
 }}
```

Começamos criando um alias para nossos módulos `User` e `Repo` para facilitar o acesso. Em seguida, chamamos [`Repo.insert/2`] com um struct User. Como estamos no ambiente `dev`, podemos ver os logs de depuração para a consulta que nosso repositório executou ao inserir os dados subjacentes `%User{}`. Recebemos uma tupla de dois elementos de volta com `{:ok, %User{}}`, o que nos informa que a inserção foi bem-sucedida.

Também poderíamos inserir um usuário passando um changeset para [`Repo.insert/2`]. Se o changeset for válido, o repositório usará uma consulta de banco de dados otimizada para inserir o registro e retornará uma tupla de dois elementos, como acima. Se o changeset não for válido, receberemos uma tupla de dois elementos que consiste em `:error` mais o changeset inválido.

Com alguns usuários inseridos, vamos buscá-los de volta do repositório.

```elixir
iex> Repo.all(User)
[debug] QUERY OK source="users" db=5.8ms queue=1.4ms idle=1672.0ms
SELECT u0."id", u0."bio", u0."email", u0."name", u0."number_of_pets", u0."inserted_at", u0."updated_at" FROM "users" AS u0 []
[
  %Hello.User{
    __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
    bio: nil,
    email: "user1@example.com",
    id: 1,
    inserted_at: ~N[2021-02-25 01:58:55],
    name: nil,
    number_of_pets: nil,
    updated_at: ~N[2021-02-25 01:58:55]
  },
  %Hello.User{
    __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
    bio: nil,
    email: "user2@example.com",
    id: 2,
    inserted_at: ~N[2021-02-25 02:03:28],
    name: nil,
    number_of_pets: nil,
    updated_at: ~N[2021-02-25 02:03:28]
  }
]
```

Isso foi fácil! `Repo.all/1` recebe uma fonte de dados, nosso schema `User` neste caso, e traduz isso para uma consulta SQL subjacente contra nosso banco de dados. Depois de buscar os dados, o Repo então usa nosso schema Ecto para mapear os valores do banco de dados de volta para estruturas de dados Elixir de acordo com nosso schema `User`. Não estamos limitados apenas a consultas básicas - o Ecto inclui uma DSL completa para geração avançada de SQL. Além de uma DSL natural do Elixir, o mecanismo de consulta do Ecto nos oferece vários recursos excelentes, como proteção contra injeção de SQL e otimização de consultas em tempo de compilação. Vamos experimentá-lo.

```elixir
iex> import Ecto.Query
Ecto.Query

iex> Repo.all(from u in User, select: u.email)
[debug] QUERY OK source="users" db=0.8ms queue=0.9ms idle=1634.0ms
SELECT u0."email" FROM "users" AS u0 []
["user1@example.com", "user2@example.com"]
```

Primeiro, importamos [`Ecto.Query`], que importa a macro [`from/2`] da DSL de Consulta do Ecto. Em seguida, construímos uma consulta que seleciona todos os endereços de e-mail em nossa tabela de usuários. Vamos tentar outro exemplo.

```elixir
iex> Repo.one(from u in User, where: ilike(u.email, "%1%"),
                               select: count(u.id))
[debug] QUERY OK source="users" db=1.6ms SELECT count(u0."id") FROM "users" AS u0 WHERE (u0."email" ILIKE '%1%') []
1
```

Agora estamos começando a ter uma ideia das ricas capacidades de consulta do Ecto. Usamos [`Repo.one/2`] para buscar a contagem de todos os usuários com um endereço de e-mail contendo `1`, e recebemos a contagem esperada em retorno. Isso apenas arranha a superfície da interface de consulta do Ecto, e muito mais é suportado, como subconsultas, consultas de intervalo e instruções select avançadas. Por exemplo, vamos construir uma consulta para buscar um mapa de todos os IDs de usuário para seus endereços de e-mail.

```elixir
iex> Repo.all(from u in User, select: %{u.id => u.email})
[debug] QUERY OK source="users" db=0.9ms
SELECT u0."id", u0."email" FROM "users" AS u0 []
[
  %{1 => "user1@example.com"},
  %{2 => "user2@example.com"}
]
```

Essa pequena consulta deu um grande resultado. Ela buscou todos os e-mails de usuário do banco de dados e construiu eficientemente um mapa dos resultados de uma só vez. Você deve navegar pela [documentação do Ecto.Query](https://hexdocs.pm/ecto/Ecto.Query.html#content) para ver a amplitude dos recursos de consulta suportados.

Além de inserções, também podemos realizar atualizações e exclusões com [`Repo.update/2`] e [`Repo.delete/2`] para atualizar ou excluir um único schema. O Ecto também suporta persistência em massa com as funções [`Repo.insert_all/3`], [`Repo.update_all/3`] e [`Repo.delete_all/2`].

Há muito mais que o Ecto pode fazer e apenas arranhamos a superfície. Com uma base sólida do Ecto estabelecida, agora estamos prontos para continuar construindo nosso aplicativo e integrar a aplicação voltada para a web com nossa persistência de back-end. Ao longo do caminho, expandiremos nosso conhecimento do Ecto e aprenderemos como isolar adequadamente nossa interface web dos detalhes subjacentes do nosso sistema. Por favor, dê uma olhada na [documentação do Ecto](https://hexdocs.pm/ecto/) para o resto da história.

Em nosso [guia de contextos](contexts.html), descobriremos como encapsular nosso acesso ao Ecto e lógica de negócios por trás de módulos que agrupam funcionalidades relacionadas. Veremos como o Phoenix nos ajuda a projetar aplicações de fácil manutenção, e descobriremos outros recursos interessantes do Ecto ao longo do caminho.

## Usando outros bancos de dados

As aplicações Phoenix são configuradas para usar PostgreSQL por padrão, mas e se quisermos usar outro banco de dados, como MySQL? Nesta seção, veremos como mudar esse padrão, seja quando estamos prestes a criar uma nova aplicação, seja quando temos uma existente configurada para PostgreSQL.

Se estamos prestes a criar uma nova aplicação, configurá-la para usar MySQL é fácil. Podemos simplesmente passar a flag `--database mysql` para `phx.new` e tudo será configurado corretamente.

```console
$ mix phx.new hello_phoenix --database mysql
```

Isso configurará todas as dependências e configurações corretas para nós automaticamente. Depois de instalar essas dependências com `mix deps.get`, estaremos prontos para começar a trabalhar com o Ecto em nossa aplicação.

Se temos uma aplicação existente, tudo o que precisamos fazer é mudar os adaptadores e fazer algumas pequenas alterações de configuração.

Para mudar de adaptador, precisamos remover a dependência do Postgrex e adicionar uma nova para o MyXQL.

Vamos abrir nosso arquivo `mix.exs` e fazer isso agora.

```elixir
defmodule HelloPhoenix.MixProject do
  use Mix.Project

  . . .
  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:myxql, ">= 0.0.0"},
      ...
    ]
  end
end
```

Em seguida, precisamos configurar nosso adaptador para usar as credenciais padrão do MySQL atualizando `config/dev.exs`:

```elixir
config :hello_phoenix, HelloPhoenix.Repo,
  username: "root",
  password: "",
  database: "hello_phoenix_dev"
```

Se já temos um bloco de configuração para nosso `HelloPhoenix.Repo`, podemos simplesmente alterar os valores para corresponder aos nossos novos valores. Você também precisa configurar os valores corretos nos arquivos `config/test.exs` e `config/runtime.exs` (anteriormente `config/prod.secret.exs`) também.

A última alteração é abrir `lib/hello_phoenix/repo.ex` e garantir que o `:adapter` seja definido como `Ecto.Adapters.MyXQL`.

Agora tudo o que precisamos fazer é buscar nossa nova dependência, e estaremos prontos para começar.

```console
$ mix deps.get
```

Com nosso novo adaptador instalado e configurado, estamos prontos para criar nosso banco de dados.

```console
$ mix ecto.create
```

O banco de dados para HelloPhoenix.Repo foi criado.
Também estamos prontos para executar quaisquer migrações ou fazer qualquer outra coisa com o Ecto que possamos escolher.

```console
$ mix ecto.migrate
[info] == Running HelloPhoenix.Repo.Migrations.CreateUser.change/0 forward
[info] create table users
[info] == Migrated in 0.2s
```

## Outras opções

Enquanto o Phoenix usa o projeto `Ecto` para interagir com a camada de acesso a dados, existem muitas outras opções de acesso a dados, algumas até incorporadas na biblioteca padrão do Erlang. [ETS](https://www.erlang.org/doc/man/ets.html) – disponível no Ecto via [`etso`](https://hexdocs.pm/etso/) – e [DETS](https://www.erlang.org/doc/man/dets.html) são armazenamentos de dados chave-valor incorporados ao [OTP](https://www.erlang.org/doc/). O OTP também fornece um banco de dados relacional chamado [Mnesia](https://www.erlang.org/doc/man/mnesia.html) com sua própria linguagem de consulta chamada QLC. Tanto o Elixir quanto o Erlang também têm várias bibliotecas para trabalhar com uma ampla gama de armazenamentos de dados populares.

O mundo dos dados é sua ostra, mas não cobriremos essas opções nestes guias.

[`cast/3`]: `Ecto.Changeset.cast/3`
[`from/2`]: `Ecto.Query.from/2`
[`Repo.delete_all/2`]: `c:Ecto.Repo.delete_all/2`
[`Repo.delete/2`]: `c:Ecto.Repo.delete/2`
[`Repo.insert_all/3`]: `c:Ecto.Repo.insert_all/3`
[`Repo.insert/2`]: `c:Ecto.Repo.insert/2`
[`Repo.one/2`]: `c:Ecto.Repo.one/2`
[`Repo.update_all/3`]: `c:Ecto.Repo.update_all/3`
[`Repo.update/2`]: `c:Ecto.Repo.update/2`
[`timestamps/1`]: `Ecto.Migration.timestamps/1`