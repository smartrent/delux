defmodule Delux.Program do
  @moduledoc """
  Create LED patterns

  See https://elixir.bootlin.com/linux/latest/source/Documentation/devicetree/bindings/leds/leds-trigger-pattern.txt
  """

  alias Delux.Effects
  alias Delux.Pattern

  defstruct red: [], green: [], blue: [], description: "", duration: :infinity

  @typedoc """
  Program information for one indicator
  """
  @type t() :: %__MODULE__{
          red: Pattern.t(),
          green: Pattern.t(),
          blue: Pattern.t(),
          description: IO.ANSI.ansidata(),
          duration: Pattern.milliseconds() | :infinity
        }

  @doc """
  Return an unformatted description of the pattern

  See `ansi_description/1` for colorized description
  """
  @spec text_description(t()) :: String.t()
  def text_description(%__MODULE__{} = pattern) do
    pattern.description |> IO.ANSI.format(false) |> IO.iodata_to_binary()
  end

  @doc """
  Return a description with nice ANSI colors

  The description is returned as `IO.ANSI.ansidata()`. Use `IO.ANSI.format/1` to
  expect escape codes for display with `IO.puts/1`.
  """
  @spec ansi_description(t()) :: IO.ANSI.ansidata()
  def ansi_description(%__MODULE__{} = pattern) do
    pattern.description
  end

  @doc """
  Adjust the brightness of a pattern

  This modifies the pattern to optionally dim it by blinking the LED at 50 Hz.
  It is not an efficient way of dimming LEDs since the blinking is done on the processor by the kernel.
  """
  @spec adjust_brightness_pwm(t(), 0..100) :: t()

  # Handle easy cases
  def adjust_brightness_pwm(pattern, percent) when percent > 99, do: pattern
  def adjust_brightness_pwm(_pattern, percent) when percent < 1, do: Effects.off()

  # Handle general case
  def adjust_brightness_pwm(pattern, percent) do
    %{
      pattern
      | red: Pattern.pwm(pattern.red, percent),
        green: Pattern.pwm(pattern.green, percent),
        blue: Pattern.pwm(pattern.blue, percent)
    }
  end

  @doc """
  Reduce the number of transitions in a pattern

  This reduces the length of the pattern and in some cases makes it
  use less of the CPU to run. It's useful for programmatically
  generated patterns that can take inputs that generate lots
  of repeating sequences.
  """
  @spec simplify(t()) :: t()
  def simplify(%__MODULE__{} = pattern) do
    %{
      pattern
      | red: Pattern.simplify(pattern.red),
        green: Pattern.simplify(pattern.green),
        blue: Pattern.simplify(pattern.blue)
    }
  end
end
