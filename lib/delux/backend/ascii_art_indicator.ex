defmodule Delux.Backend.AsciiArtIndicator do
  @moduledoc """
  Program runner for one ASCII art indicator
  """
  use GenServer
  alias Delux.Backend.AsciiArtServer

  defstruct [:name, :program, :red, :green, :blue, :r_time, :g_time, :b_time, :rgb, :gl]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server)
  end

  @spec run(GenServer.server(), Delux.Pattern.t()) :: :ok
  def run(server, pattern) do
    GenServer.call(server, {:run, pattern})
  end

  @impl GenServer
  def init(opts) do
    {:ok, _ref} = :timer.send_interval(100, :tick)
    {:ok, %__MODULE__{name: opts[:name] || "#{inspect(self())}", gl: opts[:gl]}}
  end

  @impl GenServer
  def handle_call({:run, program}, _from, state) do
    IO.puts("Run #{inspect(program)}")

    new_state =
      %{
        state
        | program: program,
          red: program.red,
          green: program.green,
          blue: program.blue,
          r_time: 0,
          g_time: 0,
          b_time: 0
      }
      |> run_step()
      |> render()

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    new_state =
      %{
        state
        | r_time: state.r_time + 100,
          g_time: state.g_time + 100,
          b_time: state.b_time + 100
      }
      |> run_step()
      |> render()

    {:noreply, new_state}
  end

  defp render(state) do
    AsciiArtServer.update(state.name, state.rgb)

    state
  end

  defp run_step(%{program: program} = state) when program != nil do
    {red, r_time, r} = value(state.red, state.r_time)
    {green, g_time, g} = value(state.green, state.g_time)
    {blue, b_time, b} = value(state.blue, state.b_time)

    %{
      state
      | red: red,
        green: green,
        blue: blue,
        r_time: r_time,
        g_time: g_time,
        b_time: b_time,
        rgb: {r, g, b}
    }
  end

  defp run_step(state) do
    state
  end

  defp value([{v1, t1}, {v2, _t2} | _rest] = p, time) when time < t1 do
    {p, time, round((v1 * (t1 - time) + v2 * time) / t1)}
  end

  defp value([{v1, t1} | rest], time) do
    value(rest ++ [{v1, t1}], time - t1)
  end
end
