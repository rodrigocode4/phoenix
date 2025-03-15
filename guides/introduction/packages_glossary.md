# Glossário de Pacotes

Por padrão, as aplicações Phoenix dependem de vários pacotes com diferentes propósitos.
Esta página é uma referência rápida dos diferentes pacotes com os quais você pode trabalhar como desenvolvedor Phoenix.

Os principais pacotes são:

  * [Ecto](https://hexdocs.pm/ecto) - uma linguagem integrada de consulta e
    wrapper de banco de dados

  * [Phoenix](https://hexdocs.pm/phoenix) - o framework web Phoenix
    (esta documentação)

  * [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - construa experiências
    ricas e em tempo real para o usuário com HTML renderizado pelo servidor. O projeto
    LiveView também define [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) e
    [o motor de templates HEEx](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2),
    usado para renderizar conteúdo HTML tanto em aplicações regulares quanto em tempo real

  * [Plug](https://hexdocs.pm/plug) - especificação e conveniências para
    construir módulos compostos de aplicações web. Este é o pacote
    responsável pela abstração de conexão e pelo ciclo de vida regular de
    requisição-resposta

Você também trabalhará com os seguintes:

  * [ExUnit](https://hexdocs.pm/ex_unit) - framework de teste integrado do Elixir

  * [Gettext](https://hexdocs.pm/gettext) - internacionalização e
    localização através do [`gettext`](https://www.gnu.org/software/gettext/)

  * [Swoosh](https://hexdocs.pm/swoosh) - uma biblioteca para compor,
    entregar e testar emails, também usada pelo `mix phx.gen.auth`

Ao explorar mais a fundo, você descobrirá que estas bibliotecas desempenham
um papel importante nas aplicações Phoenix:

  * [Phoenix HTML](https://hexdocs.pm/phoenix_html) - blocos de construção
    para trabalhar com HTML e formulários de forma segura

  * [Phoenix Ecto](https://hex.pm/packages/phoenix_ecto) - plugs e
    implementações de protocolo para usar o phoenix com ecto

  * [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub) - um sistema
    distribuído de pub/sub com suporte a presença

Quando se trata de instrumentação e monitoramento, confira:

  * [Phoenix LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) -
    ferramentas de monitoramento de desempenho e depuração em tempo real para
    desenvolvedores Phoenix

  * [Telemetry Metrics](https://hexdocs.pm/telemetry_metrics) - interface
    comum para definir métricas baseadas em eventos Telemetry