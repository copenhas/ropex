# Rope

Implementing the rope data structure to play around with Elixir some... and to do something kind of computer sciencey again.


Currently, concat is constant time but about twice the overhead of plain binary strings. 
While slice is WAY more efficient then plain binary strings. About 3 times faster in small files (tested with 2kb) and up to 50 times faster in huge files (tested with 880kb).

Find is just horrible right now, which limits some of the rope's use. 
