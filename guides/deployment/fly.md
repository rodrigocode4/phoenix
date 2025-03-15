# Implantando no Fly.io

O Fly.io mantém seu próprio guia para Elixir/Phoenix aqui: [Fly.io/docs/elixir/getting-started/](https://fly.io/docs/elixir/getting-started/). Manteremos este guia atualizado, mas para as informações mais recentes, consulte o site deles!

## O que precisaremos

A única coisa que precisaremos para este guia é uma aplicação Phoenix funcional. Para aqueles que precisam de uma aplicação simples para implantar, siga o [guia Up and Running](https://hexdocs.pm/phoenix/up_and_running.html).

Você pode simplesmente:

```console
$ mix phx.new my_app
```

## Objetivos

O principal objetivo deste guia é ter uma aplicação Phoenix rodando no [Fly.io](https://fly.io).

## Seções

Vamos separar este processo em algumas etapas, para que possamos acompanhar onde estamos.

- Instalar a CLI do Fly.io
- Criar uma conta no Fly.io
- Implantar a aplicação no Fly.io
- Dicas extras do Fly.io
- Recursos úteis do Fly.io

## Instalando a CLI do Fly.io

Siga as instruções [aqui](https://fly.io/docs/getting-started/installing-flyctl/) para instalar o Flyctl, a interface de linha de comando para a plataforma Fly.io.

## Criar uma conta no Fly.io

Podemos [criar uma conta](https://fly.io/docs/getting-started/log-in-to-fly/) usando a CLI.

```console
$ fly auth signup
```

Ou fazer login.

```console
$ flyctl auth login
```

O Fly tem um [plano gratuito](https://fly.io/docs/about/pricing/) para a maioria das aplicações. Um cartão de crédito é necessário ao configurar uma conta para ajudar a prevenir abusos. Veja a página de [preços](https://fly.io/docs/about/pricing/) para mais detalhes.

## Implantar a aplicação no Fly.io

Para informar ao Fly sobre sua aplicação, execute `fly launch` no diretório com seu código-fonte. Isso cria e configura um aplicativo Fly.io.

```console
$ fly launch
```

Isso analisa seu código, detecta o projeto Phoenix e executa `mix phx.gen.release --docker` para você! Isso cria um Dockerfile para você.

O comando `fly launch` guia você através de algumas perguntas.

- Você pode nomear o aplicativo ou deixar que gere um nome aleatório para você.
- Escolha uma organização (o padrão é `personal`). Organizações são uma forma de compartilhar aplicações e recursos entre usuários do Fly.io.
- Escolha uma região para implantar. O padrão é a região Fly.io mais próxima. Você pode conferir a [lista completa de regiões aqui](https://fly.io/docs/reference/regions/).
- Configura um banco de dados Postgres para você.
- Constrói o Dockerfile.
- Implanta sua aplicação!

O comando `fly launch` também criou um arquivo `fly.toml` para você. É aqui que você pode definir valores ENV e outras configurações.

### Armazenando segredos no Fly.io

Você também pode ter alguns segredos que gostaria de definir em seu aplicativo.

Use [`fly secrets`](https://fly.io/docs/reference/secrets/#setting-secrets) para configurá-los.

```console
$ fly secrets set MY_SECRET_KEY=my_secret_value
```

### Implantando novamente

Quando quiser implantar alterações em sua aplicação, use `fly deploy`.

```console
$ fly deploy
```

Nota: Em computadores Apple Silicon (M1), o docker executa compilações entre plataformas usando qemu, o que nem sempre funciona. Se você receber um erro de falha de segmentação como o seguinte:

```
 => [build  7/17] RUN mix deps.get --only
 => => # qemu: uncaught target signal 11 (Segmentation fault) - core dumped
```

Você pode usar o construtor remoto do fly adicionando a flag `--remote-only`:

```console
$ fly deploy --remote-only
```

Você sempre pode verificar o status de uma implantação

```console
$ fly status
```

Verificar os logs da sua aplicação

```console
$ fly logs
```

Se tudo parecer bom, abra sua aplicação no Fly

```console
$ fly open
```

## Dicas extras do Fly.io

### Obtendo um shell IEx em um nó em execução

O Elixir suporta obter um shell IEx em um nó de produção em execução.

Existem alguns pré-requisitos, primeiro precisamos estabelecer um [SSH Shell](https://fly.io/docs/flyctl/ssh/) para nossa máquina no Fly.io.

Esta etapa configura um certificado raiz para sua conta e depois emite um certificado.

```console
$ fly ssh issue --agent
```

Com o SSH configurado, vamos abrir um console.

```console
$ fly ssh console
Connecting to my-app-1234.internal... complete
/ #
```

Se tudo correu bem, então você tem um shell na máquina! Agora só precisamos lançar nosso shell IEx remoto. O Dockerfile de implantação foi configurado para colocar nossa aplicação em `/app`. Portanto, o comando para um aplicativo chamado `my_app` é assim:

```console
$ app/bin/my_app remote
Erlang/OTP 23 [erts-11.2.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1]

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(my_app@fdaa:0:1da8:a7b:ac4:b204:7e29:2)1>
```

Agora temos um shell IEx em execução no nosso nó! Você pode desconectar com segurança usando CTRL+C, CTRL+C.

### Clusterizando sua aplicação

O Elixir e o BEAM têm a incrível capacidade de serem agrupados e passar mensagens perfeitamente entre nós. Esta parte do guia mostra como clusterizar sua aplicação Elixir.

Existem 2 partes para configurar rapidamente a clusterização no Fly.io.

- Instalando e usando o `libcluster`
- Escalonando a aplicação para várias instâncias

#### Adicionando `libcluster`

A biblioteca amplamente adotada [libcluster](https://github.com/bitwalker/libcluster) ajuda aqui.

Existem várias estratégias que o `libcluster` pode usar para encontrar e se conectar com outros nós. A estratégia que usaremos no Fly.io é `DNSPoll`.

Após instalar o `libcluster`, adicione-o à aplicação desta forma:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # ...
      # configuração para clusterização
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}
    ]

    # ...
  end

  # ...
end
```

Nosso próximo passo é adicionar a configuração de `topologies` ao `config/runtime.exs`.

```elixir
  app_name =
    System.get_env("FLY_APP_NAME") ||
      raise "FLY_APP_NAME not available"

  config :libcluster,
    topologies: [
      fly6pn: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          polling_interval: 5_000,
          query: "#{app_name}.internal",
          node_basename: app_name
        ]
      ]
    ]
```

Isso configura o `libcluster` para usar a estratégia `DNSPoll` e procurar outras aplicações implantadas usando o `$FLY_APP_NAME` na rede privada `.internal`.

#### Controlando o nome do nosso nó

Precisamos controlar a nomeação de nossos nós Elixir. Para ajudá-los a se conectar, vamos nomeá-los usando este padrão: `nome-do-seu-app-fly@o.endereço.ipv6.no.fly`. Para fazer isso, vamos gerar a configuração de release.

```console
$ mix release.init
```

Em seguida, edite o arquivo `rel/env.sh.eex` gerado e adicione as seguintes linhas:

```console
ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=$FLY_APP_NAME@$ip
```

Após fazer a alteração, implante seu aplicativo!

```console
$ fly deploy
```

Para que nosso aplicativo seja clusterizado, precisamos ter várias instâncias. Em seguida, adicionaremos uma instância adicional.

#### Executando várias instâncias

Existem duas maneiras de executar várias instâncias.

1. Escalonar nossa aplicação para ter várias instâncias em uma região.
2. Adicionar uma instância a outra região (várias regiões).

Vamos começar com uma linha de base de nossa implantação única.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
f9014bf7 26      sea    run     running 1 total, 1 passing 0        1h8m ago
```

#### Escalonando em uma única região

Vamos escalonar para 2 instâncias em nossa região atual.

```console
$ fly scale count 2
Count changed to 2
```

Verificando o status, podemos ver o que aconteceu.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
eb4119d3 27      sea    run     running 1 total, 1 passing 0        39s ago
f9014bf7 27      sea    run     running 1 total, 1 passing 0        1h13m ago
```

Agora temos duas instâncias na mesma região.

Vamos garantir que elas estejam clusterizadas. Podemos verificar os logs:

```console
$ fly logs
...
app[eb4119d3] sea [info] 21:50:21.924 [info] [libcluster:fly6pn] connected to :"my-app-1234@fdaa:0:1da8:a7b:ac2:f901:4bf7:2"
...
```

Mas isso não é tão gratificante quanto ver de dentro de um nó. A partir de um shell IEx, podemos perguntar ao nó ao qual estamos conectados quais outros nós ele pode ver.

```console
$ fly ssh console -C "/app/bin/my_app remote"
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:f901:4bf7:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ac4:eb41:19d3:2"]
```

O prompt IEx é incluído para ajudar a mostrar o endereço IP do nó ao qual estamos conectados. Então, obter a `Node.list` retorna o outro nó. Nossas duas instâncias estão conectadas e agrupadas!

#### Escalonando para várias regiões

O Fly facilita a implantação de instâncias mais próximas dos seus usuários. Através da mágica do DNS, os usuários são direcionados para a região mais próxima onde sua aplicação está localizada. Você pode ler mais sobre [regiões do Fly.io aqui](https://fly.io/docs/reference/regions/).

Voltando à nossa linha de base de uma única instância em execução em `sea`, que é Seattle, Washington (EUA), vamos adicionar a região `ewr`, que é Parsippany, NJ (EUA). Isso coloca uma instância em ambas as costas dos EUA.

```console
$ fly regions add ewr
Region Pool:
ewr
sea
Backup Region:
iad
lax
sjc
vin
```

Olhando para o status, mostra que estamos apenas em 1 região porque nossa contagem está definida como 1.

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
cdf6c422 29      sea    run     running 1 total, 1 passing 0        58s ago
```

Vamos adicionar uma segunda instância e vê-la implantar em `ewr`.

```console
$ fly scale count 2
Count changed to 2
```

Agora o status mostra que temos duas instâncias espalhadas por 2 regiões!

```console
$ fly status
...
Instances
ID       VERSION REGION DESIRED STATUS  HEALTH CHECKS      RESTARTS CREATED
0a8e6666 30      ewr    run     running 1 total, 1 passing 0        16s ago
cdf6c422 30      sea    run     running 1 total, 1 passing 0        6m47s ago
```

Vamos garantir que elas estejam clusterizadas.

```console
$ fly ssh console -C "/app/bin/my_app remote"
```

```elixir
iex(my-app-1234@fdaa:0:1da8:a7b:ac2:cdf6:c422:2)1> Node.list
[:"my-app-1234@fdaa:0:1da8:a7b:ab2:a8e:6666:2"]
```

Temos duas instâncias de nossa aplicação implantadas nas costas Oeste e Leste do continente norte-americano e elas estão clusterizadas! Nossos usuários serão automaticamente direcionados para o servidor mais próximo deles.

A plataforma Fly.io tem suporte à distribuição integrado, facilitando a clusterização de nós Elixir distribuídos em várias regiões.

## Recursos úteis do Fly.io

Abrir o Dashboard para sua conta

```console
$ fly dashboard
```

Implantar sua aplicação

```console
$ fly deploy
```

Mostrar o status da sua aplicação implantada

```console
$ fly status
```

Acessar e acompanhar os logs

```console
$ fly logs
```

Escalonar sua aplicação para cima ou para baixo

```console
$ fly scale count 2
```

Consulte a [documentação do Fly.io para Elixir](https://fly.io/docs/getting-started/elixir) para informações adicionais.

[Trabalhando com aplicações Fly.io](https://fly.io/docs/getting-started/working-with-fly-apps/) aborda coisas como:

* Status e logs
* Domínios personalizados
* Certificados

## Solução de problemas

Veja [Solução de problemas](https://fly.io/docs/getting-started/troubleshooting/) e [Solução de problemas para Elixir](https://fly.io/docs/elixir/the-basics/troubleshooting/)

Visite a [Comunidade Fly.io](https://community.fly.io/) para encontrar soluções e fazer perguntas.
