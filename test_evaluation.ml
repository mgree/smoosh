open Test_prelude
open Fsh
open Path
open Printf

(***********************************************************************)
(* EXIT CODE TESTS *****************************************************)
(***********************************************************************)

let get_exit_code (os : symbolic os_state) =
  match symbolic_lookup_concrete_param os "?" with
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

  printf "=== ...ran %d evaluation tests with %d failures.\n\n" !test_count !failed

