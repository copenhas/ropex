.PHONY: test docs tags graphs

default: tags test 

all: tags test check docs

test:
	mix test

perf:
	elixir -pa ebin test/performance.exs

tags:
	ctags -R .

graph:
	rm -f graphs/*
	elixir -pa ebin test/graphs.exs
	ls graphs/*.dot | xargs -L 1 dot -Tsvg -O

check:
	dialyzer ./ebin --fullpath --no_check_plt -Wno_return

docs:
	mix docs --readme
