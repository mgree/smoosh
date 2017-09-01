open Test_prelude
open Shim
open Fsh
open Expansion
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
    initial_os_state := set_param name escaped !initial_os_state
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
(* TRACING ************************************************************)
(**********************************************************************)

type state = ty_os_state * 
             [ `Start of words 
             | `Expand of expanded_words * words 
             | `Split of expanded_words 
             | `Done of fields]

let rec step_expansion ((os0,s0) : state) : state =
  match s0 with
  | `Start w0 -> 
     let (os1, f1, w1) = expand_words os0 Unquoted UserString ([],w0) in
     (os1, `Expand (f1,w1))
  | `Expand (f0,w0) ->
     let (os1, f1, w1) = expand_words os0 Unquoted UserString (f0,w0) in
     begin 
       match w1 with
       | [] -> (os1, `Split f1)
       | _ ->  (os1, `Expand (f1,w1))
     end
  | `Split f0 ->
     (os0, `Done (quote_removal os0 (pathname_expansion os0 (field_splitting os0 f0))))
  | `Done f -> (os0,s0)
       
let trace_expansion (init : state) : state list =
  let rec loop (st0 : state) (acc : state list) : state list =
    match st0 with
      | (_, `Done _) -> List.rev (st0::acc)
      | _ -> let st1 = step_expansion st0 in
             loop st1 (st0::acc)
  in loop init []

let trace_command os = function
  | Command ([],ws,[]) -> trace_expansion (os, `Start ws)
  | _ -> failwith "unsupported command type (don't use keywords, etc.)"

(**********************************************************************)
(* OUTPUT *************************************************************)
(**********************************************************************)

let json_of_state_term = function
  | `Start w -> obj_w "Start" w
  | `Expand (f,w) -> obj_fw "Expand" f w
  | `Split f -> obj_f "Split" f
  | `Done fs -> Assoc [tag "Done"; ("fields", json_of_fields fs)]

let json_of_env (env:(string, string) Pmap.map) : json =
  Assoc (List.map (fun (k,v) -> (k, String v)) (Pmap.bindings_list env))

let json_of_state ((os,tm):state) : json =
  Assoc [("env", json_of_env os.shell_env); ("term", json_of_state_term tm)]

let show_trace trace =
  let tracej = List.map json_of_state trace in
  let out = Buffer.create (List.length tracej * 100) in
  begin
    write_json out (List tracej);
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
  let traces = List.map (trace_command !initial_os_state) cs in
  List.iter show_trace traces;;  

main ()

           
