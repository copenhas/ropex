.PHONY: test docs

default: ctags test 

all: ctags test dialyzer docs

test:
	mix test

ctags:
	ctags -R .

dialyzer:
	dialyzer ./ebin --fullpath --no_check_plt -Wno_return

docs:
	mix docs --readme
