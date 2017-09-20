### Issues

create a fork of kernel.org's dash, track it
  but remove main, have proper handler abort

~ expansion without HOME:
  should just yield ~, not null

look into ExpDQ

### Parsing

Should we write a custom parser?

### Expander tool

JS/webpage
CLI

have both read the JSON output

### Expansion.lem

Monads for parsing etc.
Clean up to make null more explicit (simplify matches?)

Error handling
  - parse errors break our libdash shim

Handle symbolic commands in pattern matching (rather than present kludge of string conversion)

### Evaluation

Handle basic command stepping
  - need process repr
  - need FD repr
  - keep everything symbolic for now
