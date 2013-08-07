Code.require_file "test_helper.exs", __DIR__

defmodule GraphVizTest do
  use ExUnit.Case

  @simple "hello world"
  @text "Have you any idea how much damage that bulldozer would suffer if I just let it roll straight over you?"
  @longtext File.read!("test/fixtures/towels.txt")

  test "write graph" do
    rope = @simple |> build_rope
    write_dot_file "simple", rope

    rope = @text |> build_rope
    write_dot_file "bulldozer", rope

    rope = Rope.rebalance rope
    write_dot_file "bulldozerrebalanced", rope

    rope = @longtext |> build_rope
    write_dot_file "towels", rope

    rope = Rope.rebalance rope
    write_dot_file "towelsrebalanced", rope
  end

  test "graph rope manipulations" do
    rope = Rope.new(@text) 
    inserted = Rope.insert_at(rope, 30, @simple)
    slice = Rope.slice(inserted, 80, rope.length)
    concat1 = Rope.concat(inserted, slice)
    concat2 = Rope.concat([concat1, "random", "text added to", "the end"])
    balanced = Rope.rebalance concat2 

    write_dot_file "manipulations", [
      original: rope, 
      insert: inserted, 
      slice: slice, 
      concat: concat1, 
      multiconcat: concat2
    ]

    write_dot_file "manipulationsbalanced", [
      balanced: balanced
    ]
  end

  defp build_rope(text) do
    words = text
      |> String.split(" ")

    first = Enum.fetch! words, 0

    words
      |> Enum.drop(1)
      |> Enum.reduce(Rope.new(first), fn (word, rope) -> Rope.concat(rope, " " <> word) end)
  end

  defp write_dot_file(name, rope)
  when is_record rope, Rope do
    write_dot_file(name, [rope: rope])
  end

  defp write_dot_file(name, ropes)
  when is_list ropes do
    File.mkdir("graphs")
    file = File.open!("graphs/#{name}.dot", [:write, :utf8])

    IO.write(file, "digraph #{name} {\n")
    IO.write(file, "\tnode [shape=record]\n")

    visited = HashDict.new()

    Enum.reduce(ropes, visited, fn({key, rope}, visited) ->
      {id, visited} = do_write_dot_file(rope, visited, fn(text) ->
        IO.write(file, "\t#{text}\n") 
      end)

      IO.write(file, "\t#{key} [label=\"#{key}\", shape=oval, style=filled, fillcolor=darkseagreen]\n")
      IO.write(file, "\t#{key} -> #{id}\n")
      visited
    end)

    IO.write(file, "}")

    File.close file
  end

  defp do_write_dot_file({Rope, length, _depth, left, right} = node, visited, appender) do
    myId = :erlang.phash2 node

    if not Dict.has_key?(visited, myId) do
      appender.("#{myId} [label=\"{<type> concat | <length> #{length} | { <left> left | <right> right } }\", style=filled, fillcolor=gray89]")
      {leftId, visited} = do_write_dot_file left, visited, appender
      appender.("#{myId}:left -> #{leftId}:type")

      {rightId, visited} = do_write_dot_file right, visited, appender
      appender.("#{myId}:right -> #{rightId}:type")

      visited = Dict.put(visited, myId, true)
    end

    {myId, visited}
  end

  defp do_write_dot_file({Rope, length, _depth, value} = leaf, visited, appender) do
    myId = :erlang.phash2 leaf
    if not Dict.has_key?(visited, myId) do
      appender.("#{myId} [label=\"{ <type> leaf | <length> #{length} | <value> &#8220;#{value}&#8221; }\"]")
      visited = Dict.put(visited, myId, true)
    end
    {myId, visited}
  end
end
