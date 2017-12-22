open Test_prelude
open Shim
open Fsh
open Semantics
open Printf

(**********************************************************************)
(* config/arg parsing *************************************************)       
(**********************************************************************)
       
let version = "0.1"

let verbose = ref false
let input_src : string option ref = ref None
let initial_os_state : ty_os_state ref = ref os_empty
                                             
let set_input_src () =
  match !input_src with
  | None -> Dash.setinputtostdin ()
  | Some f -> Dash.setinputfile f

let parse_keqv s = 
  let eq = String.index s '=' in
  let k = String.sub s 0 eq in
  let v = String.sub s (eq+1) (String.length s - eq - 1) in
  (k,v)

let parse_entry (unescape:bool) (s:string) =
  let (name,value) = parse_keqv s in
  try
    let escaped =
      try if unescape then Scanf.unescaped value else value
      with Scanf.Scan_failure _ -> eprintf "Environment parse error: couldn't handle escapes in %s, leaving as-is" s; value
    in
    initial_os_state := add_literal_env_string name escaped !initial_os_state
  with Not_found -> eprintf "Environment parse error: couldn't find an '=' in %s" s

let load_env (f:string) =
  let rec go (ic:in_channel) =
    try
      parse_entry true (input_line ic);
      go ic
    with End_of_file -> close_in ic
  in
  go (open_in f)

let ambient_env () = 
  List.iter (parse_entry false) (Array.to_list (Unix.environment ()))

let parse_user (s:string) =
  try
    let (name,value) = parse_keqv s in
    initial_os_state := set_pwdir name value !initial_os_state
  with Not_found -> eprintf "Environment parse error: couldn't find an '=' in %s" s

let load_dirs (f:string) = 
  let rec go (ic:in_channel) =
    try
      parse_user (input_line ic);
      go ic
    with End_of_file -> close_in ic
  in
  go (open_in f)

let parse_args () =
  Arg.parse
    ["-v",Arg.Set verbose,"verbose mode";
     "-env-file",Arg.String load_env,"file containing environment (one var=value per line; no need for quotes)";
     "-env-ambient",Arg.Unit ambient_env,"use the ambient environment";
     "-user-file",Arg.String load_dirs,"file containing username/directory pairings for tilde expansion (one username=dir per line)"
    ]
    (function | "-" -> input_src := None | f -> input_src := Some f)
    "Final argument should be either a filename or - (for STDIN); only the last such argument is used"

(**********************************************************************)
(* OUTPUT *************************************************************)
(**********************************************************************)

let show_trace trace =
  let out = Buffer.create (List.length trace * 250) in
  begin
    write_json out (json_of_trace trace);
    Buffer.output_buffer stdout out
  end

(**********************************************************************)
(* DRIVER *************************************************************)
(**********************************************************************)

let main () =
  Dash.initialize ();
  parse_args ();
  set_input_src ();
  let ns = Dash.parse_all () in
  let cs = List.map Shim.of_node ns in
  show_trace (trace_evaluation_multi !initial_os_state cs);;

main ()

