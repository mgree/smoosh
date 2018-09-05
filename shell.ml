open Config
open Test_prelude
open Fsh
open Semantics

(**********************************************************************)
(* ARGUMENT PARSING ***************************************************)       
(**********************************************************************)

type input_mode = NoFlag | SFlag | CFlag

let input_mode : input_mode ref = ref NoFlag

let interactive : bool ref = ref false

let args : string list ref = ref []

(* TODO 2018-08-14 
   -a, -b, -C, -e, -f, -m, -n, -o option, -u, -v, and -x options are described as part of the set utility 
 *)

let handle_arg arg = args := !args @ arg

let parse_args () =
  Arg.parse
    [ "-c", Arg.Unit (fun () -> input_mode := CFlag), "set input command"
    ; "-s", Arg.Unit (fun () -> input_mode := SFlag), "set input source to STDIN"
    ; "-i", Arg.Unit (fun () -> interactive := true), "interactive shell"
    ]
    (fun arg -> args := !args @ [arg])
    ("[command_file [argument...]]                     (no flag)\n" ^
     "[command_string [command_name [argument...]]]    (-c)\n" ^
     "[argument...]                                    (-s)")

(* sets Dash input src, returns positional params *)
let prepare_command () : string list (* positional args *) =
  match !input_mode with
  | NoFlag -> 
     begin match !args with
     | [] -> interactive := true; Dash.setinputtostdin (); [] 
     | cmd::args -> Dash.setinputfile cmd; cmd::args
     end
  | SFlag -> Dash.setinputtostdin (); Sys.argv.(0)::!args 
  | CFlag -> 
     begin match !args with
     | [] -> failwith "Need a command after -c"
     | cmd::args' -> Dash.setinputstring cmd; args'
     end

(* initialize's Dash env (for correct PS2, etc.); yields initial env *)
let initialize_env s0 : real_os_state =
  (* TODO 2018-08-23 set $- [option flags] *)
  (* will bork if we have privileges *)
  let environ = System.real_environment () in
  let set (x,v) os = 
    Dash.setvar x v;
    Os.real_set_param x v os
  in
  let s1 = List.fold_right set environ s0 in
  let s2 = Os.real_set_param "$" (string_of_int (Unix.getpid ())) s1 in
  (* override the prompt by default *)
  let s3 = Os.real_set_param "PS1" "$ " s2 in
  { s3 with real_sh = { s3.real_sh with cwd = Unix.getcwd () } }

let finish_up s0 =
  (* TODO 2018-08-14 trap on EXIT etc. goes here? *)
  match Os.real_lookup_concrete_param s0 "?" with
  | None -> failwith "BROKEN INVARIANT: missing or symbolic exit code"
  | Some s -> 
     try exit (int_of_string s)
     with Failure "int_of_string" -> failwith ("BROKEN INVARIANT: bad exit code: " ^ s)

let run_cmds s0 = 
  let ns = Dash.parse_all () in
  let cs = List.map Shim.of_node ns in
  let s1 = List.fold_right (fun c os -> real_eval os c) cs s0 in
  finish_up s1

let rec repl s0 =
  (* TODO 2018-08-14 all kinds of interactive nonsense here *)
  let prompt = 
    match real_lookup_concrete_param s0 "PS1" with
    | None -> "$ "
    | Some ps1 -> ps1
  in
  print_string prompt; flush stdout;
  (* TODO 2018-08-15 to get appropriate prompting, we need to set
     dash's actual environment up correctly, since the parser makes
     reference to ps1val, etc. *)
  match Dash.parse_next () with
  | `Done -> finish_up s0
  | `Null -> repl s0
  | `Parsed n -> 
     (* TODO 2018-08-31 record trace in a logfile *)
     let s1 = real_eval s0 (Shim.of_node n) in
     let set x v = 
       match (x,try_concrete v) with
         (* don't copy over special variables *)
       | ("?",_) -> ()
       | ("!",_) -> ()
       | ("$",_) -> ()
       | (_,None) -> ()
       | (_,Some s) -> Dash.setvar x s
     in
     Pmap.iter set s1.real_sh.env;
     repl s1

(* TODO lots of special casing at http://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html *)
let main () =
  Dash.initialize ();
  parse_args ();
  (* TODO 2018-08-14 when !interactive is true, need to look at ENV, etc. [UP: optional]

     If the shell is interactive, SIGINT signals received during
     command line editing shall be handled as described in the
     EXTENDED DESCRIPTION, and SIGINT signals received at other times
     shall be caught but no action performed.

     If the shell is interactive:

        SIGQUIT and SIGTERM signals shall be ignored.

     If the -m option is in effect, SIGTTIN, SIGTTOU, and SIGTSTP
     signals shall be ignored.

     If the -m option is not in effect, it is unspecified whether
     SIGTTIN, SIGTTOU, and SIGTSTP signals are ignored, set to the
     default action, or caught. If they are caught, the shell shall,
     in the signal-catching function, set the signal to the default
     action and raise the signal (after taking any appropriate steps,
     such as restoring terminal settings).
  *)
  let positional = prepare_command () in
  let sym_positional = List.map symbolic_string_of_string positional in
  let s0 = { Os.real_sh = { default_shell_state with 
                            positional_params = sym_positional } } in
  let s1 = initialize_env s0 in
  if !interactive
  then repl s1
  else run_cmds s1
;;

main ()
