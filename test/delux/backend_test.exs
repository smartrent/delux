defmodule Delux.BackendTest do
  use ExUnit.Case, async: true

  alias Delux.Backend
  alias Delux.Effects
  alias Delux.Support.FakeLEDs

  doctest Backend

  defp compile_and_run(state, program, percent, expected_duration) do
    compiled = Backend.compile(state, program, percent)
    duration = Backend.run(state, compiled, 0)

    assert duration == expected_duration, "Program #{inspect(program)} had unexpected duration"

    state
  end

  @tag :tmp_dir
  test "correctly writes to led files", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    Backend.open(led_path: led_dir, hz: 0, red: "led0", green: "led1", blue: "led2")
    |> compile_and_run(Delux.Effects.blink(:red, 5), 100, :infinity)
    |> Backend.close()

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
    Backend.open(led_path: led_dir, hz: 0, green: "led0")
    |> compile_and_run(Delux.Effects.blink(:white, 1), 100, :infinity)
    |> Backend.close()

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

    state = Backend.open(led_path: led_dir, green: "led0")

    compile_and_run(state, Delux.Effects.blip(:green, :green), 100, 40)

    Backend.close(state)
  end

  @tag :tmp_dir
  test "specifying hz", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    Backend.open(led_path: led_dir, hz: 100, red: "led0", green: "led1", blue: "led2")
    |> compile_and_run(Delux.Effects.blink(:red, 5), 100, :infinity)
    |> Backend.close()

    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_trigger(1) == "pattern"
    assert FakeLEDs.read_trigger(2) == "pattern"

    assert FakeLEDs.read_pattern(0) == "255 85 255 0 0 85 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3599985 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3599985 0 0 "
  end

  @tag :tmp_dir
  test "default hz adjusts for 1000 hz", %{tmp_dir: led_dir} do
    FakeLEDs.create_leds(led_dir, 255)

    Backend.open(led_path: led_dir, red: "led0", green: "led1", blue: "led2")
    |> compile_and_run(Delux.Effects.blink(:red, 5), 100, :infinity)
    |> Backend.close()

    assert FakeLEDs.read_trigger(0) == "pattern"
    assert FakeLEDs.read_trigger(1) == "pattern"
    assert FakeLEDs.read_trigger(2) == "pattern"

    assert FakeLEDs.read_pattern(0) == "255 99 255 0 0 99 0 0 "
    assert FakeLEDs.read_pattern(1) == "0 3599999 0 0 "
    assert FakeLEDs.read_pattern(2) == "0 3599999 0 0 "
  end

  describe "pattern_to_iodata/2" do
    test "simple conversions" do
      assert pattern_to_binary(Effects.off().red) == "0 3600000 0 0 "
      assert pattern_to_binary(Effects.blink(:red, 2).red) == "1 250 1 0 0 250 0 0 "
    end

    test "scaled to LED max brightness" do
      assert pattern_to_binary(Effects.blink(:red, 2).red, 255) == "255 250 255 0 0 250 0 0 "
    end
  end

  defp pattern_to_binary(pattern, brightness \\ 1) do
    {iodata, _duration} = Backend.pattern_to_iodata(pattern, brightness, fn x -> {x, x} end)
    IO.iodata_to_binary(iodata)
  end

  test "hz_comp_1000" do
    measured = [
      {0, 0},
      {1, 2},
      {1, 2},
      {2, 3},
      {3, 4},
      {4, 5},
      {5, 6},
      {6, 7},
      {7, 8},
      {8, 9},
      {9, 10},
      {10, 11}
    ]

    measured
    |> Enum.with_index()
    |> Enum.each(fn {result, input} ->
      assert Backend.hz_comp_1000(input) == result
    end)
  end

  test "hz_comp_300" do
    # If you're really using 300 Hz and you don't want to switch, please let me know.
    guessed = [
      {0, 0},
      {1, 7},
      {1, 7},
      {1, 7},
      {1, 7},
      {1, 7},
      {1, 7},
      {2, 7},
      {3, 7},
      {4, 10},
      {5, 10},
      {6, 10}
    ]

    guessed
    |> Enum.with_index()
    |> Enum.each(fn {result, input} ->
      assert Backend.hz_comp_300(input) == result
    end)
  end

  test "hz_comp_250" do
    measured = [
      {0, 0},
      {1, 8},
      {1, 8},
      {1, 8},
      {1, 8},
      {1, 8},
      {1, 8},
      {1, 8},
      {2, 8},
      {3, 8},
      {4, 8},
      {5, 12},
      {6, 12},
      {7, 12},
      {8, 12},
      {9, 16},
      {10, 16},
      {11, 16},
      {12, 16},
      {13, 20},
      {14, 20},
      {15, 20},
      {16, 20}
    ]

    measured
    |> Enum.with_index()
    |> Enum.each(fn {result, input} ->
      assert Backend.hz_comp_250(input) == result
    end)
  end

  test "hz_comp_100" do
    measured = [
      {0, 0},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {1, 20},
      {2, 20},
      {3, 20},
      {4, 20},
      {5, 20},
      {6, 20},
      {7, 20},
      {8, 20},
      {9, 20},
      {10, 20},
      {11, 30},
      {12, 30},
      {13, 30},
      {14, 30},
      {15, 30},
      {16, 30},
      {17, 30},
      {18, 30},
      {19, 30},
      {20, 30},
      {21, 40}
    ]

    measured
    |> Enum.with_index()
    |> Enum.each(fn {result, input} ->
      assert Backend.hz_comp_100(input) == result
    end)
  end
end
