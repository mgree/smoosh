### Last of the shell semantics

- tests differentiating $* and $@, fix impl
- tests that read stdout
  + tests for pipes and redirects
- eval/.
  + properly handle errors in the dash parser 
    (fork lib: setjmp before parsing, longjmp on error, return appropriate value)
  + write more tests
- set flags
- trap

- other built-ins
- non-special shell variables
  LINENO
  ENV (interactive only)
  PPID
  PS1-4
  PWD
  
  HISTFILE?
- faithful handling of PATH_MAX

- shell history

- expansion: make null more explicit... simplify matches?

- symbolic pathname expansion

- mark symbolic OS changes/unspecified states/unsoundness and move on

### Long-term

- refactor semantics.lem to use is_terminating_control
    don't immediately step! Break _n -> Done
  follow dash on break/continue behavior
- use monads (better parsing, etc.)
- support for nondeterminism (move to K?)

### Testing

- Appropriate field splitting for generated strings (particularly parameters)

- VM for POSIX testing
  run on dash, bash

### Organizational issues

- libdash
  + create a fork of kernel.org's dash, track it
  + remove main, have proper handler abort
  + offer ocaml bindings
  + clearer shim, with more functions for poking dash internals (e.g., env, aliases, etc.)

copy install instructions into top-level readme

turn model into its own repo?

### Parsing

Should we write a custom parser?

### Expander tool

JS/webpage
  + debug weird issues with newlines
  + run expander in a chroot jail
  + use syntax highlighting in editor window
  + fancier output
    - favicon
    - legend on the side, more color-coding
    - cleaner handling of environment, etc.
      add positional variables
    - presets
    - way to explore FS
  + use a JS contracts/types library 
  + error handling
  + mkdir for submissions
  + docker container, provision shell.cs.pomona.edu
CLI
  + pretty printer for JSON output

include ENTIRE shell info in JSON output

### Bugs

Bash
  - Bug related to variable assignments before built in utilities
    - "If the command name is a special built-in utility, variable assignments shall affect the current execution environment. Unless the set -a option is on (see set), it is unspecified:"
    - "x=5 :" should set x=5 in the current shell env, but it does not in Bash (version 4.4.12(1)-release)
    
    not REALLY a bug---there's an obscure flag to turn on the POSIX behavior

Dash
  - Found (and fixed) arithmetic bug
  - Are EXP_VARTILDE and EXP_VARTILDE2 necessary? 
    it seems to me that the parser is properly separating things out...
    test it!

  - seems like timescmd is implemented incorrectly, printing out wrong numbers
