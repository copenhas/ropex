defmodule Rope do
  @moduledoc """
  A rope is a tree structure for representing strings.

  ## Ropes
  A rope provides a scalable way to represent and manipulation strings
  from small to huge. They provide the following characteristics:

  1. Immutable (kind of has to be anyway for BEAM)
  2. Common operations are effecient
  3. Common oeprations scale
  4. Should be able to handle alternate representations (ex: IO stream) - we'll see

  ## Links
  - http://citeseer.ist.psu.edu/viewdoc/download?doi=10.1.1.14.9450&rep=rep1&type=pdf
  - https://en.wikipedia.org/wiki/Rope_\(data_structure\)
  """


  defrecordp :rnode, Rope,
    length: 0 :: non_neg_integer,
    depth: 1 :: non_neg_integer,
    left: nil :: Rope,
    right: nil :: Rope

  defrecordp :rleaf, Rope,
    length: 0 :: non_neg_integer,
    depth: 0 :: non_neg_integer,
    value: nil :: binary

  @type rope :: Rope | nil

  # copied the type defs from the String module
  @type str :: binary
  @type codepoint :: str
  @type grapheme :: str


  @doc """
  Creates a new rope with the string provided
  """
  @spec new(str | nil) :: rope
  def new(nil) do
    nil
  end

  def new(str) when is_binary(str) do
    rleaf(length: String.length(str), value: str)
  end

  @doc """
  Concatenates two ropes together producing a new single rope.
  """
  @spec concat(rope | str, rope | str) :: rope
  def concat(nil, nil) do
    nil
  end

  def concat(rope, nil) do
    ropeify rope
  end

  def concat(nil, rope) do
    ropeify rope
  end

  def concat(rope1, rope2) do
    rope1 = ropeify rope1
    rope2 = ropeify rope2

    depth = Enum.max([rope1.depth, rope2.depth]) + 1

    rnode(depth: depth,
          left: rope1,
          right: rope2,
          length: rope1.length + rope2.length)
  end

  @doc """
  Returns a sub-rope starting at the offset given by the first, and a length given by 
  the second. If the offset is greater than string length, than it returns nil.

  Similar to String.slice/3
  """
  @spec slice(rope, integer, integer) :: rope
  def slice(nil, _start, _len) do
    nil
  end

  def slice(rleaf(value: value), start, len) do
    ropeify String.slice(value, start, len)
  end

  def slice(rnode(length: rlen), start, _len) 
  when start > rlen do
    nil
  end

  def slice(rnode(length: rlen), start, _len) 
  when start == rlen do
    ropeify ""
  end

  def slice(rope, start, len) do
    rnode(left: left,
          right: right) = rope

    if start < 0 do
      start = rope.length + start
    end

    {startRight, lenRight} =
      if start < left.length do
        {0, len - (left.length - start)}
      else
        {start - left.length, len}
      end

    leftSub = slice(left, start, len)
    rightSub = slice(right, startRight, lenRight)

    concat(leftSub, rightSub)
  end

  @doc """
  Rebalance the rope explicitly to help keep insert, remove, etc
  efficient. This is a pretty greedy rebalancing and should produce
  a fully balanced rope.
  """
  @spec rebalance(rope) :: rope
  def rebalance(nil) do
    nil
  end

  def rebalance(rope) when is_record(rope, Rope) do
    leaves = rope
      |> Enum.reduce([], fn(leaf, acc) -> [leaf | acc] end)
      |> Enum.reverse

    rebuild_rope([], leaves)
  end

  @doc """
  Retrieve the length in ut8 characters in the rope.
  """
  @spec length(rope) :: non_neg_integer
  def length(rope) do
    case rope do
      nil -> 0
      rleaf(length: len) -> len
      rnode(length: len) -> len
    end
  end


  @doc """
  Returns the depth of the rope tree.
  """
  @spec depth(rope) :: non_neg_integer
  def depth(rope) do
    case rope do
      nil -> 0
      rnode(depth: depth) -> depth
      rleaf(depth: depth) -> depth
    end
  end

  @doc """
  Produces a new rope with the string inserted at the index provided.
  This wraps around so negative indexes will start from the end.
  """
  @spec insert_at(rope, integer, str) :: rope
  def insert_at(nil, _index, str) do
    ropeify(str)
  end

  def insert_at(rope, index, str) do
    if index < 0 do
      index = rope.length + index
    end

    left = slice(rope, 0, index)
    right = slice(rope, index, rope.length)

    left |> concat(str) |> concat(right)
  end

  @doc """
  Returns the index of the first match or -1 if no match was found.
  """
  @spec find(rope, str) :: integer
  def find(nil, _term) do
    -1
  end

  def find(rope, term) do
    termLen = String.length(term)

    matchIndex = do_reduce_while(0..rope.length, 0,
      fn(_index, matchIndex) ->
        subrope = Rope.slice(rope, matchIndex, termLen)
        Kernel.inspect(subrope) != term
      end,
      fn(index, _matchIndex) ->
        index
      end
    )

    if matchIndex == rope.length and termLen > 1 do
      -1
    else
      matchIndex
    end
  end

  @doc """
  Find all matches in the rope returning a list of indexes,
  or an empty list if no matches were found. The list is in order
  from first to last match.
  """
  @spec find_all(rope, str) :: list(non_neg_integer)
  def find_all(rope, term) do
    do_find_all(rope, term, []) |> Enum.reverse
  end

  @doc """
  Replaces the first match with the replacement text and returns
  the new rope. If not found then the existing rope is returned.
  By default, it replaces all entries, except if the global option 
  is set to false.
  """
  @spec replace(rope, str, str, list) :: rope
  def replace(rope, pattern, replacement, opts // []) do
    global = Keyword.get(opts, :global, true)

    if global do
      do_replace_all(rope, pattern, replacement)
    else
      do_replace(rope, pattern, replacement)
    end
  end

  @doc """
  Converts the entire rope to a single binary.
  """
  @spec to_binary(rope) :: binary
  def to_binary(rope) do
    rope
    |> Stream.map(fn(rleaf(value: value)) -> value end)
    |> Enum.join
  end


  defp ropeify(rope) do
    case rope do
      rnode() -> rope
      rleaf() -> rope
      <<_ :: binary>> ->
        Rope.new(rope)
      nil -> nil
    end
  end

  defp do_find_all(rope, term, matches) do
    termLen = String.length term

    lastMatch = case matches do
      [] -> 0
      [last | _tail] -> last
    end

    case find(rope, term) do
      -1 -> matches
      match when match >= 0 ->
        offset = match + termLen
        leftOvers = Rope.slice(rope, offset, rope.length - offset)
        do_find_all(leftOvers, term, [match + lastMatch | matches])
    end
  end

  def do_replace(rope, pattern, replacement) do
    termLen = String.length(pattern)
    index = find(rope, pattern)

    leftRope = slice(rope, 0, index)
    rightRope = slice(rope, index + termLen, rope.length - index - termLen)

    leftRope |> concat(replacement) |> concat(rightRope)
  end

  defp do_replace_all(rope, pattern, replacement) do
    termLen = String.length(pattern)
    indexes = find_all(rope, pattern)

    {offset, subropes} = Enum.reduce(indexes, {0, []}, fn(index, {offset, ropes}) ->
      len = index - offset
      if offset != 0, do: len = len + termLen

      leftRope = slice(rope, offset, len)
      {index + termLen, [replacement | [leftRope | ropes]]}
    end)

    leftRope = slice(rope, offset + termLen, rope.length)
    subropes = [leftRope | subropes]

    subropes = Enum.reverse subropes
    rebuild_rope [], subropes
  end

  defp do_reduce_while(enumerable, acc, whiler, reducer) do
    try do
      Enum.reduce(enumerable, acc, fn(el, acc) ->
        if not whiler.(el, acc) do
          throw {:reduce_while, acc}
        else
          reducer.(el, acc)
        end
      end)
    catch
      :throw, {:reduce_while, val} -> val
    end
  end

  defp rebuild_rope(subropes, [leaf1, leaf2 | leaves]) do
    subrope = Rope.concat(leaf1, leaf2)
    rebuild_rope([subrope | subropes], leaves)
  end

  defp rebuild_rope(subropes, [leaf1]) do
    rebuild_rope([leaf1 | subropes], [])
  end

  defp rebuild_rope([rope], []) do
    rope
  end

  defp rebuild_rope(subropes, []) do
    subropes = Enum.reverse subropes
    rebuild_rope([], subropes)
  end


  defimpl Binary.Chars, for: Rope do
    def to_binary(rope) do
      Rope.to_binary(rope)
    end
  end


  defimpl Enumerable, for: Rope do
    def count(rope) do
      Rope.reduce_leaves(rope, 0, fn(leaf, acc) -> acc + 1 end)
    end

    def member?(rope, value) do
      try do
        Rope.reduce_leaves(rope, false,
          fn(leaf, false) ->
            if leaf == value do
              #yeah yeah, it's an error for control flow
              throw :found
            end
            false
          end)
      catch
        :throw, :found -> true
      end
    end

    def reduce(rope, acc, fun) do
      Rope.reduce_leaves(rope, acc, fun)
    end
  end

  @doc false
  def reduce_leaves(rnode(right: right, left: left), acc, fun) do
      acc = reduce_leaves(left, acc, fun)
      reduce_leaves(right, acc, fun)
  end

  def reduce_leaves(rleaf() = leaf, acc, fun) do
    fun.(leaf, acc)
  end

  def reduce_leaves(nil, acc, fun) do
    acc
  end


  defimpl Inspect, for: Rope do
    def inspect(rope, _opts) do
      Rope.to_algebra_doc(rope)
    end
  end

  @doc false
  def to_algebra_doc(rnode(left: nil, right: right)) do
    to_algebra_doc(right)
  end

  def to_algebra_doc(rnode(left: left, right: nil)) do
    to_algebra_doc(left)
  end

  def to_algebra_doc(rnode(left: left, right: right)) do
    Inspect.Algebra.concat to_algebra_doc(left), to_algebra_doc(right)
  end

  def to_algebra_doc(rleaf(value: value)) do
    value
  end

end
