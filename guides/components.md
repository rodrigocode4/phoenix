# Componentes e HEEx

> **Requisito**: Este guia pressupõe que você tenha seguido os [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia pressupõe que você tenha seguido o [guia do ciclo de vida da requisição](request_lifecycle.html).

Os controladores Phoenix atuam como módulos intermediários. Suas funções — chamadas ações — são invocadas pelo roteador em resposta a requisições HTTP. As ações, por sua vez, reúnem todos os dados necessários e realizam todas as etapas necessárias antes de invocar a camada de visualização para renderizar um template ou retornar uma resposta JSON.

Os componentes de função Phoenix são blocos de construção essenciais para qualquer tipo de renderização de templates baseada em marcação que você realizará no Phoenix. Eles servem como uma abstração compartilhada para aplicações MVC baseadas em controladores padrão, aplicações LiveView, layouts e definições de UI menores que você usará em outros templates.

Neste capítulo, revisaremos como os componentes foram usados em capítulos anteriores e encontraremos novos casos de uso para eles.

## Componentes de função

No final do capítulo sobre o ciclo de vida da requisição, criamos um template em `lib/hello_web/controllers/hello_html/show.html.heex`. Vamos abri-lo:

```heex
<section>
  <h2>Hello World, from {@messenger}!</h2>
</section>
```

Este template está incorporado como parte do `HelloHTML`, em `lib/hello_web/controllers/hello_html.ex`:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"
end
```

Isso é bastante simples. Há apenas duas linhas, `use HelloWeb, :html`. Esta linha chama a função `html/0` definida em `HelloWeb`, que configura as importações e configurações básicas para nossos componentes de função e templates.

Todas as importações e aliases que fazemos em nosso módulo também estarão disponíveis em nossos templates. Isso ocorre porque os templates são efetivamente compilados como funções dentro de seus respectivos módulos. Por exemplo, se você definir uma função em seu módulo, poderá invocá-la diretamente do template. Vamos ver isso na prática.

Imagine que queremos refatorar nosso `show.html.heex` para mover a renderização de `<h2>Hello World, from {@messenger}!</h2>` para sua própria função. Podemos movê-la para um componente de função dentro de `HelloHTML`, assim:

```elixir
defmodule HelloWeb.HelloHTML do
  use HelloWeb, :html

  embed_templates "hello_html/*"

  attr :messenger, :string, required: true

  def greet(assigns) do
    ~H"""
    <h2>Hello World, from {@messenger}!</h2>
    """
  end
end
```

Declaramos os atributos que aceitamos através da macro `attr/3` fornecida por `Phoenix.Component`, então definimos nossa função `greet/1` que retorna o template HEEx.

Em seguida, precisamos atualizar `show.html.heex`:

```heex
<section>
  <.greet messenger={@messenger} />
</section>
```

Quando recarregamos `http://localhost:4000/hello/Frank`, devemos ver o mesmo conteúdo de antes. Como o template `show.html.heex` está incorporado dentro do módulo `HelloHTML`, pudemos invocar o componente de função diretamente como `<.greet messenger="..." />`. Se o componente estivesse definido em outro lugar, precisaríamos dar seu nome completo: `<HelloWeb.HelloHTML.greet messenger="..." />`.

Ao declarar atributos como obrigatórios, o Phoenix avisará em tempo de compilação se chamarmos o componente `<.greet />` sem passar os atributos. Se um atributo for opcional, você pode especificar a opção `:default` com um valor:

```
attr :messenger, :string, default: nil
```

No geral, os componentes de função são os blocos de construção essenciais da pilha de renderização do Phoenix. Na maioria das vezes, eles são funções que recebem um único argumento chamado `assigns` e chamam o sigil `~H`, como fizemos em `greet/1`. Eles também podem ser invocados a partir de templates, com validação em tempo de compilação de seus atributos declarados via `attr`.

Na verdade, cada template incorporado em `HelloHTML` é um componente de função em si. `show.html.heex` simplesmente se torna um componente de função chamado `show`. Isso também significa que você pode renderizar componentes de função diretamente do controlador, ignorando o template `show.html.heex`:

```elixir
def HelloWeb.HelloController do
  use HelloWeb, :controller

  def show(conn, %{"messenger" => messenger}) do
    # Renderiza o componente HelloWeb.HelloHTML.greet/1
    render(conn, :greet, messenger: messenger)
  end
end
```

A seguir, vamos entender completamente o poder expressivo por trás da linguagem de template HEEx.

## HEEx

Os componentes de função e arquivos de templates são alimentados pela [linguagem de template HEEx](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2), que significa "HTML+EEx". EEx é uma biblioteca Elixir que usa `<%= expression %>` para executar expressões Elixir e interpolar seus resultados em templates de texto arbitrários. HEEx estende EEx para escrever templates HTML misturados com interpolação Elixir. Podemos escrever código Elixir dentro de `{...}` para interpolação consciente de HTML dentro de atributos de tag e no corpo. Também podemos interpolar blocos HEEx arbitrários usando interpolação EEx (`<%= ... %>`). Usamos `@name` para acessar a chave `name` definida dentro de `assigns`.

Isso é frequentemente usado para exibir assigns que definimos por meio do atalho `@`. Em seu controlador, se você invocar:

```elixir
render(conn, :show, username: "joe")
```

Então você pode acessar o nome de usuário nos templates como `{@username}`. Além de exibir assigns e funções, podemos usar praticamente qualquer expressão Elixir. Por exemplo, para ter condicionais:

```heex
<%= if some_condition? do %>
  <p>Some condition is true for user: {@username}</p>
<% else %>
  <p>Some condition is false for user: {@username}</p>
<% end %>
```

ou até mesmo loops:

```heex
<table>
  <tr>
    <th>Number</th>
    <th>Power</th>
  </tr>
  <%= for number <- 1..10 do %>
    <tr>
      <td>{number}</td>
      <td>{number * number}</td>
    </tr>
  <% end %>
</table>
```

Você notou o uso de `<%= %>` versus `<% %>`? Todas as expressões que produzem algo para o template **devem** usar o sinal de igual (`=`). Se isso não for incluído, o código ainda será executado, mas nada será inserido no template.

HEEx também vem com extensões HTML úteis que aprenderemos a seguir.

### Extensões HTML

Além de permitir a interpolação de expressões Elixir via `<%= %>`, os templates `.heex` vêm com extensões conscientes de HTML. Por exemplo, vejamos o que acontece se você tentar interpolar um valor com "<" ou ">" nele, o que levaria à injeção HTML:

```heex
{"<b>Bold?</b>"}
```

Uma vez que você renderizar o template, verá o literal `<b>` na página. Isso significa que os usuários não podem injetar conteúdo HTML na página. Se você quiser permitir isso, pode chamar `raw`, mas faça isso com extremo cuidado:

```heex
{raw("<b>Bold?</b>")}
```

Outro super poder dos templates HEEx é a validação da sintaxe HTML e interpolação de atributos. Você pode escrever:

```heex
<div title="My div" class={@class}>
  <p>Hello {@username}</p>
</div>
```

Observe como você pode simplesmente usar `key={value}`. HEEx lidará automaticamente com valores especiais como `false` para remover o atributo ou uma lista de classes.

Para interpolar um número dinâmico de atributos em uma lista de palavras-chave ou mapa, faça:

```heex
<div title="My div" {@many_attributes}>
  <p>Hello {@username}</p>
</div>
```

Além disso, tente remover o fechamento `</div>` ou renomeá-lo para `</div-typo>`. Os templates HEEx irão informá-lo sobre seu erro.

HEEx também suporta sintaxe abreviada para expressões `if` e `for` através dos atributos especiais `:if` e `:for`. Por exemplo, em vez de:

```heex
<%= if @some_condition do %>
  <div>...</div>
<% end %>
```

Você pode escrever:

```heex
<div :if={@some_condition}>...</div>
```

Da mesma forma, compreensões for podem ser escritas como:

```heex
<ul>
  <li :for={item <- @items}>{item.name}</li>
</ul>
```

## Layouts

Layouts são apenas componentes de função. Eles são definidos em um módulo, assim como todos os outros templates de componentes de função. Em um aplicativo recém-gerado, isso é `lib/hello_web/components/layouts.ex`. Você também encontrará uma pasta `layouts` com dois layouts incorporados gerados pelo Phoenix. O _layout raiz_ padrão é chamado `root.html.heex`, e é o layout no qual todos os templates serão renderizados por padrão. O segundo é o _layout do aplicativo_, chamado `app.html.heex`, que é renderizado dentro do layout raiz e inclui nossos conteúdos.

Você pode estar se perguntando como a string resultante de uma visualização renderizada acaba dentro de um layout. Essa é uma ótima pergunta! Se olharmos para `lib/hello_web/components/layouts/root.html.heex`, quase no final do `<body>`, veremos isso.

```heex
{@inner_content}
```

Em outras palavras, depois de renderizar sua página, o resultado é colocado no assign `@inner_content`.

Phoenix fornece todo tipo de conveniências para controlar qual layout deve ser renderizado. Por exemplo, o módulo `Phoenix.Controller` fornece a função `put_root_layout/2` para trocarmos _layouts raiz_. Isso recebe `conn` como seu primeiro argumento e uma lista de palavras-chave de formatos e seus layouts. Você pode defini-lo como `false` para desabilitar completamente o layout.

Você pode editar a ação `index` de `HelloController` em `lib/hello_web/controllers/hello_controller.ex` para parecer com isso.

```elixir
def index(conn, _params) do
  conn
  |> put_root_layout(html: false)
  |> render(:index)
end
```

Depois de recarregar [http://localhost:4000/hello](http://localhost:4000/hello), devemos ver uma página muito diferente, uma sem título ou estilo CSS.

Para personalizar o layout da aplicação, invocamos uma função similar chamada `put_layout/2`. Vamos realmente criar outro layout e renderizar o template de índice nele. Como exemplo, digamos que tínhamos um layout diferente para a seção de administração de nossa aplicação que não tinha a imagem do logotipo. Para fazer isso, copie o existente `app.html.heex` para um novo arquivo `admin.html.heex` no mesmo diretório `lib/hello_web/components/layouts`. Em seguida, remova tudo dentro das tags `<header>...</header>` (ou altere-o para o que desejar) no novo arquivo.

Agora, na ação `index` do controlador de `lib/hello_web/controllers/hello_controller.ex`, adicione o seguinte:

```elixir
def index(conn, _params) do
  conn
  |> put_layout(html: :admin)
  |> render(:index)
end
```

Quando carregamos a página, deveríamos estar renderizando o layout de administração sem o cabeçalho (ou com um personalizado que você escreveu).

Neste ponto, você pode estar se perguntando, por que o Phoenix tem dois layouts?

Primeiro, isso nos dá flexibilidade. Na prática, dificilmente teremos vários layouts raiz, pois eles geralmente contêm apenas cabeçalhos HTML. Isso nos permite focar em diferentes layouts de aplicação apenas com as partes que mudam entre eles. Em segundo lugar, o Phoenix vem com um recurso chamado LiveView, que nos permite construir experiências de usuário ricas e em tempo real com HTML renderizado pelo servidor. LiveView é capaz de alterar dinamicamente o conteúdo da página, mas apenas altera o layout do aplicativo, nunca o layout raiz. Confira [a documentação do LiveView](https://hexdocs.pm/phoenix_live_view) para saber mais.

## CoreComponents

Em uma nova aplicação Phoenix, você também encontrará um módulo `core_components.ex` dentro da pasta `components`. Este módulo é um ótimo exemplo de definição de componentes de função para reutilização em toda a nossa aplicação. Isso garante que, à medida que nossa aplicação evolui, nossos componentes terão uma aparência consistente.

Se você olhar dentro de `def html` em `HelloWeb` localizado em `lib/hello_web.ex`, verá que `CoreComponents` é automaticamente importado em todas as visualizações HTML via `use HelloWeb, :html`. Esta também é a razão pela qual o próprio `CoreComponents` executa `use Phoenix.Component` em vez de `use HelloWeb, :html` no topo: fazer o último causaria um deadlock, pois tentaríamos importar `CoreComponents` dentro de si mesmo.

CoreComponents também desempenha um papel importante nos geradores de código Phoenix, pois os geradores pressupõem que esses componentes estão disponíveis para construir rapidamente sua aplicação. Caso você queira aprender mais sobre todas essas peças, você pode:

  * Explorar o módulo `CoreComponents` gerado para aprender mais com exemplos práticos

  * Ler a documentação oficial para [`Phoenix.Component`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html)

  * Ler a documentação oficial para [HEEx e os sigils ~H](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2)

  * Se você estiver procurando componentes de nível mais alto além dos mínimos incluídos pelo Phoenix, [o projeto LiveView mantém uma lista de sistemas de componentes](https://github.com/phoenixframework/phoenix_live_view#component-systems)
