# mix phx.gen.auth

O comando `mix phx.gen.auth` gera um sistema de autenticação flexível e pré-construído para sua aplicação Phoenix. Este gerador permite que você rapidamente supere a tarefa de adicionar autenticação ao seu código e mantenha o foco no problema do mundo real que sua aplicação está tentando resolver.

## Primeiros passos

> Antes de executar este comando, considere fazer um commit do seu trabalho, pois ele gera múltiplos arquivos.

Vamos começar executando o seguinte comando a partir da raiz da nossa aplicação (ou `apps/my_app_web` em uma aplicação guarda-chuva):

```console
$ mix phx.gen.auth Accounts User users

Um sistema de autenticação pode ser criado de duas maneiras diferentes:
- Usando Phoenix.LiveView (padrão)
- Usando apenas Phoenix.Controller

Você deseja criar um sistema de autenticação baseado em LiveView? [Y/n] Y
```

Os geradores de autenticação suportam Phoenix LiveView, para uma melhor experiência do usuário, então responderemos `Y` aqui. Você também pode responder `n` para um sistema de autenticação baseado em controllers.

Qualquer abordagem criará um contexto `Accounts` com um módulo de esquema `Accounts.User`. O argumento final é a versão plural do módulo de esquema, que é usado para gerar nomes de tabelas de banco de dados e caminhos de rota. O gerador `mix phx.gen.auth` é semelhante ao `mix phx.gen.html`, exceto por não aceitar uma lista de campos adicionais para adicionar ao esquema, e por gerar muito mais funções de contexto.

Como este gerador instalou dependências adicionais em `mix.exs`, vamos buscá-las:

```console
$ mix deps.get
```

Agora precisamos verificar os detalhes de conexão do banco de dados para os ambientes de desenvolvimento e teste em `config/` para que o migrador e os testes possam ser executados corretamente. Em seguida, execute o seguinte para criar o banco de dados:

```console
$ mix ecto.setup
```

Vamos executar os testes para garantir que nosso novo sistema de autenticação funcione como esperado.

```console
$ mix test
```

E finalmente, vamos iniciar nosso servidor Phoenix e testá-lo.

```console
$ mix phx.server
```

## Responsabilidades do desenvolvedor

Como o Phoenix gera este código em sua aplicação em vez de incorporar esses módulos no próprio Phoenix, você agora tem total liberdade para modificar o sistema de autenticação, para que funcione melhor com seu caso de uso. A única ressalva ao usar um sistema de autenticação gerado é que ele não será atualizado após ser gerado. Portanto, à medida que melhorias são feitas na saída do `mix phx.gen.auth`, torna-se sua responsabilidade determinar se essas mudanças precisam ser portadas para sua aplicação. Melhorias relacionadas à segurança e outras melhorias importantes serão explícita e claramente marcadas no arquivo `CHANGELOG.md` e nas notas de atualização.

## Código gerado

A seguir estão as notas sobre o sistema de autenticação gerado.

### Hashing de senha

O mecanismo de hashing de senha usa por padrão `bcrypt` para sistemas Unix e `pbkdf2` para sistemas Windows. Ambos os sistemas usam a [interface Comeonin](https://hexdocs.pm/comeonin/).

O mecanismo de hashing de senha pode ser substituído com a opção `--hashing-lib`. Os seguintes valores são suportados:

  * `bcrypt` - [bcrypt_elixir](https://hex.pm/packages/bcrypt_elixir)
  * `pbkdf2` - [pbkdf2_elixir](https://hex.pm/packages/pbkdf2_elixir)
  * `argon2` - [argon2_elixir](https://hex.pm/packages/argon2_elixir)

Recomendamos que os desenvolvedores considerem usar `argon2`, que é o mais robusto dos 3. A desvantagem é que o `argon2` é bastante intensivo em CPU e memória, e você precisará de instâncias mais poderosas para executar suas aplicações.

Para mais informações sobre a escolha dessas bibliotecas, consulte o [projeto Comeonin](https://github.com/riverrun/comeonin).

### Proibindo acesso

O código gerado vem com um módulo de autenticação com vários plugs que buscam o usuário atual, exigem autenticação e assim por diante. Por exemplo, em um aplicativo chamado Demo que teve `mix phx.gen.auth Accounts User users` executado nele, você encontrará um módulo chamado `DemoWeb.UserAuth` com plugs como:

  * `fetch_current_user` - busca as informações do usuário atual, se disponíveis
  * `require_authenticated_user` - deve ser invocado após `fetch_current_user` e requer que um usuário atual exista e esteja autenticado
  * `redirect_if_user_is_authenticated` - usado para as poucas páginas que não devem estar disponíveis para usuários autenticados

### Confirmação

A funcionalidade gerada vem com um mecanismo de confirmação de conta, onde os usuários têm que confirmar sua conta, normalmente por e-mail. No entanto, o código gerado não proíbe os usuários de usar a aplicação se suas contas ainda não foram confirmadas. Você pode adicionar essa funcionalidade personalizando o `require_authenticated_user` no módulo `Auth` para verificar o campo `confirmed_at` (e qualquer outra propriedade que desejar).

### Notificadores

O código gerado não está integrado a nenhum sistema para enviar SMSs ou e-mails para confirmar contas, redefinir senhas, etc. Em vez disso, ele simplesmente registra uma mensagem no terminal. É sua responsabilidade integrar-se ao sistema adequado após a geração.

Observe que se você gerou seu projeto Phoenix com `mix phx.new`, seu projeto está configurado para usar o mailer [Swoosh](https://hexdocs.pm/swoosh/Swoosh.html) por padrão. Para visualizar e-mails do notificador durante o desenvolvimento com Swoosh, navegue até `/dev/mailbox`.

### Rastreamento de sessões

Todas as sessões e tokens são rastreados em uma tabela separada. Isso permite que você acompanhe quantas sessões estão ativas para cada conta. Você poderia até mesmo expor essas informações aos usuários, se desejar.

Observe que sempre que a senha é alterada (seja por meio de redefinição de senha ou diretamente), todos os tokens são excluídos e o usuário precisa fazer login novamente em todos os dispositivos.

### Ataques de enumeração de usuários

Um ataque de enumeração de usuários permite que alguém verifique se um e-mail está registrado na aplicação. O código de autenticação gerado não tenta proteger contra tais verificações. Por exemplo, quando você registra uma conta, se o e-mail já estiver registrado, o código notificará o usuário de que o e-mail já está registrado.

Se sua aplicação é sensível a ataques de enumeração, você precisa implementar seus próprios fluxos de trabalho, que tendem a ser muito diferentes da maioria das aplicações, já que você precisa equilibrar cuidadosamente segurança e experiência do usuário.

Além disso, se você está preocupado com ataques de enumeração, tenha cuidado também com ataques de tempo. Por exemplo, registrar uma nova conta normalmente envolve trabalho adicional (como escrever no banco de dados, enviar e-mails, etc.) em comparação com quando uma conta já existe. Alguém poderia medir o tempo necessário para executar essas tarefas adicionais para enumerar e-mails. Isso se aplica a todos os endpoints (registro, confirmação, recuperação de senha, etc.) que podem enviar e-mail, notificações no aplicativo, etc.

### Sensibilidade a maiúsculas e minúsculas

A busca por e-mail é feita para ser insensível a maiúsculas e minúsculas. Buscas insensíveis a maiúsculas e minúsculas são o padrão no MySQL e MSSQL. No SQLite3, usamos [`COLLATE NOCASE`](https://www.sqlite.org/datatype3.html#collating_sequences) na definição da coluna para suportá-lo. No PostgreSQL, usamos a [extensão `citext`](https://www.postgresql.org/docs/current/citext.html).

Observe que `citext` faz parte do próprio PostgreSQL e é fornecido com ele na maioria dos sistemas operacionais e gerenciadores de pacotes. O `mix phx.gen.auth` cuida da criação da extensão e nenhum trabalho extra é necessário na maioria dos casos. Se por algum motivo seu gerenciador de pacotes divide o `citext` em um pacote separado, você receberá um erro durante a migração e provavelmente poderá resolvê-lo instalando o pacote `postgres-contrib`.

### Testes concorrentes

Os testes gerados são executados simultaneamente se você estiver usando um banco de dados que suporta testes concorrentes, o que é o caso do PostgreSQL.

## Mais sobre `mix phx.gen.auth`

Confira `mix phx.gen.auth` para mais detalhes, como usar uma biblioteca de hashing de senha diferente, personalizar o namespace do módulo web, gerar tipo de ID binário, configurar as opções padrão e usar nomes de tabela personalizados.

## Recursos adicionais

Os links a seguir têm mais informações sobre a motivação e o design do código que isso gera.

  * Post do blog de Berenice Medel sobre a geração de LiveViews para autenticação (em vez de Controllers & Views convencionais) - [Bringing Phoenix Authentication to Life](https://fly.io/phoenix-files/phx-gen-auth/)
  * Post do blog de José Valim - [An upcoming authentication solution for Phoenix](https://dashbit.co/blog/a-new-authentication-solution-for-phoenix)
  * O [repositório original `phx_gen_auth`][phx_gen_auth repo] (para aplicações Phoenix 1.5) - Este é um ótimo recurso para ver discussões sobre decisões que foram tomadas em versões anteriores do projeto.
  * [Pull request original em aplicativo Phoenix simples][auth PR]
  * [Especificação de design original](https://github.com/dashbitco/mix_phx_gen_auth_demo/blob/auth/README.md)

[phx_gen_auth repo]: https://github.com/aaronrenner/phx_gen_auth
[auth PR]: https://github.com/dashbitco/mix_phx_gen_auth_demo/pull/1
