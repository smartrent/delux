defmodule Delux.Backend.AsciiArtServer do
  @moduledoc """
  Renderer for all ASCII Art indicators
  """
  use GenServer

  @ansi_push_state "\e[s"
  @ansi_pop_state "\e[u"
  @ansi_move_upper_left "\e[1;1H"

  defstruct [:gl, :indicators]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server)
  end

  @spec update(atom() | String.t(), tuple()) :: :ok
  def update(indicator_name, rgb) do
    GenServer.call(__MODULE__, {:update, indicator_name, rgb})
  end

  @impl GenServer
  def init(_opts) do
    {:ok, %__MODULE__{indicators: %{}, gl: Process.group_leader()}}
  end

  @impl GenServer
  def handle_call({:update, name, rgb}, _from, state) do
    new_indicators = Map.put(state.indicators, name, rgb)

    {:reply, :ok, %{state | indicators: new_indicators}, 50}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    render(state)

    {:noreply, state}
  end

  defp render(state) do
    str =
      state.indicators
      |> Enum.sort()
      |> Enum.map(&render_one/1)
      |> Enum.intersperse([IO.ANSI.reset(), " | "])

    IO.write(state.gl, [
      @ansi_push_state,
      @ansi_move_upper_left,
      IO.ANSI.clear_line(),
      str,
      IO.ANSI.reset(),
      @ansi_pop_state
    ])
  end

  defp render_one({name, rgb}) do
    [ansi(rgb), to_string(name)]
  end

  defp ansi({0, 0, 0}), do: IO.ANSI.black()
  defp ansi({0, 0, 1}), do: IO.ANSI.light_blue()
  defp ansi({0, 1, 0}), do: IO.ANSI.light_green()
  defp ansi({0, 1, 1}), do: IO.ANSI.light_cyan()
  defp ansi({1, 0, 0}), do: IO.ANSI.light_red()
  defp ansi({1, 0, 1}), do: IO.ANSI.light_magenta()
  defp ansi({1, 1, 0}), do: IO.ANSI.light_yellow()
  defp ansi({1, 1, 1}), do: IO.ANSI.white()
end
