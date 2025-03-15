# Roteamento

> **Requisito**: Este guia espera que você tenha passado pelos [guias introdutórios](installation.html) e tenha uma aplicação Phoenix [funcionando](up_and_running.html).

> **Requisito**: Este guia espera que você tenha passado pelo [guia do ciclo de vida de requisições](request_lifecycle.html).

Roteadores são os principais pontos centrais de aplicações Phoenix. Eles correspondem requisições HTTP a ações de controladores, conectam manipuladores de canais em tempo real e definem uma série de transformações de pipeline com escopo para um conjunto de rotas.

O arquivo de roteador que o Phoenix gera, `lib/hello_web/router.ex`, será algo parecido com este:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Outros escopos podem usar pilhas personalizadas.
  # scope "/api", HelloWeb do
  #   pipe_through :api
  # end
  # ...
end
```

Tanto os nomes do módulo do roteador quanto do controlador terão como prefixo o nome que você deu à sua aplicação seguido de `Web`.

A primeira linha deste módulo, `use HelloWeb, :router`, simplesmente disponibiliza as funções do roteador do Phoenix em nosso roteador específico.

Os escopos têm sua própria seção neste guia, então não vamos gastar tempo no bloco `scope "/", HelloWeb do` aqui. A linha `pipe_through :browser` terá um tratamento completo na seção "Pipelines" deste guia. Por enquanto, você só precisa saber que os pipelines permitem que um conjunto de plugs seja aplicado a diferentes conjuntos de rotas.

Dentro do bloco de escopo, no entanto, temos nossa primeira rota real:

```elixir
get "/", PageController, :home
```

`get` é uma macro do Phoenix que corresponde ao verbo HTTP GET. Macros similares existem para outros verbos HTTP, incluindo POST, PUT, PATCH, DELETE, OPTIONS, CONNECT, TRACE e HEAD.

> #### Por que as macros? {: .info}
>
> O Phoenix faz o possível para manter o uso de macros baixo. Você pode ter notado, no entanto, que o `Phoenix.Router` depende muito de macros. Por quê?
>
> Usamos `get`, `post`, `put` e `delete` para definir suas rotas. Usamos macros para dois propósitos:
>
>   * Elas definem o motor de roteamento, usado em cada requisição, para escolher qual controlador irá processar a requisição. Graças às macros, o Phoenix compila todas as suas rotas em uma grande instrução case com regras de correspondência de padrões, que é altamente otimizada pela VM do Erlang
>
>   * Para cada rota que você define, também definimos metadados para implementar `Phoenix.VerifiedRoutes`. Como aprenderemos em breve, rotas verificadas nos permitem referenciar qualquer rota como se fosse uma string comum, exceto que é verificada pelo compilador para ser válida (tornando muito mais difícil enviar links, formulários, e-mails etc. quebrados para produção)
>
> Em outras palavras, o roteador depende de macros para construir aplicações que são mais rápidas e seguras. Lembre-se também que macros em Elixir são apenas em tempo de compilação, o que dá muita estabilidade após o código ser compilado. Como aprenderemos a seguir, o Phoenix também fornece introspecção para todas as rotas definidas via `mix phx.routes`.

## Examinando rotas

O Phoenix fornece uma excelente ferramenta para investigar rotas em uma aplicação: `mix phx.routes`.

Vamos ver como isso funciona. Vá para a raiz de uma aplicação Phoenix recém-gerada e execute `mix phx.routes`. Você deve ver algo como o seguinte, gerado com todas as rotas que você tem atualmente:

```console
$ mix phx.routes
GET  /  HelloWeb.PageController :home
...
```

A rota acima nos diz que qualquer requisição HTTP GET para a raiz da aplicação será tratada pela ação `home` do `HelloWeb.PageController`.

## Recursos

O roteador suporta outras macros além daquelas para verbos HTTP como [`get`](`Phoenix.Router.get/3`), [`post`](`Phoenix.Router.post/3`) e [`put`](`Phoenix.Router.put/3`). A mais importante entre elas é [`resources`](`Phoenix.Router.resources/4`). Vamos adicionar um recurso ao nosso arquivo `lib/hello_web/router.ex` assim:

```elixir
scope "/", HelloWeb do
  pipe_through :browser

  get "/", PageController, :home
  resources "/users", UserController
  ...
end
```

Por enquanto, não importa que não tenhamos realmente um `HelloWeb.UserController`.

Execute `mix phx.routes` mais uma vez na raiz do seu projeto. Você deve ver algo como o seguinte:

```console
...
GET     /users           HelloWeb.UserController :index
GET     /users/:id/edit  HelloWeb.UserController :edit
GET     /users/new       HelloWeb.UserController :new
GET     /users/:id       HelloWeb.UserController :show
POST    /users           HelloWeb.UserController :create
PATCH   /users/:id       HelloWeb.UserController :update
PUT     /users/:id       HelloWeb.UserController :update
DELETE  /users/:id       HelloWeb.UserController :delete
...
```

Esta é a matriz padrão de verbos HTTP, caminhos e ações do controlador. Por um tempo, isso foi conhecido como rotas RESTful, mas a maioria considera isso um termo errado hoje em dia. Vamos olhar para elas individualmente.

- Uma requisição GET para `/users` invocará a ação `index` para mostrar todos os usuários.
- Uma requisição GET para `/users/:id/edit` invocará a ação `edit` com um ID para recuperar um usuário individual do armazenamento de dados e apresentar as informações em um formulário para edição.
- Uma requisição GET para `/users/new` invocará a ação `new` para apresentar um formulário para criar um novo usuário.
- Uma requisição GET para `/users/:id` invocará a ação `show` com um ID para mostrar um usuário individual identificado por esse ID.
- Uma requisição POST para `/users` invocará a ação `create` para salvar um novo usuário no armazenamento de dados.
- Uma requisição PATCH para `/users/:id` invocará a ação `update` com um ID para salvar o usuário atualizado no armazenamento de dados.
- Uma requisição PUT para `/users/:id` também invocará a ação `update` com um ID para salvar o usuário atualizado no armazenamento de dados.
- Uma requisição DELETE para `/users/:id` invocará a ação `delete` com um ID para remover o usuário individual do armazenamento de dados.

Se não precisarmos de todas essas rotas, podemos ser seletivos usando as opções `:only` e `:except` para filtrar ações específicas.

Digamos que temos um recurso de posts somente leitura. Poderíamos defini-lo assim:

```elixir
resources "/posts", PostController, only: [:index, :show]
```

Executando `mix phx.routes` mostra que agora temos apenas as rotas para as ações index e show definidas.

```console
GET     /posts      HelloWeb.PostController :index
GET     /posts/:id  HelloWeb.PostController :show
```

Da mesma forma, se temos um recurso de comentários e não queremos fornecer uma rota para excluir um, poderíamos definir uma rota assim:

```elixir
resources "/comments", CommentController, except: [:delete]
```

Executando `mix phx.routes` agora mostra que temos todas as rotas, exceto a requisição DELETE para a ação delete.

```console
GET    /comments           HelloWeb.CommentController :index
GET    /comments/:id/edit  HelloWeb.CommentController :edit
GET    /comments/new       HelloWeb.CommentController :new
GET    /comments/:id       HelloWeb.CommentController :show
POST   /comments           HelloWeb.CommentController :create
PATCH  /comments/:id       HelloWeb.CommentController :update
PUT    /comments/:id       HelloWeb.CommentController :update
```

A macro `Phoenix.Router.resources/4` descreve opções adicionais para personalizar rotas de recursos.

## Rotas Verificadas

O Phoenix inclui o módulo `Phoenix.VerifiedRoutes` que fornece verificações em tempo de compilação de caminhos de roteador contra seu roteador usando o sigil `~p`. Por exemplo, você pode escrever caminhos em controladores, testes e templates, e o compilador garantirá que esses realmente correspondam às rotas definidas em seu roteador.

Vamos ver isso em ação. Execute `iex -S mix` na raiz do projeto. Vamos definir um módulo de exemplo descartável que constrói alguns caminhos de rota `~p`.

```elixir
iex> defmodule RouteExample do
...>   use HelloWeb, :verified_routes
...>
...>   def example do
...>     ~p"/comments"
...>     ~p"/unknown/123"
...>   end
...> end
warning: no route path for HelloWeb.Router matches "/unknown/123"
  iex:5: RouteExample.example/0

{:module, RouteExample, ...}
iex>
```

Observe como a primeira chamada para uma rota existente, `~p"/comments"` não deu nenhum aviso, mas um caminho de rota ruim `~p"/unknown/123"` produziu um aviso do compilador, como deveria. Isso é significativo porque nos permite escrever caminhos codificados em nossa aplicação e o compilador nos informará sempre que escrevermos uma rota incorreta ou alterarmos nossa estrutura de roteamento.

Os projetos Phoenix são configurados prontos para permitir o uso de rotas verificadas em toda a sua camada web, incluindo testes. Por exemplo, em seus templates, você pode renderizar links `~p`:

```heex
<.link href={~p"/"}>Página de Boas-vindas!</.link>
<.link href={~p"/comments"}>Ver Comentários</.link>
```

Ou em um controlador, emitir um redirecionamento:

```elixir
redirect(conn, to: ~p"/comments/#{comment}")
```

Usar `~p` para caminhos de rota garante que os caminhos e URLs de nossa aplicação permaneçam atualizados com as definições do roteador. O compilador capturará bugs para nós e nos informará quando alterarmos rotas que são referenciadas em outros lugares de nossa aplicação.

### Mais sobre rotas verificadas

E quanto a caminhos com strings de consulta? Você pode adicionar pares de chave-valor de string de consulta diretamente ou fornecer um dicionário de pares de chave-valor, por exemplo:

```elixir
~p"/users/17?admin=true&active=false"
"/users/17?admin=true&active=false"

~p"/users/17?#{[admin: true]}"
"/users/17?admin=true"
```

E se precisarmos de uma URL completa em vez de um caminho? Basta envolver seu caminho com uma chamada para `Phoenix.VerifiedRoutes.url/1`, que é importado em todos os lugares onde `~p` está disponível:

```elixir
url(~p"/users")
"http://localhost:4000/users"
```

As chamadas `url` obterão o host, porta, porta de proxy e informações SSL necessárias para construir a URL completa a partir dos parâmetros de configuração definidos para cada ambiente. Falaremos sobre configuração em mais detalhes em seu próprio guia. Por enquanto, você pode dar uma olhada no arquivo `config/dev.exs` em seu próprio projeto para ver esses valores.

## Recursos aninhados

Também é possível aninhar recursos em um roteador Phoenix. Digamos que também temos um recurso `posts` que tem um relacionamento muitos-para-um com `users`. Ou seja, um usuário pode criar muitos posts, e um post individual pertence a apenas um usuário. Podemos representar isso adicionando uma rota aninhada em `lib/hello_web/router.ex` assim:

```elixir
resources "/users", UserController do
  resources "/posts", PostController
end
```

Quando executamos `mix phx.routes` agora, além das rotas que vimos para `users` acima, obtemos o seguinte conjunto de rotas:

```elixir
...
GET     /users/:user_id/posts           HelloWeb.PostController :index
GET     /users/:user_id/posts/:id/edit  HelloWeb.PostController :edit
GET     /users/:user_id/posts/new       HelloWeb.PostController :new
GET     /users/:user_id/posts/:id       HelloWeb.PostController :show
POST    /users/:user_id/posts           HelloWeb.PostController :create
PATCH   /users/:user_id/posts/:id       HelloWeb.PostController :update
PUT     /users/:user_id/posts/:id       HelloWeb.PostController :update
DELETE  /users/:user_id/posts/:id       HelloWeb.PostController :delete
...
```

Vemos que cada uma dessas rotas limita os posts a um ID de usuário. Para a primeira, invocaremos a ação `index` do `PostController`, mas passaremos um `user_id`. Isso implica que exibiríamos todos os posts apenas para esse usuário individual. O mesmo escopo se aplica a todas essas rotas.

Ao construir caminhos para rotas aninhadas, precisaremos interpolar os IDs onde eles pertencem na definição da rota. Para a seguinte rota `show`, `42` é o `user_id` e `17` é o `post_id`.

```elixir
user_id = 42
post_id = 17
~p"/users/#{user_id}/posts/#{post_id}"
"/users/42/posts/17"
```

Rotas verificadas também suportam o protocolo `Phoenix.Param`, mas não precisamos nos preocupar com protocolos Elixir por enquanto. Saiba apenas que, uma vez que começamos a construir nossa aplicação com structs como `%User{}` e `%Post{}`, poderemos interpolar essas estruturas de dados diretamente em nossos caminhos `~p` e o Phoenix extrairá os campos corretos para usar na rota.

```elixir
~p"/users/#{user}/posts/#{post}"
"/users/42/posts/17"
```

Perceba como não precisamos interpolar `user.id` ou `post.id`? Isso é particularmente útil se decidirmos mais tarde que queremos tornar nossas URLs um pouco mais agradáveis e começar a usar slugs. Não precisamos alterar nenhum de nossos `~p`!

## Rotas com escopo

Escopos são uma maneira de agrupar rotas sob um prefixo de caminho comum e um conjunto de plugs com escopo. Podemos querer fazer isso para funcionalidades de administração, APIs e especialmente para APIs versionadas. Digamos que temos reviews geradas pelo usuário em um site, e que essas reviews primeiro precisam ser aprovadas por um administrador. A semântica desses recursos é bastante diferente, e eles podem não compartilhar o mesmo controlador. Escopos nos permitem segregar essas rotas.

Os caminhos para as reviews voltadas para o usuário seriam como um recurso padrão.

```console
/reviews
/reviews/1234
/reviews/1234/edit
...
```

Os caminhos de administração de reviews podem ter o prefixo `/admin`.

```console
/admin/reviews
/admin/reviews/1234
/admin/reviews/1234/edit
...
```

Conseguimos isso com uma rota com escopo que define uma opção de caminho para `/admin` como esta. Podemos aninhar este escopo dentro de outro escopo, mas, em vez disso, vamos defini-lo sozinho na raiz, adicionando ao `lib/hello_web/router.ex` o seguinte:

```elixir
scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

Definimos um novo escopo onde todas as rotas têm o prefixo `/admin` e todos os controladores estão sob o namespace `HelloWeb.Admin`.

Executando `mix phx.routes` novamente, além do conjunto anterior de rotas, obtemos o seguinte:

```console
...
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
...
```

Isso parece bom, mas há um problema aqui. Lembre-se de que queríamos tanto as rotas de reviews voltadas para o usuário `/reviews` quanto as de administração `/admin/reviews`. Se agora incluirmos as reviews voltadas para o usuário em nosso roteador sob o escopo raiz assim:

```elixir
scope "/", HelloWeb do
  pipe_through :browser

  ...
  resources "/reviews", ReviewController
end

scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/reviews", ReviewController
end
```

e executarmos `mix phx.routes`, obteremos saída para cada rota com escopo:

```console
...
GET     /reviews                 HelloWeb.ReviewController :index
GET     /reviews/:id/edit        HelloWeb.ReviewController :edit
GET     /reviews/new             HelloWeb.ReviewController :new
GET     /reviews/:id             HelloWeb.ReviewController :show
POST    /reviews                 HelloWeb.ReviewController :create
PATCH   /reviews/:id             HelloWeb.ReviewController :update
PUT     /reviews/:id             HelloWeb.ReviewController :update
DELETE  /reviews/:id             HelloWeb.ReviewController :delete
...
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
```

E se tivéssemos vários recursos que fossem todos tratados por administradores? Poderíamos colocar todos eles dentro do mesmo escopo assim:

```elixir
scope "/admin", HelloWeb.Admin do
  pipe_through :browser

  resources "/images",  ImageController
  resources "/reviews", ReviewController
  resources "/users",   UserController
end
```

Veja o que `mix phx.routes` nos diz:

```console
...
GET     /admin/images            HelloWeb.Admin.ImageController :index
GET     /admin/images/:id/edit   HelloWeb.Admin.ImageController :edit
GET     /admin/images/new        HelloWeb.Admin.ImageController :new
GET     /admin/images/:id        HelloWeb.Admin.ImageController :show
POST    /admin/images            HelloWeb.Admin.ImageController :create
PATCH   /admin/images/:id        HelloWeb.Admin.ImageController :update
PUT     /admin/images/:id        HelloWeb.Admin.ImageController :update
DELETE  /admin/images/:id        HelloWeb.Admin.ImageController :delete
GET     /admin/reviews           HelloWeb.Admin.ReviewController :index
GET     /admin/reviews/:id/edit  HelloWeb.Admin.ReviewController :edit
GET     /admin/reviews/new       HelloWeb.Admin.ReviewController :new
GET     /admin/reviews/:id       HelloWeb.Admin.ReviewController :show
POST    /admin/reviews           HelloWeb.Admin.ReviewController :create
PATCH   /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
PUT     /admin/reviews/:id       HelloWeb.Admin.ReviewController :update
DELETE  /admin/reviews/:id       HelloWeb.Admin.ReviewController :delete
GET     /admin/users             HelloWeb.Admin.UserController :index
GET     /admin/users/:id/edit    HelloWeb.Admin.UserController :edit
GET     /admin/users/new         HelloWeb.Admin.UserController :new
GET     /admin/users/:id         HelloWeb.Admin.UserController :show
POST    /admin/users             HelloWeb.Admin.UserController :create
PATCH   /admin/users/:id         HelloWeb.Admin.UserController :update
PUT     /admin/users/:id         HelloWeb.Admin.UserController :update
DELETE  /admin/users/:id         HelloWeb.Admin.UserController :delete
```

Isso é ótimo, exatamente o que queremos. Observe como cada rota e controlador está adequadamente com namespace.

Escopos também podem ser aninhados arbitrariamente, mas você deve fazer isso com cuidado, pois o aninhamento às vezes pode tornar nosso código confuso e menos claro. Com isso dito, suponha que tivéssemos uma API versionada com recursos definidos para imagens, reviews e usuários. Então, tecnicamente, poderíamos configurar rotas para a API versionada assim:

```elixir
scope "/api", HelloWeb.Api, as: :api do
  pipe_through :api

  scope "/v1", V1, as: :v1 do
    resources "/images",  ImageController
    resources "/reviews", ReviewController
    resources "/users",   UserController
  end
end
```

Você pode executar `mix phx.routes` para ver como essas definições serão.

Curiosamente, podemos usar vários escopos com o mesmo caminho, desde que sejamos cuidadosos para não duplicar rotas. O seguinte roteador está perfeitamente correto com dois escopos definidos para o mesmo caminho:

```elixir
defmodule HelloWeb.Router do
  use Phoenix.Router
  ...
  scope "/", HelloWeb do
    pipe_through :browser

    resources "/users", UserController
  end

  scope "/", AnotherAppWeb do
    pipe_through :browser

    resources "/posts", PostController
  end
  ...
end
```

Se duplicarmos uma rota — o que significa duas rotas tendo o mesmo caminho — receberemos este aviso familiar:

```console
warning: this clause cannot match because a previous clause at line 16 always matches
```

## Pipelines

Chegamos bastante longe neste guia sem falar sobre uma das primeiras linhas que vimos no roteador: `pipe_through :browser`. É hora de corrigir isso.

Pipelines são uma série de plugs que podem ser anexados a escopos específicos. Se você não está familiarizado com plugs, temos um [guia detalhado sobre eles](plug.html).

Rotas são definidas dentro de escopos e escopos podem passar por vários pipelines. Uma vez que uma rota corresponde, o Phoenix invoca todos os plugs definidos em todos os pipelines associados a essa rota. Por exemplo, acessar `/` passará pelo pipeline `:browser`, consequentemente invocando todos os seus plugs.

O Phoenix define dois pipelines por padrão, `:browser` e `:api`, que podem ser usados para uma série de tarefas comuns. Por sua vez, podemos personalizá-los, bem como criar novos pipelines para atender às nossas necessidades.

### Os pipelines `:browser` e `:api`

Como seus nomes sugerem, o pipeline `:browser` prepara para rotas que renderizam requisições para um navegador, e o pipeline `:api` prepara para rotas que produzem dados para uma API.

O pipeline `:browser` tem seis plugs: O `plug :accepts, ["html"]` define o formato ou formatos de requisição aceitos. `:fetch_session`, que, naturalmente, busca os dados da sessão e os disponibiliza na conexão. `:fetch_live_flash`, que busca quaisquer mensagens flash do LiveView e as mescla com as mensagens flash do controlador. Em seguida, o plug `:put_root_layout` armazenará o layout raiz para fins de renderização. Mais tarde, `:protect_from_forgery` e `:put_secure_browser_headers` protegem os envios de formulários de falsificação entre sites.

Atualmente, o pipeline `:api` define apenas `plug :accepts, ["json"]`.

O roteador invoca um pipeline em uma rota definida dentro de um escopo. Rotas fora de um escopo não têm pipelines. Embora o uso de escopos aninhados seja desencorajado (veja acima o exemplo de API versionada), se chamarmos `pipe_through` dentro de um escopo aninhado, o roteador invocará todos os `pipe_through` dos escopos pai, seguidos pelo aninhado.

Essas são muitas palavras agrupadas. Vamos dar uma olhada em alguns exemplos para desvendar seu significado.

Aqui está outra olhada no roteador de uma aplicação Phoenix recém-gerada, desta vez com o escopo `/api` descomentado de volta e uma rota adicionada.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Outros escopos podem usar pilhas personalizadas.
  scope "/api", HelloWeb do
    pipe_through :api

    resources "/reviews", ReviewController
  end
  # ...
end
```

Quando o servidor aceita uma requisição, a requisição sempre passará primeiro pelos plugs em nosso endpoint, após o qual tentará corresponder ao caminho e verbo HTTP.

Digamos que a requisição corresponda à nossa primeira rota: um GET para `/`. O roteador primeiro passará essa requisição pelo pipeline `:browser` - que buscará os dados da sessão, buscará o flash e executará a proteção contra falsificação - antes de despachar a requisição para a ação `home` do `PageController`.

Por outro lado, suponha que a requisição corresponda a qualquer uma das rotas definidas pela macro [`resources/2`](`Phoenix.Router.resources/2`). Nesse caso, o roteador a passará pelo pipeline `:api` — que atualmente só realiza negociação de conteúdo — antes de despachá-la para a ação correta do `HelloWeb.ReviewController`.

Se nenhuma rota corresponder, nenhum pipeline é invocado e um erro 404 é levantado.

### Criando novos pipelines

O Phoenix nos permite criar nossos próprios pipelines personalizados em qualquer lugar do roteador. Para fazer isso, chamamos a macro [`pipeline/2`](`Phoenix.Router.pipeline/2`) com estes argumentos: um átomo para o nome do nosso novo pipeline e um bloco com todos os plugs que queremos nele.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug HelloWeb.Authentication
  end

  scope "/reviews", HelloWeb do
    pipe_through [:browser, :auth]

    resources "/", ReviewController
  end
end
```

O exemplo acima assume que existe um plug chamado `HelloWeb.Authentication` que realiza autenticação e agora faz parte do pipeline `:auth`.

Observe que os próprios pipelines são plugs, então podemos conectar um pipeline dentro de outro pipeline. Por exemplo, poderíamos reescrever o pipeline `auth` acima para invocar automaticamente `browser`, simplificando a chamada de pipeline downstream:

```elixir
  pipeline :auth do
    plug :browser
    plug :ensure_authenticated_user
    plug :ensure_user_owns_review
  end

  scope "/reviews", HelloWeb do
    pipe_through :auth

    resources "/", ReviewController
  end
```

## Como organizar minhas rotas?

No Phoenix, tendemos a definir vários pipelines que fornecem funcionalidades específicas. Por exemplo, os pipelines `:browser` e `:api` são destinados a serem acessados por clientes específicos, navegadores e clientes http, respectivamente.

Talvez mais importante, também é muito comum definir pipelines específicos para autenticação e autorização. Por exemplo, você pode ter um pipeline que exige que todos os usuários estejam autenticados. Outro pipeline pode impor que apenas usuários administradores possam acessar certas rotas.

Uma vez que seus pipelines estão definidos, você reutiliza os pipelines nos escopos desejados, agrupando suas rotas em torno de seus pipelines. Por exemplo, voltando ao nosso exemplo de reviews. Digamos que qualquer pessoa possa ler uma review, mas apenas usuários autenticados podem criá-las. Suas rotas poderiam ser assim:

```elixir
pipeline :browser do
  ...
end

pipeline :auth do
  plug HelloWeb.Authentication
end

scope "/" do
  pipe_through [:browser]

  get "/reviews", PostController, :index
  get "/reviews/:id", PostController, :show
end

scope "/" do
  pipe_through [:browser, :auth]

  get "/reviews/new", PostController, :new
  post "/reviews", PostController, :create
end
```

Observe no exemplo acima como as rotas são divididas em diferentes escopos. Embora a separação possa ser confusa no início, ela tem uma grande vantagem: é muito fácil inspecionar suas rotas e ver todas as rotas que, por exemplo, exigem autenticação e quais não exigem. Isso ajuda na auditoria e na certificação de que suas rotas têm o escopo adequado.

Você pode criar tantos ou tão poucos escopos quanto desejar. Como os pipelines são reutilizáveis entre escopos, eles ajudam a encapsular funcionalidades comuns e você pode compô-los conforme necessário em cada escopo que definir.

## Forward

A macro `Phoenix.Router.forward/4` pode ser usada para enviar todas as requisições que começam com um caminho específico para um determinado plug. Digamos que temos uma parte do nosso sistema que é responsável (pode até ser uma aplicação ou biblioteca separada) por executar tarefas em segundo plano, ela poderia ter sua própria interface web para verificar o status das tarefas. Podemos encaminhar para esta interface de administração usando:

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  ...

  scope "/", HelloWeb do
    ...
  end

  forward "/jobs", BackgroundJob.Plug
end
```

Isso significa que todas as rotas que começam com `/jobs` serão enviadas para o módulo `HelloWeb.BackgroundJob.Plug`. Dentro do plug, você pode corresponder a sub-rotas, como `/pending` e `/active` que mostram o status de determinadas tarefas.

Podemos até mesmo misturar a macro [`forward/4`](`Phoenix.Router.forward/4`) com pipelines. Se quiséssemos garantir que o usuário estivesse autenticado e fosse um administrador para ver a página de tarefas, poderíamos usar o seguinte em nosso roteador.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  ...

  scope "/" do
    pipe_through [:authenticate_user, :ensure_admin]
    forward "/jobs", BackgroundJob.Plug
  end
end
```

Isso significa que os plugs nos pipelines `authenticate_user` e `ensure_admin` serão chamados antes do `BackgroundJob.Plug`, permitindo que eles enviem uma resposta apropriada e interrompam a requisição de acordo.

As `opts` que são recebidas no callback `init/1` do Módulo Plug podem ser passadas como um terceiro argumento. Por exemplo, talvez o trabalho em segundo plano permita que você defina o nome da sua aplicação para ser exibido na página. Isso poderia ser passado com:

```elixir
forward "/jobs", BackgroundJob.Plug, name: "Hello Phoenix"
```

Existe um quarto argumento `router_opts` que pode ser passado. Essas opções são descritas na documentação `Phoenix.Router.scope/2`.

`BackgroundJob.Plug` pode ser implementado como qualquer Módulo Plug discutido no [guia do Plug](plug.html). Observe, no entanto, que não é recomendável encaminhar para outro endpoint Phoenix. Isso ocorre porque os plugs definidos pelo seu aplicativo e pelo endpoint encaminhado seriam invocados duas vezes, o que pode levar a erros.

## Resumo

Roteamento é um grande tópico, e cobrimos muito terreno aqui. Os pontos importantes a serem tirados deste guia são:

- Rotas que começam com um nome de verbo HTTP expandem para uma única cláusula da função match.
- Rotas declaradas com `resources` expandem para 8 cláusulas da função match.
- Recursos podem restringir o número de cláusulas da função match usando as opções `only:` ou `except:`.
- Qualquer dessas rotas pode ser aninhada.
- Qualquer dessas rotas pode ter escopo para um determinado caminho.
- Usar rotas verificadas com `~p` para verificações de rota em tempo de compilação