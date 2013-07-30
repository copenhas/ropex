.PHONY: test

default: ctags test dialyzer

test:
	mix test

ctags:
	ctags -R .

dialyzer:
	dialyzer ./ebin
