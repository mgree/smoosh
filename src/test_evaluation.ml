open Test_prelude
open Smoosh
open Path
open Printf

(***********************************************************************)
(* EXIT CODE TESTS *****************************************************)
(***********************************************************************)

let get_exit_code (os : symbolic os_state) =
  match lookup_concrete_param os "?" with
  | Some digits ->
     begin 
       try int_of_string digits
       with Failure "int_of_string" -> 257 (* unrepresentable in shell *)
     end
  | None -> 258
   
let run_cmd_for_exit_code (cmd : string) (os0 : symbolic os_state) : int =
  let cs = Shim.parse_string cmd in
  let os1 = Semantics.full_evaluation_multi os0 cs in
  get_exit_code os1

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
  ; ("x=5 ; readonly x ; ! readonly x=10", os_empty, 0)
  ; ("x=- ; ! readonly $x=derp", os_empty, 0)

  (* export *)
  ; ("x=- ; ! export $x=derp", os_empty, 0)

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
  ; ("test 5 -neq 5", os_empty, 1)
  ; ("test 1 -lt 5", os_empty, 0)
  ; ("test 5 -lt 5", os_empty, 1)
  ; ("test 1 -le 1", os_empty, 0)
  ; ("test 1 -gt 5", os_empty, 1)
  ; ("test 5 -gt 5", os_empty, 1)
  ; ("test 1 -ge 1", os_empty, 0)
  ; ("test hi -ge 1", os_empty, 2)
  ; ("test \\( 5 -neq 5 \\) -o -n hello", os_empty, 0)
  ; ("test \\( 5 -eq 5 \\) -a -z \"\"", os_empty, 0)
  ; ("test 5 -eq 5 -a -z \"\"", os_empty, 0)
  ; ("test hi \\< hello", os_empty, 1)
  ; ("test lol \\< hello", os_empty, 1)
  ; ("test a \\< b", os_empty, 0)
  ]

(***********************************************************************)
(* STDOUT TESTS ********************************************************)
(***********************************************************************)

let run_cmd_for_stdout (cmd : string) (os0 : symbolic os_state) : string =
  let cs = Shim.parse_string cmd in
  let os1 = Semantics.full_evaluation_multi os0 cs in
  get_stdout os1

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

    (* redirects and pipes *)
  ; ("( echo ${x?oops} ) 2>&1", os_empty, "x: oops\n")
  ; ("echo hi | echo no", os_empty, "no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 2>&1; echo ${y?oh no}", os_empty, "y: oh no\n")
  ; ("echo ${y?oh no}", os_empty, "")
  ; ("exec 1>&2; echo ${y?oh no}", os_empty, "")

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

  (* failing in symbolic mode because of pipe/scheduler issues *)
(*  ; ("echo 1 | { read x ; echo $x ; }", os_empty, "1\n")
  ; ("echo 1 2 | { read x y ; echo $x ; echo $y ; }", os_empty, "1\n2\n") *)
  
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
