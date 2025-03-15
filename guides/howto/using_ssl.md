# Usando SSL

Para preparar uma aplicação para atender requisições via SSL, precisamos adicionar um pouco de configuração e duas variáveis de ambiente. Para que o SSL realmente funcione, precisaremos de um arquivo de chave e um arquivo de certificado de uma autoridade certificadora. As variáveis de ambiente necessárias são caminhos para esses dois arquivos.

A configuração consiste em uma nova chave `https:` para nosso endpoint, cujo valor é uma lista de palavras-chave contendo a porta, o caminho para o arquivo de chave e o caminho para o arquivo de certificado (PEM). Se adicionarmos a chave `otp_app:` cujo valor é o nome da nossa aplicação, o Plug começará a procurar esses arquivos na raiz da nossa aplicação. Podemos então colocar esses arquivos no diretório `priv` e definir os caminhos para `priv/nossa_chave.key` e `priv/nosso_certificado.crt`.

Aqui está um exemplo de configuração do arquivo `config/runtime.exs`.

```elixir
import Config

config :hello, HelloWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  https: [
    port: 443,
    cipher_suite: :strong,
    otp_app: :hello,
    keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
    certfile: System.get_env("SOME_APP_SSL_CERT_PATH"),
    # OPCIONAL Chave para certificados intermediários:
    cacertfile: System.get_env("INTERMEDIATE_CERTFILE_PATH")
  ]

```

Sem a chave `otp_app:`, precisamos fornecer caminhos absolutos para os arquivos, onde quer que estejam no sistema de arquivos, para que o Plug possa encontrá-los.

```elixir
Path.expand("../../../algum/caminho/para/ssl/chave.pem", __DIR__)
```

As opções sob a chave `https:` são passadas para o adaptador Plug, tipicamente `Bandit`, que por sua vez usa `Plug.SSL` para selecionar as opções de socket TLS. Consulte a documentação de [Plug.SSL.configure/1](https://hexdocs.pm/plug/Plug.SSL.html#configure/1) para mais informações sobre as opções disponíveis e seus valores padrão. O [Guia HTTPS do Plug](https://hexdocs.pm/plug/https.html) e a documentação [Erlang/OTP ssl](https://www.erlang.org/doc/man/ssl.html) também fornecem informações valiosas.

## SSL no Desenvolvimento

Se você deseja usar HTTPS no desenvolvimento, um certificado autoassinado pode ser gerado executando: `mix phx.gen.cert`. Isso requer Erlang/OTP 20 ou posterior.

Com seu certificado autoassinado, sua configuração de desenvolvimento em `config/dev.exs` pode ser atualizada para executar um endpoint HTTPS:

```elixir
config :my_app, MyAppWeb.Endpoint,
  ...
  https: [
    port: 4001,
    cipher_suite: :strong,
    keyfile: "priv/cert/selfsigned_key.pem",
    certfile: "priv/cert/selfsigned.pem"
  ]
```

Isso pode substituir sua configuração `http`, ou você pode executar servidores HTTP e HTTPS em portas diferentes.

## Forçar SSL

Em muitos casos, você vai querer forçar todas as requisições recebidas a usar SSL redirecionando HTTP para HTTPS. Isso pode ser realizado definindo a opção `:force_ssl` na configuração do seu endpoint. Ela espera uma lista de opções que são encaminhadas para `Plug.SSL`. Por padrão, ela define o cabeçalho "strict-transport-security" em requisições HTTPS, forçando os navegadores a sempre usar HTTPS. Se uma requisição insegura (HTTP) for enviada, ela redireciona para a versão HTTPS usando o `:host` especificado na configuração `:url`. Por exemplo:

```elixir
config :my_app, MyAppWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]]
```

Para redirecionar dinamicamente para o `host` da requisição atual, defina `:host` na configuração `:force_ssl` como `nil`.

```elixir
config :my_app, MyAppWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto], host: nil]
```

Nestes exemplos, a chave `rewrite_on:` especifica o cabeçalho HTTP usado por um proxy reverso ou balanceador de carga na frente da aplicação para indicar se a requisição foi recebida via HTTP ou HTTPS. Para mais informações sobre as implicações de descarregar TLS para um elemento externo, em particular relacionado a cookies seguros, consulte o [Guia HTTPS do Plug](https://hexdocs.pm/plug/https.html#offloading-tls). Tenha em mente que as opções passadas para `Plug.SSL` nesse documento devem ser definidas usando a opção de endpoint `force_ssl:` em uma aplicação Phoenix.

É importante observar que `force_ssl:` é uma configuração de *compilação*, então normalmente é definida em `prod.exs`, não funcionará quando definida a partir de `runtime.exs`.

## HSTS

HSTS, abreviação de 'HTTP Strict-Transport-Security', é um mecanismo que permite que sites se declarem acessíveis exclusivamente por meio de uma conexão segura (HTTPS). Foi introduzido para prevenir ataques do tipo man-in-the-middle que removem a criptografia SSL/TLS. O HSTS faz com que os navegadores redirecionem de HTTP para HTTPS e se recusem a conectar a menos que a conexão use SSL/TLS.

Com `force_ssl: [hsts: true]` definido, o cabeçalho `Strict-Transport-Security` é adicionado com um max-age que define a duração da validade da política. Navegadores modernos responderão a isso redirecionando de HTTP para HTTPS, entre outras consequências. [RFC6797](https://tools.ietf.org/html/rfc6797), que define HSTS, também especifica que **o navegador deve rastrear a política de um host e aplicá-la até que expire.** Ele também especifica que **o tráfego em qualquer porta diferente de 80 é considerado criptografado** de acordo com a política.

Embora o HSTS seja recomendado em produção, pode levar a comportamentos inesperados ao acessar aplicações no localhost. Por exemplo, acessar uma aplicação com HSTS habilitado em `https://localhost:4000` leva a uma situação onde todo o tráfego subsequente de localhost, exceto para a porta 80, é esperado ser criptografado. Isso pode interromper o tráfego para outros servidores locais ou proxies em execução no seu computador que não estão relacionados à sua aplicação Phoenix e podem não suportar tráfego criptografado.

Se você habilitar inadvertidamente o HSTS para localhost, talvez precise redefinir o cache do seu navegador antes que ele aceite tráfego HTTP do localhost novamente.

Para Chrome:
1. Abra o Painel de Ferramentas do Desenvolvedor.
2. Clique e segure o ícone de recarregar ao lado da barra de endereço para revelar um menu suspenso.
3. Selecione "Limpar Cache e Recarregar Forçado".

Para Safari:
1. Limpe o cache do navegador.
2. Remova a entrada de `~/Library/Cookies/HSTS.plist` ou exclua o arquivo inteiro.
3. Reinicie o Safari.

Para outros navegadores, consulte a documentação para HSTS.

Alternativamente, definir a opção `:expires` em `force_ssl` para `0` deve expirar a entrada e desabilitar o HSTS.

Para mais informações sobre as opções de HSTS, consulte [Plug.SSL](https://hexdocs.pm/plug/Plug.SSL.html).
