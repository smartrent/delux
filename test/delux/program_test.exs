defmodule Delux.ProgramTest do
  use ExUnit.Case, async: true

  alias Delux.Effects
  alias Delux.Program

  doctest Program

  describe "adjust_brightness_pwm/2" do
    test "no pwm needed" do
      red = Effects.on(:red)

      assert Program.adjust_brightness_pwm(red, 100) == red
      assert Program.adjust_brightness_pwm(red, 0) == Effects.off()
    end

    test "pwm needed but off" do
      off = Effects.off()

      assert Program.adjust_brightness_pwm(off, 50) == off
    end

    test "pwm needed and solid on" do
      red = Effects.on(:red)

      assert %Program{
               red: [{1, 1}, {1, 0}, {0, 19}, {0, 0}],
               green: [{0, 3_600_000}, {0, 0}],
               blue: [{0, 3_600_000}, {0, 0}]
             } = Program.adjust_brightness_pwm(red, 1)

      assert %Program{
               red: [{1, 4}, {1, 0}, {0, 16}, {0, 0}],
               green: [{0, 3_600_000}, {0, 0}],
               blue: [{0, 3_600_000}, {0, 0}]
             } = Program.adjust_brightness_pwm(red, 50)

      assert %Program{
               red: [{1, 9}, {1, 0}, {0, 11}, {0, 0}],
               green: [{0, 3_600_000}, {0, 0}],
               blue: [{0, 3_600_000}, {0, 0}]
             } = Program.adjust_brightness_pwm(red, 75)

      assert %Program{
               red: [{1, 20}, {1, 0}, {0, 0}, {0, 0}],
               green: [{0, 3_600_000}, {0, 0}],
               blue: [{0, 3_600_000}, {0, 0}]
             } = Program.adjust_brightness_pwm(red, 99)
    end
  end

  describe "simplify/1" do
    test "basic effects are already simple" do
      assert Program.simplify(Effects.off()) == Effects.off()
      assert Program.simplify(Effects.on(:magenta)) == Effects.on(:magenta)
      assert Program.simplify(Effects.blink(:green, 5)) == Effects.blink(:green, 5)
      assert Program.simplify(Effects.blip(:red, :green)) == Effects.blip(:red, :green)
    end

    test "cycles of the same color simplify" do
      cycle = Effects.cycle([:black, :black, :black], 1)
      simplified = Program.simplify(cycle)

      assert simplified.red == [{0, 999}, {0, 0}]
    end

    test "handles divide-by-zero case" do
      program = %{Effects.off() | red: [{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 100}]}
      simplified = Program.simplify(program)

      assert simplified.red == [{1, 0}, {5, 100}]
    end
  end
end
