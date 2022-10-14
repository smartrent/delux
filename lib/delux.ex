defmodule Delux do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.fetch!(1)
  use GenServer

  alias Delux.Backend
  alias Delux.Effects
  alias Delux.Pattern
  alias Delux.Program

  @default_slot :status
  @default_slots [:status, :notification, :user_feedback]

  @default_indicator :default
  @default_indicator_config %{default: %{}}

  @typedoc """
  A name of a slot for an indicator program

  Slots determine which program is rendered when more than one can be
  shown at the same time. The default slot is `:status` which is also the
  lowest priority slot. The `:notification` and `:user_feedback` slots are
  higher priority. For example, rendering visual feedback to the user pressing a button
  can be assigned to the `:user_feedback` slot so the user knows that the
  button pressed worked regardless of what else is happening.
  """
  @type slot() :: atom()

  @typedoc """
  The name for one indicator

  An indicator may be composed of multiple LEDs, but they're arranged such that
  it looks like one light source to someone looking at it. For example, an RGB
  LED has 3 LEDs inside of it.

  These can be anything you want. If you don't explicitly specify indicator
  names, an indicator named `:default` is used.
  """
  @type indicator_name() :: atom()

  @typedoc """
  Configuration for an indicator

  Specify the Linux LED name for each LED. Single LED indicators should use a
  color that's close or just choose `:red`.
  """
  @type indicator_config() :: %{
          optional(:red) => String.t(),
          optional(:green) => String.t(),
          optional(:blue) => String.t()
        }

  @typedoc """
  Delux configuration options

  * `:indicators` - a map of indicator names to their configurations
  * `:slots` - a list of slot atoms from lowest to highest priority. Defaults to `[:status, :notification, :user_feedback]`
  * `:name` - register the Delux GenServer using this name. Defaults to `Delux`. Specify `nil` to not register a name.
  * `:backend` - options for the backend
    * `:led_path` - the path to the LED directories (defaults to `"/sys/class/leds"`)
    * `:hz` - the Linux kernel's `HZ` setting. Delux will adjust its timing based on this setting (defaults to 1000)
  """
  @type options() :: [
          led_path: String.t(),
          slots: [slot()],
          indicators: %{indicator_name() => indicator_config()},
          name: atom() | nil,
          backend: keyword()
        ]

  @doc """
  Start an Delux GenServer

  See `t:options()` for configuration options
  """
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(options) do
    genserver_options =
      case Keyword.fetch(options, :name) do
        {:ok, nil} -> []
        {:ok, name} -> [name: name]
        :error -> [name: __MODULE__]
      end

    GenServer.start_link(__MODULE__, options, genserver_options)
  end

  @doc """
  Helper for rendering a program when using Delux's defaults

  This calls `render/3` using the default Delux GenServer and default slot.
  """
  @spec render(%{indicator_name() => Program.t() | nil} | Program.t() | nil) :: :ok
  def render(program) when is_map(program) or is_nil(program) do
    render(__MODULE__, program, @default_slot)
  end

  @doc """
  Helper for rendering a program to a slot

  This calls `render/3` using the default Delux GenServer.
  """
  @spec render(%{indicator_name() => Program.t() | nil} | Program.t() | nil, slot()) :: :ok
  def render(program, slot) when (is_map(program) or is_nil(program)) and is_atom(slot) do
    render(__MODULE__, program, slot)
  end

  @doc """
  Update one or more indicators to a new program

  Passing `nil` for the program removes the program running in the specified
  slot. This is the same as calling `clear/2`.
  """
  @spec render(
          GenServer.server(),
          %{indicator_name() => Program.t() | nil} | Program.t() | nil,
          slot()
        ) :: :ok

  def render(server, %Program{} = program, slot) when is_atom(slot) do
    with {:error, reason} <-
           GenServer.call(server, {:render, slot, %{@default_indicator => program}}) do
      raise reason
    end
  end

  def render(server, indicator_program_map, slot)
      when is_map(indicator_program_map) and is_atom(slot) do
    with {:error, reason} <-
           GenServer.call(server, {:render, slot, indicator_program_map}) do
      raise reason
    end
  end

  def render(server, nil, slot) when is_atom(slot) do
    clear(server, slot)
  end

  @doc """
  Clear out all programs in the specified slot

  The indicator is turned off if there are no programs in any slot.
  """
  @spec clear(GenServer.server(), slot()) :: :ok
  def clear(server \\ __MODULE__, slot \\ @default_slot) when is_atom(slot) do
    with {:error, reason} <- GenServer.call(server, {:clear, slot}) do
      raise reason
    end
  end

  @doc """
  Adjust the overall brightness of all indicators

  Effects are adjusted based on the value passed.

  NOTE: This is not fully supported yet!
  """
  @spec adjust_brightness(GenServer.server(), 0..100) :: :ok
  def adjust_brightness(server \\ __MODULE__, percent) when percent >= 0 and percent <= 100 do
    GenServer.call(server, {:adjust_brightness, percent})
  end

  @doc """
  Call `info/2` with the defaults
  """
  @spec info() :: :ok
  def info(), do: info(__MODULE__, @default_indicator)

  @doc """
  Call `info/2` with the specified indicator
  """
  @spec info(indicator_name()) :: :ok
  def info(indicator), do: info(__MODULE__, indicator)

  @doc """
  Print out info about an indicator

  This is handy when you can't physically see an indicator. It's intended for
  users at the IEx prompt. For programmatic use, see `info_as_ansidata/2`.
  """
  @spec info(GenServer.server(), indicator_name()) :: :ok
  def info(server, indicator) do
    info_as_ansidata(server, indicator) |> IO.ANSI.format() |> IO.puts()
  end

  @doc """
  Call `info_as_ansidata/2` with the defaults
  """
  @spec info_as_ansidata() :: IO.ANSI.ansidata()
  def info_as_ansidata(), do: info_as_ansidata(__MODULE__, @default_indicator)

  @doc """
  Call `info_as_ansidata/2` with the specified indicator
  """
  @spec info_as_ansidata(indicator_name()) :: IO.ANSI.ansidata()
  def info_as_ansidata(indicator), do: info_as_ansidata(__MODULE__, indicator)

  @doc """
  Return user-readable information about an indicator
  """
  @spec info_as_ansidata(GenServer.server(), indicator_name()) :: IO.ANSI.ansidata()
  def info_as_ansidata(server, indicator) do
    case GenServer.call(server, {:info, indicator}) do
      {:ok, result} -> result
      {:error, reason} -> raise reason
    end
  end

  @typep entry() ::
           {non_neg_integer(), Pattern.milliseconds(), Delux.indicator_name(), Program.t()}

  @typedoc false
  @type state() :: %{
          indicator_names: [indicator_name()],
          backend: %{indicator_name() => Backend.state()},
          slot_to_priority: %{slot() => non_neg_integer()},
          brightness: 0..100,
          active: [entry()],
          current: %{indicator_name() => entry()},
          refresh_time: integer() | :infinity
        }

  @impl GenServer
  def init(options) do
    slots = options[:slots] || options[:priorities] || @default_slots
    indicator_configs = options[:indicators] || @default_indicator_config
    backend_config = options[:backend] || []

    state = %{
      indicator_names: Map.keys(indicator_configs),
      backend: open_indicators(backend_config, indicator_configs),
      slot_to_priority: slots |> Enum.reverse() |> Enum.with_index() |> Map.new(),
      active: [],
      brightness: 100,
      current: %{},
      refresh_time: :infinity
    }

    {:ok, refresh_indicators(state)}
  end

  @impl GenServer
  def handle_call({:render, slot, indicators}, _from, state) do
    case do_render(state, slot, indicators) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:clear, slot}, _from, state) do
    case do_clear(state, slot) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:adjust_brightness, percent}, _from, state) do
    new_state = %{state | brightness: percent} |> refresh_indicators()

    {:reply, :ok, new_state}
  end

  def handle_call({:info, indicator}, _from, state) do
    result =
      if indicator in state.indicator_names do
        {_priority, _start_time, _indicator, program} = best_entry(state.active, indicator)

        {:ok, Program.ansi_description(program)}
      else
        {:error,
         %ArgumentError{
           message:
             "Invalid indicator #{inspect(indicator)}. Valid indicators #{inspect(state.indicator_names)}"
         }}
      end

    {:reply, result, state}
  end

  defp do_render(state, slot, indicators) do
    with {:ok, priority} <- slot_to_priority(slot, state),
         :ok <- check_indicator_programs(indicators, state) do
      start_time_ms = System.monotonic_time(:millisecond)

      entries =
        for {indicator, program} <- indicators, do: {priority, start_time_ms, indicator, program}

      merged_entries = merge_entries_at_priority(priority, state.active, entries)
      new_state = %{state | active: merged_entries} |> refresh_indicators()

      {:ok, new_state}
    end
  end

  # Clear out the specified priority. Since the list is in order, this stops when done.
  defp clear_entries_at_priority(p, [{p, _os, _oi, _op} | rest]) do
    clear_entries_at_priority(p, rest)
  end

  defp clear_entries_at_priority(p, [{p2, _os, _oi, _op} = entry | rest]) when p > p2 do
    [entry | clear_entries_at_priority(p, rest)]
  end

  defp clear_entries_at_priority(_p, entries) do
    entries
  end

  defp merge_entries_at_priority(p, [{p, _os, i, _op} = entry | rest], new_entries) do
    # check if indicator in set of new_entries
    if Enum.any?(new_entries, fn {_, _, indicator, _} -> indicator == i end) do
      merge_entries_at_priority(p, rest, new_entries)
    else
      [entry | merge_entries_at_priority(p, rest, new_entries)]
    end
  end

  defp merge_entries_at_priority(p, [{p2, _os, _oi, _op} = entry | rest], new_entries)
       when p > p2 do
    [entry | merge_entries_at_priority(p, rest, new_entries)]
  end

  defp merge_entries_at_priority(_p, entries, new_entries) do
    # nil programs are used to selectively remove programs running on an indicator
    # at a specific priority. They need to be in the new_entries list to filter
    # existing programs, but shouldn't be added.
    non_nil_entries = Enum.filter(new_entries, fn {_, _, _, program} -> program end)
    non_nil_entries ++ entries
  end

  defp slot_to_priority(slot, state) do
    with :error <- Map.fetch(state.slot_to_priority, slot) do
      {:error,
       %ArgumentError{
         message:
           "Invalid slot #{inspect(slot)}. Valid slots: #{inspect(Map.keys(state.slot_to_priority))}"
       }}
    end
  end

  defp check_indicator_programs(indicators, state) do
    names = Map.keys(indicators)

    case Enum.find(names, fn name -> name not in state.indicator_names end) do
      nil ->
        :ok

      name ->
        {:error,
         %ArgumentError{
           message:
             "Invalid indicator #{inspect(name)}. Valid indicators: #{inspect(state.indicator_names)}"
         }}
    end
  end

  defp do_clear(state, slot) do
    with {:ok, priority} <- slot_to_priority(slot, state) do
      new_active = clear_entries_at_priority(priority, state.active)
      new_state = %{state | active: new_active}

      {:ok, refresh_indicators(new_state)}
    end
  end

  defp best_entry([], indicator_name) do
    {99, 0, indicator_name, Effects.off()}
  end

  defp best_entry([{_p, _start_time, indicator_name, _program} = entry | _rest], indicator_name) do
    entry
  end

  defp best_entry([_entry | rest], indicator_name) do
    best_entry(rest, indicator_name)
  end

  defp pop_entry([{_p, _start_time, indicator_name, _program} | rest], indicator_name) do
    rest
  end

  defp pop_entry([entry | rest], indicator_name) do
    [entry | pop_entry(rest, indicator_name)]
  end

  defp refresh_indicators(state) do
    current_time = System.monotonic_time(:millisecond)

    new_state =
      Enum.reduce(state.indicator_names, state, &refresh_indicator(&2, &1, current_time))

    if new_state.refresh_time != :infinity do
      _ = Process.send_after(self(), :refresh, new_state.refresh_time, abs: true)
      :ok
    end

    new_state
  end

  defp refresh_indicator(state, indicator_name, current_time) do
    entry = best_entry(state.active, indicator_name)

    case state.current[indicator_name] do
      {^entry, end_time} ->
        # Currently running this entry. Check if timed out.
        if current_time > end_time do
          new_state = %{
            state
            | active: pop_entry(state.active, indicator_name),
              current: Map.delete(state.current, indicator_name)
          }

          refresh_indicator(new_state, indicator_name, current_time)
        else
          %{state | refresh_time: min(state.refresh_time, end_time)}
        end

      _ ->
        # Different entry than what's currently running
        {_priority, start_time, _indicator, program} = entry
        indicator_state = state.backend[indicator_name]
        compiled = Backend.compile(indicator_state, program, state.brightness)

        time_left = Backend.run(indicator_state, compiled, start_time - current_time)

        cond do
          time_left <= 0 ->
            # Timed out entry, so try again
            new_state = %{
              state
              | active: pop_entry(state.active, indicator_name),
                current: Map.delete(state.current, indicator_name)
            }

            refresh_indicator(new_state, indicator_name, current_time)

          time_left == :infinity ->
            %{state | current: Map.put(state.current, indicator_name, {entry, :infinity})}

          true ->
            end_time = current_time + time_left

            %{
              state
              | refresh_time: min(state.refresh_time, end_time),
                current: Map.put(state.current, indicator_name, {entry, end_time})
            }
        end
    end
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    {:noreply, refresh_indicators(state)}
  end

  defp open_indicators(backend_config, indicator_configs) do
    for {name, config} <- indicator_configs, reduce: %{} do
      acc ->
        combined_config = Map.merge(Map.new(backend_config), Map.new(config))
        Map.put(acc, name, Backend.open(combined_config))
    end
  end
end
