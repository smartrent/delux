defmodule Delux.RGBTest do
  use ExUnit.Case, async: true

  alias Delux.RGB
  doctest RGB

  describe "new/2" do
    test "converts color names" do
      assert RGB.new(:black) == {0, 0, 0}
      assert RGB.new(:red) == {1, 0, 0}
      assert RGB.new(:green) == {0, 1, 0}
      assert RGB.new(:blue) == {0, 0, 1}
      assert RGB.new(:cyan) == {0, 1, 1}
      assert RGB.new(:magenta) == {1, 0, 1}
      assert RGB.new(:yellow) == {1, 1, 0}
      assert RGB.new(:white) == {1, 1, 1}
    end

    test "raises on out-of-range raw colors" do
      assert_raise FunctionClauseError, fn -> RGB.new({255, 255, 255}) end
      assert_raise FunctionClauseError, fn -> RGB.new({-1, -1, -1}) end
    end

    test "on and off are aliases for white and black" do
      assert RGB.new(:black) == RGB.new(:off)
      assert RGB.new(:white) == RGB.new(:on)
    end
  end

  describe "to_ansidata/2" do
    test "color names" do
      ansidata = RGB.to_ansidata(:red)

      assert ansidata_to_binary(ansidata, false) == "red"
      assert ansidata_to_binary(ansidata, true) == "\e[31mred\e[0m"
    end

    test "color tuples" do
      ansidata = RGB.to_ansidata({0, 0.5, 0})

      assert ansidata_to_binary(ansidata, false) == "{0, 0.5, 0}"
      assert ansidata_to_binary(ansidata, true) == "{0, 0.5, 0}"
    end
  end

  defp ansidata_to_binary(ansidata, color?) do
    ansidata
    |> IO.ANSI.format(color?)
    |> IO.chardata_to_string()
  end
end
