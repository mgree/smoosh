### Automation

- fixup builtin.kill.jobs.test and other timing dependent tasks to be a little slower (on travis at least)

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

- add bosh
  http://schilytools.sourceforge.net/bosh.html
- add oil

### Implementation TODO

- ulimit
  id:20190721151028.2asrnf7eqimbuxs6@gondor.apana.org.au

- check opendir behavior
  id:20190723085552.GA24238@lt2.masqnet

- check bg/fg behavior
  id:20190807084015.GA402@lt2.masqnet
  
- absurd job control issues
  id:7594905a-e267-05c6-6ce7-fa7174cff3e7@inlv.org

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

- tests from https://github.com/oilshell/oil/issues/706#issuecomment-615100131

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

- refactor semantics.lem to use is_terminating_control
    don't immediately step! Break _n -> Done
- use monads (better parsing, etc.)

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

- parser
  + use Morbig
    morsmall/our AST alignment?
  + use OSH
  
  test on a variety of scripts!
  http://www.oilshell.org/release/0.6.0/test/wild.wwz/

- OSS fuzz; fuzz a variety of shells
  http://llvm.org/docs/LibFuzzer.html#fuzz-target
  https://github.com/google/oss-fuzz
  https://github.com/google/fuzzer-test-suite/blob/master/tutorial/libFuzzerTutorial.md
  https://blog.trailofbits.com/2018/10/05/how-to-spot-good-fuzzing-research/

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

- simplify scheduler
    explicit calls to indicate a desire for something else to be scheduled?
    can we drop the `step_eval` dependency in OS?

- symbolic pathname expansion
- support for nondeterminism

- per Ryan Culpepper: controlling dynamic extents to restrict phases.
  Ralf &co are more or less doing this with their restriction on aliases

### Resolving unspec behavior

* errexit

I wonder how many scripts would break if you changed the semantics of errexit-disabling (EV_EXIT/CMD_IGNORE_RETURN/whatever) so that it only had effect on a syntactic command, not the entire dynamic extent of a command.

* function defns must be compound commands
  `f() echo "$@"; f hi` vs `f() if true; then echo "$@"; fi; f hi`
  (but not in dash, zsh, ksh, ksh parser)
  
* does `fc -l` print the `fc -l` itself?

* what do shells do with PS1=${NEVERSET-$(cmd)}?
  or PS1=${PS1+$(cmd)}
  
* what is the notion of job/forking?
  id:20190721164533.z3wmmjev3lih5fm5@chaz.gmail.com

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

### Morbig

* Parsing in interactive mode with Morbig results in Smoosh exiting. You can see
  an error being raised if you use Morbig in a forked process in throwaway_driver.ml

* Integrating Morbig-Shim into the Smoosh shtepper (not just shell.ml)

* Making a cleaner abstraction for which parser is being used. Right now it is a
  part of os_state, but really you should not be able to change the parser being
  used while using the shell, because each parser maintains state and changing
  parsers will break invariants.

* Heredoc quoting. Right now, Morsmall doesn't have that information in the AST,
  so we just default to XHere (unquoted).

* Bracket expressions. These are represented in the Morsmall AST, but really
  shouldn't be.

* A variety of bugs exist in the test_morbig executable.

* A variety of bugs exist when running all shell tests. `cd tests; rm
  default.env; TEST_DEBUG=1 make` does not succeed.
  119/171 currently pass, and many, but not most, of the remaining failing tests
  relate to quotes, redirs, heredocs, and pipes.

* The mechanism for parsing calling parse_next wherein previous parsed
  statements are stored in the `unparsed_commands` list is dubious. This might
  be the source of many bugs.

* The Morsmall.AST.WLiteral case of the morsmall_wordval_to_smoosh_entries
  function has a regular expression that takes care of a lot of cases, but might
  not be entirely correct. 

* Within the Morsmall repository, I changed the cst_to_ast function to make
  single quoted words in the cst double quoted words, instead of just regular
  words. It would be better to create new value of single quoted words in the
  AST, which for some reason, does not exist. [MMG: this isn't quite the right behavior: need to introduce escapes, instead]
  
