##### Issues

### CLI

should we write a custom parser, too?
  need it for js_of_ocaml
  also need to drop/ignore zarith dep in lem somehow

### Expansion.lem

bugfix in arith: ${x=1} $((x+1)) should yield 1 2, currently errors

Monads for parsing etc.
clean up to make null more explicit (simplify matches?)

Error handling (parse errors, error expansion mode, variable lookup)

handle symbolic commands in pattern matching (rather than present kludge of string conversion)

### evaluation

handle basic command stepping (keep everything symbolic?)
