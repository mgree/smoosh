### Artifact TODO

- use travis to automate all testing, collect results nightly, auto-deploy
  + shells: smoosh bash dash yash zsh
    still need to install: osh? fish CoLiS ksh?
  + run our tests
    * smoosh suite
    * modernish
    * POSIX test suite
  + automatically export reports
    * smoosh test suite
    * modernish
    * POSIX (test journal summaries, timing)

### Implementation TODO

- PS1/PS2 expansion uses dash's expander/environment

- modernish broken in docker for smoosh (memory error?!)
  probably related to parse aborts we've seen
      mishandling of erroneous parsing in eval?

- add other utilities to testing
```
#   cd command echo false getopts kill printf pwd read sh test true wait
#
# ^awk ^basename ^bc ^cat ^cd ^chgrp ^chmod ^chown ^cksum ^cmp ^comm
# ^command ^cp ^cut ^date ^dd ^diff ^dirname ^echo ^ed ^env ^expr
# ^false ^find ^fold ^getconf ^getopts ^grep ^head ^id ^join ^kill
# ^ln ^locale ^localedef ^logger ^logname ^lp ^ls ^mailx ^mkdir
# ^mkfifo ^mv ^nohup ^od ^paste ^pathchk ^pax ^pr ^printf ^pwd
# ^read ^rm ^rmdir ^sed ^sh ^sleep ^sort ^stty ^tail ^tee ^test ^touch 
# ^tr ^true ^tty ^umask ^uname ^uniq ^wait ^wc ^xargs
```

- bools are technical debt

- generalize tc_setfg use in job control to pull code out of system.ml

- history
  + fc
  + Sh_nolog
  + HISTFILE

- job control
  need to be careful update current job statuses on ECHLD
  should trigger Sh_notify on SIGCHLD

- unspec rundown
  + unset and function names
  + variables and functions!x
  + a way to log each unspec/undef behavior to some directory
    * tracing w/help won't work with subshells. 
      best to just have timestamped occurrences w/maximum context

- non-special shell variables
  LINENO
  ENV (interactive only)
  
- faithful handling of PATH_MAX

### Known bugs/issues to investigate

- $$ not installed for symbolic shell
  but PPID is
  trickiness: $$ is unchanged in subshells, which can signal the top-level
              need to carefully hold on to such signals
  plan #1:
    add TopLevel option to proc
    add some symbolic state to record pending top-level signals
    execute on restore from step
  plan #2:
    actually put a proc entry in for the top-level shell
    much more faithful, messes with visualizaton as it exists now

- SIGPIPE in symbolic mode when reading from closed FDs

- `string_of_fields` pretty printing
  put single quotes around fields that have WS in them

- bare redirects
  cf. https://mail-index.netbsd.org/tech-userlevel/2018/11/24/msg011468.html
  via David Holland

- traps in symbolic mode
    track pid in each shell
      can do away with outermost! just compare pid and rootpid
    track pending signals for each pid in symbolic state
      special entry for pid 0, i.e., outermost shell
      
    need to check in about the KLUDGE at os_symbolic.lem:277 for the exit trap

    something to show `exit_code` in the shtepper

- https://www.spinics.net/lists/dash/msg01766.html
  my solution was to make `set` not actually break things... is that right?
  or is there something deeper going on here?

- job control and PIDs
  + INTON/INTOFF to get correct command editing behavior:
  
    If sh receives a SIGINT signal in command mode (whether generated
    by typing the interrupt character or by other means), it shall
    terminate command line editing on the current command line,
    reissue the prompt on the next line of the terminal, and reset the
    command history (see fc) so that the most recently executed
    command is the previous command (that is, the command that was
    being edited when it was interrupted is not re-entered into the
    history).
    
- "A trap on EXIT shall be executed before the shell terminates,
  except when the exit utility is invoked in that trap itself, in
  which case the shell shall exit immediately."
  
### Refactoring

- drop either for step_eval?
  + right now Left is only returned on 'hard' error
    CommandExpAssign bad set_param 
    CaseCheckMatch case on symbolic value
    Defun invalid function name
    Exec symbolic execve
  + we probably want to keep it for step_expansion
    it's handy to know more clearly about errors (rather than just checking ec)

- abstract over parser
  + functions:
    support for `EvalLoop`
      * context (e.g., stackmark/parser state)
      * parse_next function
    `set_ps1`
    `set_ps2`
  + libdash instance
  + morbig instance
    https://github.com/colis-anr/morbig/issues/102
- expansion: make null more explicit... simplify matches?

- collapse logic for tracing to there's just one eval function
  + split out `step_eval` and `log_step_eval`...
    but also use `log_step` in the middle

- there's some serious technical debt around triggering expansion within commands.
      need a uniform set of options/modes so that our congruences can be cleaner

### stepper

- JS/webpage
  + nicer way to edit the environment and home directories
  + way to configure fs
    interactions w/dash parser and host fs
    way to explore FS
  + set STDIN
  + use syntax highlighting in editor window
  + favicon
  + cleaner handling of environment, etc.
    add positional variables to display
    only show what changed
  + presets
  + more shell info
  + use a JS contracts/types library (TypeScript?)
- CLI
  + pretty printer for JSON output

### Long-term

- OSS fuzz; fuzz a variety of shells

- generate symbolic results of unknown executables

- better server support
  + SSL
    https://stackoverflow.com/questions/11589636/enable-https-in-a-rails-app-on-a-thin-server
    https://alessandrominali.github.io/sinatra_ssl
    https://certbot.eff.org/lets-encrypt/debianstretch-other.html
  + postback JS errors to the server
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
- support for nondeterminism

- per Ryan Culpepper: controlling dynamic extents to restrict phases.
  Ralf &co are more or less doing this with their restriction on aliases

### Resolving unspec behavior

* Bash
"If parameter is '*' or '@', the result of the expansion is unspecified."
weird choice in bash:
```
  set -- 'a b' 'c' 'd'
  echo ${#*}
```
yields
```
  3
```
    is also not _really_ a bug

