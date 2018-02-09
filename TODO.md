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
  + run expander in a chroot jail
  + use syntax highlighting in editor window
  + fancier output
    - favicon
    - legend on the side, more color-coding
    - step details (string that comes with each step)
    - cleaner handling of environment, etc.
    - presets
  + use a JS contracts/types library 
  + error handling
  + mkdir for submissions
  + docker container, provision shell.cs.pomona.edu
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

### Evaluation

Commands

Handle basic command stepping
  - need process repr
  - need FD repr
  - keep everything symbolic for now

### Bugs

Bash
  - Bug related to variable assignments before built in utilities
    - "If the command name is a special built-in utility, variable assignments shall affect the current execution environment. Unless the set -a option is on (see set), it is unspecified:"
    - "x=5 :" should set x=5 in the current shell env, but it does not in Bash (version 4.4.12(1)-release)

Dash
  - Are EXP_VARTILDE and EXP_VARTILDE2 necessary? 
    it seems to me that the parser is properly separating things out...
    test it!
