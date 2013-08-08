# Rope

Implemention of a rope data structure in Elixir. It provides faster index based operations, especially at scale, 
then plain binary based strings. One of the basic building block of this is the `slice/3` operation which is roughly 3x 
faster at 2kb of text and up to 50x faster at 880kb of text. The other is `concat/2` operation which runs in constant time
but as it stands so does the BEAM (how about that). `concat/2` does suffer roughly double the overhead of the `<>` operator
on plain binary based strings. The combination of `slice/3` and `concat/2` allows efficient `insert_at/3` and `remove_at/3`.


## So what does this look like?
The following images where genereated with [GraphViz](http://graphviz.org). The green oval represent the variables who point
to a rope. The squares represent the internal record data structure for the rope. 'concat' nodes are purely for connecting
the leaves together, while the leaves actually contain the text.


Worst case purely concatenation rope:

![Worst case](http://copenhas.github.io/ropex/images/bulldozer.dot.png "worst case")


The same rope rebalanced for better slice based operations:

![Worst case rebalanced](http://copenhas.github.io/ropex/images/bulldozerrebalanced.dot.png "worst case rebalanced")


Also existing leafs should be reused in new ropes. The operations performed where creating a new rope (original), 
inserting 'hello world' (insert), a subrope sliced out (slice), then concatenated back in (concat), then finally
a series of concatenations (multiconcat).

![Rope with manipulations](http://copenhas.github.io/ropex/images/manipulations.dot.png "Rope with manipulation")


That same rope rebalanced:

![Rope with manipulations rebalanced](http://copenhas.github.io/ropex/images/manipulationsbalanced.dot.png "Rope with manipulation rebalanced")
