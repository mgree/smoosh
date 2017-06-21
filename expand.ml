open Lem_pervasives_extra
open Test_prelude
open Fsh_prelude
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

let parse_entry (s:string) =
  try
    let eq = String.index s '=' in
    let name = String.sub s 0 eq in
    let value = String.sub s (eq+1) (String.length s - eq - 1) in
    let escaped =
      try Scanf.unescaped value
      with Scanf.Scan_failure _ -> eprintf "Environment parse error: couldn't handle escapes in %s, leaving as-is" s; value
    in
    initial_os_state := set_param name escaped !initial_os_state
  with Not_found -> eprintf "Environment parse error: couldn't find an '=' in %s" s

let parse_env (env:string list) = List.iter parse_entry env
                                
let load_env (f:string) =
  let rec go (ic:in_channel) =
    try
      parse_entry (input_line ic);
      go ic
    with End_of_file -> close_in ic
  in
  go (open_in f)

let ambient_env () = parse_env (Array.to_list (Unix.environment ()))
                                 
let parse_args () =
  Arg.parse
    ["-v",Arg.Set verbose,"verbose mode";
     "-env-file",Arg.String load_env,"file containing environment (one var=value per line; no need for quotes)";
     "-env-ambient",Arg.Unit ambient_env,"use the ambient environment";
    ]
    (function | "-" -> input_src := None | f -> input_src := Some f)
    "Final argument should be either a filename or - (for STDIN); only the last such argument is used"

(**********************************************************************)
(* AST munging ********************************************************)       
(**********************************************************************)

let show_unless expected actual =
  if expected = actual
  then ""
  else string_of_int actual
    
let rec join (ws:words list) : words =
  match ws with
  | [] -> []
  | [w] -> w
  | w1::w2::ws -> w1 @ [F] @ join (w2::ws)

let rec join_with (sep:words) (ws:words list) : words =
  match ws with
  | [] -> []
  | [w] -> w
  | w1::w2::ws -> w1 @ sep @ [F] @ join (w2::ws)
                                  
let join_map (f : 'a -> words) (l : 'a list) : words =
  join (List.map f l)

let join_map_with (sep:words) (f : 'a -> words) (l : 'a list) : words =
  join_with sep (List.map f l)

let rec words_of_ast (e : Ast.t) : words =
  match e with
  | Command (_,assigns,cmds,redirs) ->
     join
       [join_map (fun (x,v) -> [S x;S "=";] @ words_of_arg v) assigns;
        join_map words_of_arg cmds;
        words_of_redirs redirs]
  | Pipe (_,es) -> join_map_with [S "|"]  words_of_ast es
  | Redir (_,e,redirs) -> join [words_of_ast e; words_of_redirs redirs]
  | Background (_,e,redirs) -> join [words_of_ast e; words_of_redirs redirs; [S "&"]]
  | Subshell (_,e,redirs) -> join [[S "("]; words_of_ast e; words_of_redirs redirs; [S ")"]]
  | And (e1,e2) -> join [words_of_ast e1; [S "&&"]; words_of_ast e2]
  | Or (e1,e2) -> join [words_of_ast e1; [S "||"]; words_of_ast e2]
  | Not e -> join [[S "!"]; words_of_ast e]
  | Semi (e1,e2) -> join [words_of_ast e1; [S ";"]; words_of_ast e2]
  | If (e1,e2,e3) -> join [[S "if"]; words_of_ast e1; [S "; then"]; words_of_ast e2; [S "; else"]; words_of_ast e3; [S "; fi"]]
  | While (e1,e2) -> join [[S "while"]; words_of_ast e1; [S "; do"]; words_of_ast e2; [S "; done"]]
  | For (_,arg,e,x) -> join [[S "for"]; [S x]; [S "in"]; words_of_arg arg; [S "; do"]; words_of_ast e; [S "; done"]]
  | Case (_,arg,cases) -> join [[S "case"]; words_of_arg arg; [S "in"]; words_of_cases cases]
  | Defun (_,f,e) -> join [[S (f ^ "()")]; words_of_ast e]
and words_of_arg (a : Ast.arg) : words =
  List.map entry_of_arg_char a (* TODO string joining *)
and entry_of_arg_char (ac : Ast.arg_char) : entry =
  match ac with
  | T None -> K Tilde
  | T (Some user) -> K (TildeUser user)
  | C c -> S (String.make 1 c)
  | E c -> S (String.make 1 c)
  | A a -> K (Arith ([],words_of_arg a))
  | V (ty,nul,x,a) ->
     let w = words_of_arg a in
     let fmt = match ty,nul with
       | (Normal,_) -> Normal
       | (Minus,false) -> Default w
       | (Minus,true) -> NDefault w
       | (Plus,false) -> Assign w
       | (Plus,true) -> NAssign w
       | (Question,false) -> Error w
       | (Question,true) -> NError w
       | (Assign,false) -> Assign w
       | (Assign,true) -> NAssign w
       | (Length,_) -> Length
       | (TrimR,_) -> Substring (Prefix,Shortest,w)
       | (TrimRMax,_) -> Substring (Prefix,Longest,w)
       | (TrimL,_) -> Substring (Suffix,Shortest,w)
       | (TrimLMax,_) -> Substring (Suffix,Longest,w) in
     K (Param (x,fmt))
  | Q a -> K (Quote (words_of_arg a))
  | B e -> K (Backtick (words_of_ast e))

and words_of_redirs (rs : Ast.redirection list) : words =
  List.concat (List.map words_of_redir rs)
              
and words_of_redir = function
  | File (To,fd,a)      -> S (show_unless 1 fd ^ ">") :: words_of_arg a
  | File (Clobber,fd,a) -> S (show_unless 1 fd ^ ">|") :: words_of_arg a
  | File (From,fd,a)    -> S (show_unless 0 fd ^ "<") :: words_of_arg a
  | File (FromTo,fd,a)  -> S (show_unless 0 fd ^ "<>") :: words_of_arg a
  | File (Append,fd,a)  -> S (show_unless 1 fd ^ ">>") :: words_of_arg a
  | Dup (ToFD,fd,tgt)   -> [S (show_unless 1 fd ^ ">&" ^ string_of_int tgt)]
  | Dup (FromFD,fd,tgt) -> [S (show_unless 0 fd ^ "<&" ^ string_of_int tgt)]
  | Heredoc (t,fd,a) ->
     (* compute an EOF marker *)
     let heredoc = Ast.string_of_arg a in
     let marker = Dash.fresh_marker (Dash.lines heredoc) "EOF" in
     [S (show_unless 0 fd ^ "<<" ^ (if t = XHere then marker else "'" ^ marker ^ "'"))] @ words_of_arg a @ [S (marker ^ "\n")]
and words_of_cases (cs : Ast.case list) : words =
  List.concat
    (List.map (fun c -> words_of_arg c.Ast.cpattern @ [S ")"] @ words_of_ast c.Ast.cbody @ [S ";;"]) cs)
                
let rec expand_all (os : ty_os_state) (ws : words list) : ty_os_state * fields =
  match ws with
  | [] -> (os,[])
  | w::ws' ->
     let (os',fs) = full_expansion os w in
     let (os'', fs') = expand_all os' ws' in
     (os'', fs @ fs')
       
let main () =
  Dash.initialize ();
  parse_args ();
  set_input_src ();
  let ns = Dash.parse_all () in
  let cs = List.map Ast.of_node ns in
  let ws = List.map words_of_ast cs in (* TODO restrict to only simple commands? *)
  let (os,fs) = expand_all !initial_os_state ws in
  List.iter (fun f -> print_endline f) fs;;

main ()

           
