# Introdução ao Deployment

Uma vez que temos uma aplicação funcionando, estamos prontos para fazer o deployment. Se você ainda não terminou sua própria aplicação, não se preocupe. Basta seguir o [Guia de Primeiros Passos](up_and_running.html) para criar uma aplicação básica para trabalhar.

Ao preparar uma aplicação para deployment, existem três etapas principais:

  * Gerenciamento dos segredos da sua aplicação
  * Compilação dos assets da sua aplicação
  * Inicialização do seu servidor em produção

Neste guia, aprenderemos como configurar o ambiente de produção localmente. Você pode usar as mesmas técnicas deste guia para executar sua aplicação em produção, mas dependendo da sua infraestrutura de deployment, etapas adicionais serão necessárias.

Como exemplos de deployment em outras infraestruturas, também discutimos quatro abordagens diferentes em nossos guias: usando [releases do Elixir](releases.html) com `mix release`, [usando Gigalixir](gigalixir.html), [usando Fly](fly.html) e [usando Heroku](heroku.html). Também incluímos links para deployment do Phoenix em outras plataformas na seção [Guias de Deployment da Comunidade](#guias-de-deployment-da-comunidade). Finalmente, o guia de release possui um exemplo de Dockerfile que você pode usar se preferir fazer o deployment com tecnologias de contêineres.

Vamos explorar essas etapas uma por uma.

## Gerenciamento dos segredos da sua aplicação

Todas as aplicações Phoenix têm dados que devem ser mantidos seguros, por exemplo, o nome de usuário e senha do seu banco de dados de produção, e o segredo que o Phoenix usa para assinar e criptografar informações importantes. A recomendação geral é manter esses dados em variáveis de ambiente e carregá-los em sua aplicação. Isso é feito no arquivo `config/runtime.exs` (anteriormente `config/prod.secret.exs` ou `config/releases.exs`), que é responsável por carregar segredos e configurações das variáveis de ambiente.

Portanto, você precisa garantir que as variáveis relevantes estejam configuradas em produção:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Não copie esses valores diretamente, configure `SECRET_KEY_BASE` de acordo com o resultado de `mix phx.gen.secret` e `DATABASE_URL` de acordo com o endereço do seu banco de dados.

Se por algum motivo você não quiser depender de variáveis de ambiente, você pode codificar os segredos diretamente no seu `config/runtime.exs`, mas certifique-se de não incluir o arquivo no seu sistema de controle de versão.

Com suas informações secretas devidamente protegidas, é hora de configurar os assets!

Antes de dar este passo, precisamos fazer um pouco de preparação. Como vamos preparar tudo para produção, precisamos fazer algumas configurações nesse ambiente, obtendo nossas dependências e compilando.

```console
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile
```

## Compilando os assets da sua aplicação

Esta etapa é necessária apenas se você tiver assets compiláveis como JavaScript e folhas de estilo. Por padrão, o Phoenix usa `esbuild`, mas tudo está encapsulado em uma única tarefa `mix assets.deploy` definida no seu `mix.exs`:

```console
$ MIX_ENV=prod mix assets.deploy
Check your digested files at "priv/static".
```

E é isso! A tarefa Mix, por padrão, compila os assets e então gera digests com um arquivo de manifesto de cache para que o Phoenix possa servir assets rapidamente em produção.

> Nota: se você executar a tarefa acima em sua máquina local, ela gerará muitos assets com digest em `priv/static`. Você pode limpá-los executando `mix phx.digest.clean --all`.

Tenha em mente que, se por acaso você esquecer de executar as etapas acima, o Phoenix mostrará uma mensagem de erro:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:50:18.732 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
10:50:18.735 [error] Could not find static manifest at "my_app/_build/prod/lib/foo/priv/static/cache_manifest.json". Run "mix phx.digest" after building your static files or remove the configuration from "config/prod.exs".
```

A mensagem de erro é bastante clara: diz que o Phoenix não conseguiu encontrar um manifesto estático. Basta executar os comandos acima para corrigi-lo ou, se você não está servindo ou não se importa com os assets, você pode simplesmente remover a configuração `cache_static_manifest` do seu arquivo de configuração.

## Iniciando seu servidor em produção

Para executar o Phoenix em produção, precisamos definir as variáveis de ambiente `PORT` e `MIX_ENV` ao invocar `mix phx.server`:

```console
$ PORT=4001 MIX_ENV=prod mix phx.server
10:59:19.136 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
```

Para executar em modo desanexado, de modo que o servidor Phoenix não pare e continue em execução mesmo se você fechar o terminal:

```console
$ PORT=4001 MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
```

Caso você receba uma mensagem de erro, por favor, leia-a cuidadosamente e abra um relatório de bug se ainda não estiver claro como resolvê-lo.

Você também pode executar sua aplicação dentro de um shell interativo:

```console
$ PORT=4001 MIX_ENV=prod iex -S mix phx.server
10:59:19.136 [info] Running MyAppWeb.Endpoint with Cowboy on http://example.com
```

## Juntando tudo

As seções anteriores fornecem uma visão geral sobre as principais etapas necessárias para fazer o deployment da sua aplicação Phoenix. Na prática, você acabará adicionando etapas próprias também. Por exemplo, se você estiver usando um banco de dados, também vai querer executar `mix ecto.migrate` antes de iniciar o servidor para garantir que seu banco de dados esteja atualizado.

No geral, aqui está um script que você pode usar como ponto de partida:

```console
# Configuração inicial
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compilação de assets
$ MIX_ENV=prod mix assets.deploy

# Tarefas personalizadas (como migrações de banco de dados)
$ MIX_ENV=prod mix ecto.migrate

# Finalmente, execute o servidor
$ PORT=4001 MIX_ENV=prod mix phx.server
```

E é isso. Em seguida, você pode usar um dos nossos guias oficiais para fazer o deployment:

  * [com releases do Elixir](releases.html)
  * [para o Gigalixir](gigalixir.html), uma Plataforma como Serviço (PaaS) centrada em Elixir
  * [para o Fly.io](fly.html), um PaaS que implanta seus servidores próximos aos seus usuários com suporte integrado para distribuição
  * e [para o Heroku](heroku.html), um dos PaaS mais populares.

## Guias de Deployment da Comunidade

  * [Render](https://render.com) tem suporte de primeira classe para aplicações Phoenix. Existem guias para hospedar Phoenix com [Mix releases](https://render.com/docs/deploy-phoenix), [Distillery](https://render.com/docs/deploy-phoenix-distillery) e como um [Cluster Elixir Distribuído](https://render.com/docs/deploy-elixir-cluster).
