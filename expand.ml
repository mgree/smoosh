open Test_prelude
open Fsh
open Ast
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

let parse_entry (s:string) =
  let (name,value) = parse_keqv s in
  try
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
  | []::ws -> join ws
  | w1::w2::ws -> w1 @ [F] @ join (w2::ws)

let rec join_with (sep:words) (ws:words list) : words =
  match ws with
  | [] -> []
  | [w] -> w
  | []::ws -> join ws
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
       | (Normal,_) -> Fsh.Normal
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

(* we don't need anything else, I think---just a tiny bit of JSON *)
type json = String of string
          | List of json list 
          | Assoc of (string * json) list 

let rec write_json (buf : Buffer.t) = 
  let rec intercalate op sep = function
    | [] -> ()
    | [x] -> op x
    | x::xs -> op x; sep (); intercalate op sep xs in
  let comma () = Buffer.add_char buf ',' in
  function
  | String s -> 
     Buffer.add_char buf '"';
     Buffer.add_string buf (String.escaped s);
     Buffer.add_char buf '"'
  | List l ->
     Buffer.add_char buf '[';
     intercalate (write_json buf) comma l;
     Buffer.add_char buf ']'
  | Assoc m ->
     Buffer.add_char buf '{';
     let pair (k,v) = write_json buf (String k); Buffer.add_char buf ':'; write_json buf v in
     intercalate pair comma m;
     Buffer.add_char buf '}'

let tag name = ("tag", String name)

let obj name = Assoc [tag name]
let obj_v name v = Assoc [tag name; ("v", String v)]

let rec json_of_words w = List (List.map json_of_entry w)
and json_of_entry = function
  | S s -> obj_v "S" s
  | DQ s -> obj_v "DQ" s
  | K k -> Assoc [tag "K"; ("v", json_of_control k)]
  | F -> obj "F"
and json_of_control = function
  | Tilde -> obj "Tilde"
  | TildeUser user -> Assoc [tag "TildeUser"; ("user", String user)]
  | Param (x,fmt) -> Assoc [tag "Param"; ("var", String x); ("fmt", json_of_format fmt)]
  | LAssign (x,f,w) -> Assoc [tag "LAssign"; ("var", String x);
                              ("f", json_of_expanded_words f); ("w", json_of_words w)]
  | LMatch (x,side,mode,f,w) -> Assoc [tag "LMatch"; ("var", String x);
                                       ("side", json_of_substring_side side);
                                       ("mode", json_of_substring_mode mode);
                                       ("f", json_of_expanded_words f); ("w", json_of_words w)]
  | Backtick w -> obj_w "Backtick" w
  | Arith (f,w) ->  obj_fw "Arith" f w
  | Quote w -> obj_w "Quote" w
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
  | ExpDQ s -> obj_v "ExpDQ" s
  | UsrS s -> obj_v "UsrS" s
  | UsrDQ s -> obj_v "UsrDQ" s
and json_of_fields ss = List (List.map (fun s -> String s) ss)

and obj_w name w = Assoc [tag name; ("w", json_of_words w)]
and obj_f name f = Assoc [tag name; ("f", json_of_expanded_words f)]
and obj_fw name f w = Assoc [tag name; ("f", json_of_expanded_words f); ("w", json_of_words w)]

let json_of_state_term = function
  | `Start w -> obj_w "Start" w
  | `Expand (f,w) -> obj_fw "Expand" f w
  | `Split f -> obj_f "Split" f
  | `Done fs -> Assoc [tag "Done"; ("fields", json_of_fields fs)]

let json_of_env (env:(string, string) Pmap.map) : json =
  Assoc (List.map (fun (k,v) -> (k, String v)) (Pmap.bindings_list env))

let json_of_state ((os,tm):state) : json =
  Assoc [("env", json_of_env os.shell_env); ("term", json_of_state_term tm)]

let main () =
  Dash.initialize ();
  parse_args ();
  set_input_src ();
  let ns = Dash.parse_all () in
  let cs = List.map Ast.of_node ns in
  let ws = List.map words_of_ast cs in (* TODO restrict to only simple commands? *)
  let trace = trace_expansion (!initial_os_state, `Start (join ws)) in
  let tracej = List.map json_of_state trace in
  let out = Buffer.create (List.length tracej * 100) in
  begin
    write_json out (List tracej);
    Buffer.output_buffer stdout out
  end;;
  

main ()

           
