Code.require_file "test_helper.exs", __DIR__

defmodule RopeTest do
  use ExUnit.Case

  @simple "hello world"
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
    rope = Rope.new(@simple)
    is_equal rope, @simple

    rope = Rope.new(@text)
    is_equal rope, @text
  end

  test "can concat two single node ropes together" do
    rope = build_rope @simple
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

  test "concat handles nils" do
    rope = Rope.concat(nil, "test")
    is_equal rope, "test"

    rope = Rope.concat("test", nil)
    is_equal rope, "test"
  end

  test "slice with a start greater then the rope length returns the same as String.slice/3" do
    rope = Rope.new @simple
    assert Rope.slice(rope, 50, 10) == String.slice(@simple, 50, 10)

    rope = build_rope @simple
    assert Rope.slice(rope, 120, 10) == String.slice(@simple, 120, 10)
  end

  test "slice with start equal to the rope returns the same as String.slice/3" do
    rope = Rope.new "test"
    is_equal Rope.slice(rope, 4, 10), String.slice("test", 4, 10)

    rope = Rope.concat "hello", " world"
    length = String.length @simple
    is_equal Rope.slice(rope, length, 10), String.slice(@simple, length, 10)
  end

  test "slice works on single node ropes" do
    rope = Rope.new "test"
    is_equal Rope.slice(rope, 2, 1), "s"
  end

  test "slice works on multi-node ropes" do
    rope = build_rope @simple
    is_equal Rope.slice(rope, 3, 5), String.slice(@simple, 3, 5)
  end

  test "can get slice from middle of text" do
    rope = build_rope @longtext
    is_equal Rope.slice(rope, 231, 15), String.slice(@longtext, 231, 15)
  end

  test "rebalancing shouldn't effect a slice" do
    rope = build_rope @longtext
    rope = Rope.rebalance(rope)
    is_equal Rope.slice(rope, 231, 15), String.slice(@longtext, 231, 15)
  end

  test "get the length of a rope" do
    rope = build_rope @longtext
    assert Rope.length(rope) == String.length(@longtext)

    rope = build_rope @text
    assert Rope.length(rope) == String.length(@text)

    rope = build_rope ""
    assert Rope.length(rope) == String.length("")
  end

  test "get the depth of a rope" do
    rope = build_rope @longtext
    assert Rope.depth(rope) == 185

    rope = build_rope @simple
    assert Rope.depth(rope) == 1
  end

  test "things should rebalance" do
    rope = build_rope @longtext
    assert Rope.depth(rope) == 185

    rope = Rope.rebalance rope
    is_equal rope, @longtext
    assert Rope.depth(rope) == 8
  end

  test "rebalancing a balanced tree should return a rope of equal value" do
    rope = build_rope @longtext
    rope1= Rope.rebalance rope
    rope2 = Rope.rebalance rope1

    is_equal rope1, rope2
    assert Rope.depth(rope1) == Rope.depth(rope2)
  end

  test "rebalancing can be called explicitly anytime" do
    rope = @longtext
      |> build_rope
      |> Rope.rebalance

    rope = Rope.concat(rope, build_rope(@longtext))
    ropebalanced = Rope.rebalance(rope)

    is_equal rope, ropebalanced
  end

  test "find returns the index the search term begins at" do
    rope = @longtext
      |> build_rope
      |> Rope.rebalance

    index = Rope.find(rope, "towels")
    subrope = Rope.slice(rope, index, String.length("towels"))

    is_equal subrope, "towels"
  end

  test "find returns -1 if the term could not be found" do
    rope = @text |> build_rope |> Rope.rebalance

    assert Rope.find(rope, "unknown") == -1
  end

  test "find returns -1 if the rope is nil" do
    assert Rope.find(nil, "anything") == -1
  end

  test "find_all returns an list of matches" do
    rope = @longtext |> build_rope |> Rope.rebalance
    indexes = Rope.find_all(rope, "towel")
    assert indexes == [79, 84, 867]

    rope = @text |> build_rope |> Rope.rebalance
    indexes = Rope.find_all(rope, "you")
    assert indexes == [5,95]
  end

  test "find_all returns an empty list if there are no matches" do
    rope = @text |> build_rope |> Rope.rebalance
    indexes = Rope.find_all(rope, "towels")
    assert indexes == []
  end

  test "replace works like String.replace/4 but with ropes" do
    orig = @text |> build_rope |> Rope.rebalance

    rope = Rope.replace(orig, "you", "me", global: false)
    is_equal rope, String.replace(@text, "you", "me", global: false)

    rope = Rope.replace(orig, "you", "me")
    is_equal rope, String.replace(@text, "you", "me")
  end


  defp build_rope(text) do
    words = text
      |> String.split(" ")

    first = Enum.fetch! words, 0

    words
      |> Enum.drop(1)
      |> Enum.reduce(Rope.new(first), fn (word, rope) -> Rope.concat(rope, " " <> word) end)
  end

  defp is_equal(rope, str)
  when is_record(rope, Rope) and is_binary(str)  do
    assert Rope.length(rope) == String.length(str)
    assert rope_value(rope) == str
  end

  defp is_equal(rope1, rope2)
  when is_record(rope1, Rope) and is_record(rope2, Rope)  do
    assert Rope.length(rope1) == Rope.length(rope2)
    assert rope_value(rope1) == rope_value(rope2)
  end

  defp is_equal(thing1, thing2) do
    assert thing1 == thing2
  end

  defp rope_value(rope) do
    Kernel.inspect rope
  end

end
