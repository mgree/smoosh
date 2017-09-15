### Issues

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
  - error expansion mode
  - variable lookup

Handle symbolic commands in pattern matching (rather than present kludge of string conversion)

### Evaluation

Handle basic command stepping
  - need process repr
  - need FD repr
  - keep everything symbolic for now
