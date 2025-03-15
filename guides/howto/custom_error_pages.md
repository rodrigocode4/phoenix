# Páginas de Erro Personalizadas

Novos projetos Phoenix têm duas views de erro chamadas `ErrorHTML` e `ErrorJSON`, que ficam em `lib/hello_web/controllers/`. O objetivo dessas views é lidar com erros de forma geral para cada formato, a partir de um local centralizado.

## As Views de Erro

Para novas aplicações, as views `ErrorHTML` e `ErrorJSON` são assim:

```elixir
defmodule HelloWeb.ErrorHTML do
  use HelloWeb, :html

  # Se você deseja personalizar suas páginas de erro,
  # descomente a chamada embed_templates/1 abaixo
  # e adicione páginas ao diretório de erro:
  #
  #   * lib/<%= @lib_web_name %>/controllers/error_html/404.html.heex
  #   * lib/<%= @lib_web_name %>/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # O padrão é renderizar uma página de texto simples baseada
  # no nome do template. Por exemplo, "404.html" se torna
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule HelloWeb.ErrorJSON do
  # Se você quiser personalizar um código de status específico,
  # você pode adicionar suas próprias cláusulas, como:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # Por padrão, Phoenix retorna a mensagem de status do
  # nome do template. Por exemplo, "404.json" se torna
  # "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
```

Antes de mergulharmos nisso, vamos ver como aparece a mensagem `404 Not Found` renderizada em um navegador. No ambiente de desenvolvimento, o Phoenix depurará erros por padrão, mostrando uma página de depuração muito informativa. O que queremos aqui, no entanto, é ver qual página a aplicação serviria em produção. Para fazer isso, precisamos definir `debug_errors: false` em `config/dev.exs`.

```elixir
import Config

config :hello, HelloWeb.Endpoint,
  http: [port: 4000],
  debug_errors: false,
  code_reloader: true,
  . . .
```

Depois de modificar nosso arquivo de configuração, precisamos reiniciar nosso servidor para que essa alteração entre em vigor. Após reiniciar o servidor, vamos para [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path) para uma aplicação local em execução e ver o que obtemos.

Ok, isso não é muito empolgante. Obtemos a string simples "Not Found", exibida sem qualquer marcação ou estilo.

A primeira pergunta é: de onde vem essa string de erro? A resposta está bem no `ErrorHTML`.

```elixir
def render(template, _assigns) do
  Phoenix.Controller.status_message_from_template(template)
end
```

Ótimo, então temos essa função `render/2` que recebe um template e um mapa `assigns`, que ignoramos. Quando você chama `render(conn, :some_template)` do controller, o Phoenix primeiro procura uma função `some_template/1` no módulo da view. Se não existir nenhuma função, ele recorre à chamada de `render/2` com o nome do template e formato, como `"some_template.html"`.

Em outras palavras, para fornecer páginas de erro personalizadas, poderíamos simplesmente definir uma cláusula de função `render/2` adequada em `HelloWeb.ErrorHTML`.

```elixir
  def render("404.html", _assigns) do
    "Página Não Encontrada"
  end
```

Mas podemos fazer ainda melhor.

Phoenix gera um `ErrorHTML` para nós, mas não nos dá um diretório `lib/hello_web/controllers/error_html`. Vamos criar um agora. Dentro do nosso novo diretório, vamos adicionar um template chamado `404.html.heex` e dar-lhe alguma marcação – uma mistura do layout da nossa aplicação e uma nova `<div>` com nossa mensagem para o usuário.

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Bem-vindo ao Phoenix!</title>
    <link rel="stylesheet" href="/assets/app.css"/>
    <script defer type="text/javascript" src="/assets/app.js"></script>
  </head>
  <body>
    <header>
      <section class="container">
        <nav>
          <ul>
            <li><a href="https://hexdocs.pm/phoenix/overview.html">Comece Aqui</a></li>
          </ul>
        </nav>
        <a href="https://phoenixframework.org/" class="phx-logo">
          <img src="/images/logo.svg" alt="Logo do Phoenix Framework"/>
        </a>
      </section>
    </header>
    <main class="container">
      <section class="phx-hero">
        <p>Desculpe, a página que você está procurando não existe.</p>
      </section>
    </main>
  </body>
</html>
```

Depois de definir o arquivo de template, lembre-se de remover a cláusula `render/2` equivalente para esse template, pois caso contrário a função sobrescreverá o template. Vamos fazer isso para a cláusula 404.html que introduzimos anteriormente em `lib/hello_web/controllers/error_html.ex`. Também precisamos dizer ao Phoenix para incorporar nossos templates no módulo:

```diff
+ embed_templates "error_html/*"

- def render("404.html", _assigns) do
-  "Página Não Encontrada"
- end
```

Agora, quando voltarmos para [http://localhost:4000/such/a/wrong/path](http://localhost:4000/such/a/wrong/path), devemos ver uma página de erro muito mais agradável. Vale ressaltar que não renderizamos nosso template `404.html.heex` através do layout da nossa aplicação, mesmo que queiramos que nossa página de erro tenha a aparência e sensação do resto do nosso site. Isso é para evitar erros circulares. Por exemplo, o que acontece se nossa aplicação falhar devido a um erro no layout? Tentar renderizar o layout novamente apenas acionará outro erro. Portanto, idealmente, queremos minimizar a quantidade de dependências e lógica em nossos templates de erro, compartilhando apenas o necessário.

## Exceções personalizadas

Elixir fornece uma macro chamada `defexception/1` para definir exceções personalizadas. Exceções são representadas como structs, e structs precisam ser definidas dentro de módulos.

Para criar uma exceção personalizada, precisamos definir um novo módulo. Convencionalmente, este terá "Error" no nome. Dentro desse módulo, precisamos definir uma nova exceção com `defexception/1`, o arquivo `lib/hello_web.ex` parece um bom lugar para isso.

```elixir
defmodule HelloWeb.SomethingNotFoundError do
  defexception [:message]
end
```

Você pode levantar sua nova exceção assim:

```elixir
raise HelloWeb.SomethingNotFoundError, "oops"
```

Por padrão, Plug e Phoenix tratarão todas as exceções como erros 500. No entanto, Plug fornece um protocolo chamado `Plug.Exception` onde podemos personalizar o status e adicionar ações que as structs de exceção podem retornar na página de erro de depuração.

Se quiséssemos fornecer um status 404 para um erro `HelloWeb.SomethingNotFoundError`, poderíamos fazer isso definindo uma implementação para o protocolo `Plug.Exception` assim, em `lib/hello_web.ex`:

```elixir
defimpl Plug.Exception, for: HelloWeb.SomethingNotFoundError do
  def status(_exception), do: 404
  def actions(_exception), do: []
end
```

Alternativamente, você poderia definir um campo `plug_status` diretamente na struct de exceção:

```elixir
defmodule HelloWeb.SomethingNotFoundError do
  defexception [:message, plug_status: 404]
end
```

No entanto, implementar o protocolo `Plug.Exception` manualmente pode ser conveniente em certas ocasiões, como ao fornecer erros acionáveis.

## Erros acionáveis

Ações de exceção são funções que podem ser acionadas a partir da página de erro, e são basicamente uma lista de mapas definindo um `label` e um `handler` a ser executado. Como exemplo, Phoenix exibirá um erro se você tiver migrações pendentes e fornecerá um botão na página de erro para realizar as migrações pendentes.

Quando `debug_errors` é `true`, eles são renderizados na página de erro como uma coleção de botões e seguem o formato de:

```elixir
[
  %{
    label: String.t(),
    handler: {module(), function :: atom(), args :: []}
  }
]
```

Se quiséssemos retornar algumas ações para um `HelloWeb.SomethingNotFoundError`, implementaríamos `Plug.Exception` assim:

```elixir
defimpl Plug.Exception, for: HelloWeb.SomethingNotFoundError do
  def status(_exception), do: 404

  def actions(_exception) do
    [
      %{
        label: "Executar seeds",
        handler: {Code, :eval_file, ["priv/repo/seeds.exs"]}
      }
    ]
  end
end
```
