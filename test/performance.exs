Code.require_file "test_helper.exs", __DIR__

defmodule PerformanceTest do
  use ExUnit.Case

  defrecord TestCtxt,
    rope: nil,
    extra: [],
    time: 0


  test "rebalancing 100,000 words" do
    threshold = 100_000 #100 milliseconds
    time = build_long_rope |> build_ctxt |> run(1, :rebalance)
    IO.puts "\nROPE: 100,000 node rebalance took #{time} microseconds"
    assert time < threshold, "rebalancing worst case 100,000 leaf rope completed in #{time} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "small rope performance" do
    threshold = 3
    avg = build_rope |> build_ctxt |> run(1_000, :concat)
    IO.puts "\nSMALL ROPE: concat takes #{avg} microseconds"
    assert avg < threshold, "concats avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"

    threshold = 1_700 
    avg = build_rope |> build_ctxt |> run(10, :slice)
    IO.puts "\nSMALL ROPE: slice takes #{avg} microseconds"
    assert avg < threshold, "slices on a balanced rope avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"

    threshold = 50_000
    avg = build_rope |> build_ctxt |> run(10, :find)
    IO.puts "\nSMALL ROPE: find takes #{avg} microseconds"
    assert avg < threshold, "finds on a balanced rope avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "huge rope performance" do
    threshold = 3
    avg = build_huge_rope |> build_ctxt |> run(1_000, :concat)
    IO.puts "\nHUGE ROPE: concat takes #{avg} microseconds"
    assert avg < threshold, "concats avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"

    threshold = 4_000 
    avg = build_huge_rope |> build_ctxt |> run(10, :slice)
    IO.puts "\nHUGE ROPE: slice takes #{avg} microseconds"
    assert avg < threshold, "slice on a balanced rope avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"

    threshold = 50_000
    avg = build_huge_rope |> build_ctxt |> run(3, :find)
    IO.puts "\nHUGE ROPE: find takes #{avg} microseconds"
    assert avg < threshold, "find on a balanced rope avg of #{avg} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "small string performance" do
    time = build_text |> build_ctxt |> run(1_000, :concat)
    IO.puts "\nSMALL STRING: concat takes #{time} microseconds"

    time = build_text |> build_ctxt |> run(10, :slice)
    IO.puts "\nSMALL STRING: slice takes #{time} microseconds"

    time = build_text |> build_ctxt |> run(10, :find)
    IO.puts "\nSMALL STRING: contains? takes #{time} microseconds"
  end

  test "huge string performance" do
    time = build_huge_text |> build_ctxt |> run(1000, :concat)
    IO.puts "\nHUGE STRING: concat takes #{time} microseconds"

    time = build_huge_text |> build_ctxt |> run(10, :slice)
    IO.puts "\nHUGE STRING: slice takes #{time} microseconds"

    time = build_huge_text |> build_ctxt |> run(10, :find)
    IO.puts "\nHUGE STRING: contains? takes #{time} microseconds"
  end


  def build_ctxt(rope) do
    TestCtxt[rope: rope, extra: build_extra]
  end

  def build_rope do
    File.stream!("test/fixtures/hello_ground.txt")
      |> Enum.reduce("", fn(line, rope) -> Rope.concat(rope, line) end)
      |> Rope.rebalance
  end

  def build_huge_rope do
    File.stream!("test/fixtures/dracula.txt")
      |> Enum.reduce("", fn(line, rope) -> Rope.concat(rope, line) end)
      |> Rope.rebalance
  end

  def build_long_rope() do
    extra = build_extra
    Enum.reduce(1..100_000, "", fn(_count, left) ->
      Rope.concat([left | Enum.take(extra, 1)])
    end)
  end

  def build_extra do
    File.read!("test/fixtures/towels.txt") |> String.split |> Stream.cycle
  end

  def build_text do
    File.read!("test/fixtures/hello_ground.txt")
  end

  def build_huge_text do
    File.read!("test/fixtures/dracula.txt")
  end

  def get_timestamp do
    {mega,sec,micro} = :erlang.now()
    (mega*1000000+sec)*1000000+micro
  end

  def run(ctxt, num, op) do
    finished = Enum.reduce(1..num, ctxt, fn(_count, TestCtxt[rope: rope] = ctxt) ->
      operation = {op, generate_args(op, ctxt)}
      time_operation(operation, ctxt)
    end)

    finished.time / num
  end

  def generate_args(:slice, TestCtxt[rope: rope]) 
  when is_record(rope, Rope) do
    {:random.uniform(div(rope.length, 2)), :random.uniform(rope.length) + 100}
  end

  def generate_args(:slice, TestCtxt[rope: text]) 
  when is_binary(text) do
    {:random.uniform(div(String.length(text), 2)), :random.uniform(String.length(text)) + 100}
  end

  def generate_args(:concat, TestCtxt[extra: extra]) do
    [w] = Enum.take(extra, 1)
    w
  end

  def generate_args(:find, _ctxt) do
    case :random.uniform(6) do
      1 -> "my"
      2 -> "your"
      3 -> "going"
      4 -> "N/A"
      5 -> "I"
      6 -> "You"
    end
  end

  def generate_args(opt, _ctxt) do
     []
  end

  def time_operation(operation, ctxt) do
    startTime = get_timestamp
    newCtxt = execute_operation(operation, ctxt)
    endTime = get_timestamp

    newCtxt.update_time(fn(total) -> total + (endTime - startTime) end)
  end

  ###########################
  # Rope operations
  ###########################
  def execute_operation({:slice, {start, len}}, TestCtxt[rope: rope] = ctxt) 
  when is_record(rope, Rope) do
    Rope.slice(rope, start, len)
    ctxt #leaving the context unchanged
  end

  def execute_operation({:concat, word}, TestCtxt[rope: rope] = ctxt) 
  when is_record(rope, Rope) do
    newRope = Rope.concat([rope | [word]])
    ctxt.rope newRope
  end

  def execute_operation({:find, term}, TestCtxt[rope: rope] = ctxt) 
  when is_record(rope, Rope) do
    Rope.find(rope, term)
    ctxt #no change, and find returns the index
  end

  def execute_operation({:rebalance, _args}, TestCtxt[rope: rope] = ctxt) do
    newRope = Rope.rebalance(rope)
    ctxt.rope newRope
  end

  ############################
  # String operations for comparison
  ############################
  def execute_operation({:slice, {start, len}}, TestCtxt[rope: rope] = ctxt) 
  when is_binary(rope) do
    String.slice(rope, start, len)
    ctxt #leaving the context unchanged
  end

  def execute_operation({:concat, word}, TestCtxt[rope: rope] = ctxt) 
  when is_binary(rope) do
    newRope = rope <> word
    ctxt.rope newRope
  end

  def execute_operation({:find, term}, TestCtxt[rope: rope] = ctxt) 
  when is_binary(rope) do
    String.contains?(rope, term)
    ctxt #no change, and find returns the index
  end
end
