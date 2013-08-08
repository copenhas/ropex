defmodule RopeTest do
  use ExUnit.Case

  @simple "hello world"
  @text "Have you any idea how much damage that bulldozer would suffer if I just let it roll straight over you?"
  @longtext File.read!("test/fixtures/towels.txt")

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
    assert indexes == [79, 89, 868]

    rope = @text |> build_rope |> Rope.rebalance
    indexes = Rope.find_all(rope, "you")
    assert indexes == [5,98]
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

    rope = @longtext |> build_rope |> Rope.rebalance
    rope = Rope.replace(rope, "towel", "duck")
    is_equal rope, String.replace(@longtext, "towel", "duck")
  end

  test "insert_at allows creating a new rope with the text added" do
    orig = build_rope "Beware of the Leopard"

    is_equal Rope.insert_at(orig, 63, " END"), "Beware of the Leopard END"
    is_equal Rope.insert_at(orig, -8, " MIDDLE"), "Beware of the MIDDLE Leopard"
    is_equal Rope.insert_at(orig, 2, "SPLIT"), "BeSPLITware of the Leopard"
  end

  test "remove_at allows removing a substr of the rope" do
    orig = build_rope "Beware of the Leopard"

    is_equal Rope.remove_at(orig, 63, 10), "Beware of the Leopard"
    is_equal Rope.remove_at(orig, -7, 3), "Beware of the pard"
    is_equal Rope.remove_at(orig, 2, 5), "Beof the Leopard"
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
    assert rope_value(rope) == str
    assert Rope.length(rope) == String.length(str)
  end

  defp is_equal(rope1, rope2)
  when is_record(rope1, Rope) and is_record(rope2, Rope)  do
    assert rope_value(rope1) == rope_value(rope2)
    assert Rope.length(rope1) == Rope.length(rope2)
  end

  defp is_equal(thing1, thing2) do
    assert thing1 == thing2
  end

  defp rope_value(rope) do
    Kernel.inspect rope
  end
end
