defmodule DeluxTest do
  use ExUnit.Case, async: true

  alias Delux.Support.FakeLEDs

  test "starting Delux with an empty config" do
    # This is useful for projects that have LEDs on some devices, but not on others.
    pid = start_supervised!({Delux, name: nil})

    Delux.render(pid, Delux.Effects.blink(:green, 2), :status)
  end

  @tag :tmp_dir
  test "single LED configuration", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert info_as_binary(pid, :default) == "off"

    # Check initialized to off
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "

    # Blink it
    Delux.render(pid, Delux.Effects.blink(:green, 2), :status)
    assert info_as_binary(pid) == "green at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "

    # Clear it
    Delux.clear(pid)
    assert info_as_binary(pid) == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
  end

  @tag :tmp_dir
  test "RGB LED configuration", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil,
         glue: [led_path: led_dir, hz: 0],
         indicators: %{default: %{red: "led0", green: "led1", blue: "led2"}}}
      )

    assert info_as_binary(pid) == "off"

    # Check initialized to off
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3600000 0 0 "

    # Blink it
    Delux.render(pid, Delux.Effects.blink(:magenta, 2), :status)
    assert info_as_binary(pid) == "magenta at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "1 250 1 0 0 250 0 0 "

    # Clear it the shortcut way"
    Delux.render(pid, nil, :status)
    assert info_as_binary(pid) == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3600000 0 0 "
  end

  @tag :tmp_dir
  test "slots", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert info_as_binary(pid) == "off"

    # Blink it
    Delux.render(pid, Delux.Effects.blink(:green, 2), :status)
    assert info_as_binary(pid) == "green at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "

    # Override the 2 Hz blink
    Delux.render(pid, Delux.Effects.blink(:green, 1), :notification)
    assert info_as_binary(pid) == "green at 1 Hz"
    assert FakeLEDs.read_pattern(0) == "1 500 1 0 0 500 0 0 "

    # Set a lower priority blink and check that nothing gets written
    Delux.render(pid, Delux.Effects.blink(:green, 5), :status)
    assert info_as_binary(pid) == "green at 1 Hz"
    assert FakeLEDs.read_pattern(0) == ""

    # Clear the higher priority blink
    Delux.render(pid, nil, :notification)
    assert info_as_binary(pid) == "green at 5 Hz"
    assert FakeLEDs.read_pattern(0) == "1 100 1 0 0 100 0 0 "

    # Clear the lower priority blink
    Delux.render(pid, nil, :status)
    assert info_as_binary(pid) == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
  end

  @tag :tmp_dir
  test "timed programs", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert info_as_binary(pid) == "off"

    # Blip it
    Delux.render(pid, Delux.Effects.blip(:green, :black), :status)
    assert info_as_binary(pid) == "green->black blip"
    assert FakeLEDs.read_pattern(0) == "0 10 0 0 1 20 1 0 0 3600000 0 0"

    # Wait for the timeout
    Process.sleep(100)

    # Check that the LEDs are off again
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert info_as_binary(pid) == "off"
  end

  @tag :tmp_dir
  test "multiple indicator configuration", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil,
         glue: [led_path: led_dir, hz: 0],
         indicators: %{
           default: %{red: "led0", green: "led1", blue: "led2"},
           indicator2: %{red: "led3", green: "led4", blue: "led5"}
         }}
      )

    assert info_as_binary(pid) == "off"
    assert info_as_binary(pid, :indicator2) == "off"

    # Check initialized to off
    for i <- 0..5 do
      assert FakeLEDs.read_pattern(i) == "0 3600000 0 0 "
    end

    # Blink the default indicator
    Delux.render(pid, Delux.Effects.blink(:magenta, 2), :status)
    assert info_as_binary(pid) == "magenta at 2 Hz"
    assert info_as_binary(pid, :indicator2) == "off"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "1 250 1 0 0 250 0 0 "
    # Not written
    assert FakeLEDs.read_pattern(3) == ""
    assert FakeLEDs.read_pattern(4) == ""
    assert FakeLEDs.read_pattern(5) == ""

    # Start a second blink on indicator2
    Delux.render(pid, %{indicator2: Delux.Effects.blink(:blue, 1)}, :status)
    assert info_as_binary(pid) == "magenta at 2 Hz"
    assert info_as_binary(pid, :indicator2) == "blue at 1 Hz"
    assert FakeLEDs.read_pattern(0) == ""
    assert FakeLEDs.read_pattern(1) == ""
    assert FakeLEDs.read_pattern(2) == ""
    assert FakeLEDs.read_pattern(3) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(4) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(5) == "1 500 1 0 0 500 0 0 "

    # Turn off the first blink
    Delux.render(pid, %{default: nil}, :status)
    assert info_as_binary(pid) == "off"
    assert info_as_binary(pid, :indicator2) == "blue at 1 Hz"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(3) == ""
    assert FakeLEDs.read_pattern(4) == ""
    assert FakeLEDs.read_pattern(5) == ""

    # Turn off the second blink
    Delux.render(pid, %{indicator2: nil}, :status)
    assert info_as_binary(pid) == "off"
    assert info_as_binary(pid, :indicator2) == "off"

    assert FakeLEDs.read_pattern(0) == ""
    assert FakeLEDs.read_pattern(1) == ""
    assert FakeLEDs.read_pattern(2) == ""
    assert FakeLEDs.read_pattern(3) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(4) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(5) == "0 3600000 0 0 "
  end

  @tag :tmp_dir
  test "render raises on unknown slots", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert_raise ArgumentError, fn ->
      Delux.render(pid, Delux.Effects.on(:green), :unknown_slot)
    end
  end

  @tag :tmp_dir
  test "render raises on unknown indicator", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert_raise ArgumentError, fn ->
      Delux.render(pid, %{my_indicator: Delux.Effects.on(:green)}, :status)
    end
  end

  @tag :tmp_dir
  test "info_as_ansidata raises for unknown indicator", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: nil, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert_raise ArgumentError, fn ->
      Delux.info_as_ansidata(pid, :not_an_indicator)
    end
  end

  defp info_as_binary(pid, indicator \\ :default) do
    Delux.info_as_ansidata(pid, indicator) |> IO.ANSI.format(false) |> IO.iodata_to_binary()
  end

  @tag :tmp_dir
  test "singleton Delux", %{tmp_dir: led_dir} do
    # Since Delux is a singleton and the unit tests are run async, this is
    # the only test that uses this configuration. It exercises that default options
    # to Delux all go to the singleton instance.

    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert Process.whereis(Delux) == pid

    assert singleton_info_as_binary() == "off"

    # Check initialized to off
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "

    # Blink it
    Delux.render(Delux.Effects.blink(:green, 2))
    assert singleton_info_as_binary() == "green at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "

    # Clear it
    Delux.clear()
    assert singleton_info_as_binary() == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
  end

  defp singleton_info_as_binary() do
    Delux.info_as_ansidata() |> IO.ANSI.format(false) |> IO.iodata_to_binary()
  end

  @tag :tmp_dir
  test "named Delux", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 1)

    pid =
      start_supervised!(
        {Delux,
         name: MyDelux, glue: [led_path: led_dir, hz: 0], indicators: %{default: %{green: "led0"}}}
      )

    assert Process.whereis(MyDelux) == pid

    assert info_as_binary(MyDelux) == "off"

    # Check initialized to off
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "

    # Blink it
    Delux.render(MyDelux, Delux.Effects.blink(:green, 2), :status)
    assert info_as_binary(MyDelux) == "green at 2 Hz"
    assert FakeLEDs.read_pattern(0) == "1 250 1 0 0 250 0 0 "

    # Clear it
    Delux.clear(MyDelux)
    assert info_as_binary(MyDelux) == "off"
    assert FakeLEDs.read_pattern(0) == "0 3600000 0 0 "
  end
end
