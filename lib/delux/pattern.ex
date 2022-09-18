defmodule Delux.Pattern do
  @moduledoc """
  Utility functions for handling element sequences for one LED
  """

  alias Delux.RGB

  @typedoc """
  Integer durations in milliseconds
  """
  @type milliseconds() :: non_neg_integer()

  @typedoc """
  Value, duration for one component

  Values are 0 to 1 and durations are in milliseconds.
  """
  @type element() :: {RGB.component(), milliseconds()}

  @typedoc """
  A sequence of elements

  These get processed into the pattern string that's sent to Linux.
  """
  @type t() :: [element()]

  @doc """
  Convert a pattern to iodata

  * `pattern` - the pattern to convert
  * `max_b` - the max brightness supported by the LED (usually 1 or 255)

  Returns a tuple with the iodata and total duration
  """
  @spec build_iodata(t(), non_neg_integer()) :: {iolist(), non_neg_integer()}
  def build_iodata(pattern, max_b) do
    build(pattern, max_b, [], 0)
  end

  defp build([], _max_b, acc, total) do
    {acc, total}
  end

  defp build([{component, duration} | rest], max_b, acc, total) do
    brightness = round(component * max_b)
    new_total = duration + total
    new_acc = [acc, [to_string(brightness), " ", to_string(duration), " "]]
    build(rest, max_b, new_acc, new_total)
  end

  @doc """
  Return a number of ms that should be considered a long time

  Linux doesn't support an infinite timeout, so use this value instead.
  """
  @spec forever_ms() :: 3_600_000
  def forever_ms(), do: 3_600_000

  @doc """
  PWM a sequence of elements

  The resulting sequence will only be fully on or fully off. See
  caveats in `Program.adjust_brightness_pwm/2`.

  IMPORTANT: This function is VERY incomplete right now. It requires
  much more thought to work around flickering issues at low PWM rates.
  """
  @spec pwm(t(), 0..100) :: t()
  # Special cases for solid off
  def pwm([{0, _duration}, {0, 0}] = pattern, _percent), do: pattern

  def pwm(pattern, 0) do
    [{0, duration(pattern)}, {0, 0}]
  end

  # Special case for solid on sequences
  def pwm([{component, _duration}, {component, 0}], percent)
      when component > 0 and percent < 100 do
    pwm_on = pwm_on_time(percent)
    pwm_off = 20 - pwm_on
    [{component, pwm_on}, {component, 0}, {0, pwm_off}, {0, 0}]
  end

  # Don't PWM anything else for now.
  def pwm(other, _percent) do
    other
  end

  # Do some rough gamma correction here
  # The equation here was figured out by trial and error with one device
  @pwm_gamma List.to_tuple(for i <- 0..100, do: min(round(0.744 * :math.exp(0.0338 * i)), 20))
  defp pwm_on_time(percent) when is_integer(percent) do
    elem(@pwm_gamma, percent)
  end

  @doc """
  Reduce the number of transitions in a sequence

  This reduces the length of the pattern and in some cases makes it
  use less of the CPU to run. It's useful for programmatically
  generated patterns that can take inputs that generate lots
  of repeating sequences.
  """
  @spec simplify(t()) :: t()
  def simplify([{x1, t1}, {x1, t2}, {x1, t3} | rest]) do
    # Handle common case where second tuple can trivially be dropped
    # since the component doesn't change
    simplify([{x1, t1 + t2}, {x1, t3} | rest])
  end

  def simplify([{x1, 0}, {_x2, 0} | rest]) do
    # Handle the divide-by-zero case
    simplify([{x1, 0} | rest])
  end

  def simplify([{x1, t1}, {x2, t2}, {x3, t3} | rest]) do
    interpolated = x1 + (x3 - x1) / (t1 + t2)

    if abs(x2 - interpolated) < 0.001 do
      # {x2, t2} is redundant, so drop
      simplify([{x1, t1 + t2}, {x3, t3} | rest])
    else
      [{x1, t1} | simplify([{x2, t2}, {x3, t3} | rest])]
    end
  end

  def simplify(other), do: other

  defp duration(pattern) do
    Enum.reduce(pattern, 0, fn {_v, d}, acc -> acc + d end)
  end
end
