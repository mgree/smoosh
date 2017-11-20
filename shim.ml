open Ctypes
open Foreign
open Dash
open Fsh

let skip = Command ([],[],[])

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
  match (n @-> node_type) with
  (* NCMD *)
  | 0  ->
     let n = n @-> node_ncmd in
     Command (to_assigns (getf n ncmd_assign),
              join (to_args (getf n ncmd_args)),
              redirs (getf n ncmd_redirect))
  (* NPIPE *)
  | 1 ->
     let n = n @-> node_npipe in
     Pipe (getf n npipe_backgnd <> 0,
           List.map of_node (nodelist (getf n npipe_cmdlist)))
  (* NREDIR *)
  | 2  -> let (c,redirs) = of_nredir n in Redir (c,redirs)
  (* NBACKGND *)
  | 3  -> let (c,redirs) = of_nredir n in Background (c,redirs)
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
     let else_part = getf n nif_elsepart in
     If (of_node (getf n nif_test),
         of_node (getf n nif_ifpart),
         if nullptr else_part
         then skip
         else of_node else_part)
  (* NWHILE *)
  | 9  -> let (t,b) = of_binary n in While (t,b)
  (* NUNTIL *)
  | 10 -> let (t,b) = of_binary n in While (Not t,b)
  (* NFOR *)
  | 11 ->
     let n = n @-> node_nfor in
     For (getf n nfor_var,
          to_arg (getf n nfor_args @-> node_narg),
          of_node (getf n nfor_body))
  (* NCASE *)
  | 12 ->
     let n = n @-> node_ncase in
     Case (to_arg (getf n ncase_expr @-> node_narg),
           List.map
             (fun (pattern,body) -> (to_arg (pattern @-> node_narg), of_node body))
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
  (of_node (getf n nredir_n), redirs (getf n nredir_redirect))

and redirs (n : node union ptr) =
  if nullptr n
  then []
  else
    let mk_file ty =
      let n = n @-> node_nfile in
      RFile (ty,getf n nfile_fd,to_arg (getf n nfile_fname @-> node_narg)) in
    let mk_dup ty =
      let n = n @-> node_ndup in
      RDup (ty,getf n ndup_fd,getf n ndup_dupfd) in
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
  let a,s,bqlist,stack = parse_arg (explode (getf n narg_text)) (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s = []);
  assert (nullptr bqlist);
  assert (stack = []);
  a  

and parse_arg (s : char list) (bqlist : nodelist structure ptr) stack =
  match s,stack with
  | [],[] -> [],[],bqlist,[]
  | [],`CTLVar::_ -> failwith "End of string before CTLENDVAR"
  | [],`CTLAri::_ -> failwith "End of string before CTLENDARI"
  | [],`CTLQuo::_ -> failwith "End of string before CTLQUOTEMARK"
  (* CTLESC *)
  | '\129'::_ as s,_ -> 
     let (str,s') = parse_string [] s in
     arg_char (S (implode str)) s' bqlist stack
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
        let w,s,bqlist,stack' = parse_arg s bqlist (`CTLVar::stack) in
        K (Param (implode var_name, var_type vstype w)), s, bqlist, stack'
     | _,c::_ -> failwith ("Expected '=' terminating variable name, found " ^ Char.escaped c)
     | _,[] -> failwith "Expected '=' terminating variable name, found EOF"
     in
     arg_char v s bqlist stack
  (* CTLENDVAR *)
  | '\131'::s,`CTLVar::stack' -> [],s,bqlist,stack'
  | '\131'::_,`CTLAri::_ -> failwith "Saw CTLENDVAR before CTLENDARI"
  | '\131'::_,`CTLQuo::_ -> failwith "Saw CTLENDVAR before CTLQUOTEMARK"
  | '\131'::_,[] -> failwith "Saw CTLENDVAR outside of CTLVAR"
  (* CTLBACKQ *)
  | '\132'::s,_ ->
     if nullptr bqlist
     then failwith "Saw CTLBACKQ but bqlist was null"
     else arg_char (K (Backtick (of_node (bqlist @-> nodelist_n)))) s (bqlist @-> nodelist_next) stack
  (* CTLARI *)
  | '\134'::s,_ ->
     let a,s,bqlist,stack' = parse_arg s bqlist (`CTLAri::stack) in
     assert (stack = stack');
     arg_char (K (Arith ([],a))) s bqlist stack'
  (* CTLENDARI *)
  | '\135'::s,`CTLAri::stack' -> [],s,bqlist,stack'
  | '\135'::_,`CTLVar::_' -> failwith "Saw CTLENDARI before CTLENDVAR"
  | '\135'::_,`CTLQuo::_' -> failwith "Saw CTLENDARI before CTLQUOTEMARK"
  | '\135'::_,[] -> failwith "Saw CTLENDARI outside of CTLARI"
  (* CTLQUOTEMARK *)
  | '\136'::s,`CTLQuo::stack' -> [],s,bqlist,stack'
  | '\136'::s,_ ->
     let a,s,bqlist,stack' = parse_arg s bqlist (`CTLQuo::stack) in
     assert (stack' = stack);
     arg_char (K (Quote a)) s bqlist stack'
  (* tildes *)
  | '~'::s,stack ->
     let uname,s' = parse_tilde [] s in
     begin
       match uname with 
       | None -> arg_char (K Tilde) s bqlist stack
       | Some user -> arg_char (K (TildeUser user)) s' bqlist stack
     end
  (* ordinary character *)
  | _::_,_ -> 
     let (str,s') = parse_string [] s in
     arg_char (S (implode str)) s' bqlist stack

and parse_tilde acc = 
  let ret = if acc = [] then None else Some (implode acc) in
  function
  | [] -> (ret , [])
  (* CTLESC *)
  | '\129'::_ as s -> None, s
  (* CTLQUOTEMARK *)
  | '\136'::_ as s -> None, s
  (* terminal: CTLENDVAR, /, : *)
  | '\131'::_ as s -> ret, s
  | ':'::_ as s -> ret, s
  | '/'::_ as s -> ret, s
  (* ordinary char *)
  | c::s' -> parse_tilde (acc @ [c]) s'  

and parse_string acc = function
  | [] -> List.rev acc, []
  | '\130'::_ as s -> List.rev acc, s
  | '\131'::_ as s -> List.rev acc, s
  | '\132'::_ as s -> List.rev acc, s
  | '\134'::_ as s -> List.rev acc, s
  | '\135'::_ as s -> List.rev acc, s
  | '\136'::_ as s -> List.rev acc, s
  | '~'   ::_ as s -> List.rev acc, s
  | '\129'::c::s -> parse_string (explode (Char.escaped c) @ acc) s
  | c::s -> parse_string (c::acc) s
              
and arg_char c s bqlist stack =
  let a,s,bqlist,stack = parse_arg s bqlist stack in
  (c::a,s,bqlist,stack)

and to_assign v = function
  | [] -> failwith ("Never found an '=' sign in assignment, got " ^ v)
  | S "=" :: a -> (v,a)
  | (S c) :: a -> to_assign (v ^ c) a
  | _ -> failwith "Unexpected special character in assignment"
    
and to_assigns n = List.map (to_assign "") (to_args n)
    
and to_args (n : node union ptr) : words list =
  if nullptr n
  then [] 
  else (assert (n @-> node_type = 15);
        let n = n @-> node_narg in
        to_arg n::to_args (getf n narg_next))

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

let rec json_of_stmt = function
  | Command (assigns, args, rs) -> 
     Assoc [tag "Command"; 
            ("assigns", List (List.map json_of_assign assigns));
            ("args", json_of_words args);
            ("rs", json_of_redirs rs)]
  | Pipe (bg, cs) -> 
     Assoc [tag "Pipe"; ("bg", Bool bg); ("cs", List (List.map json_of_stmt cs))]
  | Redir (c, rs) -> obj_crs "Redir" c rs
  | Background (c, rs) -> obj_crs "Background" c rs
  | Subshell (c, rs) -> obj_crs "Subshell" c rs
  | And (c1, c2) -> obj_lr "And" c1 c2
  | Or (c1, c2) -> obj_lr "Or" c1 c2
  | Not c -> Assoc [tag "Not"; ("c", json_of_stmt c)]
  | Semi (c1, c2) -> obj_lr "Semi" c1 c2
  | If (c1, c2, c3) -> 
     Assoc [tag "If"; ("c", json_of_stmt c1); ("t", json_of_stmt c2); ("e", json_of_stmt c3)]
  | While (c1, c2) -> 
     Assoc [tag "While"; ("cond", json_of_stmt c1); ("body", json_of_stmt c2)]
  | For (x, w, c) -> 
     Assoc [tag "For"; ("var", String x); ("args", json_of_words w); ("body", json_of_stmt c)]
  | Case (w, cases) -> 
     Assoc [tag "Case"; ("args", json_of_words w); ("cases", List (List.map json_of_case cases))]
  | Defun (f, c) -> Assoc [tag "Defun"; ("name", String f); ("body", json_of_stmt c)]
and obj_lr name l r = Assoc [tag name; ("l", json_of_stmt l); ("r", json_of_stmt r)]
and obj_crs name c rs = 
  Assoc [tag name; ("c", json_of_stmt c); ("rs", json_of_redirs rs)]
and json_of_redir = function
  | RFile (ty, fd, w) -> 
     Assoc [tag "File"; 
            ("ty", json_of_redir_type ty); ("src", Int fd); ("tgt", json_of_words w)]
  | RDup (ty, src, tgt) -> 
     Assoc [tag "Dup";
            ("ty", json_of_dup_type ty); ("src", Int src); ("tgt", Int tgt)]
  | RHeredoc (ty, src, w) -> 
     Assoc [tag "Heredoc";
            ("ty", json_of_heredoc_type ty); ("src", Int src); ("w", json_of_words w)]
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
and json_of_assign (x, w) = Assoc [("var", String x); ("w", json_of_words w)]
and json_of_case (w, c) = Assoc [("pat", json_of_words w); ("stmt", json_of_stmt c)]
and json_of_words w = List (List.map json_of_entry w)
and json_of_entry = function
  | S s -> obj_v "S" s
  | K k -> Assoc [tag "K"; ("v", json_of_control k)]
  | F -> obj "F"
  | ESym sym -> Assoc [tag "ESym"; ("v", json_of_symbolic sym)]
and json_of_control = function
  | Tilde -> obj "Tilde"
  | TildeUser user -> Assoc [tag "TildeUser"; ("user", String user)]
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
  | DQuo s -> obj_v "DQuo" s
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
and list_of_symbolic_string s =
       ((function
         | [] -> []
         | C _::_ ->
           let (cs, s') = maximal_char_list s in
           String (implode cs)::list_of_symbolic_string s'
         | Sym sym::s' -> json_of_symbolic sym::list_of_symbolic_string s')
        s)

and obj_w name w = Assoc [tag name; ("w", json_of_words w)]
and obj_f name f = Assoc [tag name; ("f", json_of_expanded_words f)]
and obj_fw name f w = Assoc [tag name; ("f", json_of_expanded_words f); ("w", json_of_words w)]

let rec json_of_expansion_step = function
  | ESTilde s -> Assoc [tag "ESTilde"; ("msg", String s)]
  | ESParam s -> Assoc [tag "ESParam"; ("msg", String s)]
  | ESCommand s -> Assoc [tag "ESCommand"; ("msg", String s)]
  | ESArith s -> Assoc [tag "ESArith"; ("msg", String s)]
  | ESSplit s -> Assoc [tag "ESSplit"; ("msg", String s)]
  | ESPath s -> Assoc [tag "ESPath"; ("msg", String s)]
  | ESQuote s -> Assoc [tag "ESQuote"; ("msg", String s)]
  | ESStep s -> Assoc [tag "ESStep"; ("msg", String s)]
  | ESNested (outer, inner) -> Assoc [tag "ESNested"; ("inner", json_of_expansion_step inner); ("outer", json_of_expansion_step outer)]
