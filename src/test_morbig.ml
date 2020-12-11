open Test_prelude
open Smoosh
open Os_symbolic
open Path
open Printf

let parsed_str parse_init parse_next cmd =
  parse_init (ParseString (ParseEval, cmd));
  let rec build_result () =
    let next_parsed = parse_next Noninteractive in
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
    ; "echo  $((1 * $((2*3)) ))"
    (* nor does it track the `:` flag in parameter formats *)
    ; ": ${x=hi} ${x:=bye}"
     
    (* TODO MMG 2020-09-11 redir/simple command woes *)
    ; ": 2>&1" (* ==> Command with redirs built in *)
    ; "ls 2>&1 > dirlist"
    ; "ls > dirlist 2>&1"
    ; "ls > dirlist"
    ; ": 2<&1"
    ; "{ echo hello; echo world; } >/dev/null" (* Seq inside of Redir *)

    (* bug in morbig's parsing of length formats *)
    ; "${#x}"

    ; "${x-*}"
    ; "(trap 'echo bye' SIGTERM ; echo hi) & wait"
    ; "x=${y:=1} ; echo $((x+=`echo 2`))"
    ; "test a < b; test a \\< b"
    ; "echo \\"
    ; "printf %b \"hello\\n\""
    ; "x=hello\\*there ; echo ${x#*\\*}"
    ; "ls \n ls"
    ]
  in
  let read_whole_file filename =
    let ch = open_in filename in
    let s = really_input_string ch (in_channel_length ch) in
    close_in ch;
    s
  in
  let files = [
    "tests/shell/benchmark.fact5.test"
  ; "tests/shell/builtin.alias.empty.test"
  ] in
  let script_strs = List.map read_whole_file files in
  List.map
    (fun s -> (s, (*List.hd @@*) parsed_str Shim.parse_init Shim.parse_next s))
    (test_strs @ script_strs)

let json_str_of_stmts (s : Smoosh_prelude.stmt list) =
  let b = Buffer.create 0 in
  let js = List.map Shim.json_of_stmt s in
  List.iter (Shim.write_json b) js;
  Buffer.contents b

let check_tree_equivalence (cmd, expected) =
  checker (parsed_str Morbig_shim.parse_init Morbig_shim.parse_next)
    (fun s1 s2 -> json_str_of_stmts s1 = json_str_of_stmts s2)
    (cmd, cmd, expected)

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  print_endline "\n=== Initializing Dash parser...";
  Dash.initialize ();
  print_endline "=== Running Morbig tests...";
  test_part "Morbig" check_tree_equivalence json_str_of_stmts test_programs
    (* test_part "Morbig" check_tree_equivalence Smoosh_prelude.string_of_stmt test_programs *)
    test_count failed;
  printf "=== ...ran %d Morbig tests with %d failures.\n\n" !test_count !failed;
  !failed = 0

;;
run_tests ()
