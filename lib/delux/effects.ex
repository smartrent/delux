defmodule Delux.Effects do
  @moduledoc """
  Functions for creating a variety of LED patterns
  """

  alias Delux.Pattern
  alias Delux.Program
  alias Delux.RGB

  @long_time 3_600_000

  @typedoc """
  Option effects (none yet)
  """
  @type options() :: []

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
      duration: :infinity
    }
  end

  @doc """
  Set an indicator to the specified color
  """
  @spec on(RGB.t(), options()) :: Program.t()
  def on(c, _options \\ []) do
    {r, g, b} = RGB.new(c)

    %Program{
      red: led_on(r),
      green: led_on(g),
      blue: led_on(b),
      description: RGB.to_ansidata(c, "solid "),
      duration: :infinity
    }
  end

  @doc """
  Blink an indicator

  This returns a pattern that blinks the specified color at a 50% duty cycle.
  The pattern starts on and then goes off.
  """
  @spec blink(RGB.t(), number(), options()) :: Program.t()
  def blink(c, frequency, _options \\ []) do
    {r, g, b} = RGB.new(c)

    %Program{
      red: led_blink(r, frequency),
      green: led_blink(g, frequency),
      blue: led_blink(b, frequency),
      description: [RGB.to_ansidata(c, ""), " at #{frequency} Hz"],
      duration: :infinity
    }
  end

  @doc """
  Create a transient two color sequence

  The first color is shown for 20 ms. 10 ms in, the second color is shown for
  20 ms. The Effects is a quick flash of light that can be used to show
  feedback to a button. Total duration of the Effects is 40 ms.
  """
  @spec blip(RGB.t(), RGB.t(), options()) :: Program.t()
  def blip(c1, c2, _options \\ []) do
    {r1, g1, b1} = RGB.new(c1)
    {r2, g2, b2} = RGB.new(c2)

    %Program{
      red: led_blip(r1, r2),
      green: led_blip(g1, g2),
      blue: led_blip(b1, b2),
      description: [RGB.to_ansidata(c1), :reset, "->", RGB.to_ansidata(c2), " blip"],
      duration: 40
    }
  end

  @doc """
  Cycle between colors

  Colors are shown with equal duration determined from the specified frequency.
  """
  @spec cycle([RGB.t()], number(), options()) :: Program.t()
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
      duration: :infinity
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
  @spec waveform(fun(), non_neg_integer(), keyword()) :: Program.t()
  def waveform(fun, period, options \\ []) do
    time_step = options[:time_step] || 100
    colors = for t <- 0..period//time_step, do: fun.(t)
    {reds, greens, blues} = unzip3(colors)

    %Program{
      red: led_waveform(reds, time_step, period),
      green: led_waveform(greens, time_step, period),
      blue: led_waveform(blues, time_step, period),
      description: "waveform",
      duration: :infinity
    }
  end

  defp unzip3(tuples, acc \\ {[], [], []})
  defp unzip3([], {a1, a2, a3}), do: {Enum.reverse(a1), Enum.reverse(a2), Enum.reverse(a3)}
  defp unzip3([{x, y, z} | rest], {a1, a2, a3}), do: unzip3(rest, {[x | a1], [y | a2], [z | a3]})

  defp led_off(), do: [{0, @long_time}, {0, 0}]
  defp led_on(b), do: [{b, @long_time}, {b, 0}]
  defp led_blink(0, _frequency), do: led_off()

  defp led_blink(b, frequency) when frequency > 0 and frequency < 20 do
    on_time = round(500 / frequency)
    [{b, on_time}, {b, 0}, {0, on_time}, {0, 0}]
  end

  defp led_blink(b, frequency) when frequency >= 20, do: led_on(b)

  defp led_blip(0, 0), do: led_off()
  defp led_blip(0, b2), do: [{0, 20}, {0, 0}, {b2, 20}, {b2, 0} | led_off()]
  defp led_blip(b1, 0), do: [{0, 10}, {0, 0}, {b1, 20}, {b1, 0} | led_off()]
  defp led_blip(b1, b2), do: [{0, 10}, {0, 0}, {b1, 30}, {b2, 0} | led_off()]

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
