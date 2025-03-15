# Autenticação de API

> **Requisito**: Este guia espera que você tenha concluído o guia [`mix phx.gen.auth`](mix_phx_gen_auth.html).

Este guia mostra como adicionar autenticação de API em cima do `mix phx.gen.auth`. Como o gerador de autenticação já inclui uma tabela de tokens, nós a usamos para armazenar tokens de API também, seguindo as melhores práticas de segurança.

Dividiremos este guia em duas partes: ampliando o contexto e a implementação do plug. Vamos assumir que o seguinte comando `mix phx.gen.auth` foi executado:

```
$ mix phx.gen.auth Accounts User users
```

Se você executou algo diferente, deve ser trivial adaptar os nomes.

## Adicionando funções de API ao contexto

Nosso sistema de autenticação exigirá duas funções. Uma para criar o token de API e outra para verificá-lo. Abra `lib/my_app/accounts.ex` e adicione estas duas novas funções:

```elixir
  ## API

  @doc """
  Cria um novo token de api para um usuário.

  O token retornado deve ser salvo em algum lugar seguro.
  Este token não pode ser recuperado do banco de dados.
  """
  def create_user_api_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "api-token")
    Repo.insert!(user_token)
    encoded_token
  end

  @doc """
  Busca o usuário pelo token de API.
  """
  def fetch_user_by_api_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "api-token"),
         %User{} = user <- Repo.one(query) do
      {:ok, user}
    else
      _ -> :error
    end
  end
```

As novas funções usam a funcionalidade existente do `UserToken` para armazenar um novo tipo de token chamado "api-token". Como este é um token de email, se o usuário alterar seu email, os tokens serão expirados.

Observe também que chamamos a segunda função de `fetch_user_by_api_token`, em vez de `get_user_by_api_token`. Como queremos renderizar diferentes códigos de status em nossa API, dependendo se um usuário foi encontrado ou não, retornamos `{:ok, user}` ou `:error`. A convenção do Elixir é chamar essas funções de `fetch_*`, em vez de `get_*`, que geralmente retornaria `nil` em vez de tuplas.

Para garantir que nossas novas funções funcionem, vamos escrever testes. Abra `test/my_app/accounts_test.exs` e adicione este novo bloco describe:

```elixir
  describe "create_user_api_token/1 and fetch_user_by_api_token/1" do
    test "creates and fetches by token" do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)
      assert Accounts.fetch_user_by_api_token(token) == {:ok, user}
      assert Accounts.fetch_user_by_api_token("invalid") == :error
    end
  end
```

Se você executar os testes, eles realmente falharão. Algo semelhante a isto:

```elixir
1) test create_user_api_token/1 and fetch_user_by_api_token/1 creates and verify token (Demo.AccountsTest)
   test/demo/accounts_test.exs:21
   ** (FunctionClauseError) no function clause matching in Demo.Accounts.UserToken.days_for_context/1

   The following arguments were given to Demo.Accounts.UserToken.days_for_context/1:

       # 1
       "api-token"

   Attempted function clauses (showing 2 out of 2):

       defp days_for_context("confirm")
       defp days_for_context("reset_password")

   code: assert Accounts.verify_api_token(token) == {:ok, user}
   stacktrace:
     (demo 0.1.0) lib/demo/accounts/user_token.ex:129: Demo.Accounts.UserToken.days_for_context/1
     (demo 0.1.0) lib/demo/accounts/user_token.ex:114: Demo.Accounts.UserToken.verify_email_token_query/2
     (demo 0.1.0) lib/demo/accounts.ex:301: Demo.Accounts.verify_api_token/1
     test/demo/accounts_test.exs:24: (test)
```

Se preferir, tente olhar o erro e corrigi-lo você mesmo. A explicação virá a seguir.

O módulo `UserToken` espera que declaremos a validade de cada token e não definimos uma para "api-token". A duração dependerá da sua aplicação e quão sensível ela é em termos de segurança. Para este exemplo, vamos dizer que o token é válido por 365 dias.

Abra `lib/my_app/accounts/user_token.ex`, encontre onde `defp days_for_context` está definido e adicione uma nova cláusula, assim:

```elixir
  defp days_for_context("api-token"), do: 365
  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days
```

Agora os testes devem passar e estamos prontos para seguir em frente!

## Plug de autenticação de API

A última parte é adicionar autenticação à nossa API.

Quando executamos `mix phx.gen.auth`, ele gerou um módulo `MyAppWeb.UserAuth` com vários plugs, que são pequenas funções que recebem o `conn` e personalizam nosso ciclo de vida de requisição/resposta. Abra `lib/my_app_web/user_auth.ex` e adicione esta nova função:

```elixir
def fetch_api_user(conn, _opts) do
  with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
       {:ok, user} <- Accounts.fetch_user_by_api_token(token) do
    assign(conn, :current_user, user)
  else
    _ ->
      conn
      |> send_resp(:unauthorized, "No access for you")
      |> halt()
  end
end
```

Nossa função recebe a conexão e verifica se o cabeçalho "authorization" foi definido com "Bearer TOKEN", onde "TOKEN" é o valor retornado por `Accounts.create_user_api_token/1`. Caso o token não seja válido ou não exista tal usuário, abortamos a requisição.

Finalmente, precisamos adicionar este `plug` ao nosso pipeline. Abra `lib/my_app_web/router.ex` e você encontrará um pipeline para API. Vamos adicionar nosso novo plug abaixo dele, assim:

```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_api_user
  end
```

Agora você está pronto para receber e validar requisições de API. Sinta-se à vontade para abrir `test/my_app_web/user_auth_test.exs` e escrever seu próprio teste. Você pode usar os testes para outros plugs como modelos!

## Sua vez

O fluxo geral de autenticação de API dependerá da sua aplicação.

Se você quiser usar este token em um cliente JavaScript, precisará alterar ligeiramente o `UserSessionController` para invocar `Accounts.create_user_api_token/1` e retornar uma resposta JSON e incluir o token retornado.

Se você quiser fornecer APIs para usuários de terceiros, precisará permitir que eles criem tokens e mostrar o resultado de `Accounts.create_user_api_token/1` para eles. Eles devem salvar esses tokens em algum lugar seguro e incluí-los como parte de suas requisições usando o cabeçalho "authorization".
