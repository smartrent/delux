defmodule Delux do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.fetch!(1)
  use GenServer

  alias Delux.Effects
  alias Delux.Glue
  alias Delux.Program

  @default_slot :status
  @default_slots [:status, :notification, :user_feedback]

  @default_indicator :default
  @default_indicator_config %{default: %{}}

  @default_led_path "/sys/class/leds"

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

  * `:led_path` - the path to the LED directories (defaults to `"/sys/class/leds"`)
  * `:slots` - a list of slot atoms from lowest to highest priority. Defaults to `[:status, :notification, :user_feedback]`
  * `:indicators` - a map of indicator names to their configurations
  * `:name` - register the Delux GenServer using this name. Defaults to `Delux`. Specify `nil` to not register a name.
  """
  @type options() :: [
          led_path: String.t(),
          slots: [slot()],
          indicators: %{indicator_name() => indicator_config()},
          name: atom() | nil
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

  @typedoc false
  @type state() :: %{
          glue: %{indicator_name() => Glue.state()},
          slots: [slot()],
          brightness: 0..100,
          active: %{slot() => %{indicator_name() => Program.t()}},
          all_off: %{indicator_name() => Program.t()},
          timers: %{slot() => {reference(), reference()}},
          indicator_names: [indicator_name()]
        }

  @impl GenServer
  def init(options) do
    slots = options[:slots] || options[:priorities] || @default_slots
    indicator_configs = options[:indicators] || @default_indicator_config
    led_path = options[:led_path] || @default_led_path

    off = Effects.off()
    all_off = for {name, _config} <- indicator_configs, do: {name, off}

    state = %{
      glue: open_indicators(led_path, indicator_configs),
      indicator_names: Map.keys(indicator_configs),
      slots: slots,
      active: %{},
      brightness: 100,
      all_off: Map.new(all_off),
      timers: %{}
    }

    refresh_indicators(state)

    {:ok, state}
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
    new_state = %{state | brightness: percent}
    refresh_indicators(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:info, indicator}, _from, state) do
    summarized = summarize_programs(state)

    result =
      case summarized[indicator] do
        nil ->
          {:error,
           %ArgumentError{
             message:
               "Invalid indicator #{inspect(indicator)}. Valid indicators #{inspect(Map.keys(summarized))}"
           }}

        program ->
          {:ok, Program.ansi_description(program)}
      end

    {:reply, result, state}
  end

  defp remove_nil_values(m) do
    for {k, v} <- m, v != nil, reduce: %{} do
      acc -> Map.put(acc, k, v)
    end
  end

  defp merge_indicator_program(nil, new_mapping), do: remove_nil_values(new_mapping)

  defp merge_indicator_program(current_mapping, new_mapping) do
    current_mapping |> Map.merge(new_mapping) |> remove_nil_values()
  end

  defp do_render(state, slot, indicators) do
    with :ok <- check_slot(slot, state),
         :ok <- check_indicator_programs(indicators, state) do
      merged_indicators = merge_indicator_program(Map.get(state.active, slot), indicators)

      new_active = Map.put(state.active, slot, merged_indicators)
      new_state = %{state | active: new_active}

      refresh_indicators(new_state)

      new_timers = start_timer(state.timers, slot, merged_indicators)

      {:ok, %{new_state | timers: new_timers}}
    end
  end

  defp check_slot(slot, state) do
    if slot in state.slots do
      :ok
    else
      {:error,
       %ArgumentError{
         message: "Invalid slot #{inspect(slot)}. Valid slots: #{inspect(state.slots)}"
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

  defp find_max_duration(indicators) when map_size(indicators) == 0, do: :infinity

  defp find_max_duration(indicators) do
    durations = for {_indicator, program} <- indicators, do: program.duration
    Enum.max(durations)
  end

  defp start_timer(timers, slot, indicators) do
    duration = find_max_duration(indicators)

    if duration != :infinity do
      ref = make_ref()

      timer_ref = Process.send_after(self(), {:clear, slot, ref}, duration)

      case Map.get(timers, slot) do
        {old_timer_ref, _ref} ->
          _ = Process.cancel_timer(old_timer_ref)
          :ok

        _ ->
          :ok
      end

      Map.put(timers, slot, {timer_ref, ref})
    else
      timers
    end
  end

  defp do_clear(state, slot) do
    with :ok <- check_slot(slot, state) do
      new_active = Map.delete(state.active, slot)
      new_state = %{state | active: new_active}

      refresh_indicators(new_state)

      {:ok, new_state}
    end
  end

  @spec summarize_programs(state()) :: %{indicator_name() => Program.t()}
  defp summarize_programs(state) do
    Enum.reduce(state.slots, state.all_off, fn slot, acc ->
      case Map.fetch(state.active, slot) do
        {:ok, indicator_programs} -> Map.merge(acc, indicator_programs)
        :error -> acc
      end
    end)
  end

  defp refresh_indicators(state) do
    summarized = summarize_programs(state)

    Enum.reduce(summarized, state.glue, fn {indicator, program}, glue_state ->
      indicator_state = glue_state[indicator]
      {compiled, _duration} = Glue.compile_program!(indicator_state, program, state.brightness)

      new_indicator_state = Glue.set_program(indicator_state, compiled)
      Map.put(glue_state, indicator, new_indicator_state)
    end)
  end

  @impl GenServer
  def handle_info({:clear, slot, ref}, state) do
    case Map.get(state.timers, slot) do
      {_timer_ref, ^ref} ->
        new_timers = Map.delete(state.timers, slot)
        new_active = Map.delete(state.active, slot)
        new_state = %{state | active: new_active, timers: new_timers}

        refresh_indicators(new_state)
        {:noreply, new_state}

      _ ->
        # Old timeout message - ignore
        {:noreply, state}
    end
  end

  defp open_indicators(led_path, indicator_configs) do
    for {name, config} <- indicator_configs, reduce: %{} do
      acc -> Map.put(acc, name, Glue.open(led_path, config[:red], config[:green], config[:blue]))
    end
  end
end
