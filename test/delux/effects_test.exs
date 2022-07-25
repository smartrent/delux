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

      assert off.duration == :infinity
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

      assert pattern.duration == :infinity
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

      assert pattern.duration == :infinity
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

    test "description" do
      pattern = Effects.blink(:blue, 2)
      assert Program.text_description(pattern) == "blue at 2 Hz"
    end
  end

  describe "blip/3" do
    test "build a blip" do
      pattern = Effects.blip(:red, :green)

      assert pattern.red == [{0, 10}, {0, 0}, {1, 20}, {1, 0}, {0, 3_600_000}, {0, 0}]
      assert pattern.green == [{0, 20}, {0, 0}, {1, 20}, {1, 0}, {0, 3_600_000}, {0, 0}]
      assert pattern.blue == [{0, 3_600_000}, {0, 0}]

      assert pattern.duration == 40
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

      assert pattern.duration == :infinity
    end

    test "description" do
      pattern = Effects.cycle([:red, :green, :blue], 1)
      assert Program.text_description(pattern) == "red-green-blue cycle at 1 Hz"
    end
  end

  describe "waveform/2" do
    # TODO
  end
end
