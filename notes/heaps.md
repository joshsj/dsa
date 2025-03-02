# Heaps

A heap is a tree-based data structure that satisfies the heap property: for any
node {{#math}}N{{/math}} and its parent {{#math}}P{{/math}}, they must be
ordered by the same ordering as all other nodes.

A min-heap orders descendants to have larger values, so the smallest (min) value is
at the root.

A max-heap orders descendants to have smaller values, so the largest (max) value is
at the root.

Heaps implement the Priority Queue ADT but "heap" has come to be synonymous
with "priority queue".

## Binary Heaps

Binary heaps are a specialization of {{#page}}binary-trees{{/page}}.

They use an array-based representation of binary trees to support the following
logic performantly.

Enqueuing appends a value to the array and swims it into the correct, ordered
position: {{#bigo}}\log{n}{{/bigo}}.

Dequeuing removes the root value, replaces it with the last value, and sinks it
into the correct, ordered position: {{#bigo}}\log{n}{{/bigo}} again.

Because these operations only work from the start & end of the tree, binary
heaps are self-balancing and always complete.
