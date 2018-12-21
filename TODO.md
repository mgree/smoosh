### Paper TODO

- run POSIX tests on dash, bash, and smoosh
  + automatically export test journal summaries
- performance tests vs. dash and bash?
  + we lose, of course. but how badly?
- write paper

### Artifact TODO

- test suite for shell, expand
  + kill
  + pipes and redirects
  + eval/.
  + shell within shell
  + cf. https://github.com/modernish/modernish to check for quirks, bugs, etc.
    * modernish --test!

- VM for POSIX testing
  run on dash, bash

### Bugs

- performance regressions
  environment size seems to be a factor... 
  can we do something better viz. sync_env?
    in fact, we only need to sync PS1 and PS2
    automatically sync whenever those vars are set

- traps in symbolic mode
    track pid in each shell
      can do away with outermost! just compare pid and rootpid
    track pending signals for each pid in symbolic state
      special entry for pid 0, i.e., outermost shell
      
    need to check in about the KLUDGE at os_symbolic.lem:277 for the exit trap

    something to show `exit_code` in the shtepper

- "A trap on EXIT shall be executed before the shell terminates,
  except when the exit utility is invoked in that trap itself, in
  which case the shell shall exit immediately."

- segfault on bad source

- broken interactive mode
  echo exit | PS1='$ ' ./smoosh -i
  breaks setpgid

- job control and PIDs
  + real_waitpid needs to know more job info about what it's waiting for
  + INTON/INTOFF to get correct command editing behavior:
  
    If sh receives a SIGINT signal in command mode (whether generated
    by typing the interrupt character or by other means), it shall
    terminate command line editing on the current command line,
    reissue the prompt on the next line of the terminal, and reset the
    command history (see fc) so that the most recently executed
    command is the previous command (that is, the command that was
    being edited when it was interrupted is not re-entered into the
    history).
    
- quoting and STDOUT
```
  touch a
  touch b
  touch "a b"
  x="\"a b\""
  rm $x
```

differing from dash... because dash has a bug
```
echo "\\\\"
echo "\\\\\\"
```

- $$ not installed for symbolic shell
  trickiness: $$ is unchanged in subshells, which can signal the top-level
              need to carefully hold on to such signals
  plan #1:
    add TopLevel option to proc
    add some symbolic state to record pending top-level signals
    execute on restore from step
  plan #2:
    actually put a proc entry in for the top-level shell
    much more faithful, messes with visualizaton as it exists now

  + treat $$ and $! specially
    bonus: simpler logic on special parameters (never in env)
    

- what is the exact correct behavior for IFS null?
  no field splitting should happen on _strings_

- `string_of_fields` pretty printing
  put single quotes around fields that have WS in them

- bare redirects
  cf. https://mail-index.netbsd.org/tech-userlevel/2018/11/24/msg011468.html
  via David Holland

### Last of the shell semantics

- history
  + fc
  + Sh_nolog
  + HISTFILE

- job control
  + Sh_notify
  need to update current job statuses on ECHLD
  jobs command should also be checking!

- non-special shell variables
  LINENO
  ENV (interactive only)
  PPID
- faithful handling of PATH_MAX

- expansion: make null more explicit... simplify matches?

### stepper

- JS/webpage
  + nicer way to edit the environment and home directories
  + way to configure fs
  + use syntax highlighting in editor window
  + favicon
  + cleaner handling of environment, etc.
    add positional variables to display  
  + presets
  + way to explore FS
  + more shell info
  + use a JS contracts/types library 
- CLI
  + pretty printer for JSON output

### Long-term

- abstract over parser
  + functions:
    support for `EvalLoop`
      * context (e.g., stackmark/parser state)
      * parse_next function
    `set_ps1`
    `set_ps2`
  + libdash instance
  + morbig instance

- actually use log_unspec etc

- collapse logic for tracing to there's just one eval function
  + split out `step_eval` and `log_step_eval`...
    but also use `log_step` in the middle

- generate symbolic results of unknown executables

- better server support
  + SSL
    https://stackoverflow.com/questions/11589636/enable-https-in-a-rails-app-on-a-thin-server
    https://alessandrominali.github.io/sinatra_ssl
    https://certbot.eff.org/lets-encrypt/debianstretch-other.html
  + postback JS errors to the serve
  + auto-pull and rebuild from a production branch
    use docker-compose to make the reload process simpler
    identify revision in web-server

- move to int64
  there are almost certainly some bugs around the POSIX spec
    is it in-spec to have a shell with bignum?
- proper locale support

- explicit scheduler
  `read_line_fd` and `builtin_read` use Wait to trigger blocking.

  `read_all_fd`, which gets used for subshells, doesn't need
  `step_eval` function because we can be careful to do the stepping
  ourselves. but `read_char_fd` _does_, because who knows how far down
  the pipeline the things we want are!
  
  `waitpid`, however, triggers real blocking :(
  
  in the long term, it'd be good to have OS calls that ask the
  scheduler to do things. 
  
  we can put `step_eval` (and `eval_for_exit_code`) into an OS 'a
  value. it would only ever be used by the symbolic parts, and it
  might trigger a call to `step_eval` and appropriate logging in
  `os.log`. the system mode can rely on the system scheduler and real
  blocking.

- symbolic pathname expansion
- refactor semantics.lem to use is_terminating_control
    don't immediately step! Break _n -> Done
  follow dash on break/continue behavior inside of functions
- use monads (better parsing, etc.)
- support for nondeterminism (move to K?)

- per Ryan Culpepper: controlling dynamic extents to restrict phases.
  Ralf &co are more or less doing this with their restriction on aliases

### Parsing

Should we write a custom parser? Use Ralf Treinen's?

### Bugs in real shells

Bash
  - Bug related to variable assignments before built in utilities
    - "If the command name is a special built-in utility, variable assignments shall affect the current execution environment. Unless the set -a option is on (see set), it is unspecified:"
    - "x=5 :" should set x=5 in the current shell env, but it does not in Bash (version 4.4.12(1)-release)
    
    not REALLY a bug---there's an obscure flag to turn on the POSIX behavior

Dash
  - Found (and fixed) arithmetic bug
  - Are `EXP_VARTILDE` and `EXP_VARTILDE2` necessary? 
    it seems to me that the parser is properly separating things out...
    test it!

  - seems like timescmd is implemented incorrectly, printing out wrong numbers

BOTH
  - printf %5% seems perfectly valid, but both reject it as ill formatted
  - kill -l doesn't fit the output format
