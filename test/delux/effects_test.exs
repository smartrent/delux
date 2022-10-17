defmodule Delux.EffectsTest do
  use ExUnit.Case, async: true

  alias Delux.Effects
  alias Delux.Program

  doctest Effects

  describe "off/0" do
    test "all LEDs off" do
      off = Effects.off()

      assert off.red == [{0, 3_600_000}, {0, 0}]
      assert off.red == off.green
      assert off.red == off.blue

      assert off.mode == :simple_loop
    end

    test "description" do
      off = Effects.off()
      assert Program.text_description(off) == "off"
    end
  end

  describe "on/2" do
    test "build a color" do
      pattern = Effects.on(:magenta)

      assert pattern.red == [{1, 3_600_000}, {1, 0}]
      assert pattern.green == [{0, 3_600_000}, {0, 0}]
      assert pattern.red == pattern.blue

      assert pattern.mode == :simple_loop
    end

    test "description" do
      c1 = Effects.on(:magenta)
      assert Program.text_description(c1) == "solid magenta"
    end
  end

  describe "blink/3" do
    test "blinking blue" do
      pattern = Effects.blink(:blue, 2)

      assert pattern.red == [{0, 3_600_000}, {0, 0}]
      assert pattern.green == [{0, 3_600_000}, {0, 0}]
      assert pattern.blue == [{1, 250}, {1, 0}, {0, 250}, {0, 0}]

      assert pattern.mode == :simple_loop
    end

    test "blinking too fast is solid on" do
      pattern = Effects.blink(:white, 100)

      assert pattern.red == [{1, 3_600_000}, {1, 0}]
      assert pattern.green == [{1, 3_600_000}, {1, 0}]
      assert pattern.blue == [{1, 3_600_000}, {1, 0}]
    end

    test "blink slower than 1 Hz" do
      pattern = Effects.blink(:green, 0.1)

      assert pattern.red == [{0, 3_600_000}, {0, 0}]
      assert pattern.green == [{1, 5000}, {1, 0}, {0, 5000}, {0, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]
    end

    test "blink period is close" do
      pattern = Effects.blink(:red, 3)

      # 3 Hz has a ~333 ms period which isn't divisible by 2.
      # Therefore, on and off times should be different.
      assert pattern.red == [{1, 166}, {1, 0}, {0, 167}, {0, 0}]
      assert pattern.green == [{0, 3_600_000}, {0, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]
    end

    test "description" do
      pattern = Effects.blink(:blue, 2)
      assert Program.text_description(pattern) == "blue at 2 Hz"
    end
  end

  describe "blip/3" do
    test "build a blip" do
      pattern = Effects.blip(:red, :green)

      assert pattern.red == [{0, 10}, {0, 0}, {1, 20}, {1, 0}]
      assert pattern.green == [{0, 20}, {0, 0}, {1, 20}, {1, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]

      assert pattern.mode == :one_shot
    end

    test "description" do
      pattern = Effects.blip(:red, :green)
      assert Program.text_description(pattern) == "red->green blip"
    end
  end

  describe "cycle/3" do
    test "build a cycle" do
      pattern = Effects.cycle([:red, :green, :blue], 1)

      assert pattern.red == [{1, 333}, {1, 0}, {0, 333}, {0, 0}, {0, 333}, {0, 0}]
      assert pattern.green == [{0, 333}, {0, 0}, {1, 333}, {1, 0}, {0, 333}, {0, 0}]
      assert pattern.blue == [{0, 333}, {0, 0}, {0, 333}, {0, 0}, {1, 333}, {1, 0}]

      assert pattern.mode == :simple_loop
    end

    test "description" do
      pattern = Effects.cycle([:red, :green, :blue], 1)
      assert Program.text_description(pattern) == "red-green-blue cycle at 1 Hz"
    end
  end

  describe "waveform/2" do
    test "blue sine wave" do
      p =
        Effects.waveform(
          fn t -> {0, 0, 0.5 + 0.5 * :math.cos(:math.pi() * t / 1000)} end,
          2000
        )

      # Step size of 100 ms means 21 points where the last one has zero length
      assert length(p.blue) == 21
      total_time = p.blue |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      assert total_time == 2000

      # Test that red and green get simplified down
      assert p.red == [{0, 2000}, {0, 0}]
      assert p.green == [{0, 2000}, {0, 0}]

      assert p.mode == :simple_loop
    end

    test "triangle that uses time_step" do
      p = Effects.waveform(fn t -> {0, 0, rem(t, 2000) / 1000} end, 2000, time_step: 1000)

      assert p.blue == [{0.0, 1000}, {1.0, 1000}, {0.0, 0}]
      assert p.red == [{0, 2000}, {0, 0}]
      assert p.green == [{0, 2000}, {0, 0}]
    end

    test "cycling color names" do
      p =
        Effects.waveform(
          fn t ->
            case div(rem(t, 300), 100) do
              0 -> :red
              1 -> :green
              2 -> :blue
            end
          end,
          300
        )

      assert p.red == [{1, 100}, {0, 100}, {0, 100}, {1, 0}]
      assert p.green == [{0, 100}, {1, 100}, {0, 100}, {0, 0}]
      assert p.blue == [{0, 100}, {0, 100}, {1, 100}, {0, 0}]
    end

    test "catching bad RGB values" do
      assert_raise FunctionClauseError, fn -> Effects.waveform(fn _ -> {2, 0, 0} end, 1000) end
    end
  end

  describe "number_blink/3" do
    test "blinking out 2" do
      pattern = Effects.number_blink(:red, 2)

      assert pattern.red == [
               {1, 250},
               {1, 0},
               {0, 250},
               {0, 0},
               {1, 250},
               {1, 0},
               {0, 250},
               {0, 0},
               {0, 2000},
               {0, 0}
             ]

      assert pattern.green == [{0, 3_600_000}, {0, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]

      assert pattern.mode == :simple_loop
    end

    test "custom blink out 5" do
      pattern =
        Effects.number_blink(:cyan, 5,
          blink_on_duration: 50,
          blink_off_duration: 200,
          inter_number_delay: 3000
        )

      expected_pattern = [
        {1, 50},
        {1, 0},
        {0, 200},
        {0, 0},
        {1, 50},
        {1, 0},
        {0, 200},
        {0, 0},
        {1, 50},
        {1, 0},
        {0, 200},
        {0, 0},
        {1, 50},
        {1, 0},
        {0, 200},
        {0, 0},
        {1, 50},
        {1, 0},
        {0, 200},
        {0, 0},
        {0, 3000},
        {0, 0}
      ]

      assert pattern.red == [{0, 3_600_000}, {0, 0}]
      assert pattern.green == expected_pattern
      assert pattern.blue == expected_pattern

      assert pattern.mode == :simple_loop
    end

    test "description" do
      pattern = Effects.number_blink(:green, 10)
      assert Program.text_description(pattern) == "Blink green 10 times"
    end
  end

  describe "timing_test/3" do
    test "build a timing test" do
      pattern = Effects.timing_test(:red)

      {header, middle} = Enum.split(pattern.red, 2)
      {middle, trailer} = Enum.split(middle, -2)

      # starts and ends with 100 ms
      assert header == [{1, 100}, {1, 0}]
      assert trailer == [{1, 100}, {1, 0}]

      # middle only has 10 ms off times
      assert Enum.any?(middle, fn {x, duration} ->
               x == 0 and (duration != 0 or duration != 10)
             end)

      assert pattern.green == [{0, 3_600_000}, {0, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]

      assert pattern.mode == :one_shot
    end

    test "description" do
      pattern = Effects.timing_test(:red)
      assert Program.text_description(pattern) == "Timing test pattern in red"
    end
  end
end
