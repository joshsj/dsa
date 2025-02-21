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

## Handling Collisions

{{! TODO load factor }}

We can control two aspects of hash tables to minimise collisions: the size of
the backing array and the hash function itself.

There are four categories of collision resolution mechanisms:

{{#include}}@notes/hash-tables/collisions.html{{/include}}

### Linear Probing

Open addressing, closed hashing.

When an index collides, subsequent indexes are searched for an unused cell. If
found, the value is stored, else the backing array is resized and its items
reinserted to minimises previous collisions.

When accessing the structure, the array must be walked in the same fashion. The
"needle" key is hashed and reduced to its index, then each key stored from this
index is compared to the needle directly until an equal value is found (or
not).

By comparing unhashed keys, collisions are removed from the equation.

## Double Hashing

Double hashing follows the same approach as linear probing, but uses a
subsequent hash function to calculate the offset from the colliding index,
instead of the walking algorithm.

This avoids the problem of clumping with linear probing, which is statistically
likely (apparently). A common choice is {{#math}}1 + \frac{K}{M} \mod{(M - 1)}{{/math}}.
