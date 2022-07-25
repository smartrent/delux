defmodule Delux.Glue do
  @moduledoc false

  alias Delux.Pattern
  alias Delux.Program

  @type state() :: %{
          red: File.io_device() | nil,
          green: File.io_device() | nil,
          blue: File.io_device() | nil,
          red_max: pos_integer(),
          green_max: pos_integer(),
          blue_max: pos_integer()
        }

  @doc """
  Open and prep file handles for writing patterns
  """
  @spec open(String.t(), String.t() | nil, String.t() | nil, String.t() | nil) :: state()
  def open(led_path, red, green, blue) do
    {red_handle, red_max} = init_handle(led_path, red)
    {green_handle, green_max} = init_handle(led_path, green)
    {blue_handle, blue_max} = init_handle(led_path, blue)

    %{
      red: red_handle,
      green: green_handle,
      blue: blue_handle,
      red_max: red_max,
      green_max: green_max,
      blue_max: blue_max
    }
  end

  @doc """
  Finalize the pattern and send to Linux
  """
  @spec set_program!(state(), Program.t(), 0..100) :: :ok
  def set_program!(state, %Program{} = program, percent) do
    # Process the patterns for brightness adjustments and convert to iodata
    r = maybe_prep_iodata(state.red, program.red, percent, state.red_max)
    g = maybe_prep_iodata(state.green, program.green, percent, state.green_max)
    b = maybe_prep_iodata(state.blue, program.blue, percent, state.blue_max)

    # Write RGB as close together as possible to keep them close to in sync
    maybe_write!(state.red, r)
    maybe_write!(state.green, g)
    maybe_write!(state.blue, b)
  end

  defp maybe_prep_iodata(nil, _sequence, _percent, _max_brightness), do: nil

  defp maybe_prep_iodata(_handle, sequence, percent, max_brightness) do
    sequence
    |> Pattern.pwm(percent)
    |> Pattern.to_iodata(max_brightness)
  end

  defp maybe_write!(nil, _data), do: :ok
  defp maybe_write!(handle, data), do: :ok = IO.binwrite(handle, data)

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
