open Test_prelude
open Smoosh
open Os_symbolic
open Path
open Printf

(***********************************************************************)
(* DRIVER **************************************************************)
(* Test that Morbig generates the same AST as Dash *********************)
(***********************************************************************)

(***********************************************************************)
(* Incremental parsing *************************************************)
(* Protocol: 
 *
 *   parse_init (parse_next* parse_done)
 *
 * ParseDone and ParseError mean you're done, and should stop calling parse_next.
 * ParseNull represents an empty line. ParseStmt is a successfully parsed line.
 *
 * The parse_string function is a convenience for testing. parse_done will be
 * called for you when you evaluate the resulting command.
 *
 * See smoosh.lem for the definition of parse_source and parse_result.
 *
 * It's critical that set_ps1 and set_ps2 be called whenever those prompts are 
 * updated---parsers do the prompting themselves.
 *
 * ??? It may or may not be a problem to call parse_done before you're done.
 *
 * ??? 2018-11-14 interrupts during parsing? hopefully handled after any forking?
 *
 *)

let dash_parsed_str cmd =
  Shim.parse_init (ParseString (ParseEval, cmd));
  let rec build_result () =
    let next_parsed = Shim.parse_next Noninteractive in
    match next_parsed with
    | Smoosh_prelude.ParseDone -> []
    | Smoosh_prelude.ParseError _ -> []
    | Smoosh_prelude.ParseNull -> build_result ()
    | Smoosh_prelude.ParseStmt c -> c :: build_result ()
  in
  build_result ()

let test_programs =
  let test_strs = 
  (List.map (fun (s, _, _) -> s) Test_evaluation.exit_code_tests) @
    [ "true | true | true"
    (* TODO MMG 2020-09-11 this catches the wonky field insertion *)
    ; "this' is one 'word but\"\tthis is another\"word" (* ==> [S "this is one word"; F; S "but"; K (Quote "\tthis is another"); S "word"] *)

    (* uh oh... morbig doesn't track arithmetic expressions! *)      
    ; ": $((x += 1))"
    (* nor does it track the `:` flag in parameter formats *)
    ; ": ${x=hi} ${x:=bye}"
     
    (* TODO MMG 2020-09-11 redir/simple command woes *)
    ; ": 2>&1" (* ==> Command with redirs built in *)
    ; "{ echo hello; echo world; } >/dev/null" (* Seq inside of Redir *)      
    ]
  in
  List.map
    (fun s -> (s, List.hd @@ dash_parsed_str s))
    (test_strs @ ["s"])

let json_str_of_stmt s =
  let b = Buffer.create 0 in
  let js = Shim.json_of_stmt s in
  Shim.write_json b js;
  Buffer.contents b

let check_tree_equivalence (cmd, expected) =
  checker Smoosh.parse_string_morbig
    (fun s1 s2 -> json_str_of_stmt s1 = json_str_of_stmt s2)
    (cmd, cmd, expected)

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  print_endline "\n=== Initializing Dash parser...";
  Dash.initialize ();
  print_endline "=== Running Morbig tests...";
  test_part "Morbig" check_tree_equivalence json_str_of_stmt test_programs
    (* test_part "Morbig" check_tree_equivalence Smoosh_prelude.string_of_stmt test_programs *)
    test_count failed;
  printf "=== ...ran %d Morbig tests with %d failures.\n\n" !test_count !failed;
  !failed = 0

;;
run_tests ()
