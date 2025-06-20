defmodule Delux.Support.FakeLEDs do
  @moduledoc false

  defp base_dir(led_dir, index), do: Path.join(led_dir, "led#{index}")
  defp trigger_path(led_dir, index), do: Path.join(base_dir(led_dir, index), "trigger")
  defp pattern_path(led_dir, index), do: Path.join(base_dir(led_dir, index), "pattern")

  defp max_brightness_path(led_dir, index),
    do: Path.join(base_dir(led_dir, index), "max_brightness")

  @doc """
  Create fake LEDs with the specified max brightness
  """
  @spec create_leds(String.t(), pos_integer()) :: :ok
  def create_leds(led_dir, max_brightness) do
    Process.get({__MODULE__, :led_dir}) == nil or raise "Only run once per process!"

    Process.put({__MODULE__, :led_dir}, led_dir)

    Enum.each(0..5, fn i ->
      File.mkdir_p!(base_dir(led_dir, i))
      File.write!(trigger_path(led_dir, i), "none")
      File.write!(max_brightness_path(led_dir, i), "#{max_brightness}")
      File.write!(pattern_path(led_dir, i), "")

      handle = File.open!(pattern_path(led_dir, i), [:read, :raw])
      Process.put({__MODULE__, i}, handle)
    end)

    :ok
  end

  @spec read_trigger(non_neg_integer()) :: binary()
  def read_trigger(index) do
    led_dir = Process.get({__MODULE__, :led_dir})
    File.read!(trigger_path(led_dir, index))
  end

  @spec read_pattern(non_neg_integer()) :: binary() | :eof | {:error, any()}
  def read_pattern(index) do
    # This is a little tricky since tests must read the pattern
    # after every time it's set. This is due to how the backend code
    # to Linux just keeps appending to the magic file to set patterns,
    # but our simulation doesn't truncate the file after every write.
    handle = Process.get({__MODULE__, index})
    binread(handle)
  end

  defp binread(handle) do
    case IO.binread(handle, :eof) do
      :eof -> :eof
      {:error, _} = error -> error
      data -> IO.iodata_to_binary(data)
    end
  end
end
