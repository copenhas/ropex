.PHONY: test docs tags

default: tags test 

all: tags test check docs

test:
	mix test

perf:
	elixir -pa ebin test/performance.exs

tags:
	ctags -R .

check:
	dialyzer ./ebin --fullpath --no_check_plt -Wno_return

docs:
	mix docs --readme
