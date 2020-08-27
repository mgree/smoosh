open Ctypes
open Foreign
open Dash
open Smoosh_prelude

exception ParseException of string

let skip = Command ([],[],[], default_cmd_opts )

let var_type vstype w = 
  match vstype with
 | 0x00 -> (* VSNORMAL ${var} *) Normal
 | 0x02 -> (* VSMINUS ${var-text} *) Default w
 | 0x12 -> (* VSMINUS ${var:-text} *) NDefault w
 | 0x03 -> (* VSPLUS ${var+text} *) Alt w
 | 0x13 -> (* VSPLUS ${var:+text} *) NAlt w
 | 0x04 -> (* VSQUESTION ${var?message} *) Error w
 | 0x14 -> (* VSQUESTION ${var:?message} *) NError w
 | 0x05 -> (* VSASSIGN ${var=text} *) Assign w
 | 0x15 -> (* VSASSIGN ${var:=text} *) NAssign w
 | 0x06 -> (* VSTRIMRIGHT ${var%pattern} *) Substring (Suffix,Shortest,w)
 | 0x07 -> (* VSTRIMRIGHTMAX ${var%%pattern} *) Substring (Suffix,Longest,w)
 | 0x08 -> (* VSTRIMLEFT ${var#pattern} *) Substring (Prefix,Shortest,w)
 | 0x09 -> (* VSTRIMLEFTMAX ${var##pattern} *) Substring (Prefix,Longest,w)
 | 0x0a -> (* VSLENGTH ${#var}) *) Length
 | vs -> failwith ("Unknown VSTYPE: " ^ string_of_int vs)

let rec join (ws:words list) : words =
  match ws with
  | [] -> []
  | [w] -> w
  | []::ws -> join ws
  | w1::w2::ws -> w1 @ [F] @ join (w2::ws)

let rec of_node (n : node union ptr) : stmt =
  if nullptr n
  then skip
  else
  match (n @-> node_type) with
  (* NCMD *)
  | 0  ->
     let n = n @-> node_ncmd in
     Command (to_assigns (getf n ncmd_assign),
              join (to_args (getf n ncmd_args)),
              redirs (getf n ncmd_redirect),
              default_cmd_opts)
  (* NPIPE *)
  | 1 ->
     let n = n @-> node_npipe in
     let bg_mode = if getf n npipe_backgnd <> 0 then BG else FG in
     Pipe (bg_mode,
           List.map of_node (nodelist (getf n npipe_cmdlist)))
  (* NREDIR *)
  | 2  -> let (c,redirs) = of_nredir n in Redir (c,redirs)
  (* NBACKGND *)
  | 3  -> let (c,redirs) = of_nredir n in
          begin match c with
          | Subshell (c, redirs') -> Background (c, combine_redirs redirs redirs')
          | _ -> Background (c,redirs)
          end
  (* NSUBSHELL *)
  | 4  -> let (c,redirs) = of_nredir n in Subshell (c,redirs)
  (* NAND *)
  | 5  -> let (l,r) = of_binary n in And (l,r)
  (* NOR *)
  | 6  -> let (l,r) = of_binary n in Or (l,r)
  (* NSEMI *)
  | 7  -> let (l,r) = of_binary n in Semi (l,r)
  (* NIF *)
  | 8  ->
     let n = n @-> node_nif in
     If (of_node (getf n nif_test),
         of_node (getf n nif_ifpart),
         of_node (getf n nif_elsepart))
  (* NWHILE *)
  | 9  -> let (t,b) = of_binary n in While (t,b)
  (* NUNTIL *)
  | 10 -> let (t,b) = of_binary n in While (Not t,b)
  (* NFOR *)
  | 11 ->
     let n = n @-> node_nfor in
     For (getf n nfor_var,
          join (to_args (getf n nfor_args)),
          of_node (getf n nfor_body))
  (* NCASE *)
  | 12 ->
     let n = n @-> node_ncase in
     Case (to_arg (getf n ncase_expr @-> node_narg),
           List.map
             (fun (pattern,body) -> (to_args pattern, of_node body))
             (caselist (getf n ncase_cases)))
  (* NDEFUN *)
  | 14 ->
     let n = n @-> node_ndefun in
     Defun (getf n ndefun_text,
            of_node (getf n ndefun_body))
  (* NNOT *)
  | 25 -> Not (of_node (getf (n @-> node_nnot) nnot_com))
  | nt -> failwith ("Unexpected top level node_type " ^ string_of_int nt)

and of_nredir (n : node union ptr) =
  let n = n @-> node_nredir in
  (of_node (getf n nredir_n), ([], None, redirs (getf n nredir_redirect)))

and redirs (n : node union ptr) =
  if nullptr n
  then []
  else
    let mk_file ty =
      let n = n @-> node_nfile in
      RFile (ty,getf n nfile_fd,to_arg (getf n nfile_fname @-> node_narg)) in
    let mk_dup ty =
      let n = n @-> node_ndup in
      let src = getf n ndup_fd in
      let vname = getf n ndup_vname in
      let tgt =
        if nullptr vname
        then let dupfd = getf n ndup_dupfd in
             if dupfd = -1
             then [S "-"]
             else [S (string_of_int (getf n ndup_dupfd))]
        else to_arg (vname @-> node_narg)
      in
      RDup (ty,src,tgt) in
    let mk_here ty =
      let n = n @-> node_nhere in
      RHeredoc (ty,getf n nhere_fd,to_arg (getf n nhere_doc @-> node_narg)) in
    let h = match n @-> node_type with
      (* NTO *)
      | 16 -> mk_file To
      (* NCLOBBER *)
      | 17 -> mk_file Clobber
      (* NFROM *)
      | 18 -> mk_file From
      (* NFROMTO *)
      | 19 -> mk_file FromTo
      (* NAPPEND *)
      | 20 -> mk_file Append
      (* NTOFD *)      
      | 21 -> mk_dup ToFD
      (* NFROMFD *)              
      | 22 -> mk_dup FromFD
      (* NHERE quoted heredoc---no expansion)*)
      | 23 -> mk_here Here
      (* NXHERE unquoted heredoc (param/command/arith expansion) *)
      | 24 -> mk_here XHere
      | nt -> failwith ("unexpected node_type in redirlist: " ^ string_of_int nt)
    in
    h :: redirs (getf (n @-> node_nfile) nfile_next)

and of_binary (n : node union ptr) =
  let n = n @-> node_nbinary in
  (of_node (getf n nbinary_ch1), of_node (getf n nbinary_ch2))

and to_arg (n : narg structure) : words =
  let a,s,bqlist,stack = parse_arg ~tilde_ok:true ~assign:false (explode (getf n narg_text)) (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s = []);
  assert (nullptr bqlist);
  assert (stack = []);
  a  

and to_assign (n : narg structure) : (string * words) =
  let (v,t) = extract_assign [] (explode (getf n narg_text)) in
  let a,s,bqlist,stack = parse_arg ~tilde_ok:true ~assign:true t (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s = []);
  assert (nullptr bqlist);
  assert (stack = []);
  (v,a)
  
and in_quote stack =
  match stack with
  | [] -> false
  | `CTLQuo::_ -> true
  | _::stack' -> in_quote stack'

and parse_arg ?tilde_ok:(tilde_ok=false) ~assign:(assign:bool) 
              (s : char list) (bqlist : nodelist structure ptr) stack =
  match s,stack with
  | [],[] -> [],[],bqlist,[]
  | [],`CTLVar::_ -> failwith "End of string before CTLENDVAR"
  | [],`CTLAri::_ -> failwith "End of string before CTLENDARI"
  | [],`CTLQuo::_ -> failwith "End of string before CTLQUOTEMARK"
  (* CTLESC *)
  | '\129'::_ as s,_ -> 
     let (str,s') = parse_string [] (in_quote stack) s in
     arg_char assign (S (implode str)) s' bqlist stack
  (* CTLVAR *)
  | '\130'::t::s,_ ->
     let var_name,s = Dash.split_at (fun c -> c = '=') s in
     let t = int_of_char t in
     let v,s,bqlist,stack = match t land 0x1f, s with
     (* VSNORMAL and VSLENGTH get special treatment

     neither ever gets VSNUL
     VSNORMAL is terminated just with the =, without a CTLENDVAR *)
     (* VSNORMAL *)
     | 0x01,'='::s ->
        K (Param (implode var_name, Normal)),s,bqlist,stack
     (* VSLENGTH *)
     | 0x0a,'='::'\131'::s ->
        K (Param (implode var_name, Length)),s,bqlist,stack
     | 0x01,c::_ | 0xa,c::_ ->
        failwith ("Missing CTLENDVAR for VSNORMAL/VSLENGTH, found " ^ Char.escaped c)
     (* every other VSTYPE takes mods before CTLENDVAR *)
     | vstype,'='::s ->
        let w,s,bqlist,stack' = parse_arg ~tilde_ok:true ~assign s bqlist (`CTLVar::stack) in
        K (Param (implode var_name, var_type vstype w)), s, bqlist, stack'
     | _,c::_ -> failwith ("Expected '=' terminating variable name, found " ^ Char.escaped c)
     | _,[] -> failwith "Expected '=' terminating variable name, found EOF"
     in
     arg_char assign v s bqlist stack
  | '\130'::_, _ -> raise (ParseException "bad substitution")
  (* CTLENDVAR *)
  | '\131'::s,`CTLVar::stack' -> [],s,bqlist,stack'
  | '\131'::_,`CTLAri::_ -> failwith "Saw CTLENDVAR before CTLENDARI"
  | '\131'::_,`CTLQuo::_ -> failwith "Saw CTLENDVAR before CTLQUOTEMARK"
  | '\131'::_,[] -> failwith "Saw CTLENDVAR outside of CTLVAR"
  (* CTLBACKQ *)
  | '\132'::s,_ ->
     if nullptr bqlist
     then failwith "Saw CTLBACKQ but bqlist was null"
     else arg_char assign (K (Backtick (of_node (bqlist @-> nodelist_n)))) s (bqlist @-> nodelist_next) stack
  (* CTLARI *)
  | '\134'::s,_ ->
     let a,s,bqlist,stack' = parse_arg ~assign s bqlist (`CTLAri::stack) in
     assert (stack = stack');
     arg_char assign (K (Arith ([],a))) s bqlist stack'
  (* CTLENDARI *)
  | '\135'::s,`CTLAri::stack' -> [],s,bqlist,stack'
  | '\135'::_,`CTLVar::_' -> failwith "Saw CTLENDARI before CTLENDVAR"
  | '\135'::_,`CTLQuo::_' -> failwith "Saw CTLENDARI before CTLQUOTEMARK"
  | '\135'::_,[] -> failwith "Saw CTLENDARI outside of CTLARI"
  (* CTLQUOTEMARK *)
  | '\136'::s,`CTLQuo::stack' -> [],s,bqlist,stack'
  | '\136'::s,_ ->
     let a,s,bqlist,stack' = parse_arg ~assign s bqlist (`CTLQuo::stack) in
     assert (stack' = stack);
     arg_char assign (K (Quote ([],a))) s bqlist stack'
  (* tildes: only when tilde_ok *)
  | '~'::s,stack ->
     if (* we're not the first character in the word *)
        not tilde_ok || 
        (* we're in arithmetic or double quotes, so tilde is ignored *)
        List.exists (fun m -> m = `CTLQuo || m = `CTLAri) stack
     then
       arg_char assign (S "~") s bqlist stack
     else
       begin match parse_tilde assign [] s with
       | None -> arg_char assign (S "~") s bqlist stack
       | Some (prefix, s') -> arg_char assign (K (Tilde prefix)) s' bqlist stack
       end
  (* ordinary character *)
  | _::_,_ -> 
     let (str,s') = parse_string [] (in_quote stack) s in
     arg_char assign (S (implode str)) s' bqlist stack

and parse_tilde assign acc = 
  let ret s = Some (implode (List.rev acc), s) in
  function
  (* terminal: end-of-string, CTLENDVAR, CTLENDARI, /, : (in assignments) *)
  | [] -> ret []
  | '\131'::_ as s -> ret s (* CTLENDVAR *)
  | '\135'::_ as s -> ret s (* CTLENDARI *)
  | ':'::_ as s when assign -> ret s
  | '/'::_ as s -> ret s
  (* CTLESC *)
  | '\129'::c::s' -> parse_tilde assign (c::acc) s'
  (* other control codes, e.g., quotes, interrupt a tilde *)
  | '\130'::_ as s -> None
  | '\132'::_ as s -> None
  | '\134'::_ as s -> None
  | '\136'::_ as s -> None
  (* ordinary char *)
  | c::s' -> parse_tilde assign (c::acc) s'  

and parse_string acc quoted = function
  | [] -> List.rev acc, []
  | '\130'::_ as s -> List.rev acc, s
  | '\131'::_ as s -> List.rev acc, s
  | '\132'::_ as s -> List.rev acc, s
  | '\134'::_ as s -> List.rev acc, s
  | '\135'::_ as s -> List.rev acc, s
  | '\136'::_ as s -> List.rev acc, s
  | '~'   ::_ as s -> List.rev acc, s
  | '\129'::'\\'::'\129'::c::s when quoted ->
     let c' = ['\\'; c] in
     parse_string (List.rev c' @ acc) quoted s
  | '\129'::c::s  -> 
     let c' =
       match c with
       | '*' when not quoted -> ['\\'; c]
       | '?' when not quoted -> ['\\'; c]
       | '[' when not quoted -> ['\\'; c]
       | _   -> [c]
     in
     parse_string (List.rev c' @ acc) quoted s
  | c::s -> parse_string (c::acc) quoted s
              
and arg_char assign c s bqlist stack =
  let tilde_ok = 
    match c with
    | S "" -> false
    | S s -> assign && String.get s (String.length s - 1) = ':'
    | _ -> false
  in
  let a,s,bqlist,stack = parse_arg ~tilde_ok ~assign s bqlist stack in
  (c::a,s,bqlist,stack)

and extract_assign v = function
  | [] -> failwith ("Never found an '=' sign in assignment, got " ^ implode (List.rev v))
  | '=' :: a -> (implode (List.rev v),a)
  | '\129'::_ -> failwith "Unexpected CTLESC in variable name"
  | '\130'::_ -> failwith "Unexpected CTLVAR in variable name"
  | '\131'::_ -> failwith "Unexpected CTLENDVAR in variable name"
  | '\132'::_ -> failwith "Unexpected CTLBACKQ in variable name"
  | '\133'::_ -> failwith "Unexpected CTL??? in variable name"
  | '\134'::_ -> failwith "Unexpected CTLARI in variable name"
  | '\135'::_ -> failwith "Unexpected CTLENDARI in variable name"
  | '\136'::_ -> failwith "Unexpected CTLQUOTEMARK in variable name"
  | c :: a ->
     extract_assign (c::v) a

and to_assigns n = 
  if nullptr n
  then [] 
  else (assert (n @-> node_type = 15);
        let n = n @-> node_narg in
        to_assign n::to_assigns (getf n narg_next))
    
and to_args (n : node union ptr) : words list =
  if nullptr n
  then [] 
  else (assert (n @-> node_type = 15);
        let n = n @-> node_narg in
        to_arg n::to_args (getf n narg_next))

(***********************************************************************)
(* Incremental parsing *************************************************)
(* Protocol: 
 *
 *   parse_init (parse_next* parse_done)
 *
 * ParseDone and ParseError mean you're done, and should stop calling parse_next.
 * ParseNull represents an empty line. ParseStmt is a successfully parsed line.
 *
 * The parse_string function is a convenience for testing. parse_done will be
 * called for you when you evaluate the resulting command.
 *
 * See smoosh.lem for the definition of parse_source and parse_result.
 *
 * It's critical that set_ps1 and set_ps2 be called whenever those prompts are 
 * updated---parsers do the prompting themselves.
 *
 * ??? It may or may not be a problem to call parse_done before you're done.
 *
 * ??? 2018-11-14 interrupts during parsing? hopefully handled after any forking?
 *
 *)

let bad_file file msg =
  let prog = Filename.basename Sys.executable_name in
  Printf.eprintf "%s: file '%s' %s\n%!" prog file msg;
  exit 3

let parse_init src =
  match src with
  | ParseSTDIN -> Dash.setinputtostdin (); None
  | ParseString (_, cmd) ->
     let ss = Dash.alloc_stack_string cmd in
     Dash.setinputstring ss;
     Some ss
  | ParseFile (file, push) -> 
     if not (Sys.file_exists file)
     then bad_file file "not found"
     else try 
         Unix.access file [Unix.F_OK; Unix.R_OK];
         Dash.setinputfile ~push:(should_push_file push) file; 
         None
       with Unix.Unix_error(_,_,_) -> bad_file file "unreadable"

let parse_done m_ss m_smark =
  begin
    match m_smark with
    | None -> ()
    | Some ms -> Dash.pop_stack ms
  end;
  Dash.popfile ();
  begin
    match m_ss with
    | None -> ()
    | Some ss -> Dash.free_stack_string ss
  end

let parse_next i : parse_result =
  let stackmark = Dash.init_stack () in
  let res =
    match Dash.parse_next ~interactive:(is_interactive_mode i) () with
    | Done -> ParseDone
    | Error -> ParseError ""
    | Null -> ParseNull
    | Parsed n ->
       try
         let c = of_node n in
         ParseStmt c
       with ParseException s ->
         ParseError (Printf.sprintf "%s: %s\n" (Filename.basename Sys.executable_name) s)
  in
  Dash.pop_stack stackmark;
  res

let parse_string cmd =
  let src = ParseString (ParseEval, cmd) in
  let sstr = parse_init src in
  let stackmark = Dash.init_stack () in
  Semi
    (EvalLoop (1, (sstr, Some stackmark), src,
               Noninteractive, Subsidiary (* not top level, will call parse_done *)),
     Exit)

let dash_setvar x v = 
  match try_concrete v with
  (* don't copy over special variables *)
  | Some s when not (is_special_param x) -> Dash.setvar x s 
  | _ -> ()

(************************************************************************)
(* JSON rendering *******************************************************)
(************************************************************************)
  
(* we don't need anything else, I think---just a tiny bit of JSON *)
type json = String of string
          | Bool of bool
          | Int of int
          | List of json list 
          | Assoc of (string * json) list 

let rec write_json (buf : Buffer.t) = 
  let rec intercalate op sep = function
    | [] -> ()
    | [x] -> op x
    | x::xs -> op x; sep (); intercalate op sep xs in
  let comma () = Buffer.add_char buf ',' in
  let comma_nl () = (Buffer.add_char buf ','; Buffer.add_char buf '\n') in
  function
  | String s -> 
     Buffer.add_char buf '"';
     Buffer.add_string buf (String.escaped s);
     Buffer.add_char buf '"'
  | Bool b ->
     Buffer.add_string buf (if b then "true" else "false")
  | Int n ->
     Buffer.add_string buf (string_of_int n)
  | List l ->
     Buffer.add_char buf '[';
     intercalate (write_json buf) comma_nl l;
     Buffer.add_char buf ']'
  | Assoc m ->
     Buffer.add_char buf '{';
     let pair (k,v) = write_json buf (String k); Buffer.add_char buf ':'; write_json buf v in
     intercalate pair comma m;
     Buffer.add_char buf '}'

let tag name = ("tag", String name)

let obj name = Assoc [tag name]
let obj_v name v = Assoc [tag name; ("v", String v)]

let rec json_of_stmt = function
  | Command (assigns, args, rs, _opts) -> 
     Assoc [tag "Command"; 
            ("assigns", List (List.map json_of_assign assigns));
            ("args", json_of_words args);
            ("rs", json_of_redirs rs)]
  | CommandExpArgs (assigns, args, rs, _opts) ->
     Assoc [tag "CommandExpArgs"; 
            ("assigns", List (List.map json_of_assign assigns));
            ("args", json_of_expansion_state args);
            ("rs", json_of_redirs rs)]
  | CommandExpRedirs (assigns, args, redir_state, _opts) ->
     Assoc ([tag "CommandExpRedirs"; 
             ("assigns", List (List.map json_of_assign assigns));
             ("args", json_of_fields args)]
            @ fields_of_redir_state redir_state)
  | CommandExpAssign (assigns, args, saved_fds, _opts) -> 
     Assoc [tag "CommandExpAssign"; 
            ("assigns", List (List.map json_of_inprogress_assign assigns));
            ("args", json_of_fields args);
            ("saved_fds", json_of_saved_fds saved_fds)]
  | CommandReady (assigns, cmd, args, saved_fds, _opts) -> 
     Assoc [tag "CommandReady"; 
            ("assigns", List (List.map json_of_expanded_assign assigns));
            ("args", json_of_fields (cmd::args));
            ("saved_fds", json_of_saved_fds saved_fds)]
  | Pipe (mode, cs) -> 
     Assoc [tag "Pipe"; ("bg", Bool (is_bg mode)); ("cs", List (List.map json_of_stmt cs))]
  | Redir (c, redir_state) ->
     Assoc ([tag "Redir";
             ("c", json_of_stmt c)]
            @ fields_of_redir_state redir_state)
  | Background (c, redir_state) ->
     Assoc ([tag "Background";
             ("c", json_of_stmt c)]
            @ fields_of_redir_state redir_state)
  | Subshell (c, redir_state) ->
     Assoc ([tag "Subshell";
             ("c", json_of_stmt c)]
            @ fields_of_redir_state redir_state)
  | And (c1, c2) -> obj_lr "And" c1 c2
  | Or (c1, c2) -> obj_lr "Or" c1 c2
  | Not c -> Assoc [tag "Not"; ("c", json_of_stmt c)]
  | Semi (c1, c2) -> obj_lr "Semi" c1 c2
  | If (c1, c2, c3) -> 
     Assoc [tag "If"; ("c", json_of_stmt c1); ("t", json_of_stmt c2); ("e", json_of_stmt c3)]
  | While (c1, c2) -> 
     Assoc [tag "While"; ("cond", json_of_stmt c1); ("body", json_of_stmt c2)]
  | WhileCond (c1, c2, c3, _saved_ec) -> 
      (* TODO 2019-04-11 expose saved ec? *)
      Assoc [tag "WhileCond"; ("cond", json_of_stmt c1); ("cur", json_of_stmt c2); ("body", json_of_stmt c2)]
  | WhileRunning (c1, c2, c3) -> 
      Assoc [tag "WhileRunning"; ("cond", json_of_stmt c1); ("body", json_of_stmt c2); ("cur", json_of_stmt c3)]
  | For (x, w, c) -> 
     Assoc [tag "For"; ("var", String x); ("args", json_of_words w); ("body", json_of_stmt c)]
  | ForExpArgs (x, state, c) -> 
     Assoc [tag "ForExpArgs"; ("var", String x); ("args", json_of_expansion_state  state); ("body", json_of_stmt c)]
  | ForExpanded (x, f, c) -> 
     Assoc [tag "ForExpanded"; ("var", String x); ("args", json_of_fields f); ("body", json_of_stmt c)]
  | ForRunning (x, f, b, c) -> 
      Assoc [tag "ForRunning"; ("var", String x); ("args", json_of_fields f); ("body", json_of_stmt b); ("cur", json_of_stmt c)]
  | Case (w, cases) -> 
     Assoc [tag "Case"; ("args", json_of_words w); ("cases", List (List.map json_of_case cases))]
  | CaseExpArg (w, cases) -> 
     Assoc [tag "CaseExpArg"; ("args", json_of_expansion_state w); ("cases", List (List.map json_of_case cases))]
  | CaseMatch (w, cases) -> 
     Assoc [tag "CaseMatch"; ("args", json_of_symbolic_string w); ("cases", List (List.map json_of_case cases))]
  | CaseCheckMatch (w, pat, c, cases) -> 
     Assoc [tag "CaseCheckMatch";
            ("args", json_of_symbolic_string w);
            ("pat", json_of_expansion_state pat);
            ("c", json_of_stmt c);
            ("cases", List (List.map json_of_case cases))]
  | Defun (f, c) -> Assoc [tag "Defun"; ("name", String f); ("body", json_of_stmt c)]
  | Call (outer_loop_nest, outer_argv, func, orig, c) ->
     Assoc [tag "Call";
            ("loop_nest", Int outer_loop_nest);
            ("outer_argv", json_of_fields outer_argv);
            ("f", String func);
            ("orig", json_of_stmt orig);
            ("c", json_of_stmt c)]
  | EvalLoop (linno, _ctx, src, i, top_level) ->
     Assoc ([tag "EvalLoop";
             ("linno", Int linno);
             ("interactive", Bool (is_interactive_mode i));
             ("top_level", Bool (is_toplevel top_level))] @
             json_field_of_src src)
  | EvalLoopCmd (linno, _ctx, src, i, top_level, c) ->
     Assoc ([tag "EvalLoopCmd";
             ("linno", Int linno);
             ("interactive", Bool (is_interactive_mode i));
             ("top_level", Bool (is_toplevel top_level));
             ("c", json_of_stmt c)] @
             json_field_of_src src)
  | Break n -> Assoc [tag "Break"; ("n", Int n)]
  | Continue n -> Assoc [tag "Continue"; ("n", Int n)]
  | Return -> Assoc [tag "Return"]
  | Exec (cmd, cmd_argv0, args, env, binsh) -> 
     Assoc [tag "Exec";
            ("cmd", json_of_symbolic_string cmd);
            ("cmd_argv0", json_of_symbolic_string cmd_argv0);
            ("args", json_of_fields args);
            ("env", json_of_env env);
            ("binsh", Bool (try_binsh binsh))]
  | Wait (n, checked, bound, _mode) -> 
     Assoc ([tag "Wait"; ("pid", Int n); ("checked", Bool (checked_exit checked))] @
              match bound with
              | None -> []
              | Some steps -> [("steps", Int steps)])
  | Trapped (signal, ec, c_handler, c_cont) ->
     Assoc [tag "Trapped";
            ("signal", String (string_of_signal signal));
            ("ec", Int ec);
            ("handler", json_of_stmt c_handler);
            ("cont", json_of_stmt c_cont)]
  | Pushredir (c, saved_fds) -> 
     Assoc [tag "Pushredir"; 
            ("c", json_of_stmt c);
            ("saved_fds", json_of_saved_fds saved_fds)]
  | CheckedExit c ->
     Assoc [tag "CheckedExit";
            ("c", json_of_stmt c)]
  | Exit -> Assoc [tag "Exit"]
  | Done -> Assoc [tag "Done"]
and obj_lr name l r = Assoc [tag name; ("l", json_of_stmt l); ("r", json_of_stmt r)]
and obj_crs name c rs = 
  Assoc [tag name; ("c", json_of_stmt c); ("rs", json_of_redirs rs)]
and fields_of_redir_state (ers, mes, rs) =
  [("ers", json_of_expanded_redirs ers)] @
    (match mes with
     | None -> [] 
     | Some es -> [("exp_redir", json_of_expanding_redir es)]) @
  [("rs", json_of_redirs rs)]
and json_of_redir = function
  | RFile (ty, fd, w) -> 
     Assoc [tag "File"; 
            ("ty", json_of_redir_type ty); ("src", Int fd); ("tgt", json_of_words w)]
  | RDup (ty, src, tgt) -> 
     Assoc [tag "Dup";
            ("ty", json_of_dup_type ty); ("src", Int src); ("tgt", json_of_words tgt)]
  | RHeredoc (ty, src, w) -> 
     Assoc [tag "Heredoc";
            ("ty", json_of_heredoc_type ty); ("src", Int src); ("w", json_of_words w)]
and json_of_expanding_redir = function
  | XRFile (ty, fd, es) -> 
     Assoc [tag "File"; 
            ("ty", json_of_redir_type ty); 
            ("src", Int fd); 
            ("tgt", json_of_expansion_state es)]
  | XRDup (ty, fd, es) -> 
     Assoc [tag "Dup"; 
            ("ty", json_of_dup_type ty); 
            ("src", Int fd); 
            ("tgt", json_of_expansion_state es)]
  | XRHeredoc (ty, src, es) -> 
     Assoc [tag "Heredoc";
            ("ty", json_of_heredoc_type ty); 
            ("src", Int src); 
            ("w", json_of_expansion_state es)]
and json_of_expanded_redir = function
  | ERFile (ty, fd, ss) -> 
     Assoc [tag "File"; 
            ("ty", json_of_redir_type ty); ("src", Int fd); ("tgt", json_of_symbolic_string ss)]
  | ERDup (ty, orig_action, src, Some tgt) -> 
     Assoc [tag "Dup";
            ("ty", json_of_dup_type ty); ("src", Int src); ("tgt", Int tgt); ("close", Bool (should_close_orig orig_action))]
  | ERDup (ty, orig_action, src, None) -> 
     Assoc [tag "Dup";
            ("ty", json_of_dup_type ty); ("src", Int src); ("tgt", String "-"); ("close", Bool (should_close_orig orig_action))]
  | ERHeredoc (ty, src, ss) -> 
     Assoc [tag "Heredoc";
            ("ty", json_of_heredoc_type ty); ("src", Int src); ("w", json_of_symbolic_string ss)]
and json_of_redir_type = function
  | To -> String "To"
  | Clobber -> String "Clobber"
  | From -> String "From"
  | FromTo -> String "FromTo"
  | Append -> String "Append"
and json_of_dup_type = function
  | ToFD -> String "ToFD"
  | FromFD -> String "FromFD"
and json_of_heredoc_type = function
  | Here -> String "Here"
  | XHere -> String "XHere"
and json_of_redirs rs = List (List.map json_of_redir rs)
and json_of_expanded_redirs rs = List (List.map json_of_expanded_redir rs)
and json_of_assign (x, w) = Assoc [("var", String x); ("value", json_of_words w)]
and json_of_inprogress_assign (x, state) = Assoc [("var", String x); ("value", json_of_expansion_state state)]
and json_of_expanded_assign (x, ss) = Assoc [("var", String x); ("value", json_of_symbolic_string ss)]
and json_of_case (ws, c) = Assoc [("pats", List (List.map json_of_words ws));
                                  ("stmt", json_of_stmt c)]
and json_of_words w = List (List.map json_of_entry w)
and json_of_entry = function
  | S s -> obj_v "S" s
  | K k -> Assoc [tag "K"; ("v", json_of_control k)]
  | F -> obj "F"
  | ESym sym -> Assoc [tag "ESym"; ("v", json_of_symbolic sym)]
and json_of_control = function
  | Tilde prefix -> Assoc [tag "Tilde"; ("prefix", String prefix)]
  | Param (x,fmt) -> Assoc [tag "Param"; ("var", String x); ("fmt", json_of_format fmt)]
  | LAssign (x,f,w) -> Assoc [tag "LAssign"; ("var", String x);
                              ("f", json_of_expanded_words f); ("w", json_of_words w)]
  | LMatch (x,side,mode,f,w) -> Assoc [tag "LMatch"; ("var", json_of_fields x);
                                       ("side", json_of_substring_side side);
                                       ("mode", json_of_substring_mode mode);
                                       ("f", json_of_expanded_words f); ("w", json_of_words w)]
  | LError (x,f,w) -> Assoc [tag "LError"; ("var", String x);
                             ("f", json_of_expanded_words f); ("w", json_of_words w)]
  | Backtick c -> Assoc [tag "Backtick"; ("stmt", json_of_stmt c)]
  | LBacktick (corig, pid, fd_read) -> Assoc [tag "LBacktick"; 
                                              ("orig", json_of_stmt corig);
                                              ("pid", Int pid);
                                              ("fd_read", Int fd_read)]
  | LBacktickWait (corig, pid, s) -> Assoc [tag "LBacktickWait"; 
                                            ("orig", json_of_stmt corig);
                                            ("pid", Int pid);
                                            ("s", String s)]
  | Arith (f,w) ->  obj_fw "Arith" f w
  | Quote (f,w) -> obj_fw "Quote" f w
and json_of_format = function
  | Normal -> obj "Normal"
  | Length -> obj "Length"
  | Default w -> obj_w "Default" w
  | NDefault w -> obj_w "NDefault" w
  | Assign w -> obj_w "Assign" w
  | NAssign w -> obj_w "NAssign" w
  | Error w -> obj_w "Error" w
  | NError w -> obj_w "NError" w
  | Alt w -> obj_w "Alt" w
  | NAlt w -> obj_w "NAlt" w
  | Substring (side,mode,w) -> Assoc [tag "Substring";
                                      ("side", json_of_substring_side side);
                                      ("mode", json_of_substring_mode mode);
                                      ("w", json_of_words w)]
and json_of_substring_mode = function
  | Shortest -> String "Shortest"
  | Longest -> String "Longest"
and json_of_substring_side = function
  | Prefix -> String "Prefix"
  | Suffix -> String "Suffix"
and json_of_expanded_words f = List (List.map json_of_expanded_word f)
and json_of_expanded_word = function
  | UsrF -> obj "UsrF"
  | ExpS s -> obj_v "ExpS" s
  | At f -> Assoc [tag "At"; ("f", json_of_fields f)]
  | DQuo s -> Assoc [tag "DQuo"; ("s", json_of_symbolic_string s)]
  | UsrS s -> obj_v "UsrS" s
  | EWSym sym -> Assoc [tag "EWSym"; ("s", json_of_symbolic sym)]
and json_of_fields ss = List (List.map json_of_symbolic_string ss)
and json_of_symbolic = function
  | SymCommand c -> Assoc [tag "SymCommand"; ("stmt", json_of_stmt c)]
  | SymArith f -> Assoc [tag "SymArith"; ("f", json_of_fields f)]
  | SymPat (side, mode, pat, s) -> Assoc [tag "SymPat";
                                    ("side", json_of_substring_side side);
                                    ("mode", json_of_substring_mode mode);
                                    ("pat", json_of_symbolic_string pat);
                                    ("s", json_of_symbolic_string s)]
and json_of_symbolic_string s = List (list_of_symbolic_string s)
and list_of_symbolic_string = function
  | [] -> []
  | (C _::_) as s ->
     let (cs, s') = maximal_char_list s in
     String (implode cs)::list_of_symbolic_string s'
  | Sym sym::s' -> json_of_symbolic sym::list_of_symbolic_string s'
and json_of_tmp_field = function
  | WFS cl -> Assoc [tag "WFS"; ("s", String (implode cl))]
  | FS  cl -> Assoc [tag "FS"; ("s", String (implode cl))]
  | Field s -> Assoc [tag "Field"; ("s", json_of_symbolic_string s)]
  | QField s -> Assoc [tag "QField"; ("s", json_of_symbolic_string s)]
and json_of_intermediate_fields fs = List (List.map json_of_tmp_field fs)
and json_of_saved_fds saved_fds =
  List (List.map 
          (fun (fd, info) -> 
            Assoc [("fd", Int fd); ("info", json_of_saved_fd_info info)])
          saved_fds)
and json_of_saved_fd_info = function
  | Saved fd -> Int fd
  | Close -> String "close"

and obj_w name w = Assoc [tag name; ("w", json_of_words w)]
and obj_f name f = Assoc [tag name; ("f", json_of_expanded_words f)]
and obj_fw name f w = Assoc [tag name; ("f", json_of_expanded_words f); ("w", json_of_words w)]

and json_of_expansion_step = function
  | ESTilde s -> Assoc [tag "ESTilde"; ("msg", String s)]
  | ESParam s -> Assoc [tag "ESParam"; ("msg", String s)]
  | ESCommand s -> Assoc [tag "ESCommand"; ("msg", String s)]
  | ESArith s -> Assoc [tag "ESArith"; ("msg", String s)]
  | ESSplit s -> Assoc [tag "ESSplit"; ("msg", String s)]
  | ESPath s -> Assoc [tag "ESPath"; ("msg", String s)]
  | ESQuote s -> Assoc [tag "ESQuote"; ("msg", String s)]
  | ESStep s -> Assoc [tag "ESStep"; ("msg", String s)]
  | ESNested (outer, inner) -> Assoc [tag "ESNested"; ("inner", json_of_expansion_step inner); ("outer", json_of_expansion_step outer)]
  | ESEval (exp_step, eval_step) ->  Assoc [tag "ESEval"; ("inner", json_of_evaluation_step eval_step); ("outer", json_of_expansion_step exp_step)]

and json_of_expansion_state = function
  | ExpStart (_opts, w) -> obj_w "ExpStart" w
  | ExpExpand (_opts, f, w) -> obj_fw "ExpExpand" f w
  | ExpSplit (_opts, f) -> obj_f "ExpSplit" f
  | ExpPath (_opts, ifs) -> Assoc [tag "ExpPath"; ("ifs", json_of_intermediate_fields ifs)]
  | ExpQuote (_opts, ifs) -> Assoc [tag "ExpQuote"; ("ifs", json_of_intermediate_fields ifs)]
  | ExpError f -> Assoc [tag "ExpError"; ("msg", json_of_fields f)]
  | ExpDone fs -> Assoc [tag "ExpDone"; ("f", json_of_fields fs)]

and json_of_evaluation_step = function
  | XSSimple s -> Assoc [tag "XSSimple"; ("msg", String s)]
  | XSPipe s -> Assoc [tag "XSPipe"; ("msg", String s)]
  | XSRedir s -> Assoc [tag "XSRedir"; ("msg", String s)]
  | XSBackground s -> Assoc [tag "XSBackground"; ("msg", String s)]
  | XSSubshell s -> Assoc [tag "XSSubshell"; ("msg", String s)]
  | XSAnd s -> Assoc [tag "XSAnd"; ("msg", String s)]
  | XSOr s -> Assoc [tag "XSOr"; ("msg", String s)]
  | XSNot s -> Assoc [tag "XSNot"; ("msg", String s)]
  | XSSemi s -> Assoc [tag "XSSemi"; ("msg", String s)]
  | XSIf s -> Assoc [tag "XSIf"; ("msg", String s)]
  | XSWhile s -> Assoc [tag "XSWhile"; ("msg", String s)]
  | XSFor s -> Assoc [tag "XSFor"; ("msg", String s)]
  | XSCase s -> Assoc [tag "XSCase"; ("msg", String s)]
  | XSDefun s -> Assoc [tag "XSDefun"; ("msg", String s)]
  | XSStack(func, inner) -> Assoc [tag "XSStack";
                                   ("func", String func);
                                   ("inner", json_of_evaluation_step inner)]
  | XSStep s -> Assoc [tag "XSStep"; ("msg", String s)]
  | XSExec s -> Assoc [tag "XSExec"; ("msg", String s)]
  | XSEval (linno,src,s) -> 
     Assoc ([tag "XSEval"; 
            ("msg", String s);
            ("linno", Int linno)] @
            json_field_of_src src)
  | XSWait s -> Assoc [tag "XSWait"; ("msg", String s)]
  | XSTrap (signal, s) -> Assoc [tag "XSTrap"; 
                                 ("msg", String s); 
                                 ("signal", String (string_of_signal signal))]
  | XSProc (pid, stmt) -> 
     Assoc [tag "XSProc"; 
            ("c", json_of_stmt stmt);
            ("pid", Int pid);
            ("c_str", String (string_of_stmt stmt))]
  | XSNested (outer, inner) -> Assoc [tag "XSNested"; ("inner", json_of_evaluation_step inner); ("outer", json_of_evaluation_step outer)]
  | XSExpand (eval_step, exp_step) -> Assoc [tag "XSExpand"; ("inner", json_of_expansion_step  exp_step); ("outer", json_of_evaluation_step eval_step)]

and json_field_of_src = function
  | ParseSTDIN -> [("src", String "<STDIN>")]
  | ParseString (_mode, cmd) -> [("cmd", String cmd)]
  | ParseFile (file, _push) ->
     (* we trim it to basename because we don't want to leak filenames in the web server *)
     [("src", String (Filename.basename file))]
and json_of_env (env:(string, symbolic_string) Pmap.map) : json =
  Assoc (List.map (fun (k,v) -> (k, json_of_symbolic_string v)) (Pmap.bindings_list env))

and json_of_local_env (env:(string, (symbolic_string option * local_opts)) Pmap.map) : json =
  Assoc (List.map 
           (fun (k,(m_v,opts)) -> 
             (k, match m_v with
                 | None -> String "unset"
                 | Some v -> json_of_symbolic_string v))
           (Pmap.bindings_list env))

and json_of_locals (locals:(string, (symbolic_string option * local_opts)) Pmap.map list) 
    : json =
  List (List.map json_of_local_env locals)

and json_of_shell_state (sh:shell_state) : json = 
  Assoc [("env", json_of_env sh.env);
         ("locals", json_of_locals sh.locals);
         ("cwd", String sh.cwd);
         ("locale", String sh.locale.name)]

