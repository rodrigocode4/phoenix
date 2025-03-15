# Upload de Arquivos

Uma tarefa comum para aplicações web é o upload de arquivos. Esses arquivos podem ser imagens, vídeos, PDFs ou arquivos de qualquer outro tipo. Para fazer upload de arquivos através de uma interface HTML, precisamos de uma tag de input `file` em um formulário multipart.

> #### Procurando pelo guia de Uploads do LiveView? {: .neutral}
>
> Este guia explica uploads de arquivos HTTP multipart via `Plug.Upload`.
> Para mais informações sobre uploads de arquivos do LiveView, incluindo uploads externos direto para a nuvem no
> cliente, consulte o [guia de Uploads do LiveView](https://hexdocs.pm/phoenix_live_view/uploads.html).

O Plug fornece uma struct `Plug.Upload` para conter os dados do input `file`. Uma struct `Plug.Upload` aparecerá automaticamente em seus parâmetros de requisição se um usuário tiver selecionado um arquivo ao enviar o formulário.

Neste guia, você fará o seguinte:

  1.  Configurar um formulário multipart

  2. Adicionar um elemento de input de arquivo ao formulário

  3. Verificar seus parâmetros de upload

  4. Gerenciar seus arquivos enviados

No [`guia de Contextos`](contexts.md), geramos um recurso HTML para produtos. Podemos reutilizar o formulário que geramos lá para demonstrar como os uploads de arquivos funcionam no Phoenix. Consulte esse guia para obter instruções sobre como gerar o recurso de produto que você usará aqui.

### Configurar um formulário multipart

A primeira coisa que você precisa fazer é transformar seu formulário em um formulário multipart. O componente `simple_form/1` do `HelloWeb.CoreComponents` aceita um atributo `multipart` onde você pode especificar isso.

Aqui está o formulário de `lib/hello_web/controllers/product_html/product_form.html.heex` com essa alteração:

```heex
<.simple_form :let={f} for={@changeset} action={@action} multipart>
. . .
```

### Adicionar um input de arquivo

Uma vez que você tenha um formulário multipart, você precisa de um input `file`. Veja como você faria isso, também em `product_form.html.heex`:

```heex
. . .
  <.input field={f[:photo]} type="file" label="Foto" />

  <:actions>
    <.button>Salvar Produto</.button>
  </:actions>
</.simple_form>
```

Quando renderizado, aqui está o HTML para o componente padrão `input/1` do `HelloWeb.CoreComponents`:

```html
<div>
  <label for="product_photo" class="block text-sm...">Foto</label>
  <input type="file" name="product[photo]" id="product_photo" class="mt-2 block w-full...">
</div>
```

Observe o atributo `name` do seu input `file`. Isso criará a chave `"photo"` no mapa `product_params` que estará disponível na ação do seu controlador.

Isso é tudo do lado do formulário. Agora, quando os usuários enviarem o formulário, uma requisição `POST` será roteada para a ação `create/2` do seu `HelloWeb.ProductController`.

> #### Devo adicionar a foto ao meu schema Ecto? {: .neutral}
>
> O input de foto não precisa fazer parte do seu schema para aparecer nos `product_params`. No entanto, se você quiser persistir quaisquer propriedades da foto em um banco de dados, você precisaria adicioná-la ao seu schema `Hello.Product`.

### Verificar seus parâmetros de upload

Uma vez que você gerou um recurso HTML, agora você pode iniciar seu servidor com `mix phx.server`, visitar [http://localhost:4000/products/new](http://localhost:4000/products/new) e criar um novo produto com uma foto.

Antes de começar, adicione `IO.inspect product_params` no topo da sua ação `ProductController.create/2` em `lib/hello_web/controllers/product_controller.ex`. Isso mostrará os `product_params` em seu log de desenvolvimento para que você possa ter uma ideia melhor do que está acontecendo.

```elixir
. . .
  def create(conn, %{"product" => product_params}) do
    IO.inspect product_params
. . .
```

Quando você fizer isso, isso é o que seus `product_params` irão gerar no log:

```elixir
%{"title" => "Metaprogramming Elixir", "description" => "Write Less Code, Get More Done (and Have Fun!)", "price" => "15.000000", "views" => "0",
"photo" => %Plug.Upload{content_type: "image/png", filename: "meta-cover.png", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}}
```

Você tem uma chave `"photo"` que mapeia para a struct `Plug.Upload` pré-populada representando sua foto enviada.

Para facilitar a leitura, concentre-se na própria struct:

```elixir
%Plug.Upload{content_type: "image/png", filename: "meta-cover.png", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}
```

`Plug.Upload` fornece o tipo de conteúdo do arquivo, o nome original do arquivo e o caminho para o arquivo temporário que o Plug criou para você. Neste caso, `"/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/"` é o diretório criado pelo Plug para colocar os arquivos enviados. O diretório persistirá entre requisições. `"multipart-558399-917557-1"` é o nome que o Plug deu ao seu arquivo enviado. Se você tivesse vários inputs `file` e se o usuário tivesse selecionado fotos para todos eles, você teria vários arquivos espalhados em diretórios temporários. O Plug garantirá que todos os nomes de arquivo sejam únicos.

> #### Arquivos Plug.Upload são temporários {: .info}
>
> O Plug remove os uploads de seu diretório conforme a requisição é concluída. Se você precisar fazer qualquer coisa com este arquivo, você precisa fazê-lo antes disso (ou [entregá-lo](`Plug.Upload.give_away/3`), mas isso está fora do escopo deste guia).

### Gerenciar seus arquivos enviados

Uma vez que você tenha a struct `Plug.Upload` disponível em seu controlador, você pode realizar qualquer operação que desejar sobre ela. Por exemplo, você pode querer fazer uma ou mais das seguintes coisas:

* Verificar se o arquivo existe com `File.exists?/1`

* Copiar o arquivo para outro lugar no sistema de arquivos com `File.cp/2`

* Entregar o arquivo para outro processo Elixir com `Plug.Upload.give_away/3`

* Enviá-lo para o S3 com uma biblioteca externa

* Enviá-lo de volta para o cliente com `Plug.Conn.send_file/5`

Em um sistema de produção, você pode querer copiar o arquivo para um diretório raiz, como `/media`. Ao fazer isso, é importante garantir que os nomes sejam únicos. Por exemplo, se você está permitindo que os usuários façam upload de imagens de capa de produtos, você poderia usar o id do produto para gerar um nome único:

```elixir
if upload = product_params["photo"] do
  extension = Path.extname(upload.filename)
  File.cp(upload.path, "/media/#{product.id}-cover#{extension}")
end
```

Em seguida, um plug `Plug.Static` poderia ser adicionado em seu `lib/my_app_web/endpoint.ex` para servir os arquivos em `"/media"`:

```elixir
plug Plug.Static, at: "/uploads", from: "/media"
```

O arquivo enviado agora pode ser acessado de seus navegadores usando um caminho como `"/uploads/1-cover.jpg"`. Na prática, existem outras preocupações que você deseja lidar ao fazer upload de arquivos, como validar extensões, codificar nomes e assim por diante. Muitas vezes, usar uma biblioteca que já lida com esses casos é preferível.

Finalmente, observe que quando não há dados do input `file`, você não obtém nem a chave `"photo"` nem uma struct `Plug.Upload`. Aqui estão os `product_params` do log.

```elixir
%{"title" => "Metaprogramming Elixir", "description" => "Write Less Code, Get More Done (and Have Fun!)", "price" => "15.000000", "views" => "0"}
```

## Configurando limites de upload

A conversão dos dados enviados pelo formulário para um `Plug.Upload` real é feita pelo plug `Plug.Parsers` que você pode encontrar dentro de `HelloWeb.Endpoint`:

```elixir
# lib/hello_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Phoenix.json_library()
```

Além das opções acima, `Plug.Parsers` aceita outras opções para controlar o upload de dados:

  * `:length` - define o comprimento máximo do corpo a ser lido, o padrão é `8_000_000` bytes
  * `:read_length` - define a quantidade de bytes a serem lidos de uma vez, o padrão é `1_000_000` bytes
  * `:read_timeout` - define o tempo limite para cada pedaço recebido, o padrão é `15_000` ms

A primeira opção configura o máximo de dados permitidos. As restantes configuram quanto dados esperamos ler e sua frequência. Se o cliente não conseguir enviar dados rápido o suficiente, a conexão será encerrada. Phoenix vem com padrões razoáveis, mas você pode querer personalizá-los em circunstâncias especiais, por exemplo, se você está esperando clientes realmente lentos para enviar grandes pedaços de dados.

Também vale a pena apontar que esses limites são importantes como um mecanismo de segurança. Por exemplo, se você não definir um limite para o upload de dados, os atacantes poderiam abrir milhares de conexões para sua aplicação e enviar um byte a cada 2 minutos, o que levaria muito tempo para completar enquanto usa todas as conexões para o seu servidor. Os limites acima esperam pelo menos uma quantidade razoável de progresso, tornando a vida dos atacantes um pouco mais difícil.
