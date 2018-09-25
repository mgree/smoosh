### Paper TODO

- fold out smoosh repo
  + document
- fold out libdash
  + create a fork of kernel.org's dash, track it
  + remove main, have proper handler abort
  + offer ocaml bindings
  + clearer shim, with more functions for poking dash internals (e.g., env, aliases, etc.)
- get server up
  + install ruby
  + fold out web repo
  + run expander in a chroot jail
- run POSIX tests on dash, bash, and smoosh
- write paper
- build artifact
  + copy install instructions into top-level readme

### Bugs

### Last of the shell semantics

- tests that read stdout
  + tests for pipes and redirects
- eval/.
  + properly handle errors in the dash parser 
    
  + write more tests

- other built-ins
- non-special shell variables
  LINENO
  ENV (interactive only)
  PPID
  HISTFILE
- faithful handling of PATH_MAX

- correct application of INTON/INTOFF

- shell history
  can implement Sh_nolog

- expansion: make null more explicit... simplify matches?

- symbolic pathname expansion

- mark symbolic OS changes/unspecified states/unsoundness and move on

### Long-term

- support filesystems in symbolic stepper
- refactor semantics.lem to use is_terminating_control
    don't immediately step! Break _n -> Done
  follow dash on break/continue behavior inside of functions
- use monads (better parsing, etc.)
- support for nondeterminism (move to K?)

### Testing

- VM for POSIX testing
  run on dash, bash

### Parsing

Should we write a custom parser? Use Ralf Treinen's?

### Expander tool

JS/webpage
  + use syntax highlighting in editor window
  + fancier output
    - favicon
    - cleaner handling of environment, etc.
      add positional variables to display  
    - presets
    - way to explore FS
    - stdout and other FIFOs
    - more shell info
  + use a JS contracts/types library 
  + mkdir for submissions
CLI
  + pretty printer for JSON output

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
