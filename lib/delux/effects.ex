defmodule Delux.Effects do
  @moduledoc """
  Functions for creating a variety of LED patterns
  """

  alias Delux.Pattern
  alias Delux.Program
  alias Delux.RGB

  @typedoc """
  Options for all effects (none yet)
  """
  @type common_options() :: []

  @doc """
  All LEDs off
  """
  @spec off() :: Program.t()
  def off() do
    %Program{
      red: led_off(),
      green: led_off(),
      blue: led_off(),
      description: "off",
      mode: :simple_loop
    }
  end

  @doc """
  Set an indicator to the specified color
  """
  @spec on(RGB.color(), common_options()) :: Program.t()
  def on(c, _options \\ []) do
    {r, g, b} = RGB.new(c)

    %Program{
      red: led_on(r),
      green: led_on(g),
      blue: led_on(b),
      description: RGB.to_ansidata(c, "solid "),
      mode: :simple_loop
    }
  end

  @doc """
  Blink an indicator

  This returns a pattern that blinks the specified color at a 50% duty cycle.
  The pattern starts on and then goes off.
  """
  @spec blink(RGB.color(), number(), common_options()) :: Program.t()
  def blink(c, frequency, _options \\ []) do
    {r, g, b} = RGB.new(c)

    %Program{
      red: led_blink(r, frequency),
      green: led_blink(g, frequency),
      blue: led_blink(b, frequency),
      description: [RGB.to_ansidata(c, ""), " at #{frequency} Hz"],
      mode: :simple_loop
    }
  end

  @doc """
  Create a transient two color sequence

  The first color is shown for 20 ms. 10 ms in, the second color is shown for
  20 ms. The Effects is a quick flash of light that can be used to show
  feedback to a button. Total duration of the Effects is 40 ms.
  """
  @spec blip(RGB.color(), RGB.color(), common_options()) :: Program.t()
  def blip(c1, c2, _options \\ []) do
    {r1, g1, b1} = RGB.new(c1)
    {r2, g2, b2} = RGB.new(c2)

    %Program{
      red: led_blip(r1, r2),
      green: led_blip(g1, g2),
      blue: led_blip(b1, b2),
      description: [RGB.to_ansidata(c1), :reset, "->", RGB.to_ansidata(c2), " blip"],
      mode: :one_shot
    }
  end

  @doc """
  Create a program to verify timing

  If you're unsure about the playback timing on your device, hook up a logic
  analyzer to an LED and capture the waveform. Here's what you should see:

  1. 100 ms on
  2. 10 ms off
  3. 1 ms on
  4. 10 ms off
  5. 2 ms on
  6. 10 ms off
  7. 3 ms on
  8. 10 ms off
  9. 5 ms on
  10. 10 ms off
  11. 8 ms on
  12. 10 ms off
  13. 13 ms on
  14. 10 ms off
  15. 100 ms on
  16. off

  Look at the following in the capture:

  1. Do the 1, 2, 3, 5 ms captures match what you'd expect based on your
     kernel's HZ setting. For example, if HZ=100, they should all be 10 ms long.
     If not, check the :hz setting for Delux.
  2. Does the length of the final 100 ms on time match the first. If not,
     Delux might be calculating the duration wrong and cutting off the program
     prematurely. This is likely due to an incorrect :hz setting.

  If something still isn't right, please submit an issue with the captured
  waveform and any other hints you may have to reproduce.
  """
  @spec timing_test(RGB.color(), common_options()) :: Program.t()
  def timing_test(c, _options \\ []) do
    {r, g, b} = RGB.new(c)

    %Program{
      red: led_timing(r),
      green: led_timing(g),
      blue: led_timing(b),
      description: ["Timing test pattern in ", RGB.to_ansidata(c)],
      mode: :one_shot
    }
  end

  defp led_timing(0), do: led_off()

  defp led_timing(b),
    do: [
      {b, 100},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 1},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 2},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 3},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 5},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 8},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 13},
      {b, 0},
      {0, 10},
      {0, 0},
      {b, 100},
      {b, 0}
    ]

  @doc """
  Cycle between colors

  Colors are shown with equal duration determined from the specified frequency.
  """
  @spec cycle([RGB.color()], number(), common_options()) :: Program.t()
  def cycle(colors, frequency, _options \\ [])
      when is_list(colors) and frequency > 0 and frequency < 20 do
    {reds, greens, blues} = colors |> Enum.map(&RGB.new/1) |> unzip3()

    duration = round(1000.0 / Enum.count(colors) / frequency)

    %Program{
      red: led_cycle(reds, duration),
      green: led_cycle(greens, duration),
      blue: led_cycle(blues, duration),
      description: [
        Enum.map(colors, &RGB.to_ansidata/1) |> Enum.intersperse([:reset, "-"]),
        :reset,
        " cycle at #{frequency} Hz"
      ],
      mode: :simple_loop
    }
  end

  @doc """
  Create a program from an arbitrary function

  Pass in a function that takes times in milliseconds and returns colors. The
  returned pattern piecewise linearly interpolates the waveform.

  Here's an example of a 0.5 Hz blue sine wave:

  ```elixir
  Effects.waveform(fn t -> {0, 0, 0.5 + 0.5 *:math.cos(:math.pi() * t /  1000)} end, 2000)
  ```

  When trying this, keep in mind that if the LEDs in the indicator don't support
  varying levels of brightness, it won't look like a sine wave.

  Options

  * `:time_step` - the number of milliseconds between each sample. Defaults to 100 ms.
  """
  @spec waveform((Pattern.milliseconds() -> RGB.color()), Pattern.milliseconds(), keyword()) ::
          Program.t()
  def waveform(fun, period, options \\ []) do
    time_step = options[:time_step] || 100
    colors = for t <- 0..period//time_step, do: RGB.new(fun.(t))
    {reds, greens, blues} = unzip3(colors)

    %Program{
      red: led_waveform(reds, time_step, period),
      green: led_waveform(greens, time_step, period),
      blue: led_waveform(blues, time_step, period),
      description: "waveform",
      mode: :simple_loop
    }
  end

  @typedoc false
  @type number_blink_options() :: [
          blink_on_duration: pos_integer(),
          blink_off_duration: pos_integer(),
          inter_number_delay: pos_integer()
        ]

  @doc """
  Blink out a number

  This returns a pattern that blinks out a number. It's good for
  communicating small numbers to viewers. It repeats.

  Options:

  * `:inter_number_delay` - the amount of milliseconds to wait in between
    blinking out the count (defaults to 2000 ms)
  * `:blink_on_duration` - how long to keep the LED on when blinking (defaults to 250 ms)
  * `:blink_off_duration` - how long to keep the LED off when blinking (defaults to 250 ms)
  """
  @spec number_blink(RGB.color(), 1..20, number_blink_options()) :: Program.t()
  def number_blink(c, count, options \\ []) when count >= 1 and count <= 20 do
    {r, g, b} = RGB.new(c)

    on = Keyword.get(options, :blink_on_duration, 250)
    off = Keyword.get(options, :blink_off_duration, 250)
    inter = Keyword.get(options, :inter_number_delay, 2000)

    %Program{
      red: led_number_blink(r, count, on, off, inter),
      green: led_number_blink(g, count, on, off, inter),
      blue: led_number_blink(b, count, on, off, inter),
      description: ["Blink ", RGB.to_ansidata(c, ""), " #{count} times"],
      mode: :simple_loop
    }
  end

  defp led_number_blink(0, _count, _on, _off, _inter), do: led_off()

  defp led_number_blink(b, count, on_time, off_time, inter) do
    [List.duplicate([{b, on_time}, {b, 0}, {0, off_time}, {0, 0}], count), {0, inter}, {0, 0}]
    |> List.flatten()
  end

  defp unzip3(tuples, acc \\ {[], [], []})
  defp unzip3([], {a1, a2, a3}), do: {Enum.reverse(a1), Enum.reverse(a2), Enum.reverse(a3)}
  defp unzip3([{x, y, z} | rest], {a1, a2, a3}), do: unzip3(rest, {[x | a1], [y | a2], [z | a3]})

  defp led_off(), do: [{0, Pattern.forever_ms()}, {0, 0}]
  defp led_on(b), do: [{b, Pattern.forever_ms()}, {b, 0}]
  defp led_blink(0, _frequency), do: led_off()

  defp led_blink(b, frequency) when frequency > 0 and frequency < 20 do
    period = round(1000 / frequency)
    on_time = div(period, 2)
    off_time = period - on_time
    [{b, on_time}, {b, 0}, {0, off_time}, {0, 0}]
  end

  defp led_blink(b, frequency) when frequency >= 20, do: led_on(b)

  defp led_blip(0, 0), do: led_off()
  defp led_blip(0, b2), do: [{0, 20}, {0, 0}, {b2, 20}, {b2, 0}]
  defp led_blip(b1, 0), do: [{0, 10}, {0, 0}, {b1, 20}, {b1, 0}]
  defp led_blip(b1, b2), do: [{0, 10}, {0, 0}, {b1, 30}, {b2, 0}]

  defp led_cycle(values, duration) do
    Enum.flat_map(values, fn b -> [{b, duration}, {b, 0}] end)
  end

  defp led_waveform(values, time_step, total_time) do
    {result, 0} =
      Enum.map_reduce(values, total_time, fn v, time_left ->
        time = min(time_step, time_left)
        {{v, time}, time_left - time}
      end)

    Pattern.simplify(result)
  end
end
