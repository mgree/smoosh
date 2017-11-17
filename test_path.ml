open Test_prelude
open Fsh
open Path
open Printf

(* test_name expected got *)
type 'a result = Ok | Err of 'a err
  and 'a err = { msg : string;  expected : 'a; got : 'a }

let rec intercalate sep ss = 
  match ss with
  | [] -> ""
  | [s] -> s
  | s::ss' -> s ^ sep ^ intercalate sep ss'

let show_set set =
  "{" ^ intercalate "," (Pset.elements set) ^ "}"

let checker test_fn equal (test_name, input, expected_out) =
  let out = test_fn input in
  if equal out expected_out
  then Ok
  else Err {msg = test_name; expected = expected_out; got = out}

let check_match_path (name, state, path, expected) =
  checker (match_path state) Pset.equal (name, path, (Pset.from_list compare expected))

let match_path_tests : (string * ty_os_state * string * (string list)) list =
  [
    ("/ in empty", os_empty, "/", ["/"]);

    ("/ in /a", os_simple_fs, "/", ["/"]);
    ("a in /a", os_simple_fs, "a", ["a"]);
    ("/a in /a", os_simple_fs, "/a", ["/a"]);

    ("a in /a /b /c", os_complicated_fs, "a", ["a"]);
    ("* in /a /b /c", os_complicated_fs, "*", ["a"; "b"; "c"]);
    ("/b in /a /b /c", os_complicated_fs, "/b", ["/b"]);
    ("/c*/.. in /a /b /c", os_complicated_fs, "/c*/..", ["/c/.."]);
    (* This fails because we drop the ending / *)
    ("/c*/../ in /a /b /c", os_complicated_fs, "/c*/../", ["/c/../"]);
    ("/c*/../c in /a /b /c", os_complicated_fs, "/c*/../c", ["/c/../c"]);

    ("/a/use*", os_complicated_fs, "/a/use*", ["/a/use"; "/a/user"; "/a/useful"]);
    (* PENDING: This fails because no difference between empty dir and a file *)
    ("/a/use*/", os_complicated_fs, "/a/use*", ["/a/use/"; "/a/user/"]);
    ("/a/use*/*", os_complicated_fs, "/a/use*", ["/a/use/x"; "/a/user/x"; "a/user/y"]);

  ]

let test_part name checker stringOfExpected tests count failed =
  List.iter
    (fun t ->
      match checker t with
      | Ok -> incr count
      | Err e ->
         printf "%s test: %s failed: expected '%s' got '%s'\n"
                name e.msg (stringOfExpected e.expected) (stringOfExpected e.got);
         incr count; incr failed)
    tests

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  let prnt = fun (s, n) -> ("<| " ^ (print_shell_env s) ^ "; " ^ (Fsh.fields_to_string_crappy n) ^ " |>") in
  print_endline "\n=== Running path/fs tests...";
  (* core path matching tests *)
  test_part "Match path" check_match_path show_set match_path_tests test_count failed;

  printf "=== ...ran %d path/fs tests with %d failures.\n\n" !test_count !failed

