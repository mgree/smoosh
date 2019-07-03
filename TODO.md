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

  SIGPIPE in symbolic mode when reading from closed FDs

  while true; do echo 5; done | { read x; echo $((x+42)); }
  
  need to send SIGPIPE in write_fifo...
  which needs to know the current actor's PID...
  which means we need to track that?
  
    currently have `susp_fds` and `curpid` being tracked in symbolic
    but the big issue here is that signal handling isn't working for the _current_ process
    
    another solution here is to have the write_fd OS call possibly signal EPIPE, 
    which is forcibly handled as a SIGPIPE by the semantics.
        but that might mean a fair bit of error handling.
        real signals will be nicer to program with.
        
  use procs heavily. initialize things with main shell in proc 0
  change shim to send over the full OS state, including the proc list
  render all of the live procs side by side
    collapse all but the main shell and the active proc?

- bools are technical debt

- generalize tc_setfg use in job control to pull code out of system.ml

- non-special shell variables
  LINENO
  ENV (interactive only)
  
- faithful handling of PATH_MAX

### Known bugs/issues to investigate

- `string_of_fields` pretty printing
  put single quotes around fields that have WS in them

- bare redirects
  cf. https://mail-index.netbsd.org/tech-userlevel/2018/11/24/msg011468.html
  via David Holland

- https://www.spinics.net/lists/dash/msg01766.html
  my solution was to make `set` not actually break things... is that right?
  or is there something deeper going on here?

- "A trap on EXIT shall be executed before the shell terminates,
  except when the exit utility is invoked in that trap itself, in
  which case the shell shall exit immediately."
  
### Refactoring

- re-align shim.ml and libdash's ast.ml

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

