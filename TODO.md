### Last of the shell semantics

- special built-ins
  + trap
    need to add to the shell representation
  + eval (call parser), ./source
  + exec
- other built-ins
- special variables
  + need to add to the shell representation
  + need to sort out the difference between $* and $@
- pipes and redirects
  + need to boost what FS can do
- background processes
  + need to come up with a scheduler
    OR: just schedule opportunistically, i.e.
        step_eval (s0,Wait n) looks up pid n and steps it
           or fails with a symbolic result if n|->execve
        opportunity for deadlock?
          x=$$ ; wait $x & ; wait $!
          no: can only wait on child processes
- shell flags
  interactive, etc.
- non-special shell variables
  LINENO
  ENV (interactive only)
  PPID
  PS1-4
  PWD
  
  HISTFILE?
- shell history

### Long-term

- support for nondeterminism (move to K?)

### Testing

- Appropriate field splitting for generated strings (particularly parameters)

- VM for POSIX testing
  run on dash, bash

### Organizational issues

create a fork of kernel.org's dash, track it
but remove main, have proper handler abort

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

have both read the JSON output
  include ENTIRE shell info in JSON output

### Expansion.lem

Monads for parsing etc.
Clean up to make null more explicit (simplify matches?)

Error handling
  - parse errors break our libdash shim

No symbolic pathname expansion

### Bugs

Bash
  - Bug related to variable assignments before built in utilities
    - "If the command name is a special built-in utility, variable assignments shall affect the current execution environment. Unless the set -a option is on (see set), it is unspecified:"
    - "x=5 :" should set x=5 in the current shell env, but it does not in Bash (version 4.4.12(1)-release)

Dash
  - Are EXP_VARTILDE and EXP_VARTILDE2 necessary? 
    it seems to me that the parser is properly separating things out...
    test it!
