# Implantando com Releases

## Do que precisamos

A única coisa que precisamos para este guia é uma aplicação Phoenix funcional. Para aqueles que precisam de uma aplicação simples para implantar, por favor, siga o guia [Up and Running](up_and_running.html).

## Objetivos

Nosso principal objetivo para este guia é empacotar sua aplicação Phoenix em um diretório autônomo que inclui a VM Erlang, Elixir, todo o seu código e dependências. Este pacote pode então ser colocado em uma máquina de produção.

## Releases, montagem!

Se você ainda não está familiarizado com releases Elixir, recomendamos que leia a [excelente documentação do Elixir](https://hexdocs.pm/mix/Mix.Tasks.Release.html) antes de continuar.

Depois disso, você pode montar uma release passando por todas as etapas do nosso [guia geral de implantação](deployment.html) com `mix release` no final. Vamos recapitular.

Primeiro defina as variáveis de ambiente:

```console
$ mix phx.gen.secret
REALLY_LONG_SECRET
$ export SECRET_KEY_BASE=REALLY_LONG_SECRET
$ export DATABASE_URL=ecto://USER:PASS@HOST/database
```

Em seguida, carregue as dependências para compilar código e assets:

```console
# Configuração inicial
$ mix deps.get --only prod
$ MIX_ENV=prod mix compile

# Compilar assets
$ MIX_ENV=prod mix assets.deploy
```

E agora execute `mix phx.gen.release`:

```console
$ mix phx.gen.release
==> my_app
* creating rel/overlays/bin/server
* creating rel/overlays/bin/server.bat
* creating rel/overlays/bin/migrate
* creating rel/overlays/bin/migrate.bat
* creating lib/my_app/release.ex

Sua aplicação está pronta para ser implantada em uma release!

    # Para iniciar seu sistema
    _build/dev/rel/my_app/bin/my_app start

    # Para iniciar seu sistema com o servidor Phoenix rodando
    _build/dev/rel/my_app/bin/server

    # Para executar migrações
    _build/dev/rel/my_app/bin/migrate

Uma vez que a release esteja rodando:

    # Para conectar remotamente
    _build/dev/rel/my_app/bin/my_app remote

    # Para parar graciosamente (você também pode enviar SIGINT/SIGTERM)
    _build/dev/rel/my_app/bin/my_app stop

Para listar todos os comandos:

    _build/dev/rel/my_app/bin/my_app

```

A tarefa `phx.gen.release` gerou alguns arquivos para nos auxiliar nas releases. Primeiro, ela criou scripts *overlay* `server` e `migrate` para executar convenientemente o servidor phoenix dentro de uma release ou invocar migrações a partir de uma release. Os arquivos no diretório `rel/overlays` são copiados para todos os ambientes de release. Em seguida, gerou um arquivo `release.ex` que é usado para invocar migrações do Ecto sem depender do próprio `mix`.

*Nota*: Se você é usuário do Docker, pode passar a flag `--docker` para `mix phx.gen.release` para gerar um Dockerfile pronto para implantação.

Em seguida, podemos invocar `mix release` para construir a release:

```console
$ MIX_ENV=prod mix release
Generated my_app app
* assembling my_app-0.1.0 on MIX_ENV=prod
* using config/runtime.exs to configure the release at runtime

Release criada em _build/prod/rel/my_app!

    # Para iniciar seu sistema
    _build/prod/rel/my_app/bin/my_app start

...
```

Você pode iniciar a release chamando `_build/prod/rel/my_app/bin/my_app start`, ou iniciar seu servidor web chamando `_build/prod/rel/my_app/bin/server`, onde você deve substituir `my_app` pelo nome atual da sua aplicação.

Agora você pode obter todos os arquivos no diretório `_build/prod/rel/my_app`, empacotá-los e executá-los em qualquer máquina de produção com o mesmo sistema operacional e arquitetura do que montou a release. Para mais detalhes, consulte a [documentação de `mix release`](https://hexdocs.pm/mix/Mix.Tasks.Release.html).

Mas antes de terminarmos este guia, há mais um recurso das releases que a maioria das aplicações Phoenix usará, então vamos falar sobre isso.

## Migrações Ecto e comandos personalizados

Uma necessidade comum em sistemas de produção é executar comandos personalizados necessários para configurar o ambiente de produção. Um desses comandos é precisamente a migração do banco de dados. Como não temos o `Mix`, uma ferramenta de *build*, dentro das releases, que são um artefato de produção, precisamos trazer esses comandos diretamente para a release.

O comando `phx.gen.release` criou o seguinte arquivo `release.ex` no seu projeto `lib/my_app/release.ex`, com o seguinte conteúdo:

```elixir
defmodule MyApp.Release do
  @app :my_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

Onde você substitui as duas primeiras linhas pelos nomes da sua aplicação.

Agora você pode montar uma nova release com `MIX_ENV=prod mix release` e pode invocar qualquer código, incluindo as funções no módulo acima, chamando o comando `eval`:

```console
$ _build/prod/rel/my_app/bin/my_app eval "MyApp.Release.migrate"
```

E é isso! Se você olhar dentro do script `migrate`, verá que ele encapsula exatamente esta invocação.

Você pode usar essa abordagem para criar qualquer comando personalizado para executar em produção. Neste caso, usamos `load_app`, que chama `Application.load/1` para carregar a aplicação atual sem iniciá-la. No entanto, você pode querer escrever um comando personalizado que inicie toda a aplicação. Nesses casos, `Application.ensure_all_started/1` deve ser usado. Tenha em mente que iniciar a aplicação iniciará todos os processos para a aplicação atual, incluindo o endpoint Phoenix. Isso pode ser contornado alterando sua árvore de supervisão para não iniciar certos filhos sob certas condições. Por exemplo, no arquivo de comandos da release, você poderia fazer:

```elixir
defp start_app do
  load_app()
  Application.put_env(@app, :minimal, true)
  Application.ensure_all_started(@app)
end
```

E então na sua aplicação, você verifica `Application.get_env(@app, :minimal)` e inicia apenas parte dos filhos quando definido.

## Contêineres

Releases Elixir funcionam bem com tecnologias de contêineres, como Docker. A ideia é que você monte a release dentro do contêiner Docker e depois construa uma imagem baseada nos artefatos da release.

Se você chamar `mix phx.gen.release --docker`, verá um novo arquivo com estes conteúdos:

```Dockerfile
# Encontre imagens adequadas de builder e runner no Docker Hub. Usamos Ubuntu/Debian
# em vez de Alpine para evitar problemas de resolução de DNS em produção.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# Este arquivo é baseado nestas imagens:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - para a imagem de build
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20230612-slim - para a imagem de release
#   - https://pkgs.org/ - recurso para encontrar pacotes necessários
#   - Ex: hexpm/elixir:1.14.5-erlang-25.3.2.4-debian-bullseye-20230612-slim
#
ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=25.3.2.4
ARG DEBIAN_VERSION=bullseye-20230612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# instalar dependências de build
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# preparar diretório de build
WORKDIR /app

# instalar hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# definir ENV de build
ENV MIX_ENV="prod"

# instalar dependências mix
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copiar arquivos de configuração de tempo de compilação antes de compilarmos dependências
# para garantir que qualquer alteração de configuração relevante acionará as dependências
# a serem recompiladas.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compilar assets
RUN mix assets.deploy

# Compilar a release
RUN mix compile

# Mudanças em config/runtime.exs não requerem recompilação do código
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# iniciar um novo estágio de build para que a imagem final contenha apenas
# a release compilada e outras necessidades de runtime
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Definir o locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# definir ENV do runner
ENV MIX_ENV="prod"

# Copiar apenas a release final do estágio de build
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/my_app ./

USER nobody

# Se estiver usando um ambiente que não elimina automaticamente processos zumbis, é
# aconselhável adicionar um processo init como tini via `apt-get install`
# acima e adicionar um entrypoint. Veja https://github.com/krallin/tini para detalhes
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
```

Onde `my_app` é o nome da sua aplicação. No final, você terá uma aplicação em `/app` pronta para executar como `/app/bin/server`.

Alguns pontos sobre a configuração de uma aplicação em contêiner:

- Se você executar sua aplicação em um contêiner, o `Endpoint` precisa ser configurado para escutar em um endereço `:ip` "público" (como `0.0.0.0`) para que a aplicação possa ser acessada de fora do contêiner. Se o host deve publicar as portas do contêiner para seu próprio IP público ou para localhost depende das suas necessidades.
- Quanto mais configuração você puder fornecer em tempo de execução (usando `config/runtime.exs`), mais reutilizáveis serão suas imagens em diferentes ambientes. Em particular, segredos como credenciais de banco de dados e chaves de API não devem ser compilados na imagem, mas sim fornecidos ao criar contêineres baseados nessa imagem. É por isso que a `:secret_key_base` do `Endpoint` é configurada em `config/runtime.exs` por padrão.
- Se possível, quaisquer variáveis de ambiente necessárias em tempo de execução devem ser lidas em `config/runtime.exs`, e não espalhadas por todo o seu código. Ter todas elas visíveis em um só lugar facilitará garantir que os contêineres obtenham o que precisam, especialmente se a pessoa que faz o trabalho de infraestrutura não trabalha no código Elixir. Em particular, as bibliotecas nunca devem ler diretamente variáveis de ambiente; toda a configuração delas deve ser passada pela aplicação de nível superior, preferencialmente [sem usar o ambiente da aplicação](https://hexdocs.pm/elixir/library-guidelines.html#avoid-application-configuration).
