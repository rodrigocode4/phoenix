# Implantando no Gigalixir

## O que vamos precisar

A única coisa que precisaremos para este guia é uma aplicação Phoenix funcional. Para aqueles que precisam de uma aplicação simples para implantar, por favor, siga o guia [Up and Running](https://hexdocs.pm/phoenix/up_and_running.html).

## Objetivos

Nosso principal objetivo para este guia é colocar uma aplicação Phoenix funcionando no Gigalixir.

## Passos

Vamos separar este processo em alguns passos, para que possamos acompanhar onde estamos.

- Inicializar repositório Git
- Instalar a CLI do Gigalixir
- Cadastrar-se no Gigalixir
- Criar e configurar a aplicação Gigalixir
- Provisionar um banco de dados
- Preparar nosso projeto para o Gigalixir
- Hora do deploy!
- Comandos úteis do Gigalixir

## Inicializando repositório Git

Se você ainda não fez isso, precisaremos fazer commit dos nossos arquivos no git. Podemos fazer isso executando os seguintes comandos no diretório do nosso projeto:

```console
$ git init
$ git add .
$ git commit -m "Commit inicial"
```

## Instalando a CLI do Gigalixir

Siga as instruções [aqui](https://gigalixir.readthedocs.io/en/latest/getting-started-guide.html#install-the-command-line-interface) para instalar a interface de linha de comando para sua plataforma.

## Cadastrando-se no Gigalixir

Podemos criar uma conta em [gigalixir.com](https://www.gigalixir.com) ou com a CLI. Vamos usar a CLI.

```console
$ gigalixir signup
```

O plano gratuito do Gigalixir não requer cartão de crédito e vem com 1 instância de aplicação e 1 banco de dados PostgreSQL gratuitos, mas considere fazer upgrade para um plano pago se estiver executando uma aplicação em produção.

Em seguida, vamos fazer login

```console
$ gigalixir login
```

E verificar

```console
$ gigalixir account
```

## Criando e configurando nossa aplicação Gigalixir

Existem três maneiras diferentes de implantar um aplicativo Phoenix no Gigalixir: com mix, com releases do Elixir ou com Distillery. Neste guia, usaremos o Mix porque é o mais fácil de começar a usar, mas você não poderá conectar um observador remoto ou fazer hot upgrade. Para mais informações, consulte [Mix vs Distillery vs Elixir Releases](https://gigalixir.readthedocs.io/en/latest/modify-app/index.html#mix-vs-distillery-vs-elixir-releases). Se quiser implantar com outro método, siga o [Guia de Introdução](https://gigalixir.readthedocs.io/en/latest/getting-started-guide.html).

### Criando uma aplicação Gigalixir

Vamos criar uma aplicação Gigalixir

```console
$ gigalixir create -n "nome_da_sua_aplicacao"
```

Observação: o nome da aplicação não pode ser alterado posteriormente. Um nome aleatório é usado se você não fornecer um.

Verifique se a aplicação foi criada

```console
$ gigalixir apps
```

Verifique se um remote do git foi criado

```console
$ git remote -v
```

### Especificando versões

Os buildpacks que usamos têm como padrão versões de Elixir, Erlang e Node.js bastante antigas, e geralmente é uma boa ideia executar a mesma versão em produção que você usa em desenvolvimento, então vamos fazer isso.

```console
$ echo 'elixir_version=1.14.3' > elixir_buildpack.config
$ echo 'erlang_version=24.3' >> elixir_buildpack.config
$ echo 'node_version=12.16.3' > phoenix_static_buildpack.config
```

O Phoenix v1.6 usa `esbuild` para compilar seus assets, mas todas as imagens do Gigalixir vêm com `npm`, então vamos configurar o `npm` diretamente para implantar nossos assets. Adicione um arquivo `assets/package.json` se você não tiver nenhum, com o seguinte:

```json
{
  "scripts": {
    "deploy": "cd .. && mix assets.deploy && rm -f _build/esbuild*"
  }
}
```

Finalmente, não se esqueça de fazer commit:

```console
$ git add elixir_buildpack.config phoenix_static_buildpack.config assets/package.json
$ git commit -m "Definir versão do Elixir, Erlang e Node"
```

## Preparando nosso Projeto para o Gigalixir

Não há nada que precisemos fazer para que nossa aplicação funcione no Gigalixir, mas para uma aplicação de produção, você provavelmente quer forçar SSL. Para fazer isso, consulte [Forçar SSL](https://hexdocs.pm/phoenix/using_ssl.html#force-ssl)

Você também pode querer usar SSL para sua conexão com o banco de dados. Para isso, descomente a linha `ssl: true` na configuração do seu `Repo`.

## Provisionando um banco de dados

Vamos provisionar um banco de dados para nossa aplicação

```console
$ gigalixir pg:create --free
```

Verifique se o banco de dados foi criado

```console
$ gigalixir pg
```

Verifique se `DATABASE_URL` e `POOL_SIZE` foram criados

```console
$ gigalixir config
```

## Hora do Deploy!

Nosso projeto agora está pronto para ser implantado no Gigalixir.

```console
$ git push gigalixir
```

Verifique o status da sua implantação e aguarde até que a aplicação esteja `Healthy` (Saudável)

```console
$ gigalixir ps
```

Execute migrações

```console
$ gigalixir run mix ecto.migrate
```

Verifique os logs da sua aplicação

```console
$ gigalixir logs
```

Se tudo parecer bom, vamos dar uma olhada na sua aplicação rodando no Gigalixir

```console
$ gigalixir open
```

## Comandos Úteis do Gigalixir

Abrir um console remoto

```console
$ gigalixir account:ssh_keys:add "$(cat ~/.ssh/id_rsa.pub)"
$ gigalixir ps:remote_console
```

Para abrir um observador remoto, consulte [Observador Remoto](https://gigalixir.readthedocs.io/en/latest/runtime.html#how-to-launch-a-remote-observer)

Para configurar clustering, consulte [Clustering de Nós](https://gigalixir.readthedocs.io/en/latest/cluster.html)

Para hot upgrade, consulte [Hot Upgrades](https://gigalixir.readthedocs.io/en/latest/deploy.html#how-to-hot-upgrade-an-app)

Para domínios personalizados, escalonamento, jobs e outros recursos, consulte a [Documentação do Gigalixir](https://gigalixir.readthedocs.io/)

## Solução de Problemas

Consulte [Solução de Problemas](https://gigalixir.readthedocs.io/en/latest/troubleshooting.html)

Além disso, não hesite em enviar um e-mail para [help@gigalixir.com](mailto:help@gigalixir.com) ou [solicitar um convite](https://elixir-lang.slack.com/join/shared_invite/zt-1f13hz7mb-N4KGjF523ONLCcHfb8jYgA#/shared-invite/email) e junte-se ao canal #gigalixir no [Slack](https://elixir-lang.slack.com).
