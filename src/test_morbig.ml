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
    ; "if [ 1 ]; then echo 1; fi"
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
  ; "tests/shell/sh.interactive.ps1.test"
  ; "tests/shell/semantics.wait.alreadydead.test"
  ; "tests/shell/builtin.alias.empty.test"
  ; "tests/shell/builtin.command.nospecial.test"
  ; "tests/shell/builtin.dot.path.test"
  ; "tests/shell/builtin.dot.return.test"
  ; "tests/shell/builtin.dot.unreadable.test"
  ; "tests/shell/builtin.eval.test"
  ; "tests/shell/builtin.exec.modernish.mkfifo.loop.test"
  ; "tests/shell/builtin.export.override.test"
  ; "tests/shell/builtin.export.test"
  ; "tests/shell/builtin.hash.nonposix.test"
  ; "tests/shell/builtin.history.nonposix.test"
  ; "tests/shell/builtin.kill.signame.test"
  ; "tests/shell/builtin.readonly.assign.interactive.test"
  ; "tests/shell/builtin.set.quoted.test"
  ; "tests/shell/builtin.source.setvar.test"
  ; "tests/shell/builtin.times.ioerror.test"
  ; "tests/shell/builtin.trap.subshell.loud2.test"
  ; "tests/shell/builtin.trap.subshell.truefalse.test"
  ; "tests/shell/parse.emptyvar.test"
  ; "tests/shell/parse.error.test"
  ; "tests/shell/semantics.arith.modernish.test"
  ; "tests/shell/semantics.background.test"
  ; "tests/shell/semantics.backtick.fds.test"
  ; "tests/shell/semantics.backtick.ppid.test"
  ; "tests/shell/semantics.command-subst.newline.test"
  ; "tests/shell/semantics.command.argv0.test"
  ; "tests/shell/semantics.dot.glob.test"
  ; "tests/shell/semantics.error.noninteractive.test"
  ; "tests/shell/semantics.escaping.backslash.modernish.test"
  ; "tests/shell/semantics.escaping.backslash.test"
  ; "tests/shell/semantics.escaping.heredoc.dollar.test"
  ; "tests/shell/semantics.escaping.quote.test"
  ; "tests/shell/semantics.escaping.single.test"
  ; "tests/shell/semantics.eval.makeadder.test"
  ; "tests/shell/semantics.expansion.heredoc.backslash.test"
  ; "tests/shell/semantics.expansion.quotes.adjacent.test"
  ; "tests/shell/semantics.interactive.expansion.exit.test"
  ; "tests/shell/semantics.length.test"
  ; "tests/shell/semantics.pattern.hyphen.test"
  ; "tests/shell/semantics.pattern.rightbracket.test"
  ; "tests/shell/semantics.pipe.chained.test"
  ; "tests/shell/semantics.redir.close.test"
  ; "tests/shell/semantics.redir.fds.test"
  ; "tests/shell/semantics.simple.link.test"
  ; "tests/shell/semantics.splitting.ifs.test"
  ; "tests/shell/semantics.subshell.background.traps.test"
  ; "tests/shell/semantics.tilde.no-exp.test"
  ; "tests/shell/semantics.tilde.quoted.prefix.test"
  ; "tests/shell/semantics.tilde.quoted.test"
  ; "tests/shell/semantics.tilde.sep.test"
  ; "tests/shell/semantics.var.dashu.test"
  ; "tests/shell/semantics.var.format.tilde.test"
  ; "tests/shell/semantics.wait.alreadydead.test"
  ; "tests/shell/sh.-c.arg0.test"
  ; "tests/shell/sh.file.weirdness.test"
  ; "tests/shell/sh.interactive.ps1.test"
  ; "tests/shell/sh.ps1.override.test"
  ; "tests/shell/sh.set.ifs.test"
  ] in
  let script_strs = List.map read_whole_file files in
  List.map
    (fun s -> (s, parsed_str Shim.parse_init Shim.parse_next s))
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
