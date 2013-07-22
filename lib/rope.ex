defmodule Rope do

  defrecord RNode, left: nil,
                    right: nil,
                    length: nil

  defrecord RLeaf, length: nil,
                    value: nil

  defimpl Inspect, for: RNode do
    import Inspect.Algebra

    def inspect(RNode[left: nil, right: right], opts) do
      Kernel.inspect(right)
    end

    def inspect(RNode[left: left, right: nil], opts) do
      Kernel.inspect(left)
    end

    def inspect(rope, opts) do
      concat Kernel.inspect(rope.left), Kernel.inspect(rope.right)
    end
  end

  defimpl Inspect, for: RLeaf do
    import Inspect.Algebra

    def inspect(rope, opts) do
      rope.value
    end
  end

  def new(str) do
    RLeaf.new length: String.length(str), value: str
  end

  def concat(rope1, rope2) do
    RNode.new left: rope1, right: rope2, length: rope1.length + rope2.length
  end

  def substr(rope, start, len) do
  end

  def rebalance(rope) do
  end
end
