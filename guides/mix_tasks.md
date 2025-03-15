# Tarefas Mix

Existem atualmente várias tarefas [Mix tasks](`Mix.Task`) específicas do Phoenix e do Ecto disponíveis para nós em uma aplicação recém-gerada. Também podemos criar nossas próprias tarefas específicas para a aplicação.

> Nota: para saber mais sobre o `mix`, você pode ler a [Introdução ao Mix](https://hexdocs.pm/elixir/introduction-to-mix.html) oficial do Elixir.

## Tarefas do Phoenix

```console
$ mix help --search "phx"
mix local.phx          # Atualiza o gerador de projetos Phoenix localmente
mix phx                # Imprime informações de ajuda do Phoenix
mix phx.digest         # Gera digest e comprime arquivos estáticos
mix phx.digest.clean   # Remove versões antigas de assets estáticos
mix phx.gen.auth       # Gera lógica de autenticação para um recurso
mix phx.gen.cert       # Gera um certificado autoassinado para testes HTTPS
mix phx.gen.channel    # Gera um canal Phoenix
mix phx.gen.context    # Gera um contexto com funções em torno de um esquema Ecto
mix phx.gen.embedded   # Gera um arquivo de esquema Ecto embutido
mix phx.gen.html       # Gera controlador, views e contexto para um recurso HTML
mix phx.gen.json       # Gera controlador, views e contexto para um recurso JSON
mix phx.gen.live       # Gera LiveView, templates e contexto para um recurso
mix phx.gen.notifier   # Gera um notificador que entrega emails por padrão
mix phx.gen.presence   # Gera um rastreador de Presença
mix phx.gen.schema     # Gera um esquema Ecto e arquivo de migração
mix phx.gen.secret     # Gera um segredo
mix phx.gen.socket     # Gera um manipulador de socket Phoenix
mix phx.new            # Cria uma nova aplicação Phoenix
mix phx.new.ecto       # Cria um novo projeto Ecto dentro de um projeto guarda-chuva
mix phx.new.web        # Cria um novo projeto web Phoenix dentro de um projeto guarda-chuva
mix phx.routes         # Imprime todas as rotas
mix phx.server         # Inicia aplicações e seus servidores
```

Vimos todas essas em algum momento nos guias, mas ter todas as informações sobre elas em um único lugar parece uma boa ideia.

Vamos cobrir todas as tarefas Mix do Phoenix, exceto `phx.new`, `phx.new.ecto` e `phx.new.web`, que fazem parte do instalador do Phoenix. Você pode aprender mais sobre elas ou qualquer outra tarefa chamando `mix help TAREFA`.

### `mix phx.gen.html`

O Phoenix oferece a capacidade de gerar todo o código para criar um recurso HTML completo — migração Ecto, contexto Ecto, controlador com todas as ações necessárias, view e templates. Isso pode ser uma tremenda economia de tempo. Vamos dar uma olhada em como fazer isso acontecer.

A tarefa `mix phx.gen.html` recebe os seguintes argumentos: o nome do módulo do contexto, o nome do módulo do esquema, o nome do recurso e uma lista de atributos column_name:type. O nome do módulo que passamos deve estar em conformidade com as regras de nomenclatura de módulos do Elixir, seguindo a capitalização adequada.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/controllers/post_html/edit.html.heex
* creating lib/hello_web/controllers/post_html/post_form.html.heex
* creating lib/hello_web/controllers/post_html/index.html.heex
* creating lib/hello_web/controllers/post_html/new.html.heex
* creating lib/hello_web/controllers/post_html/show.html.heex
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
```

Quando `mix phx.gen.html` termina de criar arquivos, ele nos informa que precisamos adicionar uma linha ao nosso arquivo de roteador, além de executar nossas migrações Ecto.

```console
Adicione o recurso ao seu escopo de navegador em lib/hello_web/router.ex:

    resources "/posts", PostController

Lembre-se de atualizar seu repositório executando migrações:

    $ mix ecto.migrate
```

Importante: Se não fizermos isso, veremos os seguintes avisos em nossos logs, e nossa aplicação gerará um erro ao compilar.

```console
$ mix phx.server
Compiling 17 files (.ex)

warning: no route path for HelloWeb.Router matches \"/posts\"
  lib/hello_web/controllers/post_controller.ex:22: HelloWeb.PostController.index/2
```

Se não quisermos criar um contexto ou esquema para nosso recurso, podemos usar a flag `--no-context`. Observe que isso ainda requer um nome de módulo de contexto como parâmetro.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer --no-context
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/controllers/post_html/edit.html.heex
* creating lib/hello_web/controllers/post_html/post_form.html.heex
* creating lib/hello_web/controllers/post_html/index.html.heex
* creating lib/hello_web/controllers/post_html/new.html.heex
* creating lib/hello_web/controllers/post_html/show.html.heex
* creating lib/hello_web/controllers/post_html.ex
* creating test/hello_web/controllers/post_controller_test.exs
```

Ele nos dirá que precisamos adicionar uma linha ao nosso arquivo de roteador, mas como pulamos o contexto, não mencionará nada sobre `ecto.migrate`.

```console
Adicione o recurso ao seu escopo de navegador em lib/hello_web/router.ex:

    resources "/posts", PostController
```

Da mesma forma, se queremos um contexto criado sem um esquema para nosso recurso, podemos usar a flag `--no-schema`.

```console
$ mix phx.gen.html Blog Post posts body:string word_count:integer --no-schema
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/controllers/post_html/edit.html.heex
* creating lib/hello_web/controllers/post_html/post_form.html.heex
* creating lib/hello_web/controllers/post_html/index.html.heex
* creating lib/hello_web/controllers/post_html/new.html.heex
* creating lib/hello_web/controllers/post_html/show.html.heex
* creating lib/hello_web/controllers/post_html.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog_test.exs
* injecting test/hello/blog_test.exs
* creating test/support/fixtures/blog_fixtures.ex
* injecting test/support/fixtures/blog_fixtures.ex
```

Ele nos dirá que precisamos adicionar uma linha ao nosso arquivo de roteador, mas como pulamos o esquema, não mencionará nada sobre `ecto.migrate`.

### `mix phx.gen.json`

O Phoenix também oferece a capacidade de gerar todo o código para criar um recurso JSON completo — migração Ecto, esquema Ecto, controlador com todas as ações necessárias e view. Este comando não criará nenhum template para o aplicativo.

A tarefa `mix phx.gen.json` recebe os seguintes argumentos: o nome do módulo do contexto, o nome do módulo do esquema, o nome do recurso e uma lista de atributos column_name:type. O nome do módulo que passamos deve estar em conformidade com as regras de nomenclatura de módulos do Elixir, seguindo a capitalização adequada.

```console
$ mix phx.gen.json Blog Post posts title:string content:string
* creating lib/hello_web/controllers/post_controller.ex
* creating lib/hello_web/controllers/post_json.ex
* creating test/hello_web/controllers/post_controller_test.exs
* creating lib/hello_web/controllers/changeset_json.ex
* creating lib/hello_web/controllers/fallback_controller.ex
* creating lib/hello/blog/post.ex
* creating priv/repo/migrations/20170906153323_create_posts.exs
* creating lib/hello/blog.ex
* injecting lib/hello/blog.ex
* creating test/hello/blog/blog_test.exs
* injecting test/hello/blog/blog_test.exs
* creating test/support/fixtures/blog_fixtures.ex
* injecting test/support/fixtures/blog_fixtures.ex
```

Quando `mix phx.gen.json` termina de criar arquivos, ele nos informa que precisamos adicionar uma linha ao nosso arquivo de roteador, além de executar nossas migrações Ecto.

```console
Adicione o recurso ao escopo "/api" em lib/hello_web/router.ex:

    resources "/posts", PostController, except: [:new, :edit]

Lembre-se de atualizar seu repositório executando migrações:

    $ mix ecto.migrate
```

Importante: Se não fizermos isso, receberemos o seguinte aviso em nossos logs e a aplicação gerará um erro ao tentar compilar:

```console
$ mix phx.server
Compiling 19 files (.ex)

warning: no route path for HelloWeb.Router matches \"/posts\"
  lib/hello_web/controllers/post_controller.ex:22: HelloWeb.PostController.index/2
```

`mix phx.gen.json` também suporta `--no-context`, `--no-schema` e outros, como em `mix phx.gen.html`.

### `mix phx.gen.context`

Se não precisarmos de um recurso HTML/JSON completo e só precisarmos de um contexto, podemos usar a tarefa `mix phx.gen.context`. Ela gerará um contexto, um esquema, uma migração e um caso de teste.

A tarefa `mix phx.gen.context` recebe os seguintes argumentos: o nome do módulo do contexto, o nome do módulo do esquema, o nome do recurso e uma lista de atributos column_name:type.

```console
$ mix phx.gen.context Accounts User users name:string age:integer
* creating lib/hello/accounts/user.ex
* creating priv/repo/migrations/20170906161158_create_users.exs
* creating lib/hello/accounts.ex
* injecting lib/hello/accounts.ex
* creating test/hello/accounts/accounts_test.exs
* injecting test/hello/accounts/accounts_test.exs
* creating test/support/fixtures/accounts_fixtures.ex
* injecting test/support/fixtures/accounts_fixtures.ex
```

> Nota: Se precisarmos estabelecer um namespace para nosso recurso, podemos simplesmente colocar o primeiro argumento do gerador em um namespace.

```console
$ mix phx.gen.context Admin.Accounts User users name:string age:integer
* creating lib/hello/admin/accounts/user.ex
* creating priv/repo/migrations/20170906161246_create_users.exs
* creating lib/hello/admin/accounts.ex
* injecting lib/hello/admin/accounts.ex
* creating test/hello/admin/accounts_test.exs
* injecting test/hello/admin/accounts_test.exs
* creating test/support/fixtures/admin/accounts_fixtures.ex
* injecting test/support/fixtures/admin/accounts_fixtures.ex
```

### `mix phx.gen.schema`

Se não precisarmos de um recurso HTML/JSON completo e não estivermos interessados em gerar ou alterar um contexto, podemos usar a tarefa `mix phx.gen.schema`. Ela gerará um esquema e uma migração.

A tarefa `mix phx.gen.schema` recebe os seguintes argumentos: o nome do módulo do esquema (que pode estar em um namespace), o nome do recurso e uma lista de atributos column_name:type.

```console
$ mix phx.gen.schema Accounts.Credential credentials email:string:unique user_id:references:users
* creating lib/hello/accounts/credential.ex
* creating priv/repo/migrations/20170906162013_create_credentials.exs
```

### `mix phx.gen.auth`

O Phoenix também oferece a capacidade de gerar todo o código para configurar um sistema de autenticação completo — migração Ecto, contexto phoenix, controladores, templates, etc. Isso pode ser uma enorme economia de tempo, permitindo que você rapidamente adicione autenticação ao seu sistema e volte seu foco para os problemas primários que sua aplicação está tentando resolver.

A tarefa `mix phx.gen.auth` recebe os seguintes argumentos: o nome do módulo do contexto, o nome do módulo do esquema e uma versão plural do nome do esquema usado para gerar tabelas de banco de dados e caminhos de rota.

Aqui está um exemplo da versão do comando:

```console
$ mix phx.gen.auth Accounts User users
* creating priv/repo/migrations/20201205184926_create_users_auth_tables.exs
* creating lib/hello/accounts/user_notifier.ex
* creating lib/hello/accounts/user.ex
* creating lib/hello/accounts/user_token.ex
* creating lib/hello_web/controllers/user_auth.ex
* creating test/hello_web/controllers/user_auth_test.exs
* creating lib/hello_web/controllers/user_confirmation_html.ex
* creating lib/hello_web/templates/user_confirmation/new.html.heex
* creating lib/hello_web/templates/user_confirmation/edit.html.heex
* creating lib/hello_web/controllers/user_confirmation_controller.ex
* creating test/hello_web/controllers/user_confirmation_controller_test.exs
* creating lib/hello_web/templates/user_registration/new.html.heex
* creating lib/hello_web/controllers/user_registration_controller.ex
* creating test/hello_web/controllers/user_registration_controller_test.exs
* creating lib/hello_web/controllers/user_registration_html.ex
* creating lib/hello_web/controllers/user_reset_password_html.ex
* creating lib/hello_web/controllers/user_reset_password_controller.ex
* creating test/hello_web/controllers/user_reset_password_controller_test.exs
* creating lib/hello_web/templates/user_reset_password/edit.html.heex
* creating lib/hello_web/templates/user_reset_password/new.html.heex
* creating lib/hello_web/controllers/user_session_html.ex
* creating lib/hello_web/controllers/user_session_controller.ex
* creating test/hello_web/controllers/user_session_controller_test.exs
* creating lib/hello_web/templates/user_session/new.html.heex
* creating lib/hello_web/controllers/user_settings_html.ex
* creating lib/hello_web/templates/user_settings/edit.html.heex
* creating lib/hello_web/controllers/user_settings_controller.ex
* creating test/hello_web/controllers/user_settings_controller_test.exs
* creating lib/hello/accounts.ex
* injecting lib/hello/accounts.ex
* creating test/hello/accounts_test.exs
* injecting test/hello/accounts_test.exs
* creating test/support/fixtures/accounts_fixtures.ex
* injecting test/support/fixtures/accounts_fixtures.ex
* injecting test/support/conn_case.ex
* injecting config/test.exs
* injecting mix.exs
* injecting lib/hello_web/router.ex
* injecting lib/hello_web/router.ex - imports
* injecting lib/hello_web/router.ex - plug
* injecting lib/hello_web/templates/layout/root.html.heex
```

Quando `mix phx.gen.auth` termina de criar arquivos, ele nos informa que precisamos buscar novamente nossas dependências, além de executar nossas migrações Ecto.

```console
Por favor, busque suas dependências novamente com o seguinte comando:

    mix deps.get

Lembre-se de atualizar seu repositório executando migrações:

  $ mix ecto.migrate

Quando estiver pronto, visite "/users/register"
para criar sua conta e depois acesse "/dev/mailbox" para
ver o email de confirmação da conta.
```

Um passo a passo mais completo de como começar com este gerador está disponível no [guia de autenticação `mix phx.gen.auth`](mix_phx_gen_auth.html).

### `mix phx.gen.channel` e `mix phx.gen.socket`

Esta tarefa gerará um canal Phoenix básico, o socket para alimentar o canal (se você ainda não tiver criado um), além de um caso de teste para ele. Ela recebe o nome do módulo para o canal como único argumento:

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs
```

Se sua aplicação ainda não tiver um `UserSocket`, ele perguntará se você deseja criar um:

```console
O manipulador de socket padrão - HelloWeb.UserSocket - não foi encontrado
em sua localização padrão.

Você quer criá-lo? [Y/n]
```

Ao confirmar, um canal será criado, então você precisa conectar o socket em seu endpoint:

```console
Adicione o manipulador de socket ao seu `lib/hello_web/endpoint.ex`, por exemplo:

    socket "/socket", HelloWeb.UserSocket,
      websocket: true,
      longpoll: false

Para a integração front-end, você precisa importar o `user_socket.js`
em seu arquivo `assets/js/app.js`:

    import "./user_socket.js"
```

Caso um `UserSocket` já exista ou você decida não criar um, o gerador de `channel` informará que você deve adicioná-lo ao Socket manualmente:

```console
Adicione o canal ao seu manipulador `lib/hello_web/channels/user_socket.ex`, por exemplo:

    channel "rooms:lobby", HelloWeb.RoomChannel
```

Você também pode criar um socket a qualquer momento invocando `mix phx.gen.socket`.

### `mix phx.gen.presence`

Esta tarefa gerará um rastreador de presença. O nome do módulo pode ser passado como um argumento,
`Presence` é usado se nenhum nome de módulo for passado.

```console
$ mix phx.gen.presence Presence
* lib/hello_web/channels/presence.ex

Adicione seu novo módulo à sua árvore de supervisão,
em lib/hello/application.ex:

    children = [
      ...
      HelloWeb.Presence
    ]
```

### `mix phx.routes`

Esta tarefa tem um único propósito, mostrar-nos todas as rotas definidas para um determinado roteador. Nós a vimos sendo usada extensivamente no [guia de roteamento](routing.html).

Se não especificarmos um roteador para esta tarefa, ela usará por padrão o roteador que o Phoenix gerou para nós.

```console
$ mix phx.routes
GET  /  TaskTester.PageController.index/2
```

Também podemos especificar um roteador individual se tivermos mais de um para nossa aplicação.

```console
$ mix phx.routes TaskTesterWeb.Router
GET  /  TaskTesterWeb.PageController.index/2
```

### `mix phx.server`

Esta é a tarefa que usamos para fazer nossa aplicação funcionar. Ela não recebe nenhum argumento. Se passarmos algum, ele será silenciosamente ignorado.

```console
$ mix phx.server
[info] Running TaskTesterWeb.Endpoint with Cowboy na porta 4000 (http)
```

Ela ignorará silenciosamente nosso argumento `DoesNotExist`:

```console
$ mix phx.server DoesNotExist
[info] Running TaskTesterWeb.Endpoint with Cowboy na porta 4000 (http)
```

Se quisermos iniciar nossa aplicação e também ter uma sessão `IEx` aberta para ela, podemos executar a tarefa Mix dentro do `iex` assim, `iex -S mix phx.server`.

```console
$ iex -S mix phx.server
Erlang/OTP 17 [erts-6.4] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

[info] Running TaskTesterWeb.Endpoint with Cowboy na porta 4000 (http)
Interactive Elixir (1.0.4) - pressione Ctrl+C para sair (digite h() ENTER para ajuda)
iex(1)>
```

### `mix phx.digest`

Esta tarefa faz duas coisas, cria um digest para nossos ativos estáticos e depois os comprime.

"Digest" aqui se refere a um digest MD5 do conteúdo de um ativo que é adicionado ao nome do arquivo desse ativo. Isso cria uma espécie de impressão digital para ele. Se o digest não mudar, navegadores e CDNs usarão uma versão em cache. Se mudar, eles buscarão a nova versão.

Antes de executarmos esta tarefa, vamos inspecionar o conteúdo de dois diretórios em nossa aplicação hello.

Primeiro `priv/static/` que deve se parecer com isto:

```console
├── assets
│   ├── app.css
│   └── app.js
├── favicon.ico
└── robots.txt
```

E depois `assets/` que deve se parecer com isto:

```console
├── css
│   └── app.css
├── js
│   └── app.js
├── tailwind.config.js
└── vendor
    └── topbar.js
```

Todos esses arquivos são nossos ativos estáticos. Agora vamos executar a tarefa `mix phx.digest`.

```console
$ mix phx.digest
Verifique seus arquivos digeridos em 'priv/static'.
```

Agora podemos fazer como a tarefa sugere e inspecionar o conteúdo do diretório `priv/static/`. Veremos que todos os arquivos de `assets/` foram copiados para `priv/static/` e também cada arquivo agora tem algumas versões. Essas versões são:

* o arquivo original
* um arquivo comprimido com gzip
* um arquivo contendo o nome do arquivo original e seu digest
* um arquivo comprimido contendo o nome do arquivo e seu digest

Podemos determinar opcionalmente quais arquivos devem ser comprimidos em gzip usando a opção `:gzippable_exts` no arquivo de configuração:

```elixir
config :phoenix, :gzippable_exts, ~w(.js .css)
```

> Nota: Podemos especificar uma pasta de saída diferente onde `mix phx.digest` colocará os arquivos processados. O primeiro argumento é o caminho onde os arquivos estáticos estão localizados.

```console
$ mix phx.digest priv/static/ -o www/public/
Verifique seus arquivos digeridos em 'www/public/'
```

> Nota: Você pode usar `mix phx.digest.clean` para remover versões obsoletas dos ativos. Se quiser remover todos os arquivos produzidos, execute `mix phx.digest.clean --all`.

## Tarefas Ecto

Aplicações Phoenix recém-geradas agora incluem Ecto e Postgrex como dependências por padrão (ou seja, a menos que usemos `mix phx.new` com a flag `--no-ecto`). Com essas dependências vêm tarefas Mix para cuidar de operações comuns do Ecto. Vamos ver quais tarefas obtemos prontas.

```console
$ mix help --search "ecto"
mix ecto               # Imprime informações de ajuda do Ecto
mix ecto.create        # Cria o armazenamento do repositório
mix ecto.drop          # Descarta o armazenamento do repositório
mix ecto.dump          # Despeja a estrutura do banco de dados do repositório
mix ecto.gen.migration # Gera uma nova migração para o repositório
mix ecto.gen.repo      # Gera um novo repositório
mix ecto.load          # Carrega a estrutura do banco de dados despejada anteriormente
mix ecto.migrate       # Executa as migrações do repositório
mix ecto.migrations    # Exibe o status da migração do repositório
mix ecto.reset         # Alias definido em mix.exs
mix ecto.rollback      # Reverte as migrações do repositório
mix ecto.setup         # Alias definido em mix.exs
```

Nota: Podemos executar qualquer uma das tarefas acima com a flag `--no-start` para executar a tarefa sem iniciar a aplicação.

### `mix ecto.create`

Esta tarefa criará o banco de dados especificado em nosso repositório. Por padrão, ela procurará o repositório com o nome da nossa aplicação (o que foi gerado com nosso aplicativo, a menos que tenhamos optado por não usar o Ecto), mas podemos passar outro repositório se quisermos.

Veja como é na prática.

```console
$ mix ecto.create
O banco de dados para Hello.Repo foi criado.
```

Há algumas coisas que podem dar errado com `ecto.create`. Se nosso banco de dados Postgres não tiver uma função (usuário) "postgres", receberemos um erro como este.

```console
$ mix ecto.create
** (Mix) O banco de dados para Hello.Repo não pôde ser criado, motivo dado: psql: FATAL: função "postgres" não existe
```

Podemos corrigir isso criando a função "postgres" no console `psql` com as permissões necessárias para fazer login e criar um banco de dados.

```console
=# CREATE ROLE postgres LOGIN CREATEDB;
CREATE ROLE
```

Se a função "postgres" não tiver permissão para fazer login na aplicação, receberemos este erro.

```console
$ mix ecto.create
** (Mix) O banco de dados para Hello.Repo não pôde ser criado, motivo dado: psql: FATAL: função "postgres" não tem permissão para fazer login
```

Para corrigir isso, precisamos alterar as permissões do nosso usuário "postgres" para permitir o login.

```console
=# ALTER ROLE postgres LOGIN;
ALTER ROLE
```

Se a função "postgres" não tiver permissão para criar um banco de dados, receberemos este erro.

```console
$ mix ecto.create
** (Mix) O banco de dados para Hello.Repo não pôde ser criado, motivo dado: ERROR: permissão negada para criar banco de dados
```

Para corrigir isso, precisamos alterar as permissões do nosso usuário "postgres" no console `psql` para permitir a criação de banco de dados.

```console
=# ALTER ROLE postgres CREATEDB;
ALTER ROLE
```

Se a função "postgres" estiver usando uma senha diferente do padrão "postgres", receberemos este erro.

```console
$ mix ecto.create
** (Mix) O banco de dados para Hello.Repo não pôde ser criado, motivo dado: psql: FATAL: autenticação por senha falhou para o usuário "postgres"
```

Para corrigir isso, podemos alterar a senha no arquivo de configuração específico do ambiente. Para o ambiente de desenvolvimento, a senha usada pode ser encontrada no final do arquivo `config/dev.exs`.

Finalmente, se por acaso tivermos outro repositório chamado `OurCustom.Repo` para o qual queremos criar o banco de dados, podemos executar isto.

```console
$ mix ecto.create -r OurCustom.Repo
O banco de dados para OurCustom.Repo foi criado.
```

### `mix ecto.drop`

Esta tarefa descartará o banco de dados especificado em nosso repositório. Por padrão, ela procurará o repositório com o nome da nossa aplicação (o que foi gerado com nosso aplicativo, a menos que tenhamos optado por não usar o Ecto). Ela não nos pedirá para verificar se temos certeza de que queremos descartar o banco de dados, então tenha cuidado.

```console
$ mix ecto.drop
O banco de dados para Hello.Repo foi descartado.
```

Se por acaso tivermos outro repositório para o qual queremos descartar o banco de dados, podemos especificá-lo com a flag `-r`.

```console
$ mix ecto.drop -r OurCustom.Repo
O banco de dados para OurCustom.Repo foi descartado.
```

### `mix ecto.gen.repo`

Muitas aplicações exigem mais de um armazenamento de dados. Para cada armazenamento de dados, precisaremos de um novo repositório, e podemos gerá-los automaticamente com `ecto.gen.repo`.

Se nomearmos nosso repositório `OurCustom.Repo`, esta tarefa o criará aqui `lib/our_custom/repo.ex`.

```console
$ mix ecto.gen.repo -r OurCustom.Repo
* creating lib/our_custom
* creating lib/our_custom/repo.ex
* updating config/config.exs
Não se esqueça de adicionar seu novo repositório à sua árvore de supervisão
(normalmente em lib/hello/application.ex):

    {OurCustom.Repo, []}
```

Observe que esta tarefa atualizou `config/config.exs`. Se dermos uma olhada, veremos este bloco de configuração adicional para nosso novo repositório.

```elixir
. . .
config :hello, OurCustom.Repo,
  username: "user",
  password: "pass",
  hostname: "localhost",
  database: "hello_repo",
. . .
```

Claro, precisaremos mudar as credenciais de login para corresponder ao que nosso banco de dados espera. Também precisaremos mudar a configuração para outros ambientes.

Certamente devemos seguir as instruções e adicionar nosso novo repositório à nossa árvore de supervisão. Em nossa aplicação `Hello`, abriríamos `lib/hello/application.ex` e adicionaríamos nosso repositório como um worker à lista `children`.

```elixir
. . .
children = [
  Hello.Repo,
  # Nosso repositório personalizado
  OurCustom.Repo,
  # Inicia o endpoint quando a aplicação inicia
  HelloWeb.Endpoint,
]
. . .
```

### `mix ecto.gen.migration`

Migrações são uma forma programática e repetível de efetuar mudanças em um esquema de banco de dados. Migrações são apenas módulos, e podemos criá-los com a tarefa [`ecto.gen.migration`](`mix ecto.gen.migration`). Vamos percorrer as etapas para criar uma migração para uma nova tabela de comentários.

Simplesmente precisamos invocar a tarefa com uma versão em `snake_case` do nome do módulo que queremos. Preferencialmente, o nome descreverá o que queremos que a migração faça.

```console
$ mix ecto.gen.migration add_comments_table
* creating priv/repo/migrations
* creating priv/repo/migrations/20150318001628_add_comments_table.exs
```

Observe que o nome do arquivo da migração começa com uma representação de string da data e hora em que o arquivo foi criado.

Vamos dar uma olhada no arquivo que `ecto.gen.migration` gerou para nós em `priv/repo/migrations/20150318001628_add_comments_table.exs`.

```elixir
defmodule Hello.Repo.Migrations.AddCommentsTable do
  use Ecto.Migration

  def change do
  end
end
```

Observe que há uma única função `change/0` que lidará com migrações para frente e reversões. Definiremos as alterações de esquema que queremos usando o DSL prático do Ecto, e o Ecto descobrirá o que fazer dependendo se estamos avançando ou revertendo. Muito bom, de fato.

O que queremos fazer é criar uma tabela `comments` com uma coluna `body`, uma coluna `word_count` e colunas de timestamp para `inserted_at` e `updated_at`.

```elixir
. . .
def change do
  create table(:comments) do
    add :body, :string
    add :word_count, :integer
    timestamps()
  end
end
. . .
```

Novamente, podemos executar esta tarefa com a flag `-r` e outro repositório se precisarmos.

```console
$ mix ecto.gen.migration -r OurCustom.Repo add_users
* creating priv/repo/migrations
* creating priv/repo/migrations/20150318172927_add_users.exs
```

Para mais informações sobre como modificar seu esquema de banco de dados, consulte a [documentação do DSL de migração do Ecto](https://hexdocs.pm/ecto_sql/Ecto.Migration.html).
Por exemplo, para alterar um esquema existente, veja a documentação sobre a função [`alter/2`](`Ecto.Migration.alter/2`) do Ecto.

É isso! Estamos prontos para executar nossa migração.

### `mix ecto.migrate`

Depois que tivermos nosso módulo de migração pronto, podemos simplesmente executar `mix ecto.migrate` para ter nossas alterações aplicadas ao banco de dados.

```console
$ mix ecto.migrate
[info] == Executando Hello.Repo.Migrations.AddCommentsTable.change/0 para frente
[info] criar tabela comments
[info] == Migrado em 0.1s
```

Quando executamos `ecto.migrate` pela primeira vez, ele criará uma tabela para nós chamada `schema_migrations`. Isso acompanhará todas as migrações que executamos armazenando a parte do timestamp do nome do arquivo da migração.

Veja como é a tabela `schema_migrations`.

```console
hello_dev=# select * from schema_migrations;
version        |     inserted_at
---------------+---------------------
20150317170448 | 2015-03-17 21:07:26
20150318001628 | 2015-03-18 01:45:00
(2 rows)
```

Quando revertemos uma migração, [`ecto.rollback`](#mix-ecto-rollback) removerá o registro que representa esta migração de `schema_migrations`.

Por padrão, `ecto.migrate` executará todas as migrações pendentes. Podemos exercer mais controle sobre quais migrações executamos especificando algumas opções quando executamos a tarefa.

Podemos especificar o número de migrações pendentes que gostaríamos de executar com as opções `-n` ou `--step`.

```console
$ mix ecto.migrate -n 2
[info] == Executando Hello.Repo.Migrations.CreatePost.change/0 para frente
[info] criar tabela posts
[info] == Migrado em 0.0s
[info] == Executando Hello.Repo.Migrations.AddCommentsTable.change/0 para frente
[info] criar tabela comments
[info] == Migrado em 0.0s
```

A opção `--step` se comportará da mesma maneira.

```console
mix ecto.migrate --step 2
```

A opção `--to` executará todas as migrações até, e incluindo, a versão fornecida.

```console
mix ecto.migrate --to 20150317170448
```

### `mix ecto.rollback`

A tarefa [`ecto.rollback`](`mix ecto.rollback`) reverterá a última migração que executamos, desfazendo as alterações no esquema. [`ecto.migrate`](#mix-ecto-migrate) e `ecto.rollback` são imagens espelhadas uma da outra.

```console
$ mix ecto.rollback
[info] == Executando Hello.Repo.Migrations.AddCommentsTable.change/0 para trás
[info] descartar tabela comments
[info] == Migrado em 0.0s
```

`ecto.rollback` lidará com as mesmas opções que `ecto.migrate`, de modo que `-n`, `--step`, `-v` e `--to` se comportarão como fazem para `ecto.migrate`.

## Criando nossa própria tarefa Mix

Como vimos ao longo deste guia, tanto o Mix quanto as dependências que trazemos para nossa aplicação fornecem várias tarefas realmente úteis de graça. Como nenhuma delas poderia prever todas as necessidades individuais da nossa aplicação, o Mix nos permite criar nossas próprias tarefas personalizadas. É exatamente isso que vamos fazer agora.

A primeira coisa que precisamos fazer é criar um diretório `mix/tasks/` dentro de `lib/`. É aqui que ficarão quaisquer tarefas Mix específicas da nossa aplicação.

```console
$ mkdir -p lib/mix/tasks/
```

Dentro desse diretório, vamos criar um novo arquivo, `hello.greeting.ex`, que se parece com isso.

```elixir
defmodule Mix.Tasks.Hello.Greeting do
  use Mix.Task

  @shortdoc "Envia uma saudação para nós da Aplicação Hello Phoenix"

  @moduledoc """
  É aqui que colocaríamos qualquer documentação de forma longa e doctests.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Saudações da Aplicação Hello Phoenix!")
  end

  # Podemos definir outras funções conforme necessário aqui.
end
```

Vamos dar uma olhada rápida nas partes envolvidas em uma tarefa Mix que funciona.

A primeira coisa que precisamos fazer é nomear nosso módulo. Todas as tarefas devem ser definidas no namespace `Mix.Tasks`. Gostaríamos de invocar isso como `mix hello.greeting`, então completamos o nome do módulo com
`Hello.Greeting`.

A linha `use Mix.Task` traz funcionalidade do Mix que faz com que este módulo [se comporte como uma tarefa Mix](`Mix.Task`).

O atributo de módulo `@shortdoc` contém uma string que descreverá nossa tarefa quando os usuários invocarem `mix help`.

`@moduledoc` serve a mesma função que em qualquer módulo. É onde podemos colocar documentação de forma longa e doctests, se tivermos algum.

A função [`run/1`](`c:Mix.Task.run/1`) é o coração crítico de qualquer tarefa Mix. É a função que faz todo o trabalho quando os usuários invocam nossa tarefa. Na nossa, tudo o que fazemos é enviar uma saudação do nosso app, mas podemos implementar nossa função `run/1` para fazer o que precisamos. Observe que [`Mix.shell().info/1`](`Mix.shell/0`) é a maneira preferida de imprimir texto de volta para o usuário.

Claro, nossa tarefa é apenas um módulo, então podemos definir outras funções privadas conforme necessário para apoiar nossa função `run/1`.

Agora que temos nosso módulo de tarefa definido, nosso próximo passo é compilar a aplicação.

```console
$ mix compile
Compiled lib/tasks/hello.greeting.ex
Generated hello.app
```

Agora nossa nova tarefa deve estar visível para `mix help`.

```console
$ mix help --search hello
mix hello.greeting # Envia uma saudação para nós da Aplicação Hello Phoenix
```

Observe que `mix help` exibe o texto que colocamos no `@shortdoc` junto com o nome da nossa tarefa.

Até agora, tudo bem, mas será que funciona?

```console
$ mix hello.greeting
Saudações da Aplicação Hello Phoenix!
```

De fato, funciona.

Se você quiser que sua nova tarefa Mix use a infraestrutura da sua aplicação, você precisa garantir que a aplicação seja iniciada e configurada quando a tarefa Mix estiver sendo executada. Isso é particularmente útil se você precisar acessar seu banco de dados a partir da tarefa Mix. Felizmente, o Mix facilita isso para nós através do atributo de módulo `@requirements`:

```elixir
  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Agora tenho acesso ao Repo e outras coisas boas!")
    Mix.shell().info("Saudações da Aplicação Hello Phoenix!")
  end
```
