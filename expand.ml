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

let parse_args () =
  Arg.parse
    ["-v",Arg.Set verbose,"verbose mode"]
    (function | "-" -> input_src := None | f -> input_src := Some f)
    "Final argument should be either a filename or - (for STDIN); only the last such argument is used"

(**********************************************************************)
(* AST munging ********************************************************)       
(**********************************************************************)

let rec join (ws:words list) : words =
  match ws with
  | [] -> []
  | [w] -> w
  | w1::w2::ws -> w1 @ [F] @ join (w2::ws)

let join_map (f : 'a -> words) (l : 'a list) : words =
  join (List.map f l)

let rec words_of_ast (e : Ast.t) : words =
  match e with
  | Command (_,assigns,cmds,redirs) ->
     join
       [join_map (fun (_,arg) -> words_of_arg arg) assigns;
        join_map words_of_arg cmds;
        words_of_redirs redirs]
  | Pipe (_,es) -> join_map words_of_ast es
  | Redir (_,e,redirs) -> join [words_of_ast e; words_of_redirs redirs]
  | Background (_,e,redirs) -> join [words_of_ast e; words_of_redirs redirs]
  | Subshell (_,e,redirs) -> join [words_of_ast e; words_of_redirs redirs]
  | And (e1,e2) -> join [words_of_ast e1; words_of_ast e2]
  | Or (e1,e2) -> join [words_of_ast e1; words_of_ast e2]
  | Not e -> words_of_ast e
  | Semi (e1,e2) -> join [words_of_ast e1; words_of_ast e2]
  | If (e1,e2,e3) -> join [words_of_ast e1; words_of_ast e2; words_of_ast e3]
  | While (e1,e2) -> join [words_of_ast e1; words_of_ast e2]
  | For (_,arg,e,x) -> join [words_of_arg arg; words_of_ast e]
  | Case (_,arg,cases) -> join [words_of_arg arg; words_of_cases cases]
  | Defun (_,f,e) -> words_of_ast e
and words_of_arg (a : Ast.arg) : words =
  List.map entry_of_arg_char a (* TODO string joining *)
and entry_of_arg_char (ac : Ast.arg_char) : entry =
  match ac with
  | C '~' -> K Tilde (* TODO TildeUser *)
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
and words_of_redir (r : Ast.redirection) : words =
  match r with
  | File (_,_,a) -> words_of_arg a
  | Dup (_,_,_) -> []
  | Heredoc (_,_,a) -> words_of_arg a
and words_of_cases (cs : Ast.case list) : words =
  List.concat
    (List.map (fun c -> words_of_arg c.Ast.cpattern @ words_of_ast c.Ast.cbody) cs)

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
  let ws = List.map words_of_ast cs in
  let (os,fs) = expand_all !initial_os_state ws in
  List.iter (fun f -> print_endline f) fs;;

main ()

           
