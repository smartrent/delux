defmodule Delux.PatternTest do
  use ExUnit.Case, async: true

  alias Delux.Effects
  alias Delux.Pattern

  doctest Pattern

  defp on_pattern(), do: Effects.on(:red).red
  defp off_pattern(), do: Effects.off().red
  defp blink_2hz_pattern(), do: Effects.blink(:red, 2).red
  defp blip_pattern(), do: Effects.blip(:red, :black).red

  describe "pwm/2" do
    test "no pwm needed" do
      all_on = on_pattern()

      assert Pattern.pwm(all_on, 100) == all_on
      assert Pattern.pwm(all_on, 0) == off_pattern()

      assert Pattern.pwm(blip_pattern(), 0) == [{0, 30}, {0, 0}]
    end

    test "patterns have same duration when off" do
      assert Pattern.pwm(blip_pattern(), 0) == [{0, 30}, {0, 0}]
    end

    test "pwm needed but off pattern" do
      off = off_pattern()

      assert Pattern.pwm(off, 50) == off
    end

    test "pwm needed and solid on" do
      all_on = on_pattern()

      assert [{1, 1}, {1, 0}, {0, 19}, {0, 0}] = Pattern.pwm(all_on, 1)

      assert [{1, 4}, {1, 0}, {0, 16}, {0, 0}] = Pattern.pwm(all_on, 50)

      assert [{1, 9}, {1, 0}, {0, 11}, {0, 0}] = Pattern.pwm(all_on, 75)

      assert [{1, 20}, {1, 0}, {0, 0}, {0, 0}] = Pattern.pwm(all_on, 99)
    end
  end

  describe "to_iodata/1" do
    test "simple conversions" do
      assert pattern_to_binary(off_pattern()) == "0 3600000 0 0 "
      assert pattern_to_binary(blink_2hz_pattern()) == "1 250 1 0 0 250 0 0 "
    end

    test "scaled to LED max brightness" do
      assert pattern_to_binary(blink_2hz_pattern(), 255) == "255 250 255 0 0 250 0 0 "
    end
  end

  describe "simplify/1" do
    test "basic effects are already simple" do
      assert Pattern.simplify(off_pattern()) == off_pattern()
      assert Pattern.simplify(on_pattern()) == on_pattern()
      assert Pattern.simplify(blink_2hz_pattern()) == blink_2hz_pattern()
      assert Pattern.simplify(blip_pattern()) == blip_pattern()
    end

    test "cycles of the same color simplify" do
      cycle = Effects.cycle([:black, :black, :black], 1)
      simplified = Pattern.simplify(cycle.red)

      assert simplified == [{0, 999}, {0, 0}]
    end

    test "handles divide-by-zero case" do
      pattern = [{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 100}]
      simplified = Pattern.simplify(pattern)

      assert simplified == [{1, 0}, {5, 100}]
    end
  end

  defp pattern_to_binary(pattern, brightness \\ 1) do
    {iodata, _duration} = Pattern.build_iodata(pattern, brightness)
    IO.iodata_to_binary(iodata)
  end
end
