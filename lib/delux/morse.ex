defmodule Delux.Morse do
  @moduledoc """
  Functions for Morse code patterns
  """

  alias Delux.Program
  alias Delux.RGB

  @default_words_per_minute 10

  # See https://www.itu.int/rec/R-REC-M.1677-1-200910-I/
  @table %{
    ?A => ".-",
    ?B => "-...",
    ?C => "-.-.",
    ?D => "-..",
    ?E => ".",
    ?É => "..-..",
    ?F => "..-.",
    ?G => "--.",
    ?H => "....",
    ?I => "..",
    ?J => ".---",
    ?K => "-.-",
    ?L => ".-..",
    ?M => "--",
    ?N => "-.",
    ?O => "---",
    ?P => ".--.",
    ?Q => "--.-",
    ?R => ".-.",
    ?S => "...",
    ?T => "-",
    ?U => "..-",
    ?V => "...-",
    ?W => ".--",
    ?X => "-..-",
    ?Y => "-.--",
    ?Z => "--..",
    ?1 => ".----",
    ?2 => "..---",
    ?3 => "...--",
    ?4 => "....-",
    ?5 => ".....",
    ?6 => "-....",
    ?7 => "--...",
    ?8 => "---..",
    ?9 => "----.",
    ?0 => "-----",
    ?. => ".-.-.-",
    ?, => "--..--",
    ?: => "---...",
    ?? => "..--..",
    ?' => ".----.",
    ?- => "-....-",
    ?/ => "-..-.",
    ?( => "-.--.",
    ?) => "-.--.-",
    ?" => ".-..-.",
    ?= => "-...-",
    ?+ => ".-.-.",
    ?* => "-..-",
    ?@ => ".--.-."
  }

  @type options() :: [words_per_minute: number(), loop?: boolean()]

  @doc """
  Convert a text string to Morse code

  Programs created by this function require more precise timing than most
  effects. Linux's HZ configuration setting can limit timer precision for
  blinking LEDs to 10 ms (HZ=100). Please see the README.md for more
  information and how to configure Delux to partially compensate.

  Options:

  * `:words_per_minute` - the rate at which to send the message
  * `:loop?` - set to `true` to repeat the message (defaults to `false`)
  """
  @spec encode(RGB.color(), String.t(), options()) :: Program.t()
  def encode(c, string, options \\ []) do
    {r, g, b} = RGB.new(c)

    words_per_minute = options[:words_per_minute] || @default_words_per_minute
    loop? = options[:loop?] || false

    if words_per_minute < 1 or words_per_minute > 100 do
      raise ArgumentError, "Invalid :words_per_minute"
    end

    up_string = String.upcase(string, :ascii)
    base_elements = morse(up_string, words_per_minute)
    duration = duration_elements(base_elements)
    mode = if loop?, do: :simple_loop, else: :one_shot

    %Program{
      red: elements(r, base_elements, duration),
      green: elements(g, base_elements, duration),
      blue: elements(b, base_elements, duration),
      description: "Morse code: #{up_string}",
      mode: mode
    }
  end

  # Handle the easy brightness options (100% off and 100% on)
  defp elements(0, _pattern, duration), do: [{0, duration}, {0, 0}]
  defp elements(1, pattern, _duration), do: pattern

  defp elements(brightness, pattern, _duration) do
    # Adjust the brightness to whatever it should be for this color channel
    Enum.map(pattern, fn
      {1, ms} -> {brightness, ms}
      other -> other
    end)
  end

  defp duration_elements(elements) do
    Enum.reduce(elements, 0, fn {_value, duration}, acc -> acc + duration end)
  end

  defp morse(string, words_per_minute) do
    dot_ms = round(1200 / words_per_minute)
    word_ms = dot_ms * 7

    words = String.split(string)

    for word <- words do
      [morse_word(word, dot_ms), {0, word_ms}, {0, 0}]
    end
    |> List.flatten()
  end

  defp morse_word(word, dot_ms) do
    letters = String.to_charlist(word)
    letter_ms = dot_ms * 3

    for letter <- letters do
      morse_letter(letter, dot_ms)
    end
    |> Enum.intersperse([{0, letter_ms}, {0, 0}])
  end

  defp morse_letter(letter, dot_ms) do
    case Map.fetch(@table, letter) do
      {:ok, signals} ->
        morse_pattern(signals, dot_ms)

      :error ->
        []
    end
  end

  defp morse_pattern(signals, dot_ms) do
    for <<code <- signals>> do
      case code do
        ?. -> [{1, dot_ms}, {1, 0}]
        ?- -> [{1, dot_ms * 3}, {1, 0}]
      end
    end
    |> Enum.intersperse([{0, dot_ms}, {0, 0}])
  end
end
