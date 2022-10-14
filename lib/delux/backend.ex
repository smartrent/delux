defmodule Delux.Backend do
  @moduledoc false

  alias Delux.Pattern
  alias Delux.Program

  @type state() :: %{
          red: File.io_device() | nil,
          green: File.io_device() | nil,
          blue: File.io_device() | nil,
          red_max: pos_integer(),
          green_max: pos_integer(),
          blue_max: pos_integer(),
          comp: function()
        }

  @typedoc false
  @type compiled() :: {nil | iodata(), nil | iodata(), nil | iodata(), Pattern.milliseconds()}

  @default_led_path "/sys/class/leds"

  @led_off "0 3600000 0 0"

  @doc """
  Open and prep file handles for writing patterns

  Options:
  * `:red` - the name of the red LED if it exists
  * `:green` - the name of the green LED if it exists
  * `:blue` - the name of the blue LED if it exists
  * `:led_path` - the path to the LED files if using a nonstandard path (`"/sys/class/leds"`)
  * `:hz` - the Linux HZ configuration setting. Valid choices are 0, 100, 250, 300, 1000. Defaults
    to 1000. 0 means no adjustments for the HZ settings.
  """
  @spec open(keyword() | map()) :: state()
  def open(options) do
    led_path = options[:led_path] || @default_led_path
    comp = options[:hz] |> validate_hz()

    red = options[:red]
    green = options[:green]
    blue = options[:blue]

    {red_handle, red_max} = init_handle(led_path, red)
    {green_handle, green_max} = init_handle(led_path, green)
    {blue_handle, blue_max} = init_handle(led_path, blue)

    %{
      comp: comp,
      red: red_handle,
      green: green_handle,
      blue: blue_handle,
      red_max: red_max,
      green_max: green_max,
      blue_max: blue_max
    }
  end

  defp validate_hz(1000), do: &hz_comp_1000/1
  defp validate_hz(300), do: &hz_comp_300/1
  defp validate_hz(250), do: &hz_comp_250/1
  defp validate_hz(100), do: &hz_comp_100/1
  defp validate_hz(0), do: &hz_comp_none/1
  defp validate_hz(nil), do: &hz_comp_1000/1

  @doc """
  Compile an indicator program so that it can be run efficiently later
  """
  @spec compile(state(), Program.t(), 0..100) :: compiled()
  def compile(%{} = state, %Program{} = program, percent) do
    # Process the patterns for brightness adjustments and convert to iodata
    {r, r_duration} =
      maybe_prep_iodata(state.red, program.red, percent, state.red_max, state.comp, program.mode)

    {g, g_duration} =
      maybe_prep_iodata(
        state.green,
        program.green,
        percent,
        state.green_max,
        state.comp,
        program.mode
      )

    {b, b_duration} =
      maybe_prep_iodata(
        state.blue,
        program.blue,
        percent,
        state.blue_max,
        state.comp,
        program.mode
      )

    duration =
      case program.mode do
        :simple_loop -> :infinity
        :one_shot -> min(min(r_duration, g_duration), b_duration)
      end

    {r, g, b, duration}
  end

  @doc """
  Run a compiled program at the specified time offset

  This returns the amount of time left.

  NOTE: Specifying a time offset isn't supported yet.
  """
  @spec run(state(), compiled(), Pattern.milliseconds()) :: Pattern.milliseconds() | :infinity
  def run(%{} = state, {r, g, b, duration}, _time_offset) do
    # Write RGB as close together as possible to keep them close to in sync
    maybe_write!(state.red, r)
    maybe_write!(state.green, g)
    maybe_write!(state.blue, b)

    duration
  end

  defp maybe_write!(nil, _data), do: :ok
  defp maybe_write!(handle, data), do: :ok = IO.binwrite(handle, data)

  defp maybe_prep_iodata(nil, _sequence, _percent, _max_brightness, _res, _mode),
    do: {nil, Pattern.forever_ms()}

  defp maybe_prep_iodata(_handle, sequence, percent, max_brightness, res, mode) do
    sequence
    |> Pattern.pwm(percent)
    |> pattern_to_iodata(max_brightness, res)
    |> append_trailer(mode)
  end

  @doc """
  Convert a pattern to iodata

  * `pattern` - the pattern to convert
  * `max_b` - the max brightness supported by the LED (usually 1 or 255)
  * `comp` - a function for converting durations to values to pass to Linux
    and actual durations

  Returns a tuple with the iodata and total duration
  """
  @spec pattern_to_iodata(Pattern.t(), non_neg_integer(), function()) ::
          {iolist(), non_neg_integer()}
  def pattern_to_iodata(pattern, max_b, comp) do
    build(pattern, max_b, comp, [], 0)
  end

  defp build([], _max_b, _comp, acc, total) do
    {acc, total}
  end

  defp build([{component, duration} | rest], max_b, comp, acc, total) do
    brightness = round(component * max_b)
    {linux_duration, predicted_duration} = comp.(duration)
    new_total = predicted_duration + total
    new_acc = [acc, [to_string(brightness), " ", to_string(linux_duration), " "]]
    build(rest, max_b, comp, new_acc, new_total)
  end

  # The hz_comp_n/1 functions return {linux_duration, predicted_duration}
  # The linux_duration is what you tell Linux to get a duration close to what you want.
  # The predicted_duration is what you'll actually get.
  # These conversions where determined by measuring the output on an otherwise idle
  # device using a logic analyzer. The fit was pretty good, so one hopes that this
  # is a general result across devices.
  @doc false
  @spec hz_comp_1000(pos_integer()) :: {pos_integer(), pos_integer()}
  def hz_comp_1000(0), do: {0, 0}
  def hz_comp_1000(1), do: {1, 2}
  def hz_comp_1000(duration), do: {duration - 1, duration}

  @doc false
  # If anyone actually uses 300 Hz, it needs work since we don't support
  # sub-millisecond times.
  @spec hz_comp_300(pos_integer()) :: {pos_integer(), pos_integer()}
  def hz_comp_300(0), do: {0, 0}
  def hz_comp_300(duration) when duration < 6, do: {1, 7}

  def hz_comp_300(duration),
    do: {duration - 5, round(3.3333 + :math.ceil((duration - 5) / 3.3333) * 3.3333)}

  @doc false
  @spec hz_comp_250(pos_integer()) :: {pos_integer(), pos_integer()}
  def hz_comp_250(0), do: {0, 0}
  def hz_comp_250(duration) when duration < 7, do: {1, 8}
  def hz_comp_250(duration), do: {duration - 6, div(duration - 6 + 7, 4) * 4}

  @doc false
  @spec hz_comp_100(pos_integer()) :: {pos_integer(), pos_integer()}
  def hz_comp_100(0), do: {0, 0}
  def hz_comp_100(duration) when duration < 16, do: {1, 20}
  def hz_comp_100(duration), do: {duration - 15, div(duration - 15 + 19, 10) * 10}

  defp hz_comp_none(duration), do: {duration, duration}

  defp append_trailer({iodata, duration}, :one_shot), do: {[iodata, @led_off], duration}
  defp append_trailer(iodata_and_duration, _), do: iodata_and_duration

  @doc """
  Free resources
  """
  @spec close(state()) :: :ok
  def close(state) do
    if state.red, do: :ok = File.close(state.red)
    if state.green, do: :ok = File.close(state.green)
    if state.blue, do: :ok = File.close(state.blue)

    :ok
  end

  defp init_handle(_led_path, nil), do: {nil, 0}

  defp init_handle(led_path, name) do
    File.write!("#{led_path}/#{name}/trigger", "pattern")
    {max_brightness, _} = File.read!("#{led_path}/#{name}/max_brightness") |> Integer.parse()
    handle = File.open!("#{led_path}/#{name}/pattern", [:write, :raw])

    {handle, max_brightness}
  end
end
