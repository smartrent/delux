defmodule Delux.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    # Optionally start Delux if configured in the application
    # environment

    children =
      case Application.get_all_env(:delux) do
        [] -> []
        config -> [{Delux, config}]
      end

    opts = [strategy: :one_for_one, name: Delux.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
