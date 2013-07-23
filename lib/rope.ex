defmodule Rope do

  defrecord RNode, left: nil,
                    right: nil,
                    length: nil

  defrecord RLeaf, length: nil,
                    value: nil

  defimpl Inspect, for: RNode do
    import Inspect.Algebra

    def inspect(RNode[left: nil, right: right], _opts) do
      Kernel.inspect(right)
    end

    def inspect(RNode[left: left, right: nil], _opts) do
      Kernel.inspect(left)
    end

    def inspect(rope, _opts) do
      concat Kernel.inspect(rope.left), Kernel.inspect(rope.right)
    end
  end

  defimpl Inspect, for: RLeaf do
    def inspect(rope, _opts) do
      rope.value
    end
  end

  def new(str) do
    RLeaf.new length: String.length(str),
              value: str
  end

  def concat(rope1, rope2) do
    rope1 = ropeify(rope1)
    rope2 = ropeify(rope2)

    RNode.new left: rope1,
              right: rope2,
              length: rope1.length + rope2.length
  end

  def slice(rope = RLeaf[], start, len) do
    String.slice(rope.value, start, len)
  end

  def slice(rope = RNode[length: rlen], start, len) 
  when start > rlen do
    nil
  end

  def slice(rope = RNode[length: rlen], start, len) 
  when start == rlen do
    ""
  end

  def slice(rope, start, len) do
    
  end

  def to_string(rope) do
    Kernel.inspect rope
  end

  defp ropeify(rope) do
    case rope do
      RNode[] -> rope
      RLeaf[] -> rope
      <<_ :: binary>> ->
        Rope.new(rope)
    end
  end
end
