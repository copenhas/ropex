.PHONY: test

default: ctags test 

all: ctags test dialyzer docs

test:
	mix test

ctags:
	ctags -R .

dialyzer:
	dialyzer ./ebin --fullpath --no_check_plt

docs:
	mix docs
