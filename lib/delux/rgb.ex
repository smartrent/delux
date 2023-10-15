defmodule Delux.RGB do
  @moduledoc """
  Utilities for RGB tuples
  """

  @typedoc """
  Colors components go from 0 (off) to 1 (brightest)
  """
  @type component() :: 0 | 1 | float()

  @typedoc """
  An RGB triplet

  Note that accuracy of the color depends on the LEDs in use. The color should
  be recognizable, but Delux doesn't support calibration.
  """
  @type t() :: {component(), component(), component()}

  @type color() ::
          :black
          | :red
          | :yellow
          | :green
          | :cyan
          | :blue
          | :magenta
          | :white
          | :on
          | :off
          | t()

  @doc """
  Create a new RGB tuple

  You can pass in a tuple or a color name.
  """
  @spec new(color()) :: t()
  def new({r, g, b} = color) when r >= 0 and g >= 0 and b >= 0 and r <= 1 and g <= 1 and b <= 1 do
    color
  end

  def new(:off), do: {0, 0, 0}
  def new(:black), do: {0, 0, 0}
  def new(:red), do: {1, 0, 0}
  def new(:green), do: {0, 1, 0}
  def new(:blue), do: {0, 0, 1}
  def new(:cyan), do: {0, 1, 1}
  def new(:magenta), do: {1, 0, 1}
  def new(:yellow), do: {1, 1, 0}
  def new(:white), do: {1, 1, 1}
  def new(:on), do: {1, 1, 1}

  @doc """
  Convert a color to a human-readable ansidata

  ```elixir
  iex> RGB.to_ansidata(:red, "This is ")
  [:red, "This is ", "red"]
  iex> RGB.to_ansidata({0, 0.5, 1}, "This is ")
  [[], "This is ", "RGB{0,0.5,1}"]
  ```
  """
  @spec to_ansidata(color(), String.t()) :: IO.ANSI.ansidata()
  def to_ansidata(color, prefix \\ "") do
    [ansi(color), prefix, name(color)]
  end

  @doc """
  Return a string name for the color

  The name returned is the straightforward conversion. There are no smarts for
  normalizing color names.
  """
  @spec name(color()) :: String.t()
  def name(v) when is_atom(v), do: Atom.to_string(v)
  def name({r, g, b}), do: "RGB{#{r},#{g},#{b}}"

  @doc """
  Convert a color to an ansidata atom

  The conversion is best effort due to the limited set of color atoms. If
  there's not a direct conversion, `ansi/1` returns `[]` which will result in
  nothing getting changed when the ansidata gets flattened.
  """
  @spec ansi(color()) :: IO.ANSI.ansicode() | []
  def ansi(v) when v in [:black, :red, :green, :blue, :cyan, :magenta, :yellow, :white], do: v
  def ansi(:off), do: :black
  def ansi(:on), do: :white
  def ansi({0, 0, 0}), do: :black
  def ansi({0, 0, 1}), do: :light_blue
  def ansi({0, 1, 0}), do: :light_green
  def ansi({0, 1, 1}), do: :light_cyan
  def ansi({1, 0, 0}), do: :light_red
  def ansi({1, 0, 1}), do: :light_magenta
  def ansi({1, 1, 0}), do: :light_yellow
  def ansi({1, 1, 1}), do: :white
  def ansi(_), do: []
end
