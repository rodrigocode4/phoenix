defmodule Phoenix.Controller do
  import Plug.Conn
  alias Plug.Conn.AlreadySentError

  require Logger
  require Phoenix.Endpoint

  @unsent [:unset, :set, :set_chunked, :set_file]

  # View/Layout deprecation plan
  # 1. Deprecate :namespace option in favor of :layouts on use
  # 2. Deprecate setting a non-format view/layout on put_*
  # 3. Deprecate rendering a view/layout from :_

  @type view :: atom()
  @type layout :: {module(), layout_name :: atom()} | atom() | false

  @moduledoc """
  Controladores são usados para agrupar funcionalidades comuns no mesmo
  módulo (conectável).

  Por exemplo, a rota:

      get "/users/:id", MyAppWeb.UserController, :show

  irá invocar a ação `show/2` em `MyAppWeb.UserController`:

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller

        def show(conn, %{"id" => id}) do
          user = Repo.get(User, id)
          render(conn, :show, user: user)
        end
      end

  Uma ação é uma função regular que recebe a conexão e os parâmetros
  da requisição como argumentos. A conexão é uma struct `Plug.Conn`,
  conforme especificado pela biblioteca Plug.

  Então invocamos `render/3`, passando a conexão, o template
  a ser renderizado (tipicamente nomeado após a ação) e `user: user`
  como assigns. Exploraremos todos esses conceitos a seguir.

  ## Conexão

  Um controlador por padrão fornece muitas funções de conveniência para
  manipular a conexão, renderizar templates e muito mais.

  Essas funções são importadas de dois módulos:

    * `Plug.Conn` - uma coleção de funções de baixo nível para trabalhar
      com a conexão

    * `Phoenix.Controller` - funções fornecidas pelo Phoenix
      para suportar renderização e outros comportamentos específicos do Phoenix

  Se você quiser ter funções que manipulem a conexão sem implementar
  totalmente o controlador, você pode importar ambos os módulos diretamente
  em vez de `use Phoenix.Controller`.

  ## Renderização e layouts

  Uma das principais funcionalidades fornecidas pelos controladores é a capacidade
  de realizar negociação de conteúdo e renderizar templates com base em
  informações enviadas pelo cliente.

  Existem duas maneiras de renderizar conteúdo em um controlador. Uma opção
  é invocar funções específicas de formato, como `html/2` e `json/2`.

  No entanto, mais comumente, os controladores invocam módulos personalizados
  chamados de views. Views são módulos capazes de renderizar um formato personalizado.
  Isso é feito especificando a opção `:formats` ao definir o controlador:

      use Phoenix.Controller,
        formats: [:html, :json]

   Agora, ao invocar `render/3`, um controlador chamado `MyAppWeb.UserController`
   irá invocar `MyAppWeb.UserHTML` e `MyAppWeb.UserJSON` respectivamente
   ao renderizar cada formato:

      def show(conn, %{"id" => id}) do
        user = Repo.get(User, id)
        # Irá invocar UserHTML.show(%{user: user}) para requisições html
        # Irá invocar UserJSON.show(%{user: user}) para requisições json
        render(conn, :show, user: user)
      end

  Alguns formatos também são úteis para ter layouts, que renderizam conteúdo
  compartilhado em todas as páginas. Também podemos especificar layouts em `use`:

      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: MyAppWeb.Layouts]

  Você também pode especificar formatos e layouts a serem renderizados chamando
  `put_view/2` e `put_layout/2` diretamente com uma conexão.
  A linha acima também pode ser escrita diretamente em suas ações como:

      conn
      |> put_view(html: MyAppWeb.UserHTML, json: MyAppWeb.UserJSON)
      |> put_layout(html: MyAppWeb.Layouts)

  ### Compatibilidade com versões anteriores

  Em versões anteriores do Phoenix, um controlador sempre renderizava
  `MyApp.UserView`. Esse comportamento pode ser explicitamente mantido
  passando um sufixo para as opções de formatos:

      use Phoenix.Controller,
        formats: [html: "View", json: "View"],
        layouts: [html: MyAppWeb.Layouts]

  ### Opções

  Quando usado, o controlador suporta as seguintes opções para personalizar
  a renderização de templates:

    * `:formats` - os formatos que este controlador irá renderizar
      por padrão. Por exemplo, especificar `formats: [:html, :json]`
      para um controlador chamado `MyAppWeb.UserController` irá
      invocar `MyAppWeb.UserHTML` e `MyAppWeb.UserJSON` ao
      renderizar cada formato respectivamente. Se `:formats` não for
      definido, a view padrão é definida como `MyAppWeb.UserView`

    * `:layouts` - quais layouts renderizar para cada formato,
      por exemplo: `[html: DemoWeb.Layouts]`

  Opções obsoletas:

    * `:namespace` - define o namespace para o layout. Use
      `:layouts` em vez disso

    * `:put_default_views` - controla se a view e o layout padrão
      devem ser definidos ou não. Defina `formats: []` e
      `layouts: []` em vez disso

  ## Pipeline de Plugs

  Assim como os roteadores, os controladores também têm seu próprio pipeline de plugs.
  No entanto, diferente dos roteadores, os controladores têm um único pipeline:

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller

        plug :authenticate, usernames: ["jose", "eric", "sonny"]

        def show(conn, params) do
          # apenas usuários autenticados
        end

        defp authenticate(conn, options) do
          if get_session(conn, :username) in options[:usernames] do
            conn
          else
            conn |> redirect(to: "/") |> halt()
          end
        end
      end

  O plug `:authenticate` será invocado antes da ação. Se o plug
  chamar `Plug.Conn.halt/1` (que é importado por padrão nos
  controladores), ele irá interromper o pipeline e não invocará a ação.

  ### Guardas

  `plug/2` nos controladores suporta guardas, permitindo que um desenvolvedor
  configure um plug para ser executado apenas em alguma ação específica.

      plug :do_something when action in [:show, :edit]

  Devido à precedência de operadores no Elixir, se o segundo argumento for uma
  lista de palavras-chave, precisamos envolver a palavra-chave em `[...]` ao
  usar `when`:

      plug :authenticate, [usernames: ["jose", "eric", "sonny"]] when action in [:show, :edit]
      plug :authenticate, [usernames: ["admin"]] when not action in [:index]

  O primeiro plug será executado apenas quando a ação for show ou edit. O segundo plug
  sempre será executado, exceto para a ação index.

  Essas guardas funcionam como guardas regulares do Elixir e as únicas variáveis
  acessíveis na guarda são `conn`, a `action` como um átomo e o `controller`
  como um alias.

  ## Controladores são plugs

  Assim como os roteadores, os controladores são plugs, mas eles são conectados
  para despachar para uma função específica, que é chamada de ação.

  Por exemplo, a rota:

      get "/users/:id", UserController, :show

  irá invocar `UserController` como um plug:

      UserController.call(conn, :show)

  que irá disparar o pipeline de plugs e que eventualmente
  invocará o plug de ação interno que despacha para a função `show/2`
  em `UserController`.

  Como os controladores são plugs, eles implementam tanto [`init/1`](`c:Plug.init/1`)
  quanto [`call/2`](`c:Plug.call/2`), e também fornecem uma função chamada
  `action/2`, que é responsável por despachar a ação apropriada
  após a pilha de plugs (e também é substituível).

  ### Substituindo `action/2` para argumentos personalizados

  O Phoenix injeta um plug `action/2` no seu controlador que chama a função
  correspondente do roteador. Por padrão, ele passa a conn e os params.
  Em alguns casos, substituir o plug `action/2` no seu controlador é uma
  maneira útil de injetar argumentos em suas ações que você precisaria
  buscar repetidamente da conexão. Por exemplo, imagine se você armazenou
  um `conn.assigns.current_user` na conexão e quisesse acesso rápido ao
  usuário para cada ação no seu controlador:

      def action(conn, _) do
        args = [conn, conn.params, conn.assigns.current_user]
        apply(__MODULE__, action_name(conn), args)
      end

      def index(conn, _params, user) do
        videos = Repo.all(user_videos(user))
        # ...
      end

      def delete(conn, %{"id" => id}, user) do
        video = Repo.get!(user_videos(user), id)
        # ...
      end

  """
  defmacro __using__(opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote bind_quoted: [opts: opts] do
      import Phoenix.Controller
      import Plug.Conn

      use Phoenix.Controller.Pipeline

      if Keyword.get(opts, :put_default_views, true) do
        plug :put_new_layout, Phoenix.Controller.__layout__(__MODULE__, opts)
        plug :put_new_view, Phoenix.Controller.__view__(__MODULE__, opts)
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:action, 2}})

  defp expand_alias(other, _env), do: other

  @doc """
  Registra o plug a ser chamado como um fallback para a ação do controlador.

  Um plug de fallback é útil para traduzir estruturas de dados de domínio comuns
  em uma resposta `%Plug.Conn{}` válida. Se a ação do controlador falhar em
  retornar um `%Plug.Conn{}`, o plug fornecido será chamado e receberá
  o `%Plug.Conn{}` do controlador como estava antes da ação ser invocada,
  juntamente com o valor retornado da ação do controlador.

  ## Exemplos

      defmodule MyController do
        use Phoenix.Controller

        action_fallback MyFallbackController

        def show(conn, %{"id" => id}, current_user) do
          with {:ok, post} <- Blog.fetch_post(id),
               :ok <- Authorizer.authorize(current_user, :view, post) do

            render(conn, "show.json", post: post)
          end
        end
      end

  No exemplo acima, `with` é usado para corresponder apenas a uma busca de postagem
  bem-sucedida, seguida de uma autorização válida para o usuário atual.
  Caso qualquer uma dessas correspondências falhe, `with` não invocará
  o bloco de renderização e, em vez disso, retornará o valor não correspondido. Nesse caso,
  imagine que `Blog.fetch_post/2` retornou `{:error, :not_found}` ou
  `Authorizer.authorize/3` retornou `{:error, :unauthorized}`. Para casos
  onde essas estruturas de dados servem como valores de retorno em múltiplas
  fronteiras em nosso domínio, um único módulo de fallback pode ser usado para
  traduzir o valor em uma resposta válida. Por exemplo, você poderia
  escrever o seguinte controlador de fallback para lidar com os valores acima:

      defmodule MyFallbackController do
        use Phoenix.Controller

        def call(conn, {:error, :not_found}) do
          conn
          |> put_status(:not_found)
          |> put_view(MyErrorView)
          |> render(:"404")
        end

        def call(conn, {:error, :unauthorized}) do
          conn
          |> put_status(:forbidden)
          |> put_view(MyErrorView)
          |> render(:"403")
        end
      end
  """
  defmacro action_fallback(plug) do
    Phoenix.Controller.Pipeline.__action_fallback__(plug, __CALLER__)
  end

@doc """
  Retorna o nome da ação como um átomo, gera um erro se não estiver disponível.
  """
  @spec action_name(Plug.Conn.t()) :: atom
  def action_name(conn), do: conn.private.phoenix_action

@doc """
  Retorna o módulo do controlador como um átomo, gera um erro se não estiver disponível.
  """
  @spec controller_module(Plug.Conn.t()) :: atom
  def controller_module(conn), do: conn.private.phoenix_controller

  @doc """
  Retorna o módulo do roteador como um átomo, gera um erro se não estiver disponível.
  """
  @spec router_module(Plug.Conn.t()) :: atom
  def router_module(conn), do: conn.private.phoenix_router

  @doc """
  Retorna o módulo do endpoint como um átomo, gera um erro se não estiver disponível.
  """
  @spec endpoint_module(Plug.Conn.t()) :: atom
  def endpoint_module(conn), do: conn.private.phoenix_endpoint

  @doc """
  Retorna o nome do template renderizado na view como uma string
  (ou nil se nenhum template foi renderizado).
  """
  @spec view_template(Plug.Conn.t()) :: binary | nil
  def view_template(conn) do
    conn.private[:phoenix_template]
  end

  @doc """
  Envia uma resposta JSON.

  Ele usa a `:json_library` configurada em `:phoenix`
  para `:json` escolher o módulo encoder.

  ## Exemplos

      iex> json(conn, %{id: 123})

  """
  @spec json(Plug.Conn.t(), term) :: Plug.Conn.t()
  def json(conn, data) do
    response = Phoenix.json_library().encode_to_iodata!(data)
    send_resp(conn, conn.status || 200, "application/json", response)
  end

  @doc """
  Um plug que pode converter uma resposta JSON em uma JSONP.

  Caso uma resposta JSON seja retornada, ela será convertida
  para JSONP desde que o campo de callback esteja presente na
  query string. O campo de callback em si tem como padrão
  "callback", mas pode ser configurado com a opção callback.

  Caso não haja callback ou a resposta não esteja codificada
  no formato JSON, é uma operação nula (no-op).

  Apenas caracteres alfanuméricos e underscore são permitidos no
  nome do callback. Caso contrário, uma exceção é lançada.

  ## Exemplos

      # Irá converter JSON para JSONP se callback=someFunction for fornecido
      plug :allow_jsonp

      # Irá converter JSON para JSONP se cb=someFunction for fornecido
      plug :allow_jsonp, callback: "cb"

  """
  @spec allow_jsonp(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def allow_jsonp(conn, opts \\ []) do
    callback = Keyword.get(opts, :callback, "callback")

    case Map.fetch(conn.query_params, callback) do
      :error ->
        conn

      {:ok, ""} ->
        conn

      {:ok, cb} ->
        validate_jsonp_callback!(cb)

        register_before_send(conn, fn conn ->
          if json_response?(conn) do
            conn
            |> put_resp_header("content-type", "application/javascript")
            |> resp(conn.status, jsonp_body(conn.resp_body, cb))
          else
            conn
          end
        end)
    end
  end

  defp json_response?(conn) do
    case get_resp_header(conn, "content-type") do
      ["application/json;" <> _] -> true
      ["application/json"] -> true
      _ -> false
    end
  end

  defp jsonp_body(data, callback) do
    body =
      data
      |> IO.iodata_to_binary()
      |> String.replace(<<0x2028::utf8>>, "\\u2028")
      |> String.replace(<<0x2029::utf8>>, "\\u2029")

    "/**/ typeof #{callback} === 'function' && #{callback}(#{body});"
  end

  defp validate_jsonp_callback!(<<h, t::binary>>)
       when h in ?0..?9 or h in ?A..?Z or h in ?a..?z or h == ?_,
       do: validate_jsonp_callback!(t)

  defp validate_jsonp_callback!(<<>>), do: :ok

  defp validate_jsonp_callback!(_),
    do: raise(ArgumentError, "the JSONP callback name contains invalid characters")

  @doc """
  Envia uma resposta de texto.

  ## Exemplos

      iex> text(conn, "olá")

      iex> text(conn, :implements_to_string)

  """
  @spec text(Plug.Conn.t(), String.Chars.t()) :: Plug.Conn.t()
  def text(conn, data) do
    send_resp(conn, conn.status || 200, "text/plain", to_string(data))
  end

  @doc """
  Envia uma resposta HTML.

  ## Exemplos

      iex> html(conn, "<html><head>...")

  """
  @spec html(Plug.Conn.t(), iodata) :: Plug.Conn.t()
  def html(conn, data) do
    send_resp(conn, conn.status || 200, "text/html", data)
  end

  @doc """
  Envia uma resposta de redirecionamento para a URL fornecida.

  Por segurança, `:to` aceita apenas caminhos. Use a opção
  `:external` para redirecionar para qualquer URL.

  A resposta será enviada com o código de status definido dentro
  da conexão, através de `Plug.Conn.put_status/2`. Se nenhum código
  de status for definido, uma resposta 302 será enviada.

  ## Exemplos

      iex> redirect(conn, to: "/login")

      iex> redirect(conn, external: "https://elixir-lang.org")

  """
  def redirect(conn, opts) when is_list(opts) do
    url = url(opts)
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> send_resp(conn.status || 302, "text/html", body)
  end

  defp url(opts) do
    cond do
      to = opts[:to] -> validate_local_url(to)
      external = opts[:external] -> external
      true -> raise ArgumentError, "expected :to or :external option in redirect/2"
    end
  end

  @invalid_local_url_chars ["\\", "/%09", "/\t"]
  defp validate_local_url("//" <> _ = to), do: raise_invalid_url(to)

  defp validate_local_url("/" <> _ = to) do
    if String.contains?(to, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for local redirect in URL #{inspect(to)}"
    else
      to
    end
  end

  defp validate_local_url(to), do: raise_invalid_url(to)

  @spec raise_invalid_url(term()) :: no_return()
  defp raise_invalid_url(url) do
    raise ArgumentError, "the :to option in redirect expects a path but was #{inspect(url)}"
  end

  @doc """
  Armazena a view para renderização.

  Gera `Plug.Conn.AlreadySentError` se `conn` já foi enviado.

  ## Exemplos

      # Usar um único módulo de view
      iex> put_view(conn, AppView)

      # Usar múltiplos módulos de view para negociação de conteúdo
      iex> put_view(conn, html: AppHTML, json: AppJSON)

  """
  @spec put_view(Plug.Conn.t(), [{format :: atom, view}] | view) :: Plug.Conn.t()
  def put_view(%Plug.Conn{state: state} = conn, formats) when state in @unsent do
    put_private_view(conn, :phoenix_view, :replace, formats)
  end

  def put_view(%Plug.Conn{}, _module), do: raise(AlreadySentError)

  defp put_private_view(conn, priv_key, kind, formats) when is_list(formats) do
    formats = Enum.into(formats, %{}, fn {format, value} -> {to_string(format), value} end)
    put_private_formats(conn, priv_key, kind, formats)
  end

  # TODO: Deprecate this whole branch
  defp put_private_view(conn, priv_key, kind, value) do
    put_private_formats(conn, priv_key, kind, %{_: value})
  end

  defp put_private_formats(conn, priv_key, kind, formats) when kind in [:new, :replace] do
    update_in(conn.private, fn private ->
      existing = private[priv_key] || %{}

      new_formats =
        case kind do
          :new -> Map.merge(formats, existing)
          :replace -> Map.merge(existing, formats)
        end

      Map.put(private, priv_key, new_formats)
    end)
  end

  @doc """
  Armazena a view para renderização se uma ainda não foi armazenada.

  Gera `Plug.Conn.AlreadySentError` se `conn` já foi enviado.
  """
  # TODO: Remove | layout from the spec once we deprecate put_new_view on controllers
  @spec put_new_view(Plug.Conn.t(), [{format :: atom, view}] | view) :: Plug.Conn.t()
  def put_new_view(%Plug.Conn{state: state} = conn, formats) when state in @unsent do
    put_private_view(conn, :phoenix_view, :new, formats)
  end

  def put_new_view(%Plug.Conn{}, _module), do: raise(AlreadySentError)

  @doc """
  Recupera a view atual para o formato fornecido.

  Se nenhum formato for fornecido, pega o atual da conexão.
  """
  @spec view_module(Plug.Conn.t(), binary | nil) :: atom
  def view_module(conn, format \\ nil) do
    format = format || get_safe_format(conn)

    # TODO: Deprecate if we fall on the first branch
    # But we should only deprecate this after non-format is deprecated on put_*
    case conn.private[:phoenix_view] do
      %{_: value} when value != nil ->
        value

      %{^format => value} ->
        value

      formats ->
        raise "no view was found for the format: #{inspect(format)}. " <>
                "The supported formats are: #{inspect(Map.keys(formats || %{}) -- [:_])}"
    end
  end

  @doc """
  Armazena o layout para renderização.

  O layout deve ser fornecido como uma lista de palavras-chave, onde a chave é o formato
  da requisição ao qual o layout será aplicado (como `:html`) e o valor é um dos seguintes:

    * `{module, layout}` com o `module` onde o layout é definido e
      o nome do `layout` como um átomo

    * `layout` quando o nome do layout. Isso requer um layout para
      o formato fornecido na forma de `{module, layout}` a ser previamente
      fornecido

    * `false` que desativa o layout

  Se `false` for fornecido sem um formato, todos os layouts são desativados.

  ## Exemplos

      iex> layout(conn)
      false

      iex> conn = put_layout(conn, html: {AppView, :application})
      iex> layout(conn)
      {AppView, :application}

      iex> conn = put_layout(conn, html: :print)
      iex> layout(conn)
      {AppView, :print}

  Gera `Plug.Conn.AlreadySentError` se `conn` já foi enviado.
  """
  @spec put_layout(Plug.Conn.t(), [{format :: atom, layout}] | false) :: Plug.Conn.t()
  def put_layout(%Plug.Conn{state: state} = conn, layout) do
    if state in @unsent do
      put_private_layout(conn, :phoenix_layout, :replace, layout)
    else
      raise AlreadySentError
    end
  end

  defp put_private_layout(conn, private_key, kind, layouts) when is_list(layouts) do
    formats =
      Map.new(layouts, fn
        {format, false} ->
          {Atom.to_string(format), false}

        {format, layout} when is_atom(layout) ->
          format = Atom.to_string(format)

          case conn.private[private_key] do
            %{^format => {mod, _}} ->
              {format, {mod, layout}}

            %{} ->
              raise "cannot use put_layout/2 or put_root_layout/2 with atom because " <>
                      "there is no previous layout set for format #{inspect(format)}"
          end

        {format, {mod, layout}} when is_atom(mod) and is_atom(layout) ->
          {Atom.to_string(format), {mod, layout}}

        {format, other} ->
          raise ArgumentError, """
          put_layout and put_root_layout expects an module and template per format, such as:

              #{format}: {MyView, :app}

          Got:

              #{inspect(other)}
          """
      end)

    put_private_formats(conn, private_key, kind, formats)
  end

  defp put_private_layout(conn, private_key, kind, no_format) do
    case no_format do
      false ->
        put_private_formats(conn, private_key, kind, %{_: false})

      # TODO: Deprecate this branch
      {mod, layout} when is_atom(mod) ->
        put_private_formats(conn, private_key, kind, %{_: {mod, layout}})

      # TODO: Deprecate this branch
      layout when is_binary(layout) or is_atom(layout) ->
        case Map.get(conn.private, private_key, %{_: false}) do
          %{_: {mod, _}} ->
            put_private_formats(conn, private_key, kind, %{_: {mod, layout}})

          %{_: false} ->
            raise "cannot use put_layout/2 or put_root_layout/2 with atom/binary when layout is false, use a tuple instead"

          %{} ->
            raise "you must pass the format when using put_layout/2 or put_root_layout/2 and a previous format was set, " <>
                    "such as: put_layout(conn, html: #{inspect(layout)})"
        end
    end
  end

  @doc """
  Armazena o layout para renderização se um ainda não foi armazenado.

  Veja `put_layout/2` para mais informações.

  Gera `Plug.Conn.AlreadySentError` se `conn` já foi enviado.
  """
  # TODO: Remove | layout from the spec once we deprecate put_new_layout on controllers
  @spec put_new_layout(Plug.Conn.t(), [{format :: atom, layout}] | layout) :: Plug.Conn.t()
  def put_new_layout(%Plug.Conn{state: state} = conn, layout)
      when (is_tuple(layout) and tuple_size(layout) == 2) or is_list(layout) or layout == false do
    unless state in @unsent, do: raise(AlreadySentError)
    put_private_layout(conn, :phoenix_layout, :new, layout)
  end

  @doc """
  Armazena o layout raiz para renderização.

  O layout deve ser fornecido como uma lista de palavras-chave, onde a chave é o formato da requisição
  ao qual o layout será aplicado (como `:html`) e o valor é um dos seguintes:

    * `{module, layout}` com o `module` onde o layout é definido e
      o nome do `layout` como um átomo

    * `layout` quando o nome do layout. Isso requer um layout para
      o formato fornecido na forma de `{module, layout}` a ser previamente
      fornecido

    * `false` que desativa o layout

  ## Exemplos

      iex> root_layout(conn)
      false

      iex> conn = put_root_layout(conn, html: {AppView, :root})
      iex> root_layout(conn)
      {AppView, :root}

      iex> conn = put_root_layout(conn, html: :bare)
      iex> root_layout(conn)
      {AppView, :bare}

  Gera `Plug.Conn.AlreadySentError` se `conn` já foi enviado.
  """
  @spec put_root_layout(Plug.Conn.t(), [{format :: atom, layout}] | false) ::
          Plug.Conn.t()
  def put_root_layout(%Plug.Conn{state: state} = conn, layout) do
    if state in @unsent do
      put_private_layout(conn, :phoenix_root_layout, :replace, layout)
    else
      raise AlreadySentError
    end
  end

  @doc """
  Sets which formats have a layout when rendering.

  ## Examples

      iex> layout_formats(conn)
      ["html"]

      iex> put_layout_formats(conn, ["html", "mobile"])
      iex> layout_formats(conn)
      ["html", "mobile"]

  Raises `Plug.Conn.AlreadySentError` if `conn` is already sent.
  """
  @deprecated "put_layout_formats/2 is deprecated, pass a keyword list to put_layout/put_root_layout instead"
  @spec put_layout_formats(Plug.Conn.t(), [String.t()]) :: Plug.Conn.t()
  def put_layout_formats(%Plug.Conn{state: state} = conn, formats)
      when state in @unsent and is_list(formats) do
    put_private(conn, :phoenix_layout_formats, formats)
  end

  def put_layout_formats(%Plug.Conn{}, _formats), do: raise(AlreadySentError)

  @doc """
  Recupera os formatos de layout atuais.
  """
  @spec layout_formats(Plug.Conn.t()) :: [String.t()]
  @deprecated "layout_formats/1 está obsoleto, passe uma lista de palavras-chave para put_layout/put_root_layout em vez disso"
  def layout_formats(conn) do
    Map.get(conn.private, :phoenix_layout_formats, ~w(html))
  end

  @doc """
  Recupera o layout atual para o formato fornecido.

  Se nenhum formato for fornecido, pega o atual da conexão.
  """
  @spec layout(Plug.Conn.t(), binary | nil) :: {atom, String.t() | atom} | false
  def layout(conn, format \\ nil) do
    get_private_layout(conn, :phoenix_layout, format)
  end

  @doc """
  Recupera o layout raiz atual para o formato fornecido.

  Se nenhum formato for fornecido, pega o atual da conexão.
  """
  @spec root_layout(Plug.Conn.t(), binary | nil) :: {atom, String.t() | atom} | false
  def root_layout(conn, format \\ nil) do
    get_private_layout(conn, :phoenix_root_layout, format)
  end

  defp get_private_layout(conn, priv_key, format) do
    format = format || get_safe_format(conn)

    case conn.private[priv_key] do
      %{_: value} -> if format in [nil | layout_formats(conn)], do: value, else: false
      %{^format => value} -> value
      _ -> false
    end
  end

  @doc """
  Renderiza o template fornecido ou o template padrão
  especificado pela ação atual com os assigns fornecidos.

  Veja `render/3` para mais informações.
  """
  @spec render(Plug.Conn.t(), Keyword.t() | map | binary | atom) :: Plug.Conn.t()
  def render(conn, template_or_assigns \\ [])

  def render(conn, template) when is_binary(template) or is_atom(template) do
    render(conn, template, [])
  end

  def render(conn, assigns) do
      render(conn, action_name(conn), assigns)
  end

  @doc """
  Renderiza o `template` e `assigns` fornecidos com base nas informações da `conn`.

  Uma vez que o template é renderizado, o formato do template é definido como o tipo de conteúdo
  da resposta (por exemplo, um template HTML definirá "text/html" como tipo de conteúdo da resposta)
  e os dados são enviados ao cliente com o status padrão de 200.

  ## Argumentos

    * `conn` - a struct `Plug.Conn`

    * `template` - que pode ser um átomo ou uma string. Se um átomo, como `:index`,
      ele renderizará um template com o mesmo formato que o retornado por
      `get_format/1`. Por exemplo, para uma requisição HTML, ele renderizará
      o template "index.html". Se o template for uma string, ele deve conter
      a extensão também, como "index.json"

    * `assigns` - um dicionário com os assigns a serem usados na view. Esses
      assigns são mesclados e têm maior precedência do que os assigns da conexão
      (`conn.assigns`)

  ## Exemplos

      defmodule MyAppWeb.UserController do
        use Phoenix.Controller

        def show(conn, _params) do
          render(conn, "show.html", message: "Olá")
        end
      end

  O exemplo acima renderiza um template "show.html" da `MyAppWeb.UserView`
  e define o tipo de conteúdo da resposta como "text/html".

  Em muitos casos, você pode querer que o formato do template seja definido dinamicamente com base
  na requisição. Para fazer isso, você pode passar o nome do template como um átomo (sem
  a extensão):

      def show(conn, _params) do
        render(conn, :show, message: "Olá")
      end

  Para que o exemplo acima funcione, precisamos fazer a negociação de conteúdo com
  o plug accepts antes de renderizar. Você pode fazer isso adicionando o seguinte ao seu
  pipeline (no roteador):

      plug :accepts, ["html"]

  ## Views

  Por padrão, os Controladores renderizam templates em uma view com um nome semelhante ao
  controlador. Por exemplo, `MyAppWeb.UserController` renderizará templates dentro
  da `MyAppWeb.UserView`. Essa informação pode ser alterada a qualquer momento usando a
  função `put_view/2`:

      def show(conn, _params) do
        conn
        |> put_view(MyAppWeb.SpecialView)
        |> render(:show, message: "Olá")
      end

  `put_view/2` também pode ser usado como um plug:

      defmodule MyAppWeb.UserController do
        use Phoenix.Controller

        plug :put_view, html: MyAppWeb.SpecialView

        def show(conn, _params) do
          render(conn, :show, message: "Olá")
        end
      end

  ## Layouts

  Os templates são frequentemente renderizados dentro de layouts. Por padrão, o Phoenix
  renderizará layouts para requisições html. Por exemplo:

      defmodule MyAppWeb.UserController do
        use Phoenix.Controller

        def show(conn, _params) do
          render(conn, "show.html", message: "Olá")
        end
      end

  irá renderizar o template "show.html" dentro de um template "app.html"
  especificado em `MyAppWeb.LayoutView`. `put_layout/2` pode ser usado
  para alterar o layout, semelhante a como `put_view/2` pode ser usado para alterar
  a view.
  """
  @spec render(Plug.Conn.t(), binary | atom, Keyword.t() | map) :: Plug.Conn.t()
  def render(conn, template, assigns)
      when is_atom(template) and (is_map(assigns) or is_list(assigns)) do
    format =
      get_format(conn) ||
        raise "cannot render template #{inspect(template)} because conn.params[\"_format\"] is not set. " <>
                "Please set `plug :accepts, ~w(html json ...)` in your pipeline."

    render_and_send(conn, format, Atom.to_string(template), assigns)
  end

  def render(conn, template, assigns)
      when is_binary(template) and (is_map(assigns) or is_list(assigns)) do
    {base, format} = split_template(template)
    conn |> put_format(format) |> render_and_send(format, base, assigns)
  end

  def render(conn, view, template)
      when is_atom(view) and (is_binary(template) or is_atom(template)) do
    IO.warn(
      "#{__MODULE__}.render/3 with a view is deprecated, see the documentation for render/3 for an alternative"
    )

    render(conn, view, template, [])
  end

  @doc false
  @deprecated "render/4 is deprecated. Use put_view + render/3"
  def render(conn, view, template, assigns)
      when is_atom(view) and (is_binary(template) or is_atom(template)) do
    conn
    |> put_view(view)
    |> render(template, assigns)
  end

  defp render_and_send(conn, format, template, assigns) do
    view = view_module(conn, format)
    conn = prepare_assigns(conn, assigns, template, format)
    data = render_with_layouts(conn, view, template, format)

    conn
    |> ensure_resp_content_type(MIME.type(format))
    |> send_resp(conn.status || 200, data)
  end

  defp render_with_layouts(conn, view, template, format) do
    render_assigns = Map.put(conn.assigns, :conn, conn)

    case root_layout(conn, format) do
      {layout_mod, layout_tpl} ->
        {layout_base, _} = split_template(layout_tpl)
        inner = template_render(view, template, format, render_assigns)
        root_assigns = render_assigns |> Map.put(:inner_content, inner) |> Map.delete(:layout)
        template_render_to_iodata(layout_mod, layout_base, format, root_assigns)

      false ->
        template_render_to_iodata(view, template, format, render_assigns)
    end
  end

  defp template_render(view, template, format, assigns) do
    metadata = %{view: view, template: template, format: format}

    :telemetry.span([:phoenix, :controller, :render], metadata, fn ->
      {Phoenix.Template.render(view, template, format, assigns), metadata}
    end)
  end

  defp template_render_to_iodata(view, template, format, assigns) do
    metadata = %{view: view, template: template, format: format}

    :telemetry.span([:phoenix, :controller, :render], metadata, fn ->
      {Phoenix.Template.render_to_iodata(view, template, format, assigns), metadata}
    end)
  end

  defp prepare_assigns(conn, assigns, template, format) do
    assigns = to_map(assigns)

    layout =
      case assigns_layout(conn, assigns, format) do
        {mod, layout} when is_binary(layout) -> {mod, Path.rootname(layout)}
        {mod, layout} when is_atom(layout) -> {mod, Atom.to_string(layout)}
        false -> false
      end

    conn
    |> put_private(:phoenix_template, template <> "." <> format)
    |> Map.update!(:assigns, fn prev ->
      prev
      |> Map.merge(assigns)
      |> Map.put(:layout, layout)
    end)
  end

  defp assigns_layout(_conn, %{layout: layout}, _format), do: layout

  defp assigns_layout(conn, _assigns, format) do
    case conn.private[:phoenix_layout] do
      %{^format => bad_value, _: good_value} when good_value != false ->
        IO.warn("""
        conflicting layouts found. A layout has been set with format, such as:

            put_layout(conn, #{format}: #{inspect(bad_value)})

        But also without format:

            put_layout(conn, #{inspect(good_value)})

        In this case, the layout without format will always win.
        Passing the layout without a format is currently soft-deprecated.
        If you use layouts with formats, make sure that they are
        used everywhere. Also remember to configure your controller
        to use layouts with formats:

            use Phoenix.Controller, layouts: [#{format}: #{inspect(bad_value)}]
        """)

        if format in layout_formats(conn), do: good_value, else: false

      %{_: value} ->
        if format in layout_formats(conn), do: value, else: false

      %{^format => value} ->
        value

      _ ->
        false
    end
  end

  defp to_map(assigns) when is_map(assigns), do: assigns
  defp to_map(assigns) when is_list(assigns), do: :maps.from_list(assigns)

  defp split_template(name) when is_atom(name), do: {Atom.to_string(name), nil}

  defp split_template(name) when is_binary(name) do
    case :binary.split(name, ".") do
      [base, format] ->
        {base, format}

      [^name] ->
        raise "cannot render template #{inspect(name)} without format. Use an atom if the " <>
                "template format is meant to be set dynamically based on the request format"

      [base | formats] ->
        {base, List.last(formats)}
    end
  end

  defp send_resp(conn, default_status, default_content_type, body) do
    conn
    |> ensure_resp_content_type(default_content_type)
    |> send_resp(conn.status || default_status, body)
  end

  defp ensure_resp_content_type(%Plug.Conn{resp_headers: resp_headers} = conn, content_type) do
    if List.keyfind(resp_headers, "content-type", 0) do
      conn
    else
      content_type = content_type <> "; charset=utf-8"
      %Plug.Conn{conn | resp_headers: [{"content-type", content_type} | resp_headers]}
    end
  end

  @doc """
  Coloca a string de URL ou `%URI{}` a ser usada para geração de rotas.

  Esta função substitui a geração de URL padrão obtida
  da configuração do endpoint da `%Plug.Conn{}`.

  ## Exemplos

  Imagine que sua aplicação está configurada para rodar em "example.com"
  mas, após o usuário fazer login, você quer que todos os links usem
  "some_user.example.com". Você pode fazer isso configurando a URL
  do roteador apropriada:

      def put_router_url_by_user(conn) do
        put_router_url(conn, get_user_from_conn(conn).account_name <> ".example.com")
      end

  Agora, quando você chamar `Routes.some_route_url(conn, ...)`, ele usará
  a URL do roteador definida acima. Tenha em mente que, se você quiser gerar
  rotas para o domínio *atual*, é preferível usar os helpers
  `Routes.some_route_path`, pois estes são sempre relativos.
  """
  def put_router_url(conn, %URI{} = uri) do
    put_private(conn, :phoenix_router_url, URI.to_string(uri))
  end

  def put_router_url(conn, url) when is_binary(url) do
    put_private(conn, :phoenix_router_url, url)
  end

  @doc """
  Coloca a URL ou `%URI{}` a ser usada para a geração de URL estática.

  Usar esta função em uma struct `%Plug.Conn{}` instrui `static_url/2` a usar
  as informações fornecidas para geração de URL em vez da configuração do endpoint
  da `%Plug.Conn{}` (muito parecido com `put_router_url/2`, mas para URLs estáticas).
  """
  def put_static_url(conn, %URI{} = uri) do
    put_private(conn, :phoenix_static_url, URI.to_string(uri))
  end

  def put_static_url(conn, url) when is_binary(url) do
    put_private(conn, :phoenix_static_url, url)
  end

  @doc """
  Coloca o formato na conexão.

  Este formato é usado ao renderizar um template como um átomo.
  Por exemplo, `render(conn, :foo)` renderizará `"foo.FORMAT"`,
  onde o formato é o definido aqui. O formato padrão
  é tipicamente definido a partir da negociação feita em `accepts/2`.

  Veja `get_format/1` para recuperação.
  """
  def put_format(conn, format), do: put_private(conn, :phoenix_format, to_string(format))

  @doc """
  Retorna o formato da requisição, como "json", "html".

  Este formato é usado ao renderizar um template como um átomo.
  Por exemplo, `render(conn, :foo)` renderizará `"foo.FORMAT"`,
  onde o formato é o definido aqui. O formato padrão
  é tipicamente definido a partir da negociação feita em `accepts/2`.
  """
  def get_format(conn) do
    conn.private[:phoenix_format] || conn.params["_format"]
  end

  defp get_safe_format(conn) do
    conn.private[:phoenix_format] ||
      case conn.params do
        %{"_format" => format} -> format
        %{} -> nil
      end
  end

  @doc """
  Envia o arquivo ou binário fornecido como um download.

  O segundo argumento deve ser `{:binary, contents}`, onde
  `contents` será enviado como download, ou `{:file, path}`,
  onde `path` é a localização do arquivo no sistema de arquivos a ser
  enviado. Tenha cuidado para não interpolar o caminho de
  parâmetros externos, pois isso pode permitir a travessia do
  sistema de arquivos.

  O download é obtido definindo "content-disposition"
  como attachment. O "content-type" também será definido com base
  na extensão do nome do arquivo fornecido, mas pode ser personalizado
  através das opções `:content_type` e `:charset`.

  ## Opções

    * `:filename` - o nome do arquivo a ser apresentado ao usuário
      como download
    * `:content_type` - o tipo de conteúdo do arquivo ou binário
      enviado como download. É inferido automaticamente da
      extensão do nome do arquivo
    * `:disposition` - especifica o tipo de disposição
      (`:attachment` ou `:inline`). Se `:attachment` foi usado,
      o usuário será solicitado a salvar o arquivo. Se `:inline` foi usado,
      o navegador tentará abrir o arquivo.
      O padrão é `:attachment`.
    * `:charset` - o conjunto de caracteres do arquivo, como "utf-8".
      O padrão é nenhum
    * `:offset` - os bytes a serem deslocados ao ler. O padrão é `0`
    * `:length` - o total de bytes a serem lidos. O padrão é `:all`
    * `:encode` - codifica o nome do arquivo usando `URI.encode/2`.
      O padrão é `true`. Quando `false`, a codificação é desativada. Se você
      desativar a codificação, você precisa garantir que não haja caracteres especiais
      no nome do arquivo, como aspas, novas linhas, etc.
      Caso contrário, você pode expor sua aplicação a ataques de segurança

  ## Exemplos

  Para enviar um arquivo que está armazenado dentro do diretório priv
  da sua aplicação:

      path = Application.app_dir(:my_app, "priv/prospectus.pdf")
      send_download(conn, {:file, path})

  Ao usar `{:file, path}`, o nome do arquivo é inferido do
  caminho fornecido, mas também pode ser definido explicitamente.

  Para permitir que o usuário baixe conteúdos que estão na memória como
  um binário ou string:

      send_download(conn, {:binary, "mundo"}, filename: "hello.txt")

  Veja `Plug.Conn.send_file/3` e `Plug.Conn.send_resp/3` se você
  quiser acessar as funções de baixo nível usadas para enviar arquivos
  e respostas via Plug.
  """
  def send_download(conn, kind, opts \\ [])

  def send_download(conn, {:file, path}, opts) do
    filename = opts[:filename] || Path.basename(path)
    offset = opts[:offset] || 0
    length = opts[:length] || :all

    conn
    |> prepare_send_download(filename, opts)
    |> send_file(conn.status || 200, path, offset, length)
  end

  def send_download(conn, {:binary, contents}, opts) do
    filename =
      opts[:filename] || raise ":filename option is required when sending binary download"

    conn
    |> prepare_send_download(filename, opts)
    |> send_resp(conn.status || 200, contents)
  end

  defp prepare_send_download(conn, filename, opts) do
    content_type = opts[:content_type] || MIME.from_path(filename)
    encoded_filename = encode_filename(filename, Keyword.get(opts, :encode, true))
    disposition_type = get_disposition_type(Keyword.get(opts, :disposition, :attachment))
    warn_if_ajax(conn)

    disposition = ~s[#{disposition_type}; filename="#{encoded_filename}"]

    disposition =
      if encoded_filename != filename do
        disposition <> "; filename*=utf-8''#{encoded_filename}"
      else
        disposition
      end

    conn
    |> put_resp_content_type(content_type, opts[:charset])
    |> put_resp_header("content-disposition", disposition)
  end

  defp encode_filename(filename, false), do: filename
  defp encode_filename(filename, true), do: URI.encode(filename)

  defp get_disposition_type(:attachment), do: "attachment"
  defp get_disposition_type(:inline), do: "inline"

  defp get_disposition_type(other),
    do:
      raise(
        ArgumentError,
        "expected :disposition to be :attachment or :inline, got: #{inspect(other)}"
      )

  defp ajax?(conn) do
    case get_req_header(conn, "x-requested-with") do
      [value] -> value in ["XMLHttpRequest", "xmlhttprequest"]
      [] -> false
    end
  end

  defp warn_if_ajax(conn) do
    if ajax?(conn) do
      Logger.warning(
        "send_download/3 has been invoked during an AJAX request. " <>
          "The download may not work as expected under XMLHttpRequest"
      )
    end
  end

  @doc """
  Limpa os parâmetros da requisição.

  Este processo tem duas partes:

    * Verifica se a `required_key` está presente
    * Altera parâmetros vazios de `required_key` (recursivamente) para nils

  Esta função é útil para remover strings vazias enviadas
  via formulários HTML. Se você estiver fornecendo uma API,
  provavelmente não há necessidade de invocar `scrub_params/2`.

  Se a `required_key` não estiver presente, ela irá
  gerar `Phoenix.MissingParamError`.

  ## Exemplos

      iex> scrub_params(conn, "user")

  """
  @spec scrub_params(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def scrub_params(conn, required_key) when is_binary(required_key) do
    param = Map.get(conn.params, required_key) |> scrub_param()

    unless param do
      raise Phoenix.MissingParamError, key: required_key
    end

    params = Map.put(conn.params, required_key, param)
    %Plug.Conn{conn | params: params}
  end

  defp scrub_param(%{__struct__: mod} = struct) when is_atom(mod) do
    struct
  end

  defp scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      Map.put(acc, k, scrub_param(v))
    end)
  end

  defp scrub_param(param) when is_list(param) do
    Enum.map(param, &scrub_param/1)
  end

  defp scrub_param(param) do
    if scrub?(param), do: nil, else: param
  end

  defp scrub?(" " <> rest), do: scrub?(rest)
  defp scrub?(""), do: true
  defp scrub?(_), do: false

  @doc """
  Habilita a proteção CSRF.

  Atualmente usado como uma função wrapper para `Plug.CSRFProtection`
  e serve principalmente como um plug de função em `YourApp.Router`.

  Verifique `get_csrf_token/0` e `delete_csrf_token/0` para
  recuperar e deletar tokens CSRF.
  """
  def protect_from_forgery(conn, opts \\ []) do
    Plug.CSRFProtection.call(conn, Plug.CSRFProtection.init(opts))
  end

  @doc """
  Coloca cabeçalhos que melhoram a segurança do navegador.

  Define os seguintes cabeçalhos:

    * `referrer-policy` - envia apenas a origem em requisições de origem cruzada
    * `x-frame-options` - definido como SAMEORIGIN para evitar clickjacking
      através de iframes, a menos que na mesma origem
    * `x-content-type-options` - definido como nosniff. Isso requer
      que as tags de script e estilo sejam enviadas com o tipo de conteúdo apropriado
    * `x-download-options` - definido como noopen para instruir o navegador
      a não abrir um download diretamente no navegador, para evitar
      que arquivos HTML sejam renderizados embutidos e acessem o contexto
      de segurança da aplicação (como cookies de domínio críticos)
    * `x-permitted-cross-domain-policies` - definido como none para restringir
      o acesso do Adobe Flash Player aos dados

  Um mapa de cabeçalhos personalizados também pode ser fornecido para ser mesclado com os padrões.
  Recomenda-se que as chaves de cabeçalho personalizadas estejam em minúsculas, para evitar o envio
  de chaves duplicadas em uma requisição.
  Além disso, respostas com cabeçalhos de caso misto servidas via HTTP/2 não são
  consideradas válidas por clientes comuns, resultando em respostas descartadas.
  """
  def put_secure_browser_headers(conn, headers \\ %{})

  def put_secure_browser_headers(conn, []) do
    put_secure_defaults(conn)
  end

  def put_secure_browser_headers(conn, headers) when is_map(headers) do
    conn
    |> put_secure_defaults()
    |> merge_resp_headers(headers)
  end

  defp put_secure_defaults(conn) do
    merge_resp_headers(conn, [
      # Abaixo está o padrão de novembro de 2020, mas ainda não está no Safari em janeiro de 2022.
      # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy
      {"referrer-policy", "strict-origin-when-cross-origin"},
      {"x-content-type-options", "nosniff"},
      # Aplica-se apenas ao Internet Explorer, pode ser removido com segurança no futuro.
      {"x-download-options", "noopen"},
      {"x-frame-options", "SAMEORIGIN"},
      {"x-permitted-cross-domain-policies", "none"}
    ])
  end

  @doc """
  Obtém ou gera um token CSRF.

  Se um token existir, ele é retornado, caso contrário, é gerado e armazenado
  no dicionário de processos.
  """
  defdelegate get_csrf_token(), to: Plug.CSRFProtection

  @doc """
  Deleta o token CSRF do dicionário de processos.

  *Nota*: O token é deletado apenas após uma resposta ser enviada.
  """
  defdelegate delete_csrf_token(), to: Plug.CSRFProtection

  @doc """
  Realiza a negociação de conteúdo com base nos formatos disponíveis.

  Recebe uma conexão, uma lista de formatos que o servidor
  é capaz de renderizar e, em seguida, prossegue para realizar a negociação de conteúdo
  com base nas informações da requisição. Se o cliente aceitar algum dos formatos
  fornecidos, a requisição prossegue.

  Se a requisição contiver um parâmetro "_format", ele é considerado
  o formato desejado pelo cliente. Se nenhum parâmetro "_format" estiver disponível,
  esta função analisará o cabeçalho "accept" e encontrará um formato correspondente.

  Esta função é útil quando você deseja servir diferentes
  tipos de conteúdo (como JSON e HTML) das mesmas rotas.
  No entanto, se você sempre tiver rotas distintas, também poderá
  desativar a negociação de conteúdo e simplesmente codificar seu formato
  de escolha em seus pipelines de rota:

      plug :put_format, "html"

  É importante notar que os navegadores historicamente
  enviaram cabeçalhos accept ruins. Por esta razão, esta função usará
  o formato "html" como padrão sempre que:

    * a lista de argumentos aceitos contém o formato "html"

    * o cabeçalho accept especificou mais de um tipo de mídia precedido
      ou seguido pelo tipo de mídia curinga "`*/*`"

  Esta função gera `Phoenix.NotAcceptableError`, que é renderizado
  com o status 406, sempre que o servidor não pode servir uma resposta em nenhum
  dos formatos esperados pelo cliente.

  ## Exemplos

  `accepts/2` pode ser invocado como uma função:

      iex> accepts(conn, ["html", "json"])

  ou usado como um plug:

      plug :accepts, ["html", "json"]
      plug :accepts, ~w(html json)

  ## Tipos de mídia personalizados

  É possível adicionar tipos de mídia personalizados à sua aplicação Phoenix.
  O primeiro passo é ensinar o Plug sobre esses novos tipos de mídia em
  seu arquivo `config/config.exs`:

      config :mime, :types, %{
        "application/vnd.api+json" => ["json-api"]
      }

  A chave é o tipo de mídia, o valor é uma lista de formatos com os quais o
  tipo de mídia pode ser identificado. Por exemplo, ao usar
  "json-api", você poderá usar templates com a extensão
  "index.json-api" ou forçar um formato específico em uma determinada
  URL enviando "?_format=json-api".

  Após esta alteração, você deve recompilar o plug:

      $ mix deps.clean mime --build
      $ mix deps.get

  E agora você pode usá-lo em accepts também:

      plug :accepts, ["html", "json-api"]

  """
  @spec accepts(Plug.Conn.t(), [binary]) :: Plug.Conn.t()
  def accepts(conn, [_ | _] = accepted) do
    case conn.params do
      %{"_format" => format} ->
        handle_params_accept(conn, format, accepted)

      %{} ->
        handle_header_accept(conn, get_req_header(conn, "accept"), accepted)
    end
  end

  defp handle_params_accept(conn, format, accepted) do
    if format in accepted do
      put_format(conn, format)
    else
      raise Phoenix.NotAcceptableError,
        message: "unknown format #{inspect(format)}, expected one of #{inspect(accepted)}",
        accepts: accepted
    end
  end

  # In case there is no accept header or the header is */*
  # we use the first format specified in the accepts list.
  defp handle_header_accept(conn, header, [first | _]) when header == [] or header == ["*/*"] do
    put_format(conn, first)
  end

  # In case there is a header, we need to parse it.
  # But before we check for */* because if one exists and we serve html,
  # we unfortunately need to assume it is a browser sending us a request.
  defp handle_header_accept(conn, [header | _], accepted) do
    if header =~ "*/*" and "html" in accepted do
      put_format(conn, "html")
    else
      parse_header_accept(conn, String.split(header, ","), [], accepted)
    end
  end

  defp parse_header_accept(conn, [h | t], acc, accepted) do
    case Plug.Conn.Utils.media_type(h) do
      {:ok, type, subtype, args} ->
        exts = parse_exts(type, subtype)
        q = parse_q(args)

        if format = q === 1.0 && find_format(exts, accepted) do
          put_format(conn, format)
        else
          parse_header_accept(conn, t, [{-q, h, exts} | acc], accepted)
        end

      :error ->
        parse_header_accept(conn, t, acc, accepted)
    end
  end

  defp parse_header_accept(conn, [], acc, accepted) do
    acc
    |> Enum.sort()
    |> Enum.find_value(&parse_header_accept(conn, &1, accepted))
    |> Kernel.||(refuse(conn, acc, accepted))
  end

  defp parse_header_accept(conn, {_, _, exts}, accepted) do
    if format = find_format(exts, accepted) do
      put_format(conn, format)
    end
  end

  defp parse_q(args) do
    case Map.fetch(args, "q") do
      {:ok, float} ->
        case Float.parse(float) do
          {float, _} -> float
          :error -> 1.0
        end

      :error ->
        1.0
    end
  end

  defp parse_exts("*", "*"), do: "*/*"
  defp parse_exts(type, "*"), do: type
  defp parse_exts(type, subtype), do: MIME.extensions(type <> "/" <> subtype)

  defp find_format("*/*", accepted), do: Enum.fetch!(accepted, 0)
  defp find_format(exts, accepted) when is_list(exts), do: Enum.find(exts, &(&1 in accepted))
  defp find_format(_type_range, []), do: nil

  defp find_format(type_range, [h | t]) do
    mime_type = MIME.type(h)

    case Plug.Conn.Utils.media_type(mime_type) do
      {:ok, accepted_type, _subtype, _args} when type_range === accepted_type -> h
      _ -> find_format(type_range, t)
    end
  end

  @spec refuse(term(), [tuple], [binary]) :: no_return()
  defp refuse(_conn, given, accepted) do
    raise Phoenix.NotAcceptableError,
      accepts: accepted,
      message: """
      no supported media type in accept header.

      Expected one of #{inspect(accepted)} but got the following formats:

        * #{Enum.map_join(given, "\n  ", fn {_, header, exts} -> inspect(header) <> " with extensions: " <> inspect(exts) end)}

      To accept custom formats, register them under the :mime library
      in your config/config.exs file:

          config :mime, :types, %{
            "application/xml" => ["xml"]
          }

      And then run `mix deps.clean --build mime` to force it to be recompiled.
      """
  end

  @doc """
  Recupera o armazenamento flash.
  """
  def fetch_flash(conn, _opts \\ []) do
    if Map.get(conn.assigns, :flash) do
      conn
    else
      session_flash = get_session(conn, "phoenix_flash")
      conn = persist_flash(conn, session_flash || %{})

      register_before_send(conn, fn conn ->
        flash = conn.assigns.flash
        flash_size = map_size(flash)

        cond do
          is_nil(session_flash) and flash_size == 0 ->
            conn

          flash_size > 0 and conn.status in 300..308 ->
            put_session(conn, "phoenix_flash", flash)

          true ->
            delete_session(conn, "phoenix_flash")
        end
      end)
    end
  end

  @doc """
  Mescla um mapa no flash.

  Retorna a conexão atualizada.

  ## Exemplos

      iex> conn = merge_flash(conn, info: "Bem-vindo de volta!")
      iex> Phoenix.Flash.get(conn.assigns.flash, :info)
      "Bem-vindo de volta!"

  """
  def merge_flash(conn, enumerable) do
    map = for {k, v} <- enumerable, into: %{}, do: {flash_key(k), v}
    persist_flash(conn, Map.merge(Map.get(conn.assigns, :flash, %{}), map))
  end

  @doc """
  Persiste um valor no flash.

  Retorna a conexão atualizada.

  ## Exemplos

      iex> conn = put_flash(conn, :info, "Bem-vindo de volta!")
      iex> Phoenix.Flash.get(conn.assigns.flash, :info)
      "Bem-vindo de volta!"

  """
  def put_flash(conn, key, message) do
    flash =
      Map.get(conn.assigns, :flash) ||
        raise ArgumentError, message: "flash não buscado, chame fetch_flash/2"

    persist_flash(conn, Map.put(flash, flash_key(key), message))
  end

  @doc """
  Retorna um mapa de mensagens flash previamente definidas ou um mapa vazio.

  ## Exemplos

      iex> get_flash(conn)
      %{}

      iex> conn = put_flash(conn, :info, "Bem-vindo de volta!")
      iex> get_flash(conn)
      %{"info" => "Bem-vindo de volta!"}

  """
  @deprecated "get_flash/1 está obsoleto. Use o assign @flash fornecido pelo plug :fetch_flash"
  def get_flash(conn) do
    Map.get(conn.assigns, :flash) ||
      raise ArgumentError, message: "flash não buscado, chame fetch_flash/2"
  end

  @doc """
  Retorna uma mensagem do flash por `key` (ou `nil` se nenhuma mensagem estiver disponível para `key`).

  ## Exemplos

      iex> conn = put_flash(conn, :info, "Bem-vindo de volta!")
      iex> get_flash(conn, :info)
      "Bem-vindo de volta!"

  """
  @deprecated "get_flash/2 está obsoleto. Use Phoenix.Flash.get(@flash, key) em vez disso"
  def get_flash(conn, key) do
    get_flash(conn)[flash_key(key)]
  end

  @doc """
  Gera uma mensagem de status a partir do nome do template.

  ## Exemplos

      iex> status_message_from_template("404.html")
      "Não encontrado"
      iex> status_message_from_template("qualquercoisa.html")
      "Erro interno do servidor"

  """
  def status_message_from_template(template) do
    template
    |> String.split(".")
    |> hd()
    |> String.to_integer()
    |> Plug.Conn.Status.reason_phrase()
  rescue
    _ -> "Erro interno do servidor"
  end

  @doc """
  Limpa todas as mensagens flash.
  """
  def clear_flash(conn) do
    persist_flash(conn, %{})
  end

  defp flash_key(binary) when is_binary(binary), do: binary
  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp persist_flash(conn, value) do
    assign(conn, :flash, value)
  end

  @doc """
  Retorna o caminho da requisição atual com seus parâmetros de consulta padrão:

      iex> current_path(conn)
      "/users/123?existing=param"

  Veja `current_path/2` para substituir os parâmetros padrão.

  O caminho é normalizado com base em `conn.script_name` e
  `conn.path_info`. Por exemplo, "/foo//bar/" se tornará "/foo/bar".
  Se você quiser o caminho original, use `conn.request_path` em vez disso.
  """
  def current_path(%Plug.Conn{query_string: ""} = conn) do
    normalized_request_path(conn)
  end

  def current_path(%Plug.Conn{query_string: query_string} = conn) do
    normalized_request_path(conn) <> "?" <> query_string
  end

  @doc """
  Retorna o caminho atual com os parâmetros de consulta fornecidos.

  Você também pode recuperar apenas o caminho da requisição passando um
  mapa vazio de parâmetros.

  ## Exemplos

      iex> current_path(conn)
      "/users/123?existing=param"

      iex> current_path(conn, %{new: "param"})
      "/users/123?new=param"

      iex> current_path(conn, %{filter: %{status: ["draft", "published"]}})
      "/users/123?filter[status][]=draft&filter[status][]=published"

      iex> current_path(conn, %{})
      "/users/123"

  O caminho é normalizado com base em `conn.script_name` e
  `conn.path_info`. Por exemplo, "/foo//bar/" se tornará "/foo/bar".
  Se você quiser o caminho original, use `conn.request_path` em vez disso.
  """
  def current_path(%Plug.Conn{} = conn, params) when params == %{} do
    normalized_request_path(conn)
  end

  def current_path(%Plug.Conn{} = conn, params) do
    normalized_request_path(conn) <> "?" <> Plug.Conn.Query.encode(params)
  end

  defp normalized_request_path(%{path_info: info, script_name: script}) do
    "/" <> Enum.join(script ++ info, "/")
  end

  @doc """
  Retorna a URL da requisição atual com seus parâmetros de consulta padrão:

      iex> current_url(conn)
      "https://www.example.com/users/123?existing=param"

  Veja `current_url/2` para substituir os parâmetros padrão.
  """
  def current_url(%Plug.Conn{} = conn) do
    Phoenix.VerifiedRoutes.unverified_url(conn, current_path(conn))
  end

  @doc ~S"""
  Retorna a URL da requisição atual com parâmetros de consulta.

  O caminho será recuperado do caminho solicitado atualmente via
  `current_path/1`. O esquema, host e outros serão recebidos da
  configuração de URL em seu endpoint Phoenix. A razão pela qual não usamos
  as informações de host e esquema na requisição é porque a maioria
  das aplicações estão atrás de proxies e o host e o esquema podem não
  refletir realmente o host e o esquema acessados pelo cliente. Se você
  quiser acessar a URL precisamente como solicitado pelo cliente, veja
  `Plug.Conn.request_url/1`.

  ## Exemplos

      iex> current_url(conn)
      "https://www.example.com/users/123?existing=param"

      iex> current_url(conn, %{new: "param"})
      "https://www.example.com/users/123?new=param"

      iex> current_url(conn, %{})
      "https://www.example.com/users/123"

  ## Geração de URL personalizada

  Em alguns casos, você precisará gerar a URL de uma requisição, mas usando um
  esquema diferente, host diferente, etc. Isso pode ser feito de duas maneiras.

  Se você quiser fazer isso caso a caso, pode definir uma função personalizada
  que obtém a configuração URI do endpoint e a altera de acordo.
  Por exemplo, para obter a URL atual sempre no formato HTTPS:

      def current_secure_url(conn, params \\ %{}) do
        current_uri = MyAppWeb.Endpoint.struct_url()
        current_path = Phoenix.Controller.current_path(conn, params)
        Phoenix.VerifiedRoutes.unverified_url(%URI{current_uri | scheme: "https"}, current_path)
      end

  No entanto, se você quiser que todas as URLs geradas sempre tenham um determinado esquema,
  host, etc, você pode usar `put_router_url/2`.
  """
  def current_url(%Plug.Conn{} = conn, %{} = params) do
    Phoenix.VerifiedRoutes.unverified_url(conn, current_path(conn, params))
  end

  @doc false
  def __view__(controller_module, opts) do
    view_base = Phoenix.Naming.unsuffix(controller_module, "Controller")

    case Keyword.fetch(opts, :formats) do
      {:ok, formats} when is_list(formats) ->
        for format <- formats do
          case format do
            format when is_atom(format) ->
              {format, :"#{view_base}#{String.upcase(to_string(format))}"}

            {format, suffix} ->
              {format, :"#{view_base}#{suffix}"}
          end
        end

      :error ->
        :"#{view_base}View"
    end
  end

  @doc false
  def __layout__(controller_module, opts) do
    case Keyword.fetch(opts, :layouts) do
      {:ok, formats} when is_list(formats) ->
        Enum.map(formats, fn
          {format, mod} when is_atom(mod) ->
            {format, {mod, :app}}

          {format, {mod, template}} when is_atom(mod) and is_atom(template) ->
            {format, {mod, template}}

          other ->
            raise ArgumentError, """
            expected :layouts to be a list of format module pairs of the form: [html: DemoWeb.Layouts] or [html: {DemoWeb.Layouts, :app}]

            Got: #{inspect(other)}
            """
        end)

      :error ->
        # TODO: Deprecate :namespace option in favor of :layouts
        namespace =
          if given = Keyword.get(opts, :namespace) do
            given
          else
            controller_module
            |> Atom.to_string()
            |> String.split(".")
            |> Enum.drop(-1)
            |> Enum.take(2)
            |> Module.concat()
          end

        {Module.concat(namespace, "LayoutView"), :app}
    end
  end
end
