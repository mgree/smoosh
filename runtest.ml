open Tests
open Printf

let rec list_to_string = function		
[] -> ""		
| [f] -> f		
| f::l -> f ^ "<<FS>>" ^ (list_to_string l)

let main () =
  let failed = ref 0 in
  print_endline "=== Running tests...";
  List.iter
    (fun t ->
      match check_expansion t with
      | Ok -> ()
      | RErr(name,expected,got) ->
         printf "%s failed: expected '%s' got '%s'\n"
                name (list_to_string expected) (list_to_string got);
         incr failed)
    expansion_tests;
  printf "=== ...ran %d tests with %d failures.\n" (List.length expansion_tests) !failed

let _ = main ();;
