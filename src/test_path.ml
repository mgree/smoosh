open Test_prelude
open Smoosh
open Os_symbolic
open Path
open Printf

let check_match_path (name, state, path, expected) =
  checker (match_path_symbolic state) (=) (name, path, expected)

let match_path_tests : (string * symbolic os_state * string * (string list)) list =
  [
    ("/ in empty", os_empty, "/", ["/"]);

    ("/ in /a", os_simple_fs, "/", ["/"]);
    ("a in /a", os_simple_fs, "a", ["a"]);
    ("/a in /a", os_simple_fs, "/a", ["/a"]);

    ("a in /a /b /c", os_complicated_fs, "a", ["a"]);
    ("* in /a /b /c", os_complicated_fs, "*", ["a"; "b"; "c"]);
    ("/b in /a /b /c", os_complicated_fs, "/b", ["/b"]);
    ("/c*/.. in /a /b /c", os_complicated_fs, "/c*/..", ["/c/.."]);
    ("/c*/../ in /a /b /c", os_complicated_fs, "/c*/../", ["/c/../"]);
    ("/c*/../c in /a /b /c", os_complicated_fs, "/c*/../c", ["/c/../c"]);

    ("/a/use*", os_complicated_fs, "/a/use*", ["/a/use"; "/a/useful"; "/a/user"]);
    ("/a//use*", os_complicated_fs, "/a//use*", ["/a//use"; "/a//useful"; "/a//user"]);
    ("/a/use*/", os_complicated_fs, "/a/use*/", ["/a/use/"; "/a/user/"]);
    ("/a/user/*", os_complicated_fs, "/a/user/*", ["/a/user/x"; "/a/user/y"]);
    ("/a/use*/*", os_complicated_fs, "/a/use*/*", ["/a/use/x"; "/a/user/x"; "/a/user/y"]);

    ("* in a",      os_complicated_fs_in_a, "*",      ["use"; "useful"; "user"]);
    ("../* in a",   os_complicated_fs_in_a, "../*",   ["../a"; "../b"; "../c"]);
    ("/* in a",     os_complicated_fs_in_a, "/*",     ["/a"; "/b"; "/c"]);
    ("./* in a",    os_complicated_fs_in_a, "./*",    ["./use"; "./useful"; "./user"]);
    ("use* in a",   os_complicated_fs_in_a, "use*",   ["use"; "useful"; "user"]);
    ("use*/ in a",  os_complicated_fs_in_a, "use*/",  ["use/"; "user/"]);
    ("user/* in a", os_complicated_fs_in_a, "user/*", ["user/x"; "user/y"]);
    ("use*/* in a", os_complicated_fs_in_a, "use*/*", ["use/x"; "user/x"; "user/y"]);

    ("/c/.f*", os_complicated_fs, "/c/.f*", ["/c/.foo"]);
    ("/c/*", os_complicated_fs, "/c/*", []);

    ("/c/[.f]*oo", os_complicated_fs, "/c/[.f]*oo", []);
    ("/c/.?oo", os_complicated_fs, "/c/.?oo", ["/c/.foo"]);
    ("/c/?foo", os_complicated_fs, "/c/?foo", []);
  ]

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  let prnt = fun (s, n) -> ("<| " ^ (printable_shell_env s) ^ "; " ^ (string_of_fields n) ^ " |>") in
  print_endline "\n=== Running path/fs tests...";
  (* core path matching tests *)
  test_part "Match path" check_match_path show_list match_path_tests test_count failed;

  printf "=== ...ran %d path/fs tests with %d failures.\n\n" !test_count !failed;
  !failed = 0
