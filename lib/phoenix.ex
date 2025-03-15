defmodule Phoenix do
  @moduledoc """
  Este é o documento para o projeto Phoenix.

  Para começar, consulte seu [guia de overview](overview.html).
  """
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines()
    _ = Phoenix.Template.format_encoder("index.html")
    warn_on_missing_json_library()

    # Configure proper system flags from Phoenix only
    if stacktrace_depth = Application.get_env(:phoenix, :stacktrace_depth) do
      :erlang.system_flag(:backtrace_depth, stacktrace_depth)
    end

    if Application.fetch_env!(:phoenix, :logger) do
      Phoenix.Logger.install()
    end

    children = [
      # Code reloading must be serial across all Phoenix apps
      Phoenix.CodeReloader.Server,
      {DynamicSupervisor, name: Phoenix.Transports.LongPoll.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Phoenix.Supervisor)
  end

  @doc """
  Retorna a biblioteca de codificação JSON configurada para o Phoenix.

  Para personalizar a biblioteca JSON, inclua o seguinte
  no seu `config/config.exs`:

      config :phoenix, :json_library, AlternativeJsonLibrary

  """
  def json_library do
    Application.get_env(:phoenix, :json_library, Jason)
  end

  @doc """
  Retorna o `:plug_init_mode` que controla quando os plugs são
  inicializados.

  Recomendamos configurá-lo como `:runtime` em desenvolvimento para
  melhorias no tempo de compilação. Deve ser `:compile` em
  produção (o padrão).

  Esta opção é passada como `:init_mode` para `Plug.Builder.compile/3`.
  """
  def plug_init_mode do
    Application.get_env(:phoenix, :plug_init_mode, :compile)
  end

  defp warn_on_missing_json_library do
    configured_lib = Application.get_env(:phoenix, :json_library)

    if configured_lib && not Code.ensure_loaded?(configured_lib) do
      IO.warn """
      found #{inspect(configured_lib)} in your application configuration
      for Phoenix JSON encoding, but module #{inspect(configured_lib)} is not available.
      Ensure #{inspect(configured_lib)} is listed as a dependency in mix.exs.
      """
    end
  end
end
