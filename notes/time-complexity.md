# Time Complexity

Time complexity expresses the execution time of an algorithm as a function
of its input size.

{{#aside}}

There is also space complexity, which expresses the amount of memory
required by an algorithm as a function of its input size. The idea is the same
but time complexity is generally the focus (as far as I've read).

{{/aside}}

These provide a theoretical understanding of how an algorithm performs,
ignorant of any other variables: implementation details, hardware limitations,
compiler optimisations, etc.

This enables developers to reason about different algorithms without
implementing and benchmarking them. Many data structures and their associated
algorithms can be used to solve a given problem so complexity 

This understanding is important because:

1. Developers can reason about different algorithms without implementing and
   benchmarking them, saving time and money.
2. When an algorithm is used in a real-world system, its performance can be
   predicted as the system and its dataset scales.

## Notation

Time complexity is measured with Big O notation.

{{#math}}O{{/math}} is the name of the aforementioned function and its
arguments(s) are the size of the data, typically using {{#math}}n{{/math}} for
a single argument, {{#math}}n{{/math}} and {{#math}}m{{/math}} for two
arguments, and then it's the dealer's choice from there.

For example, {{#math}}O(n){{/math}}.

## Measuring

Time complexity has two unexpected rules:

1. Keep only the greatest term of your input variables, and
2. Drop coefficients

So an expression like {{#math}}3n^2+4n+7{{/math}} is written as
{{#math}}O(n^2){{/math}} in Big O notation.

Why? Because it looks at how an algorithm performs at scale so coefficients
and smaller terms become insignificant to the computation:

{{#dmath}} n=10, n^2=100 {{/dmath}}

{{#dmath}} n=1000, n^2=1,000,000 {{/dmath}}

{{#dmath}} n=100,000, n^2=10,000,000,000 {{/dmath}}

## Common Time Complexities

Constant, {{#bigo}}1{{/bigo}}: same number of steps, regardless of input size.

Logarithmic, {{#bigo}}\log{n}{{/bigo}}: after each pass, the number of steps is
halved.

{{#aside}}

With time complexity (and with software in general), the logarithm base is
assumed to be 2, so {{#bigo}}\log{n} = \log_2{n}{{/bigo}}.

{{/aside}}

Linear, {{#bigo}}n{{/bigo}}: as many steps as there are elements.

Linearithmic, {{#bigo}}n\log{n}{{/bigo}}: linear times logarithmic, or,
{{#bigo}}n{{/bigo}} steps are taken {{#bigo}}\log{n}{{/bigo}} times.

Quadratic, {{#bigo}}n^2{{/bigo}} and cubic, {{#bigo}}n^3{{/bigo}}.

(From here, you're basically done for)

Expontential, {{#bigo}}2^n{{/bigo}}.

Factorial, {{#bigo}}n!{{/bigo}}.

## Cases

Big O can describe the perfomance of an algorithm in a best, average, and worst
case. These cases are distrubuted on a bell curve: best and worst case are
rare, average is more likely.

The worst-case is normally considered when comparing the performance of
algorithms because

1. no assumptions can be about the problem space, and
2. the upper bound of the function is most important at scale.

## Practical Considerations

Big O isn't everything.

### Equal Complexities

When two algorithms have the same time complexity, the discarded coefficients
and smaller terms come back into play.

Take a bubble and selection sort:

```zig
{{#include}}@lib/common/slice-sort.zig[12..26]{{/include}}
{{#include}}@lib/common/slice-sort.zig[70..88]{{/include}}
```

They're both {{#bigo}}n^2{{/bigo}} and do rougly the same amount of comparisons
but, in the worst case (reverse ordered), bubble sort will do a lot more swaps so
selection sort is likely a better fit.

### Limited Scale

If the inputs aren't going to grow then a "less efficient" algorithm could be
more performant for the use-case.

For example, compare {{#bigo}}50n{{/bigo}} and {{#bigo}}n^2{{/bigo}} with a
small input side:

{{#dmath}} n = 10, 50n = 500 {{/dmath}}

{{#dmath}} n = 5, n^2 = 100 {{/dmath}}

Limited growth can also change whether the worst-case is the right case to
analyse. If the problem space will encounter the average case more frequently,
then an algorithm can be chosen to optimise for this scenario.

{{#aside}}

See "The Average Case" in {{#ref}}common-sense{{/ref}} for a breakdown of insertion vs. selection sort
in different expected scenarios.

{{/aside}}

