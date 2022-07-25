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
  ["This is ", "{0, 0.5, 1}"]
  ```
  """
  @spec to_ansidata(t(), String.t()) :: IO.ANSI.ansidata()
  def to_ansidata(color, prefix \\ "")

  def to_ansidata(:off, prefix), do: [:reverse, prefix, "off"]
  def to_ansidata(:black, prefix), do: [:reverse, prefix, "black"]
  def to_ansidata(:red, prefix), do: [:red, prefix, "red"]
  def to_ansidata(:green, prefix), do: [:green, prefix, "green"]
  def to_ansidata(:blue, prefix), do: [:blue, prefix, "blue"]
  def to_ansidata(:cyan, prefix), do: [:cyan, prefix, "cyan"]
  def to_ansidata(:magenta, prefix), do: [:magenta, prefix, "magenta"]
  def to_ansidata(:yellow, prefix), do: [:yellow, prefix, "yellow"]
  def to_ansidata(:white, prefix), do: [:white, prefix, "white"]
  def to_ansidata(:on, prefix), do: [:white, prefix, "on"]
  def to_ansidata(v, prefix) when is_atom(v), do: [prefix, to_string(v)]
  def to_ansidata(v, prefix), do: [prefix, inspect(v)]
end
