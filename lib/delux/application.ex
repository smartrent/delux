defmodule Delux.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    # Optionally start Delux if configured in the application
    # environment

    apply_dt_overlays()

    children =
      case Application.get_all_env(:delux) do
        [] -> []
        config -> [{Delux, config}]
      end

    opts = [strategy: :one_for_one, name: Delux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp apply_dt_overlays() do
    config = Application.get_env(:delux, :dt_overlays, [])

    Enum.each(config[:pins] || [], fn {label, pin} ->
      args = [config[:overlays_path], "label=#{label}", "gpio=#{pin}"]
      System.cmd("dtoverlay", args)
    end)
  end
end
