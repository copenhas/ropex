.PHONY: test

default: ctags test 

test:
	mix test

ctags:
	ctags -R .

dialyzer:
	dialyzer ./ebin
