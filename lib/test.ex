defmodule Test do
  @moduledoc """
  A module to demonstrate split-screen effect using ANSI control sequences.
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def init(opts) do
    {:ok, _} = :timer.send_interval(100, :tick)
    {:ok, %{gl: opts[:gl] || Process.group_leader(), count: 0}}
  end

  def handle_info(:tick, state) do
    print_top(state.gl, "Hello #{state.count}")
    {:noreply, %{state | count: state.count + 1}}
  end

  @doc """
  Prints text to the top half of the screen.
  """
  def print_top(gl, text) do
    # Move to the first line and clear it
    IO.write(gl, [
      "\e[s\e[1;1H",
      IO.ANSI.reverse(),
      IO.ANSI.clear_line(),
      text,
      "\e[u",
      IO.ANSI.reset()
    ])
  end

  def swap_gl() do
    old = Process.group_leader()
    gl = :group.start(self(), {IEx, :start, []})
    Process.group_leader(self(), gl)
    old
  end

  def swap_gl2() do
    old = Process.group_leader()
    user = Process.whereis(:user)
    Process.group_leader(self(), user)
    old
  end
end
