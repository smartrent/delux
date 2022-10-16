defmodule DeluxAppTest do
  use ExUnit.Case, async: false

  alias Delux.Support.FakeLEDs

  test "empty config doesn't start Delux" do
    assert Process.whereis(Delux) == nil
  end

  @tag :tmp_dir
  test "single LED configuration", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    :ok = Application.stop(:delux)
    Application.put_env(:delux, :backend, led_path: led_dir, hz: 0)
    Application.put_env(:delux, :indicators, %{default: %{green: "led0"}})
    :ok = Application.start(:delux)

    on_exit(fn ->
      Application.stop(:delux)
      :application.unset_env(:delux, :backend)
      :application.unset_env(:delux, :indicators)
      :ok = Application.start(:delux)
    end)

    assert info_as_binary(:default) == "off"

    # Check initialized to off
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "

    # Blink it
    Delux.render(Delux.Effects.blink(:green, 2), :status)
    assert info_as_binary() == "green at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "

    # Clear it
    Delux.clear()
    assert info_as_binary() == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
  end

  defp info_as_binary(indicator \\ :default) do
    Delux.info_as_ansidata(indicator) |> IO.ANSI.format(false) |> IO.chardata_to_string()
  end
end
