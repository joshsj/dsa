# Hash Tables

{{#dl}}hash-func hash-coll load-factor{{/dl}}

Hash tables are designed for
[lightning-fast](https://www.youtube.com/watch?v=imO-mrsdLcs&t=12s) data access
&mdash; {{#bigo}}1{{/bigo}} to be precise.

Entries in a table consist of a key and a value which are implicitly
associated. The key uniquely identifies the entry and the value stores the
required data.

## Construction

{{! TODO add link to array list notes}}

Hash tables are backed by an array list.

Indexes are calculated using a {{#dfn}}hash-func{{/dfn}} on the key to produce
a unique numerical value (bar collisions)

This is passed to a subsequent reducer function which produces an index within
the capacity of the backing structure, modulo being a simple option.

This approach gives a time complexity of {{#bigo}}1{{/bigo}}.

{{#aside}} The worst-case is technically {{#bigo}}\log{n}{{/bigo}} or
{{#bigo}}n{{/bigo}}: when collisions require the hash table to be resized and
rehashed. However, the average-case of {{#bigo}}1{{/bigo}} is accepted because
a good hash function and good handling of load avoids the worst-case scenario.
{{/aside}}

## Handling Collisisions

Even a perfectly-distributed hash function and reducer will encounter clashing
indexes.

## Open Addressing

Open addressing uses an algorithm to determine the index for a given key, not
just a hash and reducer function.

This involves "probing" the backing array for an available index if the
immediate cell is populated using one of many strategies:

- Linear probing walks the array by a fixed offset, usually 1, until an unused
cell is found.
- Double hashing uses a second hash function to calculate the offset.

Open addressing has significant impact on the appropriate load factor for the
hash table, as all elements are stored in the backing array directly.
Implementations using open addressing typically maintain a load factor of 0.6
to 0.75.

## Separate Chaining

Separate chaining stores an additional data structure in each bucket instead of
the key/value, typically a linked list.

Compared to open addressing, only the hash function determines the index for a
key - no algorithm is needed. To find an entry, the linked list stored at the index is
walked instead.

Load factor is not a critical issue for separate chaining because the linked
lists can continue to grow. For best performance, it should be between 1 and 3
to balances the extra computation of resizing and rehashing against walking the
chained entries.

{{#aside}}

A load factor greater than 1 is possible because mutliple values are stored at a single index.

{{/aside}}

