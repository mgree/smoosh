### Testing

Add test case for appropriated field splitting for generated string (particularly parameters)

Unify testing helpers

### Organizational issues

create a fork of kernel.org's dash, track it
but remove main, have proper handler abort

copy install instructions into top-level readme

turn model into its own repo?

### Parsing

Should we write a custom parser?

### Expander tool

JS/webpage
  run expander in a chroot jail
  use syntax highlighting in editor window
    fancier output
    cleaner handling of environment, etc.
    presets
  error handling
  mkdir for submissions
CLI

have both read the JSON output
  include ENTIRE shell info in JSON output

### Expansion.lem

Monads for parsing etc.
Clean up to make null more explicit (simplify matches?)

Separate out splitting, quote removal

Error handling
  - parse errors break our libdash shim

No symbolic pathname expansion

Split particular symbolic things out of symbolic_char to ease pattern matching burden?

### Evaluation

Commands

Handle basic command stepping
  - need process repr
  - need FD repr
  - keep everything symbolic for now
