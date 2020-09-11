open Os_system
open Semantics

(**********************************************************************)
(* Simple AST generation using Morbig *********************************)       
(**********************************************************************)

(* Reads in 1 line of shell command, spits out the internal AST *)
let print_parse_result (pr : Smoosh.parse_result) = 
  match (pr : Smoosh.parse_result) with
| Smoosh.ParseDone -> print_endline "ParseDone"
| Smoosh.ParseError e -> print_endline @@ "Error: " ^ e
| Smoosh.ParseNull -> print_endline "Null"
| Smoosh.ParseStmt s -> print_endline "Stmt"

let main () = 
  print_endline "Hello world";
  let test_cmd = "echo hello" in
  let parse_result = Smoosh.parse_string_morbig test_cmd in
  print_parse_result parse_result
;;

main ()