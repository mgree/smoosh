open Config
open Smoosh
open Os_system
open Semantics

(**********************************************************************)
(* ARGUMENT PARSING ***************************************************)       
(**********************************************************************)

type input_mode = NoFlag | SFlag | CFlag of string

let input_mode : input_mode ref = ref NoFlag

let explicitly_unset_i : bool ref = ref false
let explicitly_unset_m : bool ref = ref false
let override_prompts : bool ref = ref true

let opts : sh_opt list ref = ref []
let add_opt (opt : sh_opt) : unit = opts := opt::!opts
let del_opt (opt : sh_opt) : unit =
  begin 
    match opt with
    | Sh_monitor -> explicitly_unset_m := true
    | Sh_interactive -> explicitly_unset_i := true
    | _ -> ()
  end;
  opts := List.filter (fun opt' -> opt <> opt') !opts

let params : string list ref = ref []

let implode = Dash.implode
let explode = Dash.explode

let flag_descriptions =
  [ "-c", "set input command"
  ; "-s", "set input source to STDIN"
  ; "-i", "interactive shell"  
  ; "-a", "export by default [allexport]"
  ; "-b", "notify mode [-o notify]"
  ; "-C", "do not clobber files with > [-o noclobber]"
  ; "-e", "exit on error [-o errexit]"
  ; "-f", "turn off pathname expansion [-o noglob]"
  ; "-h", "hash commands during function definition"
  ; "-m", "monitor mode [-o monitor]"
  ; "-n", "do not execute commands [noexec]"
  ; "-p", "do not override PS1 and PS2 (not in the POSIX spec)"
  ; "-u", "error on unset parameters [nounset]"   
  ; "-v", "print input to stderr [verbose]"
  ; "-x", "trace commands"
  ; "-o", "enable long format option"
  ; "+o", "disable long format option"
  ]
            
let usage_msg =
  let prog = Filename.basename Sys.executable_name in
  let flags = " [-abCefhimnpuvx] [-o option]... [+abCefhimnpuvx] [+o option]... " in
  "smoosh shell v" ^ Config.version ^ "\n" ^
  prog ^ "   " ^ flags ^ "[command_file [argument...]] \n" ^
  prog ^ " -c" ^ flags ^ "[command_string [command_name [argument...]]]\n" ^
  prog ^ " -s" ^ flags ^ "[argument...]\n\n" ^
  "flags:\n\t-[flag] enables, +[flag] disables\n" ^
  concat "" (List.map (fun (flag, descr) -> Printf.sprintf "\t%s\t%s\n" flag descr) flag_descriptions)

let show_usage () =
  prerr_string usage_msg;
  exit 2
  
let bad_arg msg =
  (* TODO 2018-11-01 show usage *)
  Printf.eprintf "bad argument: %s\n" msg;
  show_usage ()
  
let rec parse_arg_loop args =
  match args with
  | [] -> ()
  | arg::args' ->
     let parse_longopt handler =
       match args' with
       | [] -> bad_arg ("missing option after " ^ arg)
       | lo::args'' -> 
          begin
            match sh_opt_of_longopt lo with
            | None -> bad_arg ("unrecognized " ^ arg ^ " flag: " ^ lo)
            | Some sh_opt -> handler sh_opt; parse_arg_loop args''
          end in
     let rec parse_shortopts handler opts =
       match opts with
       | [] -> parse_arg_loop args'
       | opt::opts' ->
          begin
            match (opt, sh_opt_of_shortopt opt) with
            | ('p', _) -> override_prompts := false
            | ('i', _) -> handler Sh_interactive
            | (_, Some sh_opt) -> handler sh_opt
            | (_, None) -> bad_arg (Printf.sprintf "unknown flag '%c' in %s" opt arg)
          end;
          parse_shortopts handler opts'
     in
     match explode arg with
     | ['-'; '-'] -> params := args'
     | ['-'; '-'; 'h'; 'e'; 'l'; 'p'] -> show_usage ()
     | ['-'; 'o'] -> parse_longopt add_opt
     | ['+'; 'o'] -> parse_longopt del_opt
     (* special case for when no options after---treat as normal args *)
     | ['-']      -> params := args
     | ['+']      -> params := args
     | ['-'; 'c'] -> 
        begin
          match args' with
          | [] -> bad_arg "Need a command after -c"
          | cmd::args'' -> input_mode := CFlag cmd; parse_arg_loop args''
        end
     | ['-'; 's'] -> input_mode := SFlag; parse_arg_loop args'
     | '-'::opts  -> parse_shortopts add_opt opts
     | '+'::opts  -> parse_shortopts del_opt opts
     | _          -> params := args
        
let parse_args () =
  let args =
    match Array.to_list Sys.argv with
    | [] -> []
    | _::argv -> argv
  in
  parse_arg_loop args

(* sets Dash input src, returns positional params *)
let prepare_command () : string list (* positional args *) =
  match !input_mode with
  | NoFlag -> 
     begin match !params with
     | [] -> 
        if not !explicitly_unset_i then add_opt Sh_interactive; 
        Dash.setinputtostdin (); [Sys.argv.(0)] 
     | cmd::args -> Dash.setinputfile cmd; cmd::args
     end
  | SFlag -> Dash.setinputtostdin (); Sys.argv.(0)::!params
  | CFlag cmd -> Dash.setinputstring cmd; cmd::!params

let set_param x v s0 =
  Os.internal_set_param x (symbolic_string_of_string v) s0

(* track the last shell state---used for signal handling, at_exit *)
let last_state = 
  ref { Os.sh = { default_shell_state with rootpid = Unix.getpid () }; 
        Os.log = []; 
        Os.fuel = None; (* unbounded *)
        Os.symbolic = (); }

let setup_handlers () =
  System.real_eval := 
    (fun os stmt -> real_eval_for_exit_code (Obj.magic os) (Obj.magic stmt));
  System.real_eval_string := 
    (fun os cmd -> 
      real_eval_for_exit_code (Obj.magic os) (command_eval (symbolic_string_of_string cmd)))

(* initialize's Dash env (for correct PS2, etc.); yields initial env *)
let initialize_env s0 : system os_state =
  (* will bork if we have privileges *)
  let environ = System.real_environment () in
  let set (x,v) os = 
    Dash.setvar x v;
    set_param x v os
  in
  let s1 = List.fold_right set environ s0 in
  let s2 = 
    if !override_prompts
    then set ("PS1","$ ") (set ("PS2","> ") (set ("PS4","+ ") s1))
    else s1
  in
  let s3 = set_param "$" (string_of_int (Unix.getpid ())) s2 in
  (* override the prompt by default *)
  (* set up shell options, will set up $- *)
  let s4 = List.fold_right (fun opt os -> real_set_sh_opt os opt) !opts s3 in
  { s4 with sh = { s4.sh with cwd = Unix.getcwd (); 
                              (* If a variable is initialized from the
                                 environment, it shall be marked for
                                 export immediately. *)
                              export = Pset.from_list compare (List.map fst environ) } }

let run os c =
  let os' = real_eval os c in
  last_state := os';
  os'

let run_cmds s0 = 
  let s1 = run s0 (EvalLoop (1, ParseFile "<STDIN>", 
                             is_interactive s0, true (* top level *))) in
  ignore (run s1 Exit)

let rec repl s0 =
  (* update job list *)
  let (s1, changed) = real_update_jobs s0 in
  let s2 = Command.show_changed_jobs s1 changed in
  let s3 = List.fold_left real_delete_job s2 changed in
  (* no need to actually print PS1: the dash parser will do it for us *)
  match Dash.parse_next ~interactive:true () with
  | Done -> 
     if Pset.mem Sh_ignoreeof s3.sh.opts
     then 
       begin
         prerr_endline "Use \"exit\" to leave shell."; 
         repl s3
       end
     else ignore (real_eval s3 Exit)
  | Error -> repl s3
  | Null -> repl s3
  | Parsed n -> 
     (* TODO 2018-08-31 record trace in a logfile *)
     let c = Shim.of_node n in
     begin 
       if Pset.mem Sh_verbose s3.sh.opts
       then prerr_endline (string_of_stmt c)
     end;
     let s4 = run s3 c in
     let set x v = 
       match try_concrete v with
       (* don't copy over special variables *)
       | Some s when not (is_special_param x) -> Dash.setvar x s 
       | _ -> ()
     in
     Pmap.iter set s4.sh.env;
     repl s4

(* TODO lots of special casing at http://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html *)
let main () =
  Dash.initialize ();
  setup_handlers ();
  parse_args ();
  (* TODO 2018-08-14 need to look at ENV, etc. [UP: optional]

     If the shell is interactive, SIGINT signals received during
     command line editing shall be handled as described in the
     EXTENDED DESCRIPTION, and SIGINT signals received at other times
     shall be caught but no action performed.
  *)
  (* System.real_reset_tty (); *)
  let positional = prepare_command () in
  let sym_positional = List.map symbolic_string_of_string positional in
  let s0 = { !last_state with 
             Os.sh = { !last_state.Os.sh with 
                       positional_params = sym_positional } } in
  let s1 = initialize_env s0 in
  let s2 =
    if is_interactive s1 
    then
      (* If the shell is interactive: 
          - SIGQUIT and SIGTERM signals shall be ignored
          - SIGINT is caught so that wait is interruptible
       *)
      begin
        Sys.set_signal Sys.sigint (Signal_handle (fun _ -> repl !last_state));
        List.fold_left real_ignore_signal s1 [SIGTERM; SIGQUIT]
      end
    else s1 
  in
  (* [from sh description, about -m]
     This option is enabled by default for interactive shells. *)
  let s3 = 
    if is_interactive s2 && not !explicitly_unset_m
    then real_set_sh_opt s2 Sh_monitor
    else s2
  in
  last_state := s3;
  if is_interactive !last_state
  then repl !last_state
  else run_cmds !last_state
;;

main ()
