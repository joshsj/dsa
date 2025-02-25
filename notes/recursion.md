# Recursion

{{#dl}}recursion{{/dl}}

Recursion is one tool in the DSA belt to implement algorithms effectively.

In its formal definition, a algorithm is recursive when it has the two
following properties:

1. A base case (or cases): a terminating scenario that does not use recursion
   to produce an answer.
2. A recursive step: logic which works towards the base case and ultimately
   recurs.

## Comparison to Iteration

Who wins?

### Performance

Performance is not a benefit.

Recursive implementations of an algorithm _can_ be as performant as an
iterative implementation but the need to create a new stack frame for each
recursive step adds overhead.

{{#aside}}

See [tail call
elimination](https://en.wikipedia.org/wiki/Tail_call#:~:text=sequence%20is%20called-,tail%2Dcall%20elimination,-or%20tail%2Dcall)
for how this performance can be reclaimed.

{{/aside}}

Note that recursion vs. iteration only applies to the implementation of an
algorithm and therefore does not affect its Big O.

## Safety

Where iteration has infinite loops, recursion has call stack errors.

Both are bad for their own reasons, just write better code.

### Simplicity

Many algorithms are more simple to express recursively instead of iteratively
&mdash; so the clarity better outweigh the performance hit.

Take an implementation of quicksort (excluding the `partition` function):

```zig
{{#include}}@lib/common/slice-sort.zig[58..67]{{/include}}
```

Converting the implementation to be iterative would require:

- 2 loops, one for each recursive step
- 2 variables to store the current window over `items` (probably `left` and
`right`)
- An outer loop
- Some conditions to terminate the algorithm &mdash; either in the loop
condition or using `if` + `break`

## Thinking recursively

When using recursion, the recursive step can be broken down into three
sub-steps:

- Pre: what happens before recurring
- Recurse: self-explanatory
- Post: what happens after recurring

Pathing algorithms are a good example of this:

```zig
// TODO
```

