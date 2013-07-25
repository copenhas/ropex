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


  # copied the type defs from the String module
  @type t :: binary
  @type codepoint :: t
  @type grapheme :: t

  @type rope :: Rope.t | nil


  @doc """
  Creates a new rope with the string provided
  """
  @spec new(t | nil) :: rope
  def new(nil) do
    nil
  end

  def new(str) when is_binary(str) do
    rleaf(length: String.length(str), value: str)
  end


  @doc """
  Concatenates two ropes together producing a new single rope.
  """
  @spec concat(rope | t, rope | t) :: rope
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


  defp ropeify(rope) do
    case rope do
      rnode() -> rope
      rleaf() -> rope
      <<_ :: binary>> ->
        Rope.new(rope)
      nil -> nil
    end
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
