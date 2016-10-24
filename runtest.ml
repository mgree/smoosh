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
         printf "%s failed: expected %s got %s\n" name "TODO" "derp";
         incr failed)
    expansion_tests

let _ = main ();;
