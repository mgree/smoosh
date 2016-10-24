open Test
open Printf

let main () =
  let failed = ref 0 in
  print_endline "=== Running tests...";
  List.iter
    (fun t ->
      match check_expansion t with
      | Ok -> ()
      | RErr(name,expected,got) ->
         printf "%s failed: expected %s got %s\n"
                name (Expansion.string_of_words expected) (Expansion.string_of_words got);
         incr failed)
    expansion_tests;
  printf "=== ...ran %d tests with %d failures." (List.length expansion_tests) !failed

let _ = main ();;
