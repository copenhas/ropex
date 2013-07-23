Code.require_file "test_helper.exs", __DIR__

defmodule RopeTest do
  use ExUnit.Case

  @text "Have you any idea how much damage that bulldozer would suffer if I just let it roll straight over you?"
  @longtext """
  The Hitchhiker’s Guide to the Galaxy has a few things to say on the subject of towels.
  A towel, it says, is about the most massively useful thing an interstellar hitch hiker 
  can have. Partly it has great practical value — you can wrap it around you for warmth 
  as you bound across the cold moons of Jaglan Beta; you can lie on it on the brilliant 
  marble‐sanded beaches of Santraginus V, inhaling the heady sea vapours; you can sleep 
  under it beneath the stars which shine so redly on the desert world of Kakrafoon; use 
  it to sail a mini raft down the slow heavy river Moth; wet it for use in 
  hand‐to‐hand‐combat; wrap it round your head to ward off noxious fumes or to avoid the 
  gaze of the Ravenous Bugblatter Beast of Traal (a mindbogglingly stupid animal, it 
  assumes that if you can't see it, it can't see you — daft as a bush, but very 
  ravenous); you can wave your towel in emergencies as a distress signal, and of course 
  dry yourself off with it if it still seems to be clean enough.
  """

  test "can create a basic rope" do
    rope = Rope.new("test")
    is_equal rope, "test"

    rope = Rope.new(@text)
    is_equal rope, @text
  end

  test "can concat two single node ropes together" do
    rope = Rope.concat(Rope.new("hello"), Rope.new(" world"))
    is_equal rope, "hello world"
  end

  test "can concat two strings together" do
    rope = Rope.concat("hello", " world")
    is_equal rope, "hello world"
  end

  test "can concat a single node rope and a string" do
    rope = Rope.new("hello")
    rope = Rope.concat(rope, " world")

    is_equal rope, "hello world"
  end

  test "can concat a multi-node rope and a string together" do
    rope = Rope.concat(Rope.new("Have you any idea how "), Rope.new("much damage that bulldozer"))
    str = " would suffer if I just let it roll straight over you?"

    rope = Rope.concat(rope, str)

    is_equal rope, @text
  end

  test "can concat a lot" do
    rope = build_rope @longtext
    is_equal rope, @longtext
  end

  test "slice with a start greater then the rope length returns the same as String.slice/3" do
    rope = Rope.new "test"
    assert Rope.slice(rope, 5, 10) == String.slice("test", 5, 10)

    rope = Rope.concat "hello", " world"
    assert Rope.slice(rope, 12, 10) == String.slice("hello world", 12, 10)
  end

  test "slice with start equal to the rope returns the same as String.slice/3" do
    rope = Rope.new "test"
    assert Rope.slice(rope, 4, 10) == String.slice("test", 4, 10)

    rope = Rope.concat "hello", " world"
    assert Rope.slice(rope, 11, 10) == String.slice("hello world", 11, 10)
  end

  test "slice works on single node ropes" do
    rope = Rope.new "test"
    assert Rope.slice(rope, 2, 1) == "s"
  end

  test "slice works on multi-node ropes" do
    rope = Rope.concat "hello", " world"
    assert Rope.slice(rope, 3, 5) == "lo wo"
  end

  test "can get slice from middle of text" do
    rope = build_rope @longtext
    is_equal Rope.slice(rope, 231, 15), "wrap it around"
  end

  defp build_rope(text) do
    words = text
      |> String.split(" ")

    first = Enum.fetch! words, 0

    words
      |> Enum.drop(1)
      |> Enum.reduce(first, fn (word, rope) -> Rope.concat(rope, " " <> word) end)
  end

  defp is_equal(rope, str) do
    assert rope_value(rope) == str
  end

  defp rope_value(rope) do
    Rope.to_string rope
  end

end
