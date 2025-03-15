# Estrutura de diretórios

> **Requisito**: Este guia pressupõe que você tenha percorrido os [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [em funcionamento](up_and_running.html).

Quando usamos `mix phx.new` para gerar uma nova aplicação Phoenix, ele constrói uma estrutura de diretório de nível superior como esta:

```console
├── _build
├── assets
├── config
├── deps
├── lib
│   ├── hello
│   ├── hello.ex
│   ├── hello_web
│   └── hello_web.ex
├── priv
└── test
```

Vamos percorrer esses diretórios um por um:

  * `_build` - um diretório criado pela ferramenta de linha de comando `mix` que acompanha o Elixir e contém todos os artefatos de compilação. Como vimos em "[Em funcionamento](up_and_running.html)", `mix` é a principal interface para sua aplicação. Usamos o Mix para compilar nosso código, criar bancos de dados, executar nosso servidor e muito mais. Este diretório não deve ser incluído no controle de versão e pode ser removido a qualquer momento. Removê-lo forçará o Mix a reconstruir sua aplicação do zero.

  * `assets` - um diretório que mantém o código-fonte para seus ativos de front-end, tipicamente JavaScript e CSS. Essas fontes são automaticamente empacotadas pela ferramenta `esbuild`. Arquivos estáticos como imagens e fontes vão em `priv/static`.

  * `config` - um diretório que contém a configuração do seu projeto. O arquivo `config/config.exs` é o ponto de entrada para sua configuração. No final do `config/config.exs`, ele importa configurações específicas do ambiente, que podem ser encontradas em `config/dev.exs`, `config/test.exs` e `config/prod.exs`. Finalmente, `config/runtime.exs` é executado e é o melhor lugar para ler segredos e outras configurações dinâmicas.

  * `deps` - um diretório com todas as nossas dependências Mix. Você pode encontrar todas as dependências listadas no arquivo `mix.exs`, dentro da definição da função `defp deps do`. Este diretório não deve ser incluído no controle de versão e pode ser removido a qualquer momento. Removê-lo forçará o Mix a baixar todas as dependências do zero.

  * `lib` - um diretório que contém o código-fonte da sua aplicação. Este diretório é dividido em dois subdiretórios, `lib/hello` e `lib/hello_web`. O diretório `lib/hello` será responsável por hospedar toda a sua lógica de negócios e domínio de negócios. Normalmente, interage diretamente com o banco de dados - é o "Modelo" na arquitetura Modelo-Visão-Controlador (MVC). `lib/hello_web` é responsável por expor seu domínio de negócios ao mundo, neste caso, através de uma aplicação web. Ele contém tanto a Visão quanto o Controlador do MVC. Discutiremos o conteúdo desses diretórios com mais detalhes nas próximas seções.

  * `priv` - um diretório que mantém todos os recursos necessários em produção, mas que não fazem parte diretamente do seu código-fonte. Você normalmente mantém scripts de banco de dados, arquivos de tradução, imagens e mais aqui. Os ativos gerados, criados a partir de arquivos no diretório `assets`, são colocados em `priv/static/assets` por padrão.

  * `test` - um diretório com todos os testes da nossa aplicação. Frequentemente, espelha a mesma estrutura encontrada em `lib`.

## O diretório lib/hello

O diretório `lib/hello` hospeda todo o seu domínio de negócios. Como nosso projeto ainda não possui nenhuma lógica de negócios, o diretório está praticamente vazio. Você encontrará apenas três arquivos:

```console
lib/hello
├── application.ex
├── mailer.ex
└── repo.ex
```

O arquivo `lib/hello/application.ex` define uma aplicação Elixir chamada `Hello.Application`. Isso porque, no final das contas, as aplicações Phoenix são simplesmente aplicações Elixir. O módulo `Hello.Application` define quais serviços fazem parte da nossa aplicação:

```elixir
children = [
  HelloWeb.Telemetry,
  Hello.Repo,
  {Phoenix.PubSub, name: Hello.PubSub},
  HelloWeb.Endpoint
]
```

Se esta é sua primeira vez com Phoenix, você não precisa se preocupar com os detalhes agora. Por enquanto, basta dizer que nossa aplicação inicia um repositório de banco de dados, um sistema PubSub para compartilhar mensagens entre processos e nós, e o endpoint da aplicação, que efetivamente serve requisições HTTP. Esses serviços são iniciados na ordem em que são definidos e, ao desligar sua aplicação, são interrompidos na ordem inversa.

Você pode aprender mais sobre aplicações na [documentação oficial do Elixir para Application](https://hexdocs.pm/elixir/Application.html).

O arquivo `lib/hello/mailer.ex` contém o módulo `Hello.Mailer`, que define a interface principal para enviar e-mails:

```elixir
defmodule Hello.Mailer do
  use Swoosh.Mailer, otp_app: :hello
end
```

No mesmo diretório `lib/hello`, encontraremos um `lib/hello/repo.ex`. Ele define um módulo `Hello.Repo` que é nossa interface principal para o banco de dados. Se você estiver usando Postgres (o banco de dados padrão), verá algo como isto:

```elixir
defmodule Hello.Repo do
  use Ecto.Repo,
    otp_app: :hello,
    adapter: Ecto.Adapters.Postgres
end
```

E é isso por enquanto. À medida que você trabalha em seu projeto, adicionaremos arquivos e módulos a este diretório.

## O diretório lib/hello_web

O diretório `lib/hello_web` contém as partes relacionadas à web da nossa aplicação. Ele se parece com isto quando expandido:

```console
lib/hello_web
├── controllers
│   ├── page_controller.ex
│   ├── page_html.ex
│   ├── error_html.ex
│   ├── error_json.ex
│   └── page_html
│       └── home.html.heex
├── components
│   ├── core_components.ex
│   ├── layouts.ex
│   └── layouts
│       ├── app.html.heex
│       └── root.html.heex
├── endpoint.ex
├── gettext.ex
├── router.ex
└── telemetry.ex
```

Todos os arquivos que estão atualmente nos diretórios `controllers` e `components` estão lá para criar a página "Welcome to Phoenix!" que vimos no guia "[Em funcionamento](up_and_running.html)".

Ao observar os diretórios `controller` e `components`, podemos ver que o Phoenix fornece recursos para lidar com layouts, HTML e páginas de erro prontos para uso.

Além dos diretórios mencionados, `lib/hello_web` tem quatro arquivos em sua raiz. `lib/hello_web/endpoint.ex` é o ponto de entrada para requisições HTTP. Uma vez que o navegador acessa [http://localhost:4000](http://localhost:4000), o endpoint começa a processar os dados, eventualmente levando ao roteador, que é definido em `lib/hello_web/router.ex`. O roteador define as regras para despachar requisições para "controladores", que chamam um módulo de visualização para renderizar páginas HTML de volta aos clientes. Exploramos essas camadas extensivamente em outros guias, começando com o guia "[Ciclo de vida da requisição](request_lifecycle.html)" que vem a seguir.

Através do _Telemetry_, o Phoenix é capaz de coletar métricas e enviar eventos de monitoramento da sua aplicação. O arquivo `lib/hello_web/telemetry.ex` define o supervisor responsável por gerenciar os processos de telemetria. Você pode encontrar mais informações sobre este tópico no [guia de Telemetria](telemetry.html).

Finalmente, há um arquivo `lib/hello_web/gettext.ex` que fornece internacionalização através do [Gettext](https://hexdocs.pm/gettext/Gettext.html). Se você não está preocupado com internacionalização, pode pular com segurança este arquivo e seu conteúdo.

## O diretório assets

O diretório `assets` contém arquivos fonte relacionados a ativos de front-end, como JavaScript e CSS. Desde o Phoenix v1.6, usamos o [`esbuild`](https://github.com/evanw/esbuild/) para compilar ativos, que é gerenciado pelo pacote Elixir [`esbuild`](https://github.com/phoenixframework/esbuild). A integração com o `esbuild` está incorporada em seu aplicativo. A configuração relevante pode ser encontrada em seu arquivo `config/config.exs`.

Seus outros ativos estáticos são colocados na pasta `priv/static`, onde `priv/static/assets` é mantido para ativos gerados. Tudo em `priv/static` é servido pelo plug `Plug.Static` configurado em `lib/hello_web/endpoint.ex`. Quando executado no modo de desenvolvimento (`MIX_ENV=dev`), o Phoenix observa quaisquer alterações que você fizer no diretório `assets` e, em seguida, cuida de atualizar sua aplicação front-end em seu navegador enquanto você trabalha.

Observe que quando você cria seu aplicativo Phoenix pela primeira vez usando `mix phx.new`, é possível especificar opções que afetarão a presença e o layout do diretório `assets`. Na verdade, os aplicativos Phoenix podem trazer suas próprias ferramentas de front-end ou não ter um front-end (útil se você estiver escrevendo uma API, por exemplo). Para mais informações, você pode executar `mix help phx.new` ou ver a documentação em [Tarefas Mix](mix_tasks.html).

Se a integração padrão do esbuild não atender às suas necessidades, por exemplo, porque você deseja usar outra ferramenta de build, você pode mudar para uma [build de ativos personalizada](asset_management.html#custom_builds).

Quanto ao CSS, o Phoenix vem com o [Tailwind CSS Framework](https://tailwindcss.com/), fornecendo uma configuração base para projetos. Você pode mudar para qualquer framework CSS de sua escolha. Referências adicionais podem ser encontradas no guia de [gerenciamento de ativos](asset_management.md#css).
