defmodule Delux.GlueTest do
  use ExUnit.Case, async: true

  alias Delux.Glue
  alias Delux.Support.FakeLEDs

  doctest Glue

  @tag :tmp_dir
  test "correctly writes to led files", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    state = Glue.open(led_dir, "led0", "led1", "led2")
    Glue.set_program!(state, Delux.Effects.blink(:red, 5), 100)

    Glue.close(state)

    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_trigger(1) == "pattern"
    assert FakeLEDs.read_trigger(2) == "pattern"

    assert FakeLEDs.read_pattern(0) == "255 100 255 0 0 100 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3600000 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3600000 0 0 "
  end

  @tag :tmp_dir
  test "non-RGB indicator support", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    # Only configure a green LED, but run a blinking white program
    state = Glue.open(led_dir, nil, "led0", nil)

    Glue.set_program!(state, Delux.Effects.blink(:white, 1), 100)

    Glue.close(state)

    # Verify that only "led0" is configured and written
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_trigger(1) == "none"
    assert FakeLEDs.read_trigger(2) == "none"

    assert FakeLEDs.read_pattern(0) == "255 500 255 0 0 500 0 0 "
    assert FakeLEDs.read_pattern(1) == ""
    assert FakeLEDs.read_pattern(2) == ""
  end
end
