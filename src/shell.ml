open Config
open Smoosh
open Semantics

(**********************************************************************)
(* ARGUMENT PARSING ***************************************************)       
(**********************************************************************)

type input_mode = NoFlag | SFlag | CFlag

let input_mode : input_mode ref = ref NoFlag

let opts : sh_opt list ref = ref []
let add_opt (opt : sh_opt) : unit = opts := opt::!opts
let del_opt (opt : sh_opt) : unit = opts := List.filter (fun opt' -> opt <> opt') !opts

let args : string list ref = ref []

(* TODO 2018-08-14 
   -a, -b, -C, -e, -f, -m, -n, -o option, -u, -v, and -x options are described as part of the set utility 
 *)

(* TODO 2018-09-10 need to support all of the Sh options *)
let parse_args () =
  Arg.parse
    [ "-c", Arg.Unit (fun () -> input_mode := CFlag), "set input command"
    ; "-s", Arg.Unit (fun () -> input_mode := SFlag), "set input source to STDIN"

    ; "-i", Arg.Unit (fun () -> add_opt Sh_interactive), "interactive shell"
    ; "+i", Arg.Unit (fun () -> del_opt Sh_interactive), ""

    ; "-a", Arg.Unit (fun () -> add_opt Sh_allexport), "export by default [allexport]"
    ; "+a", Arg.Unit (fun () -> del_opt Sh_allexport), ""

    ; "-b", Arg.Unit (fun () -> add_opt Sh_notify), "notify mode [notify]"
    ; "+b", Arg.Unit (fun () -> del_opt Sh_notify), ""

    ; "-C", Arg.Unit (fun () -> add_opt Sh_noclobber), "do not clobber files with > [noclobber]"
    ; "+C", Arg.Unit (fun () -> del_opt Sh_noclobber), ""

    ; "-e", Arg.Unit (fun () -> add_opt Sh_errexit), "exit on error [errexit]"
    ; "+e", Arg.Unit (fun () -> del_opt Sh_errexit), ""

    ; "-f", Arg.Unit (fun () -> add_opt Sh_noglob), "turn off pathname expansion [noglob]"
    ; "+f", Arg.Unit (fun () -> del_opt Sh_noglob), ""

    ; "-h", Arg.Unit (fun () -> add_opt Sh_earlyhash), "hash commands during function definition"
    ; "+h", Arg.Unit (fun () -> del_opt Sh_earlyhash), ""

    ; "-m", Arg.Unit (fun () -> add_opt Sh_monitor), "monitor mode [monitor]"
    ; "+m", Arg.Unit (fun () -> del_opt Sh_monitor), ""

    ; "-n", Arg.Unit (fun () -> add_opt Sh_noexec), "do not execute commands [noexec]"
    ; "+n", Arg.Unit (fun () -> del_opt Sh_noexec), ""

    ; "-u", Arg.Unit (fun () -> add_opt Sh_nounset), "error on unset parameters [nounset]"   
    ; "+u", Arg.Unit (fun () -> del_opt Sh_nounset), ""

    ; "-v", Arg.Unit (fun () -> add_opt Sh_verbose), "print input to stderr [verbose]"
    ; "+v", Arg.Unit (fun () -> del_opt Sh_verbose), ""

    ; "-x", Arg.Unit (fun () -> add_opt Sh_xtrace), "trace commands"
    ; "+x", Arg.Unit (fun () -> del_opt Sh_xtrace), ""

    ; "-o", Arg.String 
              (fun lo ->
                match sh_opt_of_longopt lo with
                | None -> raise (Arg.Bad ("unrecognized -o flag: " ^ lo))
                | Some opt -> add_opt opt), 
      "enable long format option"

    ; "+o", Arg.String 
              (fun lo ->
                match sh_opt_of_longopt lo with
                | None -> raise (Arg.Bad ("unrecognized -o flag: " ^ lo))
                | Some opt -> del_opt opt), 
      "disable long format option; individual + flags disable short options, e.g., +i turns off interactivity"
    ]
    (fun arg -> args := !args @ [arg])
    (let prog = Filename.basename Sys.executable_name in
     let flags = " [-abCefhimnuvx] [-o option]... [+abCefhimnuvx] [+o option]... " in
     prog ^ "   " ^ flags ^ "[command_file [argument...]] \n" ^
     prog ^ " -c" ^ flags ^ "[command_string [command_name [argument...]]]\n" ^
     prog ^ " -s" ^ flags ^ "[argument...]")

(* sets Dash input src, returns positional params *)
let prepare_command () : string list (* positional args *) =
  match !input_mode with
  | NoFlag -> 
     begin match !args with
     | [] -> add_opt Sh_interactive; Dash.setinputtostdin (); [Sys.argv.(0)] 
     | cmd::args -> Dash.setinputfile cmd; cmd::args
     end
  | SFlag -> Dash.setinputtostdin (); Sys.argv.(0)::!args 
  | CFlag -> 
     begin match !args with
     | [] -> failwith "Need a command after -c"
     | cmd::args' -> Dash.setinputstring cmd; args'
     end

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
    (fun cmd -> 
      real_eval_for_exit_code !last_state (command_eval (symbolic_string_of_string cmd)));
  at_exit (fun () -> 
      match List.assoc_opt 0 !System.current_traps with
      | None -> ()
      | Some cmd -> ignore (!System.real_eval_string cmd))

(* initialize's Dash env (for correct PS2, etc.); yields initial env *)
let initialize_env s0 : system os_state =
  (* will bork if we have privileges *)
  let environ = System.real_environment () in
  let set (x,v) os = 
    Dash.setvar x v;
    set_param x v os
  in
  let s0_defaults = set ("PS2","> ") (set ("PS4","+ ") s0) in
  let s1 = List.fold_right set environ s0_defaults in
  let s2 = set_param "$" (string_of_int (Unix.getpid ())) s1 in
  (* override the prompt by default *)
  let s3 = set ("PS1","$ ") s2 in
  (* set up shell options, will set up $- *)
  let s4 = List.fold_right (fun opt os -> real_set_sh_opt os opt) !opts s3 in
  { s4 with sh = { s4.sh with cwd = Unix.getcwd (); 
                              (* If a variable is initialized from the
                                 environment, it shall be marked for
                                 export immediately. *)
                              export = Pset.from_list compare (List.map fst environ) } }

let finish_up s0 =
  (* TODO 2018-08-14 trap on EXIT etc. goes here? *)
  match Os.lookup_concrete_param s0 "?" with
  | None -> failwith "BROKEN INVARIANT: missing or symbolic exit code"
  | Some s -> 
     try exit (int_of_string s)
     with Failure "int_of_string" -> failwith ("BROKEN INVARIANT: bad exit code: " ^ s)

let run_cmds s0 = 
  let ns = Dash.parse_all () in
  let cs = List.map Shim.of_node ns in
  begin
    if Pset.mem Sh_verbose s0.sh.opts
    then List.iter (fun c -> prerr_endline (string_of_stmt c)) cs
    else ()
  end;
  let run os c =
    let os' = real_eval os c in
    last_state := os';
    os'
  in
  let s1 = List.fold_left run s0 cs in
  finish_up s1

let rec repl s0 =
  (* TODO 2018-08-14 all kinds of interactive nonsense here *)
  (* no need to actually print PS1: the dash parser will do it for us *)
  match Dash.parse_next ~interactive:true () with
  | Done -> 
     if Pset.mem Sh_ignoreeof s0.sh.opts
     then 
       begin
         prerr_endline "Use \"exit\" to leave shell."; 
         repl s0
       end
     else finish_up s0
  | Error -> repl s0
  | Null -> repl s0
  | Parsed n -> 
     (* TODO 2018-08-31 record trace in a logfile *)
     let c = Shim.of_node n in
     begin 
       if Pset.mem Sh_verbose s0.sh.opts
       then prerr_endline (string_of_stmt c)
     end;
     let s1 = real_eval s0 c in
     last_state := s1;
     let set x v = 
       match try_concrete v with
       (* don't copy over special variables *)
       | Some s when not (is_special_param x) -> Dash.setvar x s 
       | _ -> ()
     in
     Pmap.iter set s1.sh.env;
     repl s1

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
  System.real_reset_tty ();
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
  let s3 =
    if is_monitoring s2
    then
      (* If the -m option is in effect, SIGTTIN, SIGTTOU, and SIGTSTP
         signals shall be ignored. *)
      List.fold_left real_ignore_signal s2 [SIGTTIN; SIGTTOU; SIGTSTP]
    else s2
  in
  last_state := s3;
  if is_interactive !last_state
  then repl !last_state
  else run_cmds !last_state
;;

main ()
