### Artifact TODO

- https://github.com/modernish/modernish to check for quirks, bugs, etc.
    * modernish --test!

- use travis to automate all testing, collect results nightly, auto-deploy
  + run on dash, yash, bash, and smoosh
  + automatically export test journal summaries

- performance tests?

### Implementation TODO

- history
  + fc
  + Sh_nolog
  + HISTFILE

- job control
  need to be careful update current job statuses on ECHLD
  should trigger Sh_notify on SIGCHLD

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
- support for nondeterminism

- per Ryan Culpepper: controlling dynamic extents to restrict phases.
  Ralf &co are more or less doing this with their restriction on aliases

### Bugs in real shells

* Bash
  - Bug related to variable assignments before built in utilities
    - "If the command name is a special built-in utility, variable assignments shall affect the current execution environment. Unless the set -a option is on (see set), it is unspecified:"
    - "x=5 :" should set x=5 in the current shell env, but it does not in Bash (version 4.4.12(1)-release)
    
    not REALLY a bug---there's an obscure flag to turn on the POSIX behavior

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

- Dash
  - Found (and fixed) arithmetic bug
  - Are `EXP_VARTILDE` and `EXP_VARTILDE2` necessary? 
    it seems to me that the parser is properly separating things out...
    test it!

  - seems like timescmd is implemented incorrectly, printing out wrong numbers
  - mishandles empty alias

- Dash, Bash
  - printf %5% seems perfectly valid, but both reject it as ill formatted
  - kill -l doesn't fit the output format
 
- Yash
  - set +m doesn't cause redirect of STDIN to /dev/null on asynchronous commands
  - fg has incorrect output

### Bugs per the spec
     
#### Dash

- empty aliases (441); fixed in patch

#### POSIX test suite and spec

- I think there's a typo/rendering error in Section 2.7.4. In the
  sentence that begins "However, the double-quote character...", the
  actual double-quote is mangled (or at least isn't displaying properly
  in my browser).

##### Confirmed

- bug in `sh_05.sh`
  
In `sh_05.sh` lines 5806-5815, we find the snippet:

```
    function func_sh5_326 {
        if [ $1 -eq 1 ] && [ $2 -eq 2 ] && [ $2 -eq 2 ] && 
           [ $3 -eq 3 ] && [ $4 -eq 4 ] && [ $5 -eq 5 ] &&
           [ $6 -eq 6 ] && [ $7 -eq 7 ] && [ $8 -eq 8 ] && [ $9 -eq 9 ]
        then
                return 0
        else
                return 1
        fi
    }
```

But that's not the right syntax. It should instead be:

```
    func_sh5_326() {
        ...
    }
```

Confirmed by Brian Selves of OpenGroup on 2019-01-07; will be fixed in
the next version.

- bugs in sh_12.ex

> You are correct that the test code assumes the shell will wait for
> both commands in the pipeline, but the standard doesn't require the
> shell to do that.  We will change the test code to ensure the echo
> has completed before the output is checked.

- I think I've found another subtle issue in sh_12.ex: test #718 uses
  the command `kill -TERM $$`... but `-[signame]` is an XSI extension,
  so not every shell will support it. It should be safe to use `kill
  -s TERM $$` on any platform.

> You  are right that sh_12.ex test #718 should use kill -s TERM $$

- I'm back with another subtle issue: tp722 seems to execute undefined
  behavior by setting a trap for SIGKILL. (There's also a typo in its
  header, writing signal 0 instead of 9 for SIGKILL).

> You are right :)  We will change the test so it doesn't try to
> catch signal 9 / SIGKILL (and fix the typo).

