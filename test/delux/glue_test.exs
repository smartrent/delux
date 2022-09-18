defmodule Delux.GlueTest do
  use ExUnit.Case, async: true

  alias Delux.Glue
  alias Delux.Support.FakeLEDs

  doctest Glue

  defp compile_and_set(state, program, percent, expected_duration) do
    compiled = Glue.compile_program!(state, program, percent)
    {state, duration} = Glue.set_program(state, compiled, 0)

    assert duration == expected_duration, "Program #{inspect(program)} had unexpected duration"

    state
  end

  @tag :tmp_dir
  test "correctly writes to led files", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    Glue.open(led_dir, "led0", "led1", "led2")
    |> compile_and_set(Delux.Effects.blink(:red, 5), 100, 3_600_000)
    |> Glue.close()

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
    Glue.open(led_dir, nil, "led0", nil)
    |> compile_and_set(Delux.Effects.blink(:white, 1), 100, 3_600_000)
    |> Glue.close()

    # Verify that only "led0" is configured and written
    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_trigger(1) == "none"
    assert FakeLEDs.read_trigger(2) == "none"

    assert FakeLEDs.read_pattern(0) == "255 500 255 0 0 500 0 0 "
    assert FakeLEDs.read_pattern(1) == ""
    assert FakeLEDs.read_pattern(2) == ""
  end

  @tag :tmp_dir
  test "calculates duration of non-repeating patterns", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    state = Glue.open(led_dir, nil, "led0", nil)

    compile_and_set(state, Delux.Effects.blip(:green, :green), 100, 40)

    Glue.close(state)
  end
end
