let lexer_state  = (Morbig__ExtPervasives.lexing_make_interactive "STDIN") in
let pid = Unix.fork () in
let on_ps2 = fun () -> Printf.eprintf "PS2%!" in
if pid == 0 then
  let res = Morbig.parse_string_interactive on_ps2 lexer_state None in
  print_endline "Child"
else
  print_endline "Parent"
