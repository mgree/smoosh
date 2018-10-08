### Paper TODO

- get server up
  + install ruby
  + fold out web repo
  + run expander in a chroot jail... or simply via Docker?
  + postback JS errors
- run POSIX tests on dash, bash, and smoosh
  + Dockerfile for loading POSIX tests
  + export test journal summaries
- strawman performance tests vs. dash and bash?
- write paper

### Bugs

- eval and ./source should work in a line-oriented fashion

- not properly catching SIGINT at the toplevel
  dash raises a top-level exception, handles it in main.c:123
  probably wrong in system.ml:42
  need to setup a handler in shell.ml
  + correct application of INTON/INTOFF

- fork_and_subshell should handle pgrps
  + needs to know if we're FG or not
    cf. jobs.c:869

- read_fd/read_char_fd should trigger steps/set up scheduler plans
  needed to get the right behavior on some symbolic tests for read

### Last of the shell semantics

- Sh_errexit

- other built-ins
  + getopts
  + kill

- history
  + fc
  + Sh_nolog
  + HISTFILE

- job control
  + bg
  + fg
  + Sh_notify
  need to update current job statuses on ECHLD, every command loop
  jobs command should also be checking!

- non-special shell variables
  LINENO
  ENV (interactive only)
  PPID
- faithful handling of PATH_MAX

- tests for pipes and redirects
- eval/.
  + write more tests

- expansion: make null more explicit... simplify matches?

### Long-term

- actually use log_unspec etc

- collapse logic for tracing to there's just one eval function

- generate symbolic results of unknown executables


- move to int64
  there are almost certainly some bugs around the POSIX spec
    is it in-spec to have a shell with bignum?
- proper locale support

- symbolic pathname expansion
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

### Bugs in real shells

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

BOTH
  - printf %5% seems perfectly valid, but both reject it as ill formatted
