defmodule PerfTest do
  use ExUnit.Case

  defrecord TestCtxt,
    rope: nil,
    extra: [],
    time: 0


  test "10,000 concats" do
    threshold = 30_000 #30 milliseconds
    time = build_rope |> build_ctxt |> run(10_000, :concat)
    IO.puts "\nROPE: 10,000 concats took #{time} microseconds"
    assert time < threshold, "10,000 concats completed in #{time} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "rebalancing 10,000 words" do
    threshold = 40_000 #40 milliseconds
    time = build_long_rope |> build_ctxt |> run(1, :rebalance)
    IO.puts "\nROPE: 10,000 node rebalance took #{time} microseconds"
    assert time < threshold, "rebalancing worst case 10,000 leaf rope completed in #{time} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "1,000 slices on a balanced rope" do
    threshold = 100_000 #1/10 second
    time = build_rope |> build_ctxt |> run(1000, :slice)
    IO.puts "\nROPE: 1,000 slice took #{time} microseconds"
    assert time < threshold, "1,000 slices on a balanced rope completed in #{time} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "100 finds on a balanced rope" do
    threshold = 500_000 #1/2 second
    time = build_rope |> build_ctxt |> run(100, :find)
    IO.puts "\nROPE: 100 find took #{time} microseconds"
    assert time < threshold, "100 finds on a balanced rope completed in #{time} microseconds, longer then threshold of #{threshold} microseconds"
  end

  test "string performance" do
    time = build_text |> build_ctxt |> run(10_000, :concat)
    IO.puts "\nSTRING: 10,000 concats took #{time} microseconds"

    time = build_text |> build_ctxt |> run(1_000, :slice)
    IO.puts "\nSTRING: 1,000 slices took #{time} microseconds"

    time = build_text |> build_ctxt |> run(100, :find)
    IO.puts "\nSTRING: 100 contains? took #{time} microseconds"
  end


  def build_ctxt(rope) do
    TestCtxt[rope: rope, extra: build_extra]
  end

  def build_rope do
    File.stream!("test/fixtures/hello_ground.txt")
      |> Enum.reduce("", fn(line, rope) -> Rope.concat(rope, line) end)
      |> Rope.rebalance
  end

  def build_long_rope() do
    extra = build_extra
    Enum.reduce(1..10_000, "", fn(_count, left) ->
      Rope.concat([left | Enum.take(extra, 1)])
    end)
  end

  def build_extra do
    File.read!("test/fixtures/towels.txt") |> String.split |> Stream.cycle
  end

  def build_text do
    File.read!("test/fixtures/hello_ground.txt")
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

    finished.time
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
