# Hash Functions

{{#dl}}
hash-func
hash-coll
{{/dl}}

All hash functions obey the equality property: given two keys of equal value, their hashes must also be equal.

A perfect hash function also obeys the inequality property: given two keys of inequal value, their hashes must be unequal. In the real world, this is difficult to achieve so a 'good' hash function minimises collisions.

They are used beyond {{#page}}hash-tables{{/page}}: cryptography, version control diffs, password storage etc.

