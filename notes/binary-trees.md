# Binary Trees

Trees are a form of {{#page}}graphs:graph{{/page}} that specifically represent a
hierarchy.

The root of a tree is the node with no parent (the one at the top); a leaf is a node
with no children.

The height of a tree is count of nodes between the root and the furthest leaf.

Binary trees contain nodes with 2 children at most: `left`, and `right`
conventionally.

A binary tree is balanced when any node's left and right children have the same height.

## Complexity

Binary trees have an additional time complexity based on their height
{{#math}}h{{/math}}.

Complexities using {{#math}}h{{/math}} are consistent regardless of how
balanced the tree is.

{{! TODO: why O(h) }}

## Traversals

Trees can be traversed breath-first, meaning the nodes on each level
are visited with each step.

They can also be visited depth-first, meaning that the left or right branch
is exhausted before the other. There are three visiting orders in this case:

- Pre: self, left, right
- In: left, self, right
- Post: left, right, self

Using this tree as an example,

```
    4
   / \
  2   5
 / \   \
1   3   7
```

each traversal algorithm would produce the following sequence:

```
pre   = 4 2 1 3 5 7
in    = 1 2 3 4 5 7
post  = 1 3 2 7 5 4
depth = 4 2 5 1 3 6
```

In either case, these operations are {{#bigo}}n{{/bigo}} &mdash; as the traversal of any
data structure should be &mdash; or {{#bigo}}2^h{{/bigo}}.

## Representation

The simplest way to represent a binary tree is with **nodes**, each holding a `value`
and a reference to the `left` and `right` child.

The more awesome way is using an **array**, static or {{#page}}array-lists:dynamic{{/page}}.

Nodes are arranged in breadth order (see above for an example) and the following algorithms
are used to traverse between nodes:

{{#dmath}}
\textnormal{left} = 2i + 1 \\
\textnormal{right} = 2i + 2 \\
\textnormal{parent} = \frac{i - 1}{2}
{{/dmath}}

See {{#page}}heaps{{/page}} for one usage of array-based binary trees.

{{!TODO

## Balancing

AVL

Red black

}}

