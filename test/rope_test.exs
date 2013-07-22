Code.require_file "test_helper.exs", __DIR__

defmodule RopeTest do
  use ExUnit.Case

  test "can create a basic rope" do
    rope = Rope.new("test")
    assert Kernel.inspect(rope) == "test"
  end

  test "can concat two ropes together" do
    rope = Rope.concat(Rope.new("hello"), Rope.new(" world"))
    assert Kernel.inspect(rope) == "hello world"
  end

end
