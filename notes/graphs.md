# Graphs

Graphs consist of nodes (or vertexes).

An edge is a connection between nodes.

A node with an edge is connected; a node is disconnected otherwise.

Nodes that are connected by an edge are adjacent.

Edges can be directed or undirected.

Edges can be weighed or unweighed. For a bidirectional edge, a different weight
can be given for each direction.

A path is a sequence of edges between nodes. A cycle is a path
starting and ending at the same node.

Graphs are cyclic when when contain a cycle; they are acyclic otherwise.

## Complexity

Graphs commonly use {{#math}}V{{/math}} and {{#math}}E{{/math}} to stand for
the number of vertexes and edges respectively.

## Representation

Using this graph for reference:

{{! TODO: work out colors }}

{{#figure}}

{{#include}}@notes/graphs/graph.svg{{/include}}

{{/figure}}

### Adjacency List

These use a {{#page}}hash-maps-sets:hash map{{/page}} to map each node to a
list of edges to its adjacent nodes.

```jsonc
{
  "A": [
    {
      "to": "B",
      "weight": 10,
    },
    {
      "to": "D",
      "weight": 5
    }
  ],
  // etc
}
```

### Adjacency Matrix

These use a {{#math}}V \times V{{/math}} 2D array where each cell in both arrays
represents a node positionally.

{{#aside}}These are not good for space complexity: {{#bigo}}V^2{{/bigo}}.{{/aside}}

```jsonc
[
//  A  B   C  D
  [ 0, 10, 0, 0 ],
  [ 0, 0,  0, 2 ],
// etc
]
```

