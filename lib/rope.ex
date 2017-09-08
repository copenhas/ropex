defmodule Rope do
  @moduledoc """
  A rope is a tree structure for representing strings.

  ## Ropes
  A rope provides a tree based scalable way to represent and manipulation strings
  from small to huge. They provide the following characteristics:

  1. Immutable (kind of has to be anyway for BEAM)
  2. Common operations are effecient
  3. Common oeprations scale
  4. Should be able to handle alternate representations (ex: IO stream) - we'll see

  A rope is build up of leaf and parent/concatenation nodes. Leaf nodes contain the
  chunks of binary strings that are concatenated or inserted into the rope. The
  parent/concatentation nodes are purely used to link the various leaf nodes together.
  The concatentation nodes contain basic tree information.

  ## Ropes as strings
  Although they can not be swapped in, this rope implementation supports the
  Kernel.Inspect and Binary.Chars protocols.

  ## Ropes as enumerations
  An implmentation of the Enumerable protocol has been provided to enumerate
  over the leaf nodes which contain the chunks of binary data. The parent/concat
  nodes are skipped.

  ## Notes
  Current implementation is mostly focused on operations that work well at larger
  scales. Performance should hopefully improve over time but don't expect a fully
  String module compatible API.

  ## Links
  - http://citeseer.ist.psu.edu/viewdoc/download?doi=10.1.1.14.9450&rep=rep1&type=pdf
  - https://en.wikipedia.org/wiki/Rope_\(data_structure\)
  """

  require Record

  @partition_size_threshold 1000
  @partition_term_ratio 0.1
  @partition_depth_limit 3

  defmodule Rnode do
    defstruct [
      length: 0,
      depth: 1,
      left: nil,
      right: nil
    ]

    @type t :: %__MODULE__{
      length: non_neg_integer,
      depth: non_neg_integer,
      left: Rope.t,
      right: Rope.t
    }
  end

  defmodule Rleaf do
    defstruct [
      length: 0,
      depth: 0,
      value: nil
    ]

    @type t :: %__MODULE__{
      length: non_neg_integer,
      depth: non_neg_integer,
      value: binary
    }
  end

  @type t :: Rnode.t | Rleaf.t | nil

  # copied the type defs from the String module
  @type str :: binary
  @type codepoint :: str
  @type grapheme :: str


  @doc """
  Creates a new rope with the string provided. Not needed since
  `concat/2` supports strings and ropes as arguments.

  ## Examples

      iex> Rope.new("Don't panic") |> Rope.to_string
      "Don't panic"
  """
  @spec new(str | nil) :: t
  def new(nil) do
    nil
  end

  def new(str) when is_binary(str) do
    %Rleaf{length: String.length(str), value: str}
  end

  @doc """
  Concatenates the list of ropes or strings together into a single new rope.
  Accepts ropes or strings as arguments. Additionally you can override the
  auto-rebalancing behavior with a `rebalance: false` option.

  ## Examples

      iex> Rope.concat(["Time is", " an illusion."]) |> Rope.to_string
      "Time is an illusion."

      iex> Rope.concat([Rope.new("terrible"), " ghastly", " silence"]) |> Rope.to_string
      "terrible ghastly silence"
  """
  @spec concat(list(t | str), list) :: t
  def concat(_rope, _opts \\ [])
  def concat([first | rest], opts) do
    Enum.reduce(rest, ropeify(first), fn(right, left) -> do_concat(left, right, opts) end)
  end

  def concat([], _opts) do
    nil
  end


  @doc """
  Returns a sub-rope starting at the offset given by the first, and a length given by
  the second. If the offset is greater than string length, than it returns nil.

  Similar to String.slice/3, check the tests for some examples of usage.
  """
  @spec slice(t, integer, integer) :: t
  def slice(nil, _start, _len) do
    nil
  end

  def slice(_rope, _start, len) when len == 0 do
    ropeify ""
  end

  def slice(%Rnode{length: rlen}, start, len)
  when start == rlen and len > 0 do
    ropeify ""
  end

  def slice(node = %Rnode{length: rlen}, start, len)
  when start == 0 and rlen <= len and len > 0 do
    node
  end

  def slice(%Rnode{length: rlen}, start, len)
  when start > rlen and len > 0 do
    nil
  end

  def slice(leaf = %Rleaf{length: rlen, value: value}, start, len)
  when len > 0 do
    if start == 0 and rlen <= len do
      leaf
    else
      ropeify String.slice(value, start, len)
    end
  end

  def slice(rope, start, len) when len > 0 do
    %Rnode{left: left,
          right: right} = rope

    start =
      if start < 0 do
        rope.length + start
      else
        start
      end

    {startRight, lenRight} =
      if start < left.length do
        {0, len - (left.length - start)}
      else
        {start - left.length, len}
      end

    leftSub = slice(left, start, len)

    if lenRight > 0 do
      rightSub = slice(right, startRight, lenRight)
      concat([leftSub, rightSub])
    else
      leftSub
    end
  end

  @doc """
  Checks if the rope is considered balanced based on comparing total length
  and depth verses the fibanocci sequence.
  """
  @spec balanced?(t) :: boolean
  def balanced?(nil) do
    true
  end

  def balanced?(rope) do
    depth = Rope.depth(rope)
    length = Rope.length(rope)

    length >= fib(depth + 2)
  end

  @doc """
  Rebalance the rope explicitly to help keep insert, remove, etc
  efficient. This is a pretty greedy rebalancing and should produce
  a fully balanced rope.
  """
  @spec rebalance(t) :: t
  def rebalance(nil) do
    nil
  end

  def rebalance(%Rleaf{} = rope), do: rebalance_rope(rope)
  def rebalance(%Rnode{} = rope), do: rebalance_rope(rope)

  defp rebalance_rope(rope) do
    leaves =
      rope
      |> Enum.reduce([], fn(leaf, acc) -> [leaf | acc] end)
      |> Enum.reverse

    rebuild_rope([], leaves)
  end

  @doc """
  Retrieve the length in ut8 characters in the rope.

  ## Examples

      iex> Rope.length(Rope.concat([Rope.new("terrible"), " ghastly silence"]))
      24
  """
  @spec length(t) :: non_neg_integer
  def length(rope) do
    case rope do
      nil -> 0
      %Rleaf{length: len} -> len
      %Rnode{length: len} -> len
    end
  end


  @doc """
  Returns the depth of the rope tree. Only particularly of interest to
  the curious, or those wanting to calculate for themselves when to
  rebalance.

  Concatenation nodes have a depth of 1 and leaf nodes have a depth of 0.

  ## Examples

      iex> Rope.depth(Rope.concat([Rope.new("terrible"), " ghastly silence"]))
      1

      iex> Rope.depth(Rope.concat([Rope.new("terrible"), " ghastly", " silence"]))
      2
  """
  @spec depth(t) :: non_neg_integer
  def depth(rope) do
    case rope do
      nil -> 0
      %Rnode{depth: depth} -> depth
      %Rleaf{depth: depth} -> depth
    end
  end

  @doc """
  Produces a new rope with the string inserted at the index provided.
  This wraps around so negative indexes will start from the end.

  ## Examples

      iex> Rope.insert_at(Rope.concat(["infinite ", "number ", "monkeys"]), 16, "of ") |> Rope.to_string
      "infinite number of monkeys"

      iex> Rope.insert_at(Rope.concat(["infinite ", "number ", "monkeys"]), -7, "of ") |> Rope.to_string
      "infinite number of monkeys"
  """
  @spec insert_at(t, integer, str) :: t
  def insert_at(nil, _index, str) do
    ropeify(str)
  end

  def insert_at(rope, index, str) do
    index =
      if index < 0 do
        rope.length + index
      else
        index
      end

    left = slice(rope, 0, index)
    right = slice(rope, index, rope.length)

    concat([left, str, right])
  end

  @doc """
  Produces a new rope with the substr defined by the starting index and the length of
  characters removed. The advantage of this is it takes full advantage of ropes
  being optimized for index based operation.

  ## Examples

      iex> Rope.remove_at(Rope.concat(["infinite ", "number of ", "monkeys"]), 19, 3) |> Rope.to_string
      "infinite number of keys"

      iex> Rope.remove_at(Rope.concat(["infinite ", "number of ", "monkeys"]), -7, 3) |> Rope.to_string
      "infinite number of keys"
  """
  @spec remove_at(t, integer, non_neg_integer) :: t
  def remove_at(nil, _index, _len) do
    nil
  end

  def remove_at(rope, index, len) do
    index =
      if index < 0 do
        rope.length + index
      else
        index
      end

    left = slice(rope, 0, index)
    right = slice(rope, index + len, rope.length)

    concat([left, right])
  end

  @doc """
  Returns the index of the first match or -1 if no match was found.

  ## Examples

      iex> Rope.find(Rope.concat(["loathe it", " or ignore it,", " you can't like it"]), "it")
      7

      iex> Rope.find(Rope.concat(["loathe it", " or ignore it,", " you can't like it"]), "and")
      -1
  """
  @spec find(t, str) :: integer
  def find(nil, _term) do
    -1
  end

  Record.defrecordp :findctxt,
    findIndex: 0, #where the match started in the rope
    termIndex: 0  #next index to try

  @type findctxt_t :: record(:findctxt,
    findIndex: non_neg_integer, #where the match started in the rope
    termIndex: non_neg_integer  #next index to try
  )

  def find(rope, term) do
    termLen = String.length(term)

    foundMatch = fn(findctxt(termIndex: i)) -> i == termLen end

    {_offset, possibles} = do_reduce_while(rope, { 0, []},
      fn(_leaf, {_offset, possibles}) ->
        # it wil continue so long as we retruen true
        # we want to stop when we have a match
        not Enum.any?(possibles, foundMatch)
      end,
      fn(%Rleaf{length: len, value: chunk}, {offset, possibles}) ->
        {offset + len, build_possible_matches(offset, chunk, term, possibles)}
      end
    )

    match = possibles
      |> Enum.filter(foundMatch)
      |> Enum.map(fn(findctxt(findIndex: i)) -> i end)
      |> Enum.reverse
      |> Enum.at(0)

    if match == nil do
      -1
    else
      match
    end
  end

  @doc """
  Find all matches in the rope returning a list of indexes,
  or an empty list if no matches were found. The list is in order
  from first to last match.

  ## Examples

      iex> Rope.find_all(Rope.concat(["loathe it", " or ignore it,", " you can't like it"]), "it")
      [7, 20, 39]

      iex> Rope.find_all(Rope.concat(["loathe it", " or ignore it,", " you can't like it"]), "and")
      []
  """
  @spec find_all(t, str) :: list(non_neg_integer)
  def find_all(rope, term) do
    termLength = String.length(term)
    segments = partition_rope(0, rope, termLength, 0)
    parent = self()

    segments
      |> Enum.map(fn({offset, length}) ->
          slice = Rope.slice(rope, offset, length)
          ref = make_ref()

          spawn_link(fn() ->
            matches = do_find_all(slice, term)
              |> Enum.map(fn(match) -> match + offset end)

            send parent, {ref, :pfind, self(), matches}
          end)
        end)
      |> Enum.map(fn(_child) ->
          receive do
            {_ref, :pfind, _child, matches} ->
              matches
          end
        end)
      |> List.flatten
      |> Enum.uniq
      |> Enum.sort
  end

  @doc """
  Replaces the first match with the replacement text and returns
  the new rope. If not found then the existing rope is returned.
  By default, it replaces all entries, except if the global option
  is set to false.
  """
  @spec replace(t, str, str, list) :: t
  def replace(rope, pattern, replacement, opts \\ []) do
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
  @spec to_string(t) :: binary
  def to_string(rope) do
    rope
    |> Enum.map(fn(%Rleaf{value: value}) -> value end)
    |> Enum.join
  end


  defp ropeify(rope) do
    case rope do
      %Rnode{} -> rope
      %Rleaf{} -> rope
      <<_ :: binary>> -> Rope.new(rope)
      nil -> nil
    end
  end

  defp do_concat(nil, nil, _opts) do
    nil
  end

  defp do_concat(rope, nil, _opts) do
    ropeify(rope)
  end

  defp do_concat(nil, rope, _opts) do
    ropeify(rope)
  end

  defp do_concat(rope1, rope2, opts) do
    rebalance = Keyword.get(opts, :rebalance, true)

    rope1 = ropeify(rope1)
    rope2 = ropeify(rope2)

    depth = max(rope2.depth, rope1.depth)

    rope = %Rnode{
      depth: depth + 1,
      left: rope1,
      right: rope2,
      length: rope1.length + rope2.length
    }

    if rebalance and (not Rope.balanced?(rope)) do
      Rope.rebalance(rope)
    else
      rope
    end
  end


  defp build_possible_matches(offset, chunk, term, possibles) do
    chunkLength = String.length(chunk)
    termLength = String.length(term)

    Enum.reduce(0..(chunkLength - 1), possibles, fn(chunkIndex, possibles) ->
      #filter out bad matches
      possibles = Enum.map(possibles, fn(possible) ->
        findctxt(findIndex: findIndex, termIndex: termIndex) = possible

        cond do
          termIndex == termLength ->
            #already matched don't change it
            possible
          String.at(chunk, chunkIndex) == String.at(term, termIndex) ->
            findctxt(findIndex: findIndex, termIndex: termIndex + 1)
          true ->
            #no match toss this one out
            nil
        end
      end)
      |> Enum.filter(fn(possible) -> possible != nil end)

      #add new possible match
      if String.at(chunk, chunkIndex) == String.at(term, 0) do
        [findctxt(findIndex: offset + chunkIndex, termIndex: 1) | possibles]
      else
        possibles
      end
    end)
  end


  defp partition_rope(_offset, nil, _termLength, _depth) do
    []
  end

  defp partition_rope(offset, %Rleaf{length: len}, termLength, _depth) do
    [{offset, len + termLength}]
  end

  defp partition_rope(offset, %Rnode{length: len, right: right, left: left}, termLength, depth) do
    offset =
      if offset > termLength do
        offset - termLength
      else
        offset
      end

    cond do
      depth >= @partition_depth_limit ->
        [{offset, offset + len + termLength}]
      Rope.length(left) <= @partition_size_threshold or
      Rope.length(right) <= @partition_size_threshold ->
        [{offset, offset + len + termLength}]
      (termLength / Rope.length(left)) > @partition_term_ratio or
      (termLength / Rope.length(right)) > @partition_term_ratio ->
        [{offset, offset + len + termLength}]
      true ->
        leftSegments = partition_rope(offset, left, termLength, depth + 1)
        rightSegments = partition_rope(offset + Rope.length(left), right, termLength, depth + 1)

        leftSegments ++ rightSegments
    end
  end

  defp do_find_all(rope, term) do
    termLen = String.length(term)

    foundMatch = fn(findctxt(termIndex: i)) -> i == termLen end

    {_offset, possibles} = Enum.reduce(rope, { 0, []},
      fn(%Rleaf{length: len, value: chunk}, {offset, possibles}) ->
        {offset + len, build_possible_matches(offset, chunk, term, possibles)}
      end
    )

    possibles
      |> Enum.filter(foundMatch)
      |> Enum.map(fn(findctxt(findIndex: i)) -> i end)
      |> Enum.reverse
  end

  defp do_replace(rope, pattern, replacement) do
    termLen = String.length(pattern)
    index = find(rope, pattern)

    leftRope = slice(rope, 0, index)
    rightRope = slice(rope, index + termLen, rope.length - index - termLen)

    concat([leftRope, replacement, rightRope])
  end

  defp do_replace_all(rope, pattern, replacement) do
    termLen = String.length(pattern)
    indexes = find_all(rope, pattern)

    {offset, subropes} = Enum.reduce(indexes, {0, []}, fn(index, {offset, ropes}) ->
      len = index - offset
      # if offset != 0, do: len = len

      leftRope = slice(rope, offset, len)
      {index + termLen, [replacement | [leftRope | ropes]]}
    end)

    leftRope = slice(rope, offset, rope.length)
    subropes = [leftRope | subropes]

    subropes = Enum.reverse(subropes)
    rebuild_rope([], subropes)
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
    subrope = Rope.concat([leaf1, leaf2], rebalance: false)
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

  defp fib(n) when n <= 1 do
    1
  end

  defp fib(n) do
    do_fib(n, [1, 1])
  end

  defp do_fib(2, [n2, n1]) do
    n2 + n1
  end

  defp do_fib(n, [n2, n1]) do
    do_fib(n - 1, [n2 + n1, n2])
  end


  defimpl String.Chars do
    @doc """
    Converts the entire rope to a single binary string.
    """
    def to_string(rope) do
      Rope.to_string(rope)
    end
  end


  defimpl Enumerable, for: Rope.Rleaf do
    @moduledoc """
    A convenience implementation that enumerates over the leaves of the rope but none
    of the parent/concatenation nodes.

    Refer to the Rope module documentation for leaf vs parent/concat node.
    """

    @doc """
    A count of the leaf nodes in the rope. This current traverses the rope to count them.
    """
    def count(rope) do
      {:ok, reduce(rope, 0, fn(_leaf, acc) -> acc + 1 end)}
    end

    @doc """
    Searches the ropes leaves in order for a match.
    """
    def member?(rope, value) do
      {:ok, Enum.any?(rope, fn (leaf) -> leaf.value == value end)}
    end

    @doc """
    Reduces over the leaf nodes.
    """
    def reduce(_,       {:halt, acc}, _fun),   do: {:halted, acc}
    def reduce(rope,    {:suspend, acc}, fun), do: {:suspended, acc, &reduce(rope, &1, fun)}
    # def reduce([],      {:cont, acc}, _fun),   do: {:done, acc}
    # def reduce([h | t], {:cont, acc}, fun),    do: reduce(t, fun.(h, acc), fun)

    def reduce(%Rnode{right: right, left: left}, {:cont, acc}, fun) do
      acc = reduce(left, acc, fun)
      reduce(right, acc, fun)
    end

    def reduce(%Rnode{right: right, left: left}, acc, fun) do
      acc = reduce(left, acc, fun)
      reduce(right, acc, fun)
    end

    def reduce(%Rleaf{} = leaf, {:cont, acc}, fun) do
      fun.(leaf, acc)
    end

    def reduce(%Rleaf{} = leaf, acc, fun) do
      fun.(leaf, acc)
    end
  end

  defimpl Enumerable, for: Rope.Rnode do
    defdelegate reduce(rope, acc, fun), to: Enumerable.Rope.Rleaf
    defdelegate count(rope), to: Enumerable.Rope.Rleaf
    defdelegate member?(rope, value), to: Enumerable.Rope.Rleaf
  end

  # defimpl Inspect, for: Rope.Rleaf do
  #   @doc """
  #   Traveres the leaf nodes and converts the chunks of binary data into a single
  #   algebra document. Will convert '\n' characters into algebra document line breaks.
  #   """
  #   def inspect(rope, _opts) do
  #     Apex.Format.format(rope, [])
  #   end
  # end

  # defimpl Inspect, for: Rope.Rnode do
  #   defdelegate inspect(rope, opts), to: Inspect.Rope.Rleaf
  # end
end
