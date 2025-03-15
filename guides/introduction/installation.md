# Instalação

Para construir uma aplicação Phoenix, precisamos de algumas dependências instaladas em nosso Sistema Operacional:

  * a máquina virtual Erlang e a linguagem de programação Elixir
  * um banco de dados - Phoenix recomenda PostgreSQL, mas você pode escolher outros ou nem mesmo usar um banco de dados
  * e outros pacotes opcionais.

Por favor, dê uma olhada nesta lista e certifique-se de instalar tudo o que for necessário para o seu sistema. Ter dependências instaladas com antecedência pode evitar problemas frustrantes posteriormente.

## Elixir 1.15 ou posterior

Phoenix é escrito em Elixir, e nosso código de aplicação também será escrito em Elixir. Não iremos muito longe em uma aplicação Phoenix sem ele! O site do Elixir mantém uma excelente [Página de Instalação](https://elixir-lang.org/install.html) para ajudar.

## Erlang 24 ou posterior

O código Elixir é compilado para byte code Erlang para executar na máquina virtual Erlang. Sem Erlang, o código Elixir não tem uma máquina virtual para executar, então precisamos instalar o Erlang também.

Quando instalamos o Elixir usando as instruções da [Página de Instalação](https://elixir-lang.org/install.html) do Elixir, geralmente também obtemos o Erlang. Se o Erlang não foi instalado junto com o Elixir, consulte a seção [Instruções do Erlang](https://elixir-lang.org/install.html#installing-erlang) na Página de Instalação do Elixir para obter instruções.

## Phoenix

Para verificar se estamos no Elixir 1.15 e Erlang 24 ou posterior, execute:

```console
elixir -v
Erlang/OTP 24 [erts-12.0] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Elixir 1.15.0
```

Uma vez que temos Elixir e Erlang, estamos prontos para instalar o gerador de aplicações Phoenix:

```console
$ mix archive.install hex phx_new
```

O gerador `phx.new` agora está disponível para gerar novas aplicações no próximo guia, chamado [Up and Running](up_and_running.html). As flags mencionadas abaixo são opções de linha de comando para o gerador; veja todas as opções disponíveis chamando `mix help phx.new`.

## PostgreSQL

PostgreSQL é um servidor de banco de dados relacional. O Phoenix configura aplicações para usá-lo por padrão, mas podemos mudar para MySQL, MSSQL ou SQLite3 passando a flag `--database` ao criar uma nova aplicação.

Para se comunicar com bancos de dados, as aplicações Phoenix usam outro pacote Elixir, chamado [Ecto](https://github.com/elixir-ecto/ecto). Se você não planeja usar bancos de dados em sua aplicação, pode passar a flag `--no-ecto`.

No entanto, se você está apenas começando com Phoenix, recomendamos que instale o PostgreSQL e certifique-se de que ele esteja rodando. O wiki do PostgreSQL possui [guias de instalação](https://wiki.postgresql.org/wiki/Detailed_installation_guides) para vários sistemas diferentes.

## inotify-tools (para usuários Linux)

Phoenix fornece um recurso muito útil chamado Live Reloading. Conforme você altera suas views ou seus assets, ele recarrega automaticamente a página no navegador. Para que essa funcionalidade funcione, você precisa de um observador de sistema de arquivos.

Usuários de macOS e Windows já possuem um observador de sistema de arquivos, mas usuários de Linux devem instalar o inotify-tools. Consulte o [wiki do inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki) para instruções de instalação específicas da distribuição.

## Resumo

Ao final desta seção, você deve ter instalado Elixir, Hex, Phoenix e PostgreSQL. Agora que temos tudo instalado, vamos criar nossa primeira aplicação Phoenix e [colocá-la para funcionar](up_and_running.html).