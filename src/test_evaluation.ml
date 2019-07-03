open Test_prelude
open Smoosh
open Os_symbolic
open Path
open Printf

(***********************************************************************)
(* EXIT CODE TESTS *****************************************************)
(***********************************************************************)
   
let run_cmd_for_exit_code (cmd : string) (os0 : symbolic os_state) : int =
  let c = Shim.parse_string cmd in
  let os1 = Semantics.symbolic_full_evaluation os0 c in
  if out_of_fuel os1
  then -1
  else os1.sh.exit_code

let check_exit_code (cmd, state, expected) =
  checker (run_cmd_for_exit_code cmd) (=) (cmd, state, expected)
 
let exit_code_tests : (string * symbolic os_state * int) list =
  (* basic logic *)
  [ ("true", os_empty, 0)
  ; ("false", os_empty, 1)
  ; ("true && true", os_empty, 0)
  ; ("true && false", os_empty, 1)
  ; ("false && true", os_empty, 1)
  ; ("false || true", os_empty, 0)
  ; ("false ; true", os_empty, 0)
  ; ("true ; false", os_empty, 1)
  ; ("! true", os_empty, 1)
  ; ("! false", os_empty, 0)
  ; ("! { true ; false ; }", os_empty, 0)
  ; ("! { false ; true ; }", os_empty, 1)
  ; ("x=`false`", os_empty, 1)
  ; ("x=$(exit 5)", os_empty, 5)
  ; ("exit $(echo 3; exit 5)", os_empty, 3)

  (* expansion *)
  ; ("x=5 ; echo ${x?erp}", os_empty, 0)
  ; ("echo ${x?erp}", os_empty, 1)
  ; ("for y in ${x?oh no}; do exit 5; done", os_empty, 1)
  ; ("x=5 ; for y in ${x?oh no}; do exit $y; done", os_empty, 5)
  ; ("case ${x?alas} in *) true;; esac", os_empty, 1)
  ; ("x=7 ; case ${x?alas} in *) exit $x;; esac", os_empty, 7)
  ; ("x=$(echo 5) ; exit $x", os_empty, 5)
  ; ("x=$(echo hello) ; case $x in *ell*) true;; *) false;; esac", os_empty, 0)

  (* exit *)
  ; ("exit", os_empty, 0)
  ; ("exit 2", os_empty, 2)
  ; ("false; exit", os_empty, 1)
  ; ("false; exit 2", os_empty, 2)
  ; ("exit 2; false", os_empty, 2)
  ; ("exit 2; exit 40", os_empty, 2)
  
  (* break *)
  ; ("while true; do break; done", os_empty, 0)

  (* for loop with no args should exit 0 *)
  ; ("for x in; do exit 1; done", os_empty, 0)
  ; ("for x in \"\"; do exit 1; done", os_empty, 1)

  (* case cascades *)
  ; ("case abc in ab) true;; abc) false;; esac", os_empty, 1)
  ; ("case abc in ab|ab*) true;; abc) false;; esac", os_empty, 0)
  ; ("case abc in *) true;; abc) false;; esac", os_empty, 0)
  ; ("x=hello ; case $x in *el*) true;; *) false;; esac", os_empty, 0)
  ; ("case \"no one is home\" in esac", os_empty, 0)
  ; ("case Linux in Lin*) true;; *) false;; esac", os_empty, 0)

  (* pipes *)
  ; ("false | true", os_empty, 0)
  ; ("true | false", os_empty, 1)
  ; ("true | exit 5", os_empty, 5)

  (* unset *)
  ; ("x=5 ; exit $x", os_empty, 5)
  ; ("x=5 ; unset x; exit $x", os_empty, 0)
  ; ("x=5 ; unset x; exit ${x-42}", os_empty, 42)
  ; ("f() { exit 3 ; } ; f", os_empty, 3)
  ; ("f() { exit 3 ; } ; unset f ; f", os_empty, 3)
  ; ("f() { exit 3 ; } ; unset -f f ; f", os_empty, 127)

  (* readonly *)
  ; ("x=5 ; readonly x", os_empty, 0)
  ; ("x=5 ; readonly x ; readonly x=10", os_empty, 1)
  ; ("x=- ; readonly $x=derp", os_empty, 1)

  (* export *)
  ; ("x=- ; export $x=derp", os_empty, 1)

  (* eval *)
  ; ("eval exit 0", os_empty, 0)
  ; ("eval exit 1", os_empty, 1)
  ; ("! ( eval exit 1 )", os_empty, 0)
  ; ("! eval exit 1", os_empty, 1)
  ; ("! eval exit 47", os_empty, 47)

  (* function calls *)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i g", os_empty, 5)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i h", os_empty, 6)
  ; ("g() { exit 5 ; } ; h() { exit 6 ; } ; i() { $1 ; exit 7 ; } ; i :", os_empty, 7)

  (* $# *)
  ; ("f() { exit $# ; } ; f", os_empty, 0)
  ; ("f() { exit $# ; } ; f a", os_empty, 1)
  ; ("f() { exit $# ; } ; f a b", os_empty, 2)
  ; ("f() { exit $# ; } ; f a b c", os_empty, 3)
  ; ("f() { $@ ; } ; f exit 12", os_empty, 12)
  ; ("f() { $* ; } ; f exit 12", os_empty, 12)

  (* set *)
  ; ("set -- a b c; exit $#", os_empty, 3)
  ; ("set -- ; exit $#", os_empty, 0)
  ; ("set -n ; exit 5", os_empty, 0)
  ; ("set -u ; echo $x", os_empty, 1)
  ; ("set -- a b c; set -u; exit $#", os_empty, 3)
  ; ("set -- a b c; set -u a b; exit $#", os_empty, 2)

    (* test *)
  ; ("test hi = hi", os_empty, 0)
  ; ("test hi = bye", os_empty, 1)
  ; ("test hi != hi", os_empty, 1)
  ; ("test hi != bye", os_empty, 0)
  ; ("test", os_empty, 1)
  ; ("test hello", os_empty, 0)
  ; ("test \"\"", os_empty, 1)
  ; ("test -n hello", os_empty, 0)
  ; ("test -n \"\"", os_empty, 1)
  ; ("test -z \"\"", os_empty, 0)
  ; ("test -z hello", os_empty, 1)
  ; ("test 5 -eq 5", os_empty, 0)
  ; ("test 5 -ne 5", os_empty, 1)
  ; ("test 1 -lt 5", os_empty, 0)
  ; ("test 5 -lt 5", os_empty, 1)
  ; ("test 1 -le 1", os_empty, 0)
  ; ("test 1 -gt 5", os_empty, 1)
  ; ("test 5 -gt 5", os_empty, 1)
  ; ("test 1 -ge 1", os_empty, 0)
  ; ("test hi -ge 1", os_empty, 2)
  ; ("test \\( 5 -ne 5 \\) -o -n hello", os_empty, 0)
  ; ("test \\( 5 -eq 5 \\) -a -z \"\"", os_empty, 0)
  ; ("test 5 -eq 5 -a -z \"\"", os_empty, 0)
  ; ("test hi \\< hello", os_empty, 1)
  ; ("test lol \\< hello", os_empty, 1)
  ; ("test a \\< b", os_empty, 0)

  (* regression: support negative numbers *)
  ; ("test -5 -eq $((0-5))", os_empty, 0)
  ; ("test -5 -eq $((5*5))", os_empty, 1)
  ; ("test $((0-5)) -eq -5", os_empty, 0)
  ; ("test $((5*5)) -eq -5", os_empty, 1)
  ]

(***********************************************************************)
(* STDOUT TESTS ********************************************************)
(***********************************************************************)

let run_cmd_for_stdout (cmd : string) (os0 : symbolic os_state) : string =
  let c = Shim.parse_string cmd in
  let os1 = Semantics.symbolic_full_evaluation os0 c in
  if out_of_fuel os1
  then "!!! OUT OF FUEL"
  else get_stdout os1

let check_stdout (cmd, state, expected) =
  checker (run_cmd_for_stdout cmd) (=) (cmd, state, expected)

let stdout_tests : (string * symbolic os_state * string) list =
    (* basic logic *)
  [ ("true", os_empty, "")
  ; ("false", os_empty, "")
  ; ("echo hi ; echo there", os_empty, "hi\nthere\n")
  ; ("echo -n hi ; echo there", os_empty, "hithere\n")
  ; ("echo -n \"hi \" ; echo there", os_empty, "hi there\n")
  ; ("x=${y:=1} ; echo $((x+=`echo 2`))", os_empty, "3\n")

  (* regression: krazy kwotes 
     see test_prelude.ml for fs details of why these are the outputs
   *)
  ; ("echo *", os_complicated_fs, "a b c\n")
  ; ("echo \\*", os_complicated_fs, "*\n")
  ; ("x=\\* ; echo $x", os_complicated_fs, "a b c\n")
  ; ("x=\\* ; set -f ; echo $x ; set +f ; echo $x", os_complicated_fs, "*\na b c\n")
  ; ("x=\\* ; cd b ; echo $x", os_complicated_fs, "user\n")
  ; ("case hi\\\"there\\\" in *\\\"there\\\") echo matched;; *) echo did not;; esac", os_complicated_fs, "matched\n")
  ; ("case hi\\\"there\\\" in *\"there\") echo matched;; *) echo did not;; esac", os_complicated_fs, "did not\n")
  ; ("x='' ; case $x in \"\") echo e ;; *) echo nope ;; esac", os_empty, "e\n")
  ; ("case hi\\\"there\\\" in *\\\") echo m;; *) echo n;; esac", os_empty, "m\n")
  ; ("x=hello\\*there ; echo ${x#*\\*}", os_complicated_fs, "there\n")

  ; ("case Linux in Lin*) echo matched;; *) echo nope;; esac", os_empty, "matched\n")
  ; ("case Linux in *) echo matched;; esac", os_empty, "matched\n")
  (* regression: don't do pathname expansion on patterns *)
  ; ("case Linux in *) echo matched;; esac", os_complicated_fs, "matched\n")
  ; ("case Linux in *) echo matched;; esac", os_complicated_fs_in_a, "matched\n")
  ; ("echo []", os_complicated_fs, "[]\n")
  ; ("echo \"[]\"", os_complicated_fs, "[]\n")
  ; ("echo '[]'", os_complicated_fs, "[]\n")
  ; ("echo \\[]", os_complicated_fs, "[]\n")

    (* regression: support [a-zA-Z][a-zA-Z0-9_] as varnames *)
  ; ("var_1=5 ; echo $((var_1 + 1))", os_empty, "6\n")
  ; ("_var1=5 ; echo $((_var1 * 2))", os_empty, "10\n")
  ; ("_=5 ; echo $((_ - 3))", os_empty, "2\n")
  ; ("_234=5 ; echo $((_234 % 4))", os_empty, "1\n")
  
    (* regression: correct handling of patterns *)
  ; ("x=foo_47.bar ; echo ${x%%[!0-9]*}", os_empty, "\n")
  ; ("x=foo_47.bar ; echo ${x%%[!0-9]*}", os_complicated_fs, "\n")
  ; ("x=foo_47.bar ; echo ${x##[!0-9]*}", os_empty, "\n")
  ; ("x=foo_47.bar ; echo ${x##[!0-9]*}", os_complicated_fs, "\n")

    (* regression: correct positional param restore on function return *)
  ; ("g() { set -- q ; } ; f() { echo $# [$*] ; g ; echo $# [$*] ; } ; f a b c",
     os_empty,
     "3 [a b c]\n3 [a b c]\n")

    (* regression: shift shouldn't affect $0 *)
  ; ("echo $0 ; set -- a b c ; echo $0 ; shift ; echo $0 ; shift 2 ; echo $0",
     os_empty,
     "smoosh\nsmoosh\nsmoosh\nsmoosh\n")

    (* regression: eval and set *)
  ; ("eval set -- 1 2 3 ; echo $#", os_empty, "3\n")
  ; ("eval set -- 1 2 3 ; echo $*", os_empty, "1 2 3\n")

    (* regression: set -- *)
  ; ("set -- 1 2 3; echo $#; set --; echo $#", os_empty, "3\n0\n")
     
    (* subshells *)
  ; ("x=$(echo *) ; echo $x", os_complicated_fs, "a b c\n")
  ; ("x=$(echo hello there); echo $x", os_empty, "hello there\n")
  ; ("x=$(echo 5); echo $((x * x))", os_empty, "25\n")

    (* shift *)
  ; ("set -- a b c ; shift ; echo $#", os_empty, "2\n")
  ; ("set -- a b c ; shift 1 ; echo $#", os_empty, "2\n")
  ; ("set -- a b c ; shift 2 ; echo $# [$*]", os_empty, "1 [c]\n")
  ; ("set -- a b c ; shift 3 ; echo $# [$*]", os_empty, "0 []\n")
  ; ("set -- a b c ; shift 0 ; echo $# [$*]", os_empty, "3 [a b c]\n")
  ; ("set -- a b c ; shift 4 ; echo failed", os_empty, "")
  ; ("set -- a b c ; shift 4 ; echo failed", os_empty, "")

    (* redirects and pipes *)
  ; ("( echo ${x?oops} ) 2>&1", os_empty, "x: oops\n")
  ; ("echo hi | echo no", os_empty, "no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 2>&1; echo ${y?oh no}", os_empty, "y: oh no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 1>&2; echo ${y?oh no}", os_empty, "")
  ; ("while true; do echo 5; done | echo done", os_empty, "done\n")
  ; ("while true; do echo 5; done | { read x; echo $((x + 42)) ; }", os_empty, "47\n")

    (* $* vs $@ 

       e.g.s from https://stackoverflow.com/questions/12314451/accessing-bash-command-line-args-vs/12316565
     *)
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in $*; do echo \"$x\"; done",
     os_empty,
     "arg\n1\narg\n2\narg\n3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in $@; do echo \"$x\"; done",
     os_empty,
     "arg\n1\narg\n2\narg\n3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$*\"; do echo \"$x\"; done",
     os_empty,
     "arg  1 arg  2 arg  3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$@\"; do echo \"$x\"; done",
     os_empty,
     "arg  1\narg  2\narg  3\n")
  ; ("set -- 'arg  1' 'arg  2' 'arg  3' ; for x in \"$@\"; do echo $x; done",
     os_empty,
     "arg 1\narg 2\narg 3\n")

    (* command types *)
  ; ("type type", os_empty, "type is a shell builtin\n")
  ; ("type :", os_empty, ": is a special shell builtin\n")
  ; ("f() : ; type f", os_empty, "f is a shell function\n")
  ; ("type nonesuch", os_empty, "nonesuch: not found\n")
  ; ("pwd() echo florp ; pwd", os_empty, "florp\n")
  ; ("pwd() echo florp ; command pwd", os_empty, "/\n")
  ; ("pwd() echo florp ; command -p pwd", os_empty, "/\n")

    (* umask *)
  ; ("umask", os_empty, "0022\n")
  ; ("umask -S", os_empty, "u=rwx,g=rx,o=rx\n")
  ; ("umask 0044 ; umask", os_empty, "0044\n")
  ; ("umask 0044 ; umask -S", os_empty, "u=rwx,g=wx,o=wx\n")
  ; ("umask a= ; umask", os_empty, "0777\n")
  ; ("umask a= ; umask u+rwx ; umask", os_empty, "0077\n")
  ; ("umask a= ; umask u+rwx,go+rx ; umask", os_empty, "0022\n")
  ; ("umask u=o; umask", os_empty, "0222\n")
  ; ("umask u=g; umask", os_empty, "0222\n")
  ; ("umask g+u; umask", os_empty, "0002\n")

    (* read *)
  ; ("echo 1 | read x; echo ${x-subshell}", os_empty, "subshell\n")
  ; ("echo 1 | { read x ; echo $x ; }", os_empty, "1\n")
  ; ("echo 1 2 | { read x y ; echo $x ; echo $y ; }", os_empty, "1\n2\n")
  
    (* printf *)
  ; ("printf", os_empty, "")
  ; ("printf \\\\n", os_empty, "\n")
  ; ("printf hi\\\\n%%\\\\tthere", os_empty, "hi\n%\tthere")
  ; ("printf oct%spus o", os_empty, "octopus")
  ; ("printf %s $((10 * 10))", os_empty, "100")
  ; ("printf %b 'hello\\n'", os_empty, "hello\n")
  ; ("printf %b \"hello\\n\"", os_empty, "hello\n")
  ; ("printf %b \"hello\\\\n\"", os_empty, "hello\n")
  ; ("printf %c oops", os_empty, "o")
  ; ("printf %.1s hello", os_empty, "h")
  ; ("printf %.0s hello", os_empty, "")
  ; ("printf %.s hello", os_empty, "")
  ; ("printf %d 0xf", os_empty, "15")
  ; ("printf %i 0xf", os_empty, "15")
  ; ("printf %x 16", os_empty, "10")
  ; ("printf %X 15", os_empty, "F")
  ; ("printf %#X 15", os_empty, "0XF")
  ; ("printf %#x 15", os_empty, "0xf")
  ; ("printf %04x 15", os_empty, "000f")
  ; ("printf %#04x 15", os_empty, "0x0f")
  ; ("printf %#05x 15", os_empty, "0x00f")
  ; ("printf %#5x 15", os_empty, "  0xf")
  ; ("printf %x -5", os_empty, "fffffffffffffffb")
  ; ("printf %u -5", os_empty, "18446744073709551611")

    (* regression: printf should rerun to print all arguments *)
  ; ("printf '%d %d' 1 2 3 4 5 6 7 8 9", os_empty, "1 23 45 67 89 0")

    (* kill *)
  ; ("echo hi & wait", os_empty, "hi\n")
  ; ("echo hi & kill $! ; wait", os_empty, "")
  ; ("(trap 'echo bye' SIGTERM ; echo hi) & wait", os_empty, "hi\n")
  (* this test doesn't work, because demand-driven scheduling means the trap
     is never installed before teh signal arrives *)
(*  ; ("(trap 'echo bye' SIGTERM ; echo hi) & kill %1 ; wait", os_empty, "bye\n") *)
  ; ("(trap 'echo bye' EXIT) & wait", os_empty, "bye\n")
  ; ("trap 'echo bye' EXIT", os_empty, "bye\n")
  ; ("(trap 'echo bye' EXIT; echo hi) ; wait", os_empty, "hi\nbye\n")
  ; ("trap 'echo sig' SIGTERM; kill $$", os_empty, "sig\n")
  ; ("(trap 'echo hi; exit' TERM; while true; do echo loop; done) & :; :; kill $!", os_empty, "loop\nhi\n")

    (* getopts *)
  ; ("getopts ab opt -a -b -- c d ; " ^
     "echo $opt $OPTIND $?; " ^
     "getopts ab opt -a -b -- c d ; " ^
     "echo $opt $OPTIND $?; " ^
     "getopts ab opt -a -b -- c d ; " ^
     "echo $opt $OPTIND $?",
     os_empty,
     "a 2 0\nb 3 0\n? 4 1\n")

  ; ("getopts abc opt -caaa c d e ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts abc opt -caaa c d e ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts abc opt -caaa c d e ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts abc opt -caaa c d e ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts abc opt -caaa c d e ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=c OPTIND=2 OPTARG= ?=0\n" ^
     "opt=a OPTIND=2 OPTARG= ?=0\n" ^
     "opt=a OPTIND=2 OPTARG= ?=0\n" ^
     "opt=a OPTIND=2 OPTARG= ?=0\n" ^
     "opt=? OPTIND=2 OPTARG= ?=1\n")

  ; ("getopts a:b opt -a -b ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=a OPTIND=3 OPTARG=-b ?=0\n")
  ; ("getopts a:b opt -a -b ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts a:b opt -a -b ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=a OPTIND=3 OPTARG=-b ?=0\n" ^
     "opt=? OPTIND=3 OPTARG= ?=1\n")

  ; ("getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=? OPTIND=2 OPTARG=b ?=0\n")
  ; ("getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=? OPTIND=2 OPTARG=b ?=0\n" ^
     "opt=a OPTIND=3 OPTARG= ?=0\n")
  ; ("getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=? OPTIND=2 OPTARG=b ?=0\n" ^
     "opt=a OPTIND=3 OPTARG= ?=0\n" ^
     "opt=? OPTIND=4 OPTARG=c ?=0\n")
  ; ("getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; " ^
     "getopts :a opt -b -a -c ; " ^
     "echo opt=$opt OPTIND=$OPTIND OPTARG=$OPTARG ?=$? ; ",
     os_empty,
     "opt=? OPTIND=2 OPTARG=b ?=0\n" ^
     "opt=a OPTIND=3 OPTARG= ?=0\n" ^
     "opt=? OPTIND=4 OPTARG=c ?=0\n" ^
     "opt=? OPTIND=4 OPTARG= ?=1\n")
       
     (* set -e *)
  ; ("set -e; false; echo hi", os_empty, "")
  ; ("set -e; true; echo hi", os_empty, "hi\n")
  ; ("set -e; ! false; echo hi", os_empty, "hi\n")
  ; ("set -e; ! true; echo hi", os_empty, "hi\n")
  ; ("set -e; (false; echo one) | echo two; echo three", os_empty, "two\nthree\n")
  ; ("set -e; (false; echo one) ; echo two", os_empty, "")

     (* exit *)
  ; ("echo hi; exit; echo farewell", os_empty, "hi\n")
  ]

(***********************************************************************)
(* DRIVER **************************************************************)
(***********************************************************************)

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  print_endline "\n=== Initializing Dash parser...";
  Dash.initialize ();
  print_endline "=== Running evaluation tests...";
  test_part "Exit code" check_exit_code string_of_int exit_code_tests test_count failed;
  test_part "Output on STDOUT" check_stdout (fun s -> s) stdout_tests test_count failed;
  printf "=== ...ran %d evaluation tests with %d failures.\n\n" !test_count !failed;
  !failed = 0
