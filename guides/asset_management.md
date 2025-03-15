# Gerenciamento de Assets

Além de produzir HTML, a maioria das aplicações web possuem vários assets (JavaScript, CSS, imagens, fontes e assim por diante).

Desde o Phoenix v1.7, novas aplicações usam [esbuild](https://esbuild.github.io/) para preparar assets via [wrapper Elixir do esbuild](https://github.com/phoenixframework/esbuild), e [tailwindcss](https://tailwindcss.com) via [wrapper Elixir do tailwindcss](https://github.com/phoenixframework/tailwind) para CSS. A integração direta com `esbuild` e `tailwind` significa que aplicações recém-geradas não têm dependências no Node.js ou em um sistema de build externo (ex: Webpack).

Seu JavaScript normalmente é colocado em "assets/js/app.js" e o `esbuild` o extrairá para "priv/static/assets/app.js". Em desenvolvimento, isso é feito automaticamente pelo observador do `esbuild`. Em produção, isso é feito executando `mix assets.deploy`.

O `esbuild` também pode lidar com seus arquivos CSS, mas por padrão o `tailwind` cuida de toda a construção de CSS.

Finalmente, todos os outros assets, que geralmente não precisam ser pré-processados, vão diretamente para "priv/static".

## Pacotes JS de terceiros

Se você deseja importar dependências JavaScript, você tem pelo menos três opções para adicioná-las à sua aplicação:

1. Incorporar essas dependências dentro do seu projeto e importá-las em seu "assets/js/app.js" usando um caminho relativo:

   ```javascript
   import topbar from "../vendor/topbar"
   ```

2. Chamar `npm install topbar --prefix assets` criará `package.json` e `package-lock.json` dentro do diretório assets e o `esbuild` poderá detectá-los automaticamente:

   ```javascript
   import topbar from "topbar"
   ```

3. Usar o Mix para rastrear a dependência de um repositório fonte:

   ```elixir
   # mix.exs
   {:topbar, github: "buunguyen/topbar", app: false, compile: false}
   ```

   Execute `mix deps.get` para buscar a dependência e então importe-a:

   ```javascript
   import topbar from "topbar"
   ```

   Novas aplicações usam essa terceira abordagem para importar Heroicons, evitando
   incorporar uma cópia de todos os ícones quando você pode usar apenas alguns ou mesmo nenhum,
   evitando Node.js e `npm`, e rastreando uma versão explícita que é fácil de
   atualizar graças ao Mix. É importante notar que dependências git não podem
   ser usadas por pacotes Hex, então se você pretende publicar seu projeto no Hex,
   considere incorporar os arquivos.

Note que se você usar gerenciadores de pacotes JS de terceiros, pode precisar ajustar suas etapas de implantação
para incluir adequadamente os pacotes. Se você estiver usando `mix phx.gen.release --docker`, dê uma olhada na
[documentação](Mix.Tasks.Phx.Gen.Release.html#module-docker) para mais detalhes.

## Imagens, fontes e arquivos externos

Se você referenciar um arquivo externo em seus arquivos CSS ou JavaScript, o `esbuild` tentará validar e gerenciar esses arquivos, a menos que seja instruído de outra forma.

Por exemplo, imagine que você quer referenciar `priv/static/images/bg.png`, servido em `/images/bg.png`, do seu arquivo CSS:

```css
body {
  background-image: url(/images/bg.png);
}
```

O código acima pode falhar com a seguinte mensagem:

```text
error: Could not resolve "/images/bg.png" (mark it as external to exclude it from the bundle)
```

Dado que as imagens já são gerenciadas pelo Phoenix, você precisa marcar todos os recursos de `/images` (e também `/fonts`) como externos, como diz a mensagem de erro. Isso é o que o Phoenix faz por padrão para novos aplicativos desde v1.6.1+. No seu `config/config.exs`, você encontrará:

```elixir
args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
```

Se você precisar referenciar outros diretórios, você precisa atualizar os argumentos acima adequadamente. Note que executar `mix phx.digest` criará arquivos digeridos para todos os assets em `priv/static`, então suas imagens e fontes ainda terão cache-busting.

## Plugins do Esbuild

A configuração padrão do `esbuild` do Phoenix (via wrapper Elixir) não permite que você use [plugins do esbuild](https://esbuild.github.io/plugins/). Se você quiser usar um plugin do esbuild, por exemplo para compilar arquivos SASS para CSS, você pode substituir o sistema de build padrão por um script de build personalizado.

O seguinte é um exemplo de uma build personalizada usando esbuild via Node.js. Primeiro, você precisará instalar o Node.js em desenvolvimento e disponibilizá-lo para sua etapa de build de produção.

Então você precisará adicionar `esbuild` aos seus pacotes Node.js e aos pacotes Phoenix. Dentro do diretório `assets`, execute:

```console
$ npm install esbuild --save-dev
$ npm install ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view --save
```

ou, para Yarn:

```console
$ yarn add --dev esbuild
$ yarn add ../deps/phoenix ../deps/phoenix_html ../deps/phoenix_live_view
```

Em seguida, adicione um script de build JavaScript personalizado. Vamos chamar o exemplo de `assets/build.js`:

```javascript
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const deploy = args.includes('--deploy');

const loader = {
  // Adicione loaders para imagens/fontes/etc, ex: { '.svg': 'file' }
};

const plugins = [
  // Adicione e configure plugins aqui
];

// Define as opções do esbuild
let opts = {
  entryPoints: ["js/app.js"],
  bundle: true,
  logLevel: "info",
  target: "es2022",
  outdir: "../priv/static/assets",
  external: ["*.css", "fonts/*", "images/*"],
  nodePaths: ["../deps"],
  loader: loader,
  plugins: plugins,
};

if (deploy) {
  opts = {
    ...opts,
    minify: true,
  };
}

if (watch) {
  opts = {
    ...opts,
    sourcemap: "inline",
  };
  esbuild
    .context(opts)
    .then((ctx) => {
      ctx.watch();
    })
    .catch((_error) => {
      process.exit(1);
    });
} else {
  esbuild.build(opts);
}
```

Este script cobre os seguintes casos de uso:

- `node build.js`: compila para desenvolvimento e teste (útil em CI)
- `node build.js --watch`: como acima, mas observa mudanças continuamente
- `node build.js --deploy`: compila assets minificados para produção

Modifique o `config/dev.exs` para que o script seja executado sempre que você alterar arquivos, substituindo a configuração existente de `:esbuild` em `watchers`:

```elixir
config :hello, HelloWeb.Endpoint,
  ...
  watchers: [
    node: ["build.js", "--watch", cd: Path.expand("../assets", __DIR__)]
  ],
  ...
```

Modifique a tarefa `aliases` em `mix.exs` para instalar pacotes `npm` durante `mix setup` e usar o novo `esbuild` em `mix assets.deploy`:

```elixir
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      ...,
      "assets.deploy": ["cmd --cd assets node build.js --deploy", "phx.digest"]
    ]
  end
```

Finalmente, remova a configuração do `esbuild` do `config/config.exs` e remova a dependência da função `deps` no seu `mix.exs`, e está pronto!

## Ferramentas de build JS alternativas

Se você estiver escrevendo uma API ou quiser usar outra ferramenta de build de asset, você pode querer remover o pacote Hex `esbuild` (veja os passos abaixo). Então você deve seguir as etapas adicionais exigidas pela ferramenta de terceiros.

### Remover esbuild

1. Remova a configuração do `esbuild` em `config/config.exs` e `config/dev.exs`,
2. Remova a tarefa `assets.deploy` definida em `mix.exs`,
3. Remova a dependência `esbuild` de `mix.exs`,
4. Desbloqueie a dependência `esbuild`:

```console
$ mix deps.unlock esbuild
```

## Frameworks CSS alternativos

Por padrão, o Phoenix gera CSS com a biblioteca `tailwind` e seus plugins padrão.

Se você quiser usar plugins `tailwind` externos ou outro framework CSS, você deve substituir o pacote Hex `tailwind` (veja os passos abaixo). Então você pode usar um plugin `esbuild` (como descrito acima) ou até mesmo trazer um framework completamente separado.

### Remover tailwind

1. Remova a configuração do `tailwind` em `config/config.exs` e `config/dev.exs`,
2. Remova a tarefa `assets.deploy` definida em `mix.exs`,
3. Remova a dependência `tailwind` de `mix.exs`,
4. Desbloqueie a dependência `tailwind`:

```console
$ mix deps.unlock tailwind
```

Você pode opcionalmente remover e excluir a dependência `heroicons` também.
