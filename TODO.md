### Testing

Add test case for appropriated field splitting for generated string (particularly parameters)

### Issues

create a fork of kernel.org's dash, track it
but remove main, have proper handler abort

copy install instructions into top-level readme

turn model into its own repo?

### Merging symbolic

Merge once all tests pass
  Get patterns to work via try_concrete, at least
  coalesce strings as much as possible, everywhere

### Parsing

Should we write a custom parser?

### Expander tool

JS/webpage
  run expander in a chroot jail
  error handling
  mkdir for submissions
CLI

have both read the JSON output

### Expansion.lem

Monads for parsing etc.
Clean up to make null more explicit (simplify matches?)

Separate out splitting, quote removal

Minimal FS model

Commands

Error handling
  - parse errors break our libdash shim

Handle symbolic commands in pattern matching (rather than present kludge of string conversion)

### Evaluation

Handle basic command stepping
  - need process repr
  - need FD repr
  - keep everything symbolic for now
