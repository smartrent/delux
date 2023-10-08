defmodule Delux.Backend do
  @moduledoc """
  LED backend

  LED backends connect Delux to the code that actually changes the state of the LEDs.
  """

  alias Delux.Pattern
  alias Delux.Program

  @type state() :: term()
  @type compiled() :: term()

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
  @callback open(keyword() | map()) :: state()

  @doc """
  Compile an indicator program so that it can be run efficiently later
  """
  @callback compile(state(), Program.t(), 0..100) :: compiled()

  @doc """
  Run a compiled program at the specified time offset

  This returns the amount of time left.

  NOTE: Specifying a time offset isn't supported yet.
  """
  @callback run(state(), compiled(), Pattern.milliseconds()) :: Pattern.milliseconds() | :infinity

  @doc """
  Free resources
  """
  @callback close(state()) :: :ok
end
