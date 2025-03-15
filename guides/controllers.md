# Controladores

> **Requisito**: Este guia pressupõe que você percorreu os [guias introdutórios](installation.html) e conseguiu [executar](up_and_running.html) uma aplicação Phoenix.

> **Requisito**: Este guia pressupõe que você percorreu o [guia do ciclo de vida da requisição](request_lifecycle.html).

Os controladores Phoenix atuam como módulos intermediários. Suas funções — chamadas de ações — são invocadas a partir do roteador em resposta às requisições HTTP. As ações, por sua vez, reúnem todos os dados necessários e executam todas as etapas necessárias antes de invocar a camada de visualização para renderizar um template ou retornar uma resposta JSON.

Os controladores Phoenix também são construídos sobre o pacote Plug e são, eles próprios, plugs. Os controladores fornecem as funções para fazer quase tudo o que precisamos em uma ação. Se nos encontrarmos procurando algo que os controladores Phoenix não fornecem, podemos encontrar o que estamos procurando no próprio Plug. Consulte o [guia do Plug](plug.html) ou a [documentação do Plug](`Plug`) para mais informações.

Uma aplicação Phoenix recém-gerada terá um único controlador chamado `PageController`, que pode ser encontrado em `lib/hello_web/controllers/page_controller.ex` e que se parece com isto:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
```

A primeira linha abaixo da definição do módulo invoca a macro `__using__/1` do módulo `HelloWeb`, que importa alguns módulos úteis.

`PageController` nos fornece a ação `home` para exibir a [página de boas-vindas] do Phoenix associada à rota padrão que o Phoenix define no roteador.

## Ações

As ações do controlador são apenas funções. Podemos nomeá-las como quisermos, desde que sigam as regras de nomenclatura do Elixir. O único requisito que devemos cumprir é que o nome da ação corresponda a uma rota definida no roteador.

Por exemplo, em `lib/hello_web/router.ex`, poderíamos mudar o nome da ação na rota padrão que o Phoenix nos dá em uma nova aplicação, de `home`:

```elixir
get "/", PageController, :home
```

para `index`:

```elixir
get "/", PageController, :index
```

desde que mudemos o nome da ação no `PageController` para `index` também, a [página de boas-vindas] carregará como antes.

```elixir
defmodule HelloWeb.PageController do
  ...

  def index(conn, _params) do
    render(conn, :home)
  end
end
```

Embora possamos nomear nossas ações como quisermos, existem convenções para nomes de ações que devemos seguir sempre que possível. Vimos essas convenções no [guia de roteamento](routing.html), mas daremos outra olhada rápida aqui.

- index   - renderiza uma lista de todos os itens do tipo de recurso fornecido
- show    - renderiza um item individual por ID
- new     - renderiza um formulário para criar um novo item
- create  - recebe parâmetros para um novo item e o salva em um armazenamento de dados
- edit    - recupera um item individual por ID e o exibe em um formulário para edição
- update  - recebe parâmetros para um item editado e salva o item em um armazenamento de dados
- delete  - recebe um ID para um item a ser excluído e o exclui de um armazenamento de dados

Cada uma dessas ações recebe dois parâmetros, que serão fornecidos pelo Phoenix nos bastidores.

O primeiro parâmetro é sempre `conn`, uma struct que contém informações sobre a requisição, como o host, elementos do caminho, porta, string de consulta e muito mais. `conn` chega ao Phoenix através do framework middleware Plug do Elixir. Informações mais detalhadas sobre `conn` podem ser encontradas na [documentação do Plug.Conn](`Plug.Conn`).

O segundo parâmetro é `params`. Não surpreendentemente, este é um mapa que contém quaisquer parâmetros passados na requisição HTTP. É uma boa prática fazer pattern matching nos parâmetros na assinatura da função para fornecer dados em um pacote simples que podemos passar para a renderização. Vimos isso no [guia do ciclo de vida da requisição](request_lifecycle.html) quando adicionamos um parâmetro messenger à nossa rota `show` em `lib/hello_web/controllers/hello_controller.ex`.

```elixir
defmodule HelloWeb.HelloController do
  ...

  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger)
  end
end
```

Em alguns casos — frequentemente em ações `index`, por exemplo — não nos importamos com os parâmetros porque nosso comportamento não depende deles. Nesses casos, não usamos os parâmetros de entrada e simplesmente prefixamos o nome da variável com um sublinhado, chamando-a de `_params`. Isso impedirá que o compilador reclame sobre a variável não utilizada, mantendo a aridade correta.

## Renderização

Os controladores podem renderizar conteúdo de várias maneiras. A mais simples é renderizar algum texto simples usando a função [`text/2`] que o Phoenix fornece.

Por exemplo, vamos reescrever a ação `show` do `HelloController` para retornar texto em vez disso. Para isso, poderíamos fazer o seguinte.

```elixir
def show(conn, %{"messenger" => messenger}) do
  text(conn, "Do mensageiro #{messenger}")
end
```

Agora [`/hello/Frank`] em seu navegador deve exibir `Do mensageiro Frank` como texto simples sem qualquer HTML.

Um passo além disso é renderizar JSON puro com a função [`json/2`]. Precisamos passar algo que a [biblioteca Jason](`Jason`) possa decodificar em JSON, como um mapa. (Jason é uma das dependências do Phoenix.)

```elixir
def show(conn, %{"messenger" => messenger}) do
  json(conn, %{id: messenger})
end
```

Se visitarmos novamente [`/hello/Frank`] no navegador, deveremos ver um bloco de JSON com a chave `id` mapeada para a string `"Frank"`.

```json
{"id": "Frank"}
```

A função [`json/2`] é útil para escrever APIs e também existe a função [`html/2`] para renderizar HTML, mas na maioria das vezes usamos as views do Phoenix para construir nossas respostas. Isso é especialmente importante para respostas HTML, já que as Views do Phoenix fornecem benefícios de desempenho e segurança.

Vamos reverter nossa ação `show` para o que escrevemos originalmente no [guia do ciclo de vida da requisição](request_lifecycle.html):

```elixir
defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger)
  end
end
```

Para que a função [`render/3`] funcione corretamente, o controlador e a view devem compartilhar o mesmo nome raiz (neste caso `Hello`), e o módulo `HelloHTML` deve incluir uma definição `embed_templates` especificando onde seus templates vivem. Por padrão, o controlador, o módulo de visualização e os templates estão localizados juntos no mesmo diretório do controlador. Em outras palavras, `HelloController` requer `HelloHTML`, e `HelloHTML` requer a existência do diretório `lib/hello_web/controllers/hello_html/`, que deve conter o template `show.html.heex`.

[`render/3`] também passará o valor que a ação `show` recebeu para `messenger` dos parâmetros como um assign.

Se precisarmos passar valores para o template ao usar `render`, isso é fácil. Podemos passar uma keyword list como já vimos com `messenger: messenger`, ou podemos usar `Plug.Conn.assign/3`, que convenientemente retorna `conn`.

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> Plug.Conn.assign(:messenger, messenger)
    |> render(:show)
  end
```

Nota: Usar `Phoenix.Controller` importa `Plug.Conn`, então abreviar a chamada para [`assign/3`] funciona perfeitamente.

Passar mais de um valor para nosso template é tão simples quanto conectar funções [`assign/3`] juntas:

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> assign(:messenger, messenger)
    |> assign(:receiver, "Dweezil")
    |> render(:show)
  end
```

Ou você pode passar os assigns diretamente para `render`:

```elixir
  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger, receiver: "Dweezil")
  end
```

De maneira geral, uma vez que todos os assigns estão configurados, invocamos a camada de visualização. A camada de visualização (`HelloWeb.HelloHTML`) então renderiza `show.html` junto com o layout e uma resposta é enviada de volta ao navegador.

[Componentes e templates HEEx](components.html) têm seu próprio guia, então não vamos gastar muito tempo com eles aqui. O que vamos examinar é como renderizar diferentes formatos de dentro de uma ação do controlador.

## Novos formatos de renderização

Renderizar HTML através de um template é bom, mas e se precisarmos mudar o formato de renderização dinamicamente? Digamos que às vezes precisamos de HTML, às vezes precisamos de texto simples e às vezes precisamos de JSON. E então?

O trabalho da view não é apenas renderizar templates HTML. As views são sobre apresentação de dados. Dado um conjunto de dados, o propósito da view é apresentá-los de maneira significativa dado algum formato, seja HTML, JSON, CSV ou outros. Muitas aplicações web hoje retornam JSON para clientes remotos, e as views do Phoenix são *ótimas* para renderização de JSON.

Como exemplo, vamos pegar a ação `home` do `PageController` de uma aplicação recém-gerada. De fábrica, isso tem a view correta `PageHTML`, os templates incorporados de (`lib/hello_web/controllers/page_html`), e o template correto para renderizar HTML (`home.html.heex`.)

```elixir
def home(conn, _params) do
  render(conn, :home, layout: false)
end
```

O que ela não tem é uma view para renderizar JSON. O Controller do Phoenix entrega a um módulo de view para renderizar templates, e faz isso por formato. Já temos uma view para o formato HTML, mas precisamos instruir o Phoenix sobre como renderizar o formato JSON também. Por padrão, você pode ver quais formatos seus controladores suportam em `lib/hello_web.ex`:

```elixir
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: {HelloWeb.Layouts, :app}]
      ...
    end
  end
```

Então, por padrão, o Phoenix procurará por módulos de view `HTML` e `JSON` baseados no formato da requisição e no nome do controlador. Também podemos explicitamente informar ao Phoenix em nosso controlador qual(is) view(s) usar para cada formato. Por exemplo, o que o Phoenix faz por padrão pode ser explicitamente definido com o seguinte em seu controlador:

```elixir
plug :put_view, html: {HelloWeb.PageHTML, :app}, json: {HelloWeb.PageJSON, :app}
```

O nome do layout pode ser omitido, caso em que o nome de layout padrão `:app` é usado, então o acima é equivalente a:

```elixir
plug :put_view, html: HelloWeb.PageHTML, json: HelloWeb.PageJSON
```

Vamos adicionar um módulo de view `PageJSON` em `lib/hello_web/controllers/page_json.ex`:

```elixir
defmodule HelloWeb.PageJSON do
  def home(_assigns) do
    %{message: "isto é algum JSON"}
  end
end
```

Como a camada de View do Phoenix é simplesmente uma função que o controlador renderiza, passando assigns de conexão, podemos definir uma função regular `home/1` e retornar um mapa para ser serializado como JSON.

Há apenas mais algumas coisas que precisamos fazer para que isso funcione. Como queremos renderizar tanto HTML quanto JSON do mesmo controlador, precisamos informar ao nosso roteador que ele deve aceitar o formato `json`. Fazemos isso adicionando `json` à lista de formatos aceitos no pipeline `:browser`. Vamos abrir `lib/hello_web/router.ex` e mudar `plug :accepts` para incluir `json` assim como `html` assim.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
...
```

O Phoenix nos permite mudar formatos dinamicamente com o parâmetro de query string `_format`. Se formos para [`http://localhost:4000/?_format=json`](http://localhost:4000/?_format=json), veremos `%{"message": "isto é algum JSON"}`.

Na prática, no entanto, aplicações que precisam renderizar ambos os formatos normalmente usam dois pipelines distintos para cada um, como o `pipeline :api` já definido em seu arquivo de roteador. Para saber mais, veja [nosso guia de JSON e APIs](json_and_apis.md).

### Enviando respostas diretamente

Se nenhuma das opções de renderização acima se encaixa perfeitamente em nossas necessidades, podemos compor a nossa própria usando algumas das funções que o `Plug` nos fornece. Digamos que queremos enviar uma resposta com um status "201" e sem nenhum corpo. Podemos fazer isso com a função `Plug.Conn.send_resp/3`.

Edite a ação `home` do `PageController` em `lib/hello_web/controllers/page_controller.ex` para ficar assim:

```elixir
def home(conn, _params) do
  send_resp(conn, 201, "")
end
```

Recarregando [http://localhost:4000](http://localhost:4000) deveria mostrar uma página completamente em branco. A aba de rede das ferramentas de desenvolvedor do nosso navegador deve mostrar um status de resposta "201" (Created). Alguns navegadores (Safari) irão baixar a resposta, já que o tipo de conteúdo não está definido.

Para ser específico sobre o tipo de conteúdo, podemos usar [`put_resp_content_type/2`] em conjunto com [`send_resp/3`].

```elixir
def home(conn, _params) do
  conn
  |> put_resp_content_type("text/plain")
  |> send_resp(201, "")
end
```

Usando funções `Plug` desta forma, podemos criar exatamente a resposta que precisamos.

### Definindo o tipo de conteúdo

Análogo ao parâmetro de query string `_format`, podemos renderizar qualquer tipo de formato que quisermos modificando o Cabeçalho HTTP Content-Type e fornecendo o template apropriado.

Se quiséssemos renderizar uma versão XML da nossa ação `home`, poderíamos implementar a ação assim em `lib/hello_web/page_controller.ex`.

```elixir
def home(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render(:home, content: some_xml_content)
end
```

Então precisaríamos fornecer um template `home.xml.eex` que criasse XML válido, e estaríamos prontos.

Para uma lista de tipos de conteúdo mime válidos, por favor veja a biblioteca `MIME`.

### Definindo o Status HTTP

Podemos também definir o código de status HTTP de uma resposta de forma semelhante à maneira como definimos o tipo de conteúdo. O módulo `Plug.Conn`, importado em todos os controladores, tem uma função `put_status/2` para fazer isso.

`Plug.Conn.put_status/2` leva `conn` como o primeiro parâmetro e como o segundo parâmetro um número inteiro ou um "nome amigável" usado como um átomo para o código de status que queremos definir. A lista de representações de código de status em átomos pode ser encontrada na documentação de `Plug.Conn.Status.code/1`.

Vamos mudar o status em nossa ação `home` do `PageController`.

```elixir
def home(conn, _params) do
  conn
  |> put_status(202)
  |> render(:home, layout: false)
end
```

O código de status que fornecemos deve ser um número válido.

## Redirecionamento

Frequentemente, precisamos redirecionar para uma nova URL no meio de uma requisição. Uma ação `create` bem-sucedida, por exemplo, geralmente redirecionará para a ação `show` do recurso que acabamos de criar. Alternativamente, poderia redirecionar para a ação `index` para mostrar todas as coisas desse mesmo tipo. Há muitos outros casos em que o redirecionamento é útil também.

Qualquer que seja a circunstância, os controladores Phoenix fornecem a útil função [`redirect/2`] para tornar o redirecionamento fácil. O Phoenix diferencia entre redirecionar para um caminho dentro da aplicação e redirecionar para uma URL — seja dentro da nossa aplicação ou externa a ela.

Para experimentar [`redirect/2`], vamos criar uma nova rota em `lib/hello_web/router.ex`.

```elixir
defmodule HelloWeb.Router do
  ...

  scope "/", HelloWeb do
    ...
    get "/", PageController, :home
    get "/redirect_test", PageController, :redirect_test
    ...
  end
end
```

Então vamos mudar a ação `home` do nosso `PageController` para não fazer nada além de redirecionar para nossa nova rota.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/redirect_test")
  end
end

```

Utilizamos `Phoenix.VerifiedRoutes.sigil_p/2` para construir nosso caminho de redirecionamento, que é a abordagem preferida para referenciar qualquer caminho dentro da nossa aplicação. Aprendemos sobre rotas verificadas no [guia de roteamento](routing.html).

Finalmente, vamos definir no mesmo arquivo a ação para a qual redirecionamos, que simplesmente renderiza a home, mas agora sob um novo endereço:

```elixir
def redirect_test(conn, _params) do
  render(conn, :home, layout: false)
end
```

Quando recarregamos nossa [página de boas-vindas], vemos que fomos redirecionados para `/redirect_test` que mostra a página de boas-vindas original. Funciona!

Se quisermos, podemos abrir nossas ferramentas de desenvolvedor, clicar na aba de rede e visitar nossa rota raiz novamente. Vemos duas requisições principais para esta página - um get para `/` com um status de `302`, e um get para `/redirect_test` com um status de `200`.

Observe que a função de redirecionamento leva `conn` assim como uma string representando um caminho relativo dentro da nossa aplicação. Por razões de segurança, a opção `:to` só pode redirecionar para caminhos dentro da sua aplicação. Se você quiser redirecionar para um caminho totalmente qualificado ou uma URL externa, você deve usar `:external` em vez disso:

```elixir
def home(conn, _params) do
  redirect(conn, external: "https://elixir-lang.org/")
end
```

## Mensagens Flash

Às vezes precisamos nos comunicar com os usuários durante o curso de uma ação. Talvez tenha havido um erro ao atualizar um esquema, ou talvez apenas queremos dar-lhes as boas-vindas de volta à aplicação. Para isso, temos mensagens flash.

O módulo `Phoenix.Controller` fornece [`put_flash/3`] para definir mensagens flash como um par chave-valor e colocá-las em um assign `@flash` na conexão. Vamos definir duas mensagens flash em nosso `HelloWeb.PageController` para experimentar isso.

Para fazer isso, modificamos a ação `home` da seguinte forma:

```elixir
defmodule HelloWeb.PageController do
  ...
  def home(conn, _params) do
    conn
    |> put_flash(:error, "Vamos fingir que temos um erro.")
    |> render(:home, layout: false)
  end
end
```

Para ver nossas mensagens flash, precisamos ser capazes de recuperá-las e exibi-las em um layout de template. Podemos fazer isso usando [`Phoenix.Flash.get/2`] que pega os dados flash e a chave que nos interessa. Em seguida, retorna o valor para essa chave.

Para nossa conveniência, um componente `flash_group` já está disponível e adicionado ao início da nossa [página de boas-vindas]

```heex
<.flash_group flash={@flash} />
```

Quando recarregamos a [página de boas-vindas], nossa mensagem deve aparecer no canto superior direito da página.

A funcionalidade flash é útil quando misturada com redirecionamentos. Talvez você queira redirecionar para uma página com algumas informações extras. Se reutilizarmos a ação de redirecionamento da seção anterior, podemos fazer:

```elixir
  def home(conn, _params) do
    conn
    |> put_flash(:error, "Vamos fingir que temos um erro.")
    |> redirect(to: ~p"/redirect_test")
  end
```

Agora, se você recarregar a [página de boas-vindas], você será redirecionado e a mensagem flash será mostrada mais uma vez.

Além de [`put_flash/3`], o módulo `Phoenix.Controller` tem outra função útil que vale a pena conhecer. [`clear_flash/1`] pega apenas `conn` e remove quaisquer mensagens flash que possam estar armazenadas na sessão.

O Phoenix não impõe quais chaves são armazenadas no flash. Desde que sejamos internamente consistentes, tudo estará bem. `:info` e `:error`, no entanto, são comuns e são tratados por padrão em nossos templates.

## Páginas de erro

O Phoenix tem duas views chamadas `ErrorHTML` e `ErrorJSON` que vivem em `lib/hello_web/controllers/`. O propósito dessas views é lidar com erros de maneira geral para requisições HTML ou JSON de entrada. Semelhante às views que construímos neste guia, as views de erro podem retornar tanto respostas HTML quanto JSON. Veja o [How-To de Páginas de Erro Personalizadas](custom_error_pages.html) para mais informações.

[`render/4`]: `Phoenix.Template.render/4`
[`/hello/Frank`]:  http://localhost:4000/hello/Frank
[`assign/3`]: `Plug.Conn.assign/3`
[`clear_flash/1`]: `Phoenix.Controller.clear_flash/1`
[`Phoenix.Flash.get/2`]: `Phoenix.Flash.get/2`
[`html/2`]: `Phoenix.Controller.html/2`
[`json/2`]: `Phoenix.Controller.json/2`
[`put_flash/3`]: `Phoenix.Controller.put_flash/3`
[`put_resp_content_type/2`]: `Plug.Conn.put_resp_content_type/2`
[`put_root_layout/2`]: `Phoenix.Controller.put_root_layout/2`
[`redirect/2`]: `Phoenix.Controller.redirect/2`
[`render/3`]: `Phoenix.Controller.render/3`
[`send_resp/3`]: `Plug.Conn.send_resp/3`
[`text/2`]: `Phoenix.Controller.text/2`
[página de boas-vindas]: http://localhost:4000/
