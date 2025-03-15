# Implantação no Heroku

## O que vamos precisar

A única coisa que vamos precisar para este guia é uma aplicação Phoenix funcionando. Para aqueles que precisam de uma aplicação simples para implantar, por favor siga o guia [Up and Running](https://hexdocs.pm/phoenix/up_and_running.html).

## Objetivos

Nosso principal objetivo para este guia é colocar uma aplicação Phoenix em funcionamento no Heroku.

## Limitações

O Heroku é uma excelente plataforma e o Elixir funciona bem nela. No entanto, você pode encontrar limitações se planeja utilizar recursos avançados fornecidos pelo Elixir e Phoenix, como:

- As conexões são limitadas.
  - O Heroku [limita o número de conexões simultâneas](https://devcenter.heroku.com/articles/http-routing#request-concurrency) bem como a [duração de cada conexão](https://devcenter.heroku.com/articles/limits#http-timeouts). É comum usar Elixir para aplicativos em tempo real que precisam de muitas conexões persistentes e simultâneas, e o Phoenix é capaz de [lidar com mais de 2 milhões de conexões em um único servidor](https://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections).

- Clustering distribuído não é possível.
  - O Heroku [isola os dynos uns dos outros com firewall](https://devcenter.heroku.com/articles/dynos#networking). Isso significa que coisas como [canais Phoenix distribuídos](https://dockyard.com/blog/2016/01/28/running-elixir-and-phoenix-projects-on-a-cluster-of-nodes) e [tarefas distribuídas](https://hexdocs.pm/elixir/distributed-tasks.html) precisarão confiar em algo como Redis em vez da distribuição incorporada do Elixir.

- Estados em memória como aqueles em [Agents](https://hexdocs.pm/elixir/agents.html), [GenServers](https://hexdocs.pm/elixir/genservers.html) e [ETS](https://hexdocs.pm/elixir/erlang-term-storage.html) serão perdidos a cada 24 horas.
  - O Heroku [reinicia os dynos](https://devcenter.heroku.com/articles/dynos#restarting) a cada 24 horas, independentemente de o nó estar saudável ou não.

- [O observer integrado](https://hexdocs.pm/elixir/debugging.html#observer) não pode ser usado com o Heroku.
  - O Heroku permite a conexão ao seu dyno, mas você não poderá usar o observer para monitorar o estado do seu dyno.

Se você está apenas começando, ou não espera usar os recursos acima, o Heroku deve ser suficiente para suas necessidades. Por exemplo, se você está migrando uma aplicação existente rodando no Heroku para Phoenix, mantendo um conjunto semelhante de recursos, o Elixir funcionará tão bem ou até melhor que sua stack atual.

Se você quer um serviço de plataforma sem essas limitações, experimente [Gigalixir](gigalixir.html). Se você prefere implantar em uma plataforma de nuvem, como EC2, Google Cloud, etc., considere usar `mix release`.

## Passos

Vamos separar este processo em algumas etapas, para que possamos acompanhar onde estamos.

- Inicializar repositório Git
- Cadastrar-se no Heroku
- Instalar o Heroku Toolbelt
- Criar e configurar a aplicação Heroku
- Preparar nosso projeto para o Heroku
- Hora da implantação!
- Comandos úteis do Heroku

## Inicializando repositório Git

[Git](https://git-scm.com/) é um popular sistema de controle de revisão descentralizado e também é usado para implantar aplicativos no Heroku.

Antes de podermos enviar para o Heroku, precisaremos inicializar um repositório Git local e confirmar nossos arquivos nele. Podemos fazer isso executando os seguintes comandos em nosso diretório de projeto:

```console
$ git init
$ git add .
$ git commit -m "Commit inicial"
```

O Heroku oferece algumas ótimas informações sobre como está usando o Git [aqui](https://devcenter.heroku.com/articles/git#prerequisites-install-git-and-the-heroku-cli).

## Cadastrando-se no Heroku

Cadastrar-se no Heroku é muito simples, basta acessar [https://signup.heroku.com/](https://signup.heroku.com/) e preencher o formulário.

O plano gratuito nos dará um [dyno](https://devcenter.heroku.com/articles/dynos) web e um dyno worker, bem como uma instância PostgreSQL e Redis de graça.

Estes são destinados a serem usados para testes e desenvolvimento, e vêm com algumas limitações. Para executar uma aplicação de produção, considere atualizar para um plano pago.

## Instalando o Heroku Toolbelt

Depois de nos cadastrarmos, podemos baixar a versão correta do Heroku Toolbelt para nosso sistema [aqui](https://toolbelt.heroku.com/).

O Heroku CLI, parte do Toolbelt, é útil para criar aplicativos Heroku, listar dynos atualmente em execução para um aplicativo existente, ver logs ou executar comandos únicos (tarefas mix, por exemplo).

## Criar e Configurar Aplicação Heroku

Existem duas maneiras diferentes de implantar um aplicativo Phoenix no Heroku. Podemos usar buildpacks do Heroku ou sua stack de contêiner. A diferença entre essas duas abordagens está em como dizemos ao Heroku para tratar nossa compilação. No caso do buildpack, precisamos atualizar a configuração dos nossos aplicativos no Heroku para usar buildpacks específicos de Phoenix/Elixir. Na abordagem de contêiner, temos mais controle sobre como queremos configurar nosso aplicativo, e podemos definir nossa imagem de contêiner usando `Dockerfile` e `heroku.yml`. Esta seção explorará a abordagem de buildpack. Para usar o Dockerfile, geralmente é recomendado converter nosso aplicativo para usar releases, o que descreveremos mais tarde.

### Criar Aplicação

Um [buildpack](https://devcenter.heroku.com/articles/buildpacks) é uma maneira conveniente de empacotar suporte de framework e/ou runtime. Phoenix requer 2 buildpacks para rodar no Heroku, o primeiro adiciona suporte básico para Elixir e o segundo adiciona comandos específicos do Phoenix.

Com o Toolbelt instalado, vamos criar a aplicação Heroku. Faremos isso usando a versão mais recente disponível do [buildpack Elixir](https://github.com/HashNuke/heroku-buildpack-elixir):

```console
$ heroku create --buildpack hashnuke/elixir
Creating app... done, ⬢ mysterious-meadow-6277
Setting buildpack to hashnuke/elixir... done
https://mysterious-meadow-6277.herokuapp.com/ | https://git.heroku.com/mysterious-meadow-6277.git
```

> Nota: na primeira vez que usamos um comando Heroku, ele pode nos pedir para fazer login. Se isso acontecer, basta inserir o e-mail e a senha que você especificou durante o cadastro.

> Nota: o nome da aplicação Heroku é a string aleatória após "Creating" na saída acima (mysterious-meadow-6277). Isso será único, então espere ver um nome diferente de "mysterious-meadow-6277".

> Nota: a URL na saída é a URL para nossa aplicação. Se a abrirmos em nosso navegador agora, obteremos a página de boas-vindas padrão do Heroku.

> Nota: se não tivéssemos inicializado nosso repositório Git antes de executarmos o comando `heroku create`, não teríamos nosso repositório remoto Heroku configurado corretamente neste momento. Podemos configurar isso manualmente executando: `heroku git:remote -a [nome-do-nosso-app].`

O buildpack usa uma versão predefinida de Elixir e Erlang, mas para evitar surpresas ao implantar, é melhor listar explicitamente a versão de Elixir e Erlang que queremos em produção para ser a mesma que estamos usando durante o desenvolvimento ou em seus servidores de integração contínua. Isso é feito criando um arquivo de configuração chamado `elixir_buildpack.config` no diretório raiz do seu projeto com sua versão alvo de Elixir e Erlang:

```console
# Versão do Elixir
elixir_version=1.14.0

# Versão do Erlang
# https://github.com/HashNuke/heroku-buildpack-elixir-otp-builds/blob/master/otp-versions
erlang_version=24.3

# Invoca assets.deploy definido no seu mix.exs para implantar assets com esbuild
# Note que eliminamos o executável esbuild da imagem
hook_post_compile="eval mix assets.deploy && rm -f _build/esbuild*"
```

Finalmente, vamos dizer ao buildpack como iniciar nosso servidor web. Crie um arquivo chamado `Procfile` na raiz do seu projeto:

```console
web: mix phx.server
```

### Opcional: Node, npm e o buildpack Phoenix Static

Por padrão, o Phoenix usa `esbuild` e gerencia todos os assets para você. No entanto, se você estiver usando `node` e `npm`, precisará instalar o [buildpack Phoenix Static](https://github.com/gjaldon/heroku-buildpack-phoenix-static) para lidar com eles:

```console
$ heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
Buildpack added. Next release on mysterious-meadow-6277 will use:
  1. https://github.com/HashNuke/heroku-buildpack-elixir.git
  2. https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
```

Ao usar este buildpack, você quer delegar todo o empacotamento de assets para o `npm`. Portanto, você deve remover a configuração `hook_post_compile` do seu `elixir_buildpack.config` e movê-la para o script de implantação do seu `assets/package.json`. Algo assim:

```javascript
{
  ...
  "scripts": {
    "deploy": "cd .. && mix assets.deploy && rm -f _build/esbuild*"
  }
  ...
}
```

O buildpack Phoenix Static usa uma versão predefinida do Node.js, mas para evitar surpresas ao implantar, é melhor listar explicitamente a versão do Node.js que queremos em produção para ser a mesma que estamos usando durante o desenvolvimento ou em seus servidores de integração contínua. Isso é feito criando um arquivo de configuração chamado `phoenix_static_buildpack.config` no diretório raiz do seu projeto com sua versão alvo do Node.js:

```text
# Versão do Node.js
node_version=10.20.1
```

Consulte a [seção de configuração](https://github.com/gjaldon/heroku-buildpack-phoenix-static#configuration) para obter detalhes completos. Você pode fazer seu próprio script de compilação personalizado, mas por enquanto, usaremos o [padrão fornecido](https://github.com/gjaldon/heroku-buildpack-phoenix-static/blob/master/compile).

Finalmente, observe que, como estamos usando vários buildpacks, você pode encontrar um problema em que a sequência está fora de ordem (o buildpack Elixir precisa ser executado antes do buildpack Phoenix Static). [A documentação do Heroku](https://devcenter.heroku.com/articles/using-multiple-buildpacks-for-an-app) explica isso melhor, mas você precisará garantir que o buildpack Phoenix Static venha por último.

## Preparando nosso Projeto para o Heroku

Todo novo projeto Phoenix vem com um arquivo de configuração `config/runtime.exs` (anteriormente `config/prod.secret.exs`) que carrega configurações e segredos de [variáveis de ambiente](https://devcenter.heroku.com/articles/config-vars). Isso está alinhado com as melhores práticas do Heroku ([apps 12-factor](https://12factor.net/)), então o único trabalho que resta para nós é configurar URLs e SSL.

Primeiro, vamos dizer ao Phoenix para usar apenas a versão SSL do site. Encontre a configuração do endpoint em seu `config/prod.exs`:

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [port: 443, scheme: "https"],
```

... e adicione `force_ssl`

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [port: 443, scheme: "https"],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
```

`force_ssl` precisa ser definido aqui porque é uma configuração de _compilação_. Não funcionará quando definido a partir de `runtime.exs`.

Então, em seu `config/runtime.exs` (anteriormente `config/prod.secret.exs`):

... adicione `host`

```elixir
config :scaffold, ScaffoldWeb.Endpoint,
  url: [host: host, port: 443, scheme: "https"]
```

e descomente a linha `# ssl: true,` em sua configuração de repositório. Ficará assim:

```elixir
config :hello, Hello.Repo,
  ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

Finalmente, se você planeja usar websockets, então precisaremos diminuir o tempo limite para o transporte websocket em `lib/hello_web/endpoint.ex`. Se você não planeja usar websockets, então deixá-lo definido como falso está bem. Você pode encontrar mais explicações sobre as opções disponíveis na [documentação](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).

```elixir
defmodule HelloWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hello

  socket "/socket", HelloWeb.UserSocket,
    websocket: [timeout: 45_000]

  ...
end
```

Defina também o host no Heroku:

```console
$ heroku config:set PHX_HOST="mysterious-meadow-6277.herokuapp.com"
```

Isso garante que quaisquer conexões ociosas sejam fechadas pelo Phoenix antes de atingirem a janela de tempo limite de 55 segundos do Heroku.

## Criando Variáveis de Ambiente no Heroku

A variável de configuração `DATABASE_URL` é criada automaticamente pelo Heroku quando adicionamos o [addon Heroku Postgres](https://elements.heroku.com/addons/heroku-postgresql). Podemos criar o banco de dados via Heroku toolbelt:

```console
$ heroku addons:create heroku-postgresql:mini
```

Agora definimos a variável de configuração `POOL_SIZE`:

```console
$ heroku config:set POOL_SIZE=18
```

Este valor deve ser um pouco abaixo do número de conexões disponíveis, deixando algumas abertas para migrações e tarefas mix. O banco de dados mini permite 20 conexões, então definimos esse número para 18. Se dynos adicionais compartilharem o banco de dados, reduza o `POOL_SIZE` para dar a cada dyno uma parte igual.

Ao executar uma tarefa mix posteriormente (depois de termos enviado o projeto para o Heroku), você também desejará limitar o tamanho do pool assim:

```console
$ heroku run "POOL_SIZE=2 mix hello.task"
```

Para que o Ecto não tente abrir mais do que as conexões disponíveis.

Ainda precisamos criar a configuração `SECRET_KEY_BASE` com base em uma string aleatória. Primeiro, use `mix phx.gen.secret` para obter um novo segredo:

```console
$ mix phx.gen.secret
xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53
```

Sua string aleatória será diferente; não use este valor de exemplo.

Agora defina-o no Heroku:

```console
$ heroku config:set SECRET_KEY_BASE="xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53"
Setting config vars and restarting mysterious-meadow-6277... done, v3
SECRET_KEY_BASE: xvafzY4y01jYuzLm3ecJqo008dVnU3CN4f+MamNd1Zue4pXvfvUjbiXT8akaIF53
```

## Hora da Implantação!

Nosso projeto agora está pronto para ser implantado no Heroku.

Vamos confirmar todas as nossas alterações:

```console
$ git add elixir_buildpack.config
$ git commit -a -m "Usar configuração de produção de variáveis ENV do Heroku e diminuir o tempo limite do socket"
```

E implantar:

```console
$ git push heroku main
Counting objects: 55, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (49/49), done.
Writing objects: 100% (55/55), 48.48 KiB | 0 bytes/s, done.
Total 55 (delta 1), reused 0 (delta 0)
remote: Compressing source files... done.
remote: Building source:
remote:
remote: -----> Multipack app detected
remote: -----> Fetching custom git buildpack... done
remote: -----> elixir app detected
remote: -----> Checking Erlang and Elixir versions
remote:        WARNING: elixir_buildpack.config wasn't found in the app
remote:        Using default config from Elixir buildpack
remote:        Will use the following versions:
remote:        * Stack cedar-14
remote:        * Erlang 17.5
remote:        * Elixir 1.0.4
remote:        Will export the following config vars:
remote:        * Config vars DATABASE_URL
remote:        * MIX_ENV=prod
remote: -----> Stack changed, will rebuild
remote: -----> Fetching Erlang 17.5
remote: -----> Installing Erlang 17.5 (changed)
remote:
remote: -----> Fetching Elixir v1.0.4
remote: -----> Installing Elixir v1.0.4 (changed)
remote: -----> Installing Hex
remote: 2015-07-07 00:04:00 URL:https://s3.amazonaws.com/s3.hex.pm/installs/1.0.0/hex.ez [262010/262010] ->
"/app/.mix/archives/hex.ez" [1]
remote: * creating /app/.mix/archives/hex.ez
remote: -----> Installing rebar
remote: * creating /app/.mix/rebar
remote: -----> Fetching app dependencies with mix
remote: Running dependency resolution
remote: Dependency resolution completed successfully
remote: [...]
remote: -----> Compiling
remote: [...]
remote: Generated phoenix_heroku app
remote: [...]
remote: Consolidated protocols written to _build/prod/consolidated
remote: -----> Creating .profile.d with env vars
remote: -----> Fetching custom git buildpack... done
remote: -----> Phoenix app detected
remote:
remote: -----> Loading configuration and environment
remote:        Loading config...
remote:        [...]
remote:        Will export the following config vars:
remote:        * Config vars DATABASE_URL
remote:        * MIX_ENV=prod
remote:
remote: -----> Compressing... done, 82.1MB
remote: -----> Launching... done, v5
remote:        https://mysterious-meadow-6277.herokuapp.com/ deployed to Heroku
remote:
remote: Verifying deploy... done.
To https://git.heroku.com/mysterious-meadow-6277.git
 * [new branch]      master -> master
```

Digitar `heroku open` no terminal deve iniciar um navegador com a página de boas-vindas do Phoenix aberta. No caso de você estar usando Ecto para acessar um banco de dados, você também precisará executar migrações após a primeira implantação:

```console
$ heroku run "POOL_SIZE=2 mix ecto.migrate"
```

E é isso!

## Implantando no Heroku usando a stack de contêiner

### Criar aplicação Heroku

Defina a stack do seu aplicativo para `container`, isso nos permite usar o `Dockerfile` para definir a configuração do nosso aplicativo.

```console
$ heroku create
Creating app... done, ⬢ mysterious-meadow-6277
$ heroku stack:set container
```

Adicione um novo arquivo `heroku.yml` à sua pasta raiz. Neste arquivo, você pode definir addons usados pelo seu aplicativo, como construir a imagem e quais configurações são passadas para a imagem. Você pode aprender mais sobre as opções do `heroku.yml` do Heroku [aqui](https://devcenter.heroku.com/articles/build-docker-images-heroku-yml). Aqui está um exemplo:

```yaml
setup:
  addons:
    - plan: heroku-postgresql
      as: DATABASE
build:
  docker:
    web: Dockerfile
  config:
    MIX_ENV: prod
    SECRET_KEY_BASE: $SECRET_KEY_BASE
    DATABASE_URL: $DATABASE_URL
```

### Configurar releases e Dockerfile

Agora precisamos definir um `Dockerfile` na pasta raiz do seu projeto que contém sua aplicação. Recomendamos usar releases ao fazer isso, pois o release nos permitirá construir um contêiner apenas com as partes do Erlang e Elixir que realmente usamos. Siga a [documentação de releases](releases.html). No final do guia, há um exemplo de arquivo Dockerfile que você pode usar.

Uma vez que você tenha a definição da imagem configurada, você pode enviar seu aplicativo para o Heroku e pode ver que ele começa a construir a imagem e implantá-la.

## Comandos Úteis do Heroku

Podemos olhar os logs da nossa aplicação executando o seguinte comando em nosso diretório de projeto:

```console
$ heroku logs # use --tail se quiser acompanhá-los
```

Também podemos iniciar uma sessão IEx conectada ao nosso terminal para experimentar no ambiente do nosso aplicativo:

```console
$ heroku run "POOL_SIZE=2 iex -S mix"
```

Na verdade, podemos executar qualquer coisa usando o comando `heroku run`, como a tarefa de migração do Ecto acima:

```console
$ heroku run "POOL_SIZE=2 mix ecto.migrate"
```

## Conectando-se ao seu dyno

O Heroku oferece a capacidade de se conectar ao seu dyno com um shell IEx que permite executar código Elixir, como consultas de banco de dados.

- Modifique o processo `web` em seu Procfile para executar um nó nomeado:

  ```text
  web: elixir --sname server -S mix phx.server
  ```

- Reimplante no Heroku
- Conecte-se ao dyno com `heroku ps:exec` (se você tiver vários aplicativos no mesmo repositório, precisará especificar o nome do aplicativo ou o nome remoto com `--app NOME_APP` ou `--remote NOME_REMOTO`)
- Inicie uma sessão iex com `iex --sname console --remsh server`

Você tem uma sessão iex em seu dyno!

## Solução de Problemas

### Erro de Compilação

Ocasionalmente, um aplicativo será compilado localmente, mas não no Heroku. O erro de compilação no Heroku será algo como isto:

```console
remote: == Compilation error on file lib/postgrex/connection.ex ==
remote: could not compile dependency :postgrex, "mix compile" failed. You can recompile this dependency with "mix deps.compile postgrex", update it with "mix deps.update postgrex" or clean it with "mix deps.clean postgrex"
remote: ** (CompileError) lib/postgrex/connection.ex:207: Postgrex.Connection.__struct__/0 is undefined, cannot expand struct Postgrex.Connection
remote:     (elixir) src/elixir_map.erl:58: :elixir_map.translate_struct/4
remote:     (stdlib) lists.erl:1353: :lists.mapfoldl/3
remote:     (stdlib) lists.erl:1354: :lists.mapfoldl/3
remote:
remote:
remote:  !     Push rejected, failed to compile elixir app
remote:
remote: Verifying deploy...
remote:
remote: !   Push rejected to mysterious-meadow-6277.
remote:
To https://git.heroku.com/mysterious-meadow-6277.git
```

Isso tem a ver com dependências obsoletas que não estão sendo recompiladas corretamente. É possível forçar o Heroku a recompilar todas as dependências em cada implantação, o que deve resolver esse problema. A maneira de fazer isso é adicionar um novo arquivo chamado `elixir_buildpack.config` na raiz da aplicação. O arquivo deve conter esta linha:

```text
always_rebuild=true
```

Confirme este arquivo no repositório e tente enviar novamente para o Heroku.

### Erro de Tempo Limite de Conexão

Se você estiver constantemente obtendo tempos limite de conexão ao executar `heroku run`, isso pode significar que seu provedor de internet bloqueou o número da porta 5000:

```console
heroku run "POOL_SIZE=2 mix myapp.task"
Running POOL_SIZE=2 mix myapp.task on mysterious-meadow-6277... !
ETIMEDOUT: connect ETIMEDOUT 50.19.103.36:5000
```

Você pode superar isso adicionando a opção `detached` ao comando run:

```console
heroku run:detached "POOL_SIZE=2 mix ecto.migrate"
Running POOL_SIZE=2 mix ecto.migrate on mysterious-meadow-6277... done, run.8089 (Free)
```
