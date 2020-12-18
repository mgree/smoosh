open Morbig
open Smoosh_prelude

exception ParseException of string

let unparsed_commands = ref []

let rec intercalate sep l =
  match l with
  | [] -> []
  | [elt] -> elt
  | elt::l -> elt @ [sep] @ intercalate sep l

let rec parse_program should_save_unparsed (program : Morsmall.AST.program) : Smoosh_prelude.stmt =
  match program with
  | [] -> failwith "No program"
  (* You need to keep calling parse_next to parse `rest` *)
  | cmd :: rest -> if should_save_unparsed then unparsed_commands := rest; 
  (* Printf.printf "Parsing program with %d commands\n" (1 + List.length rest); *)
  parse_command cmd
  (* | _ :: _ :: _ -> failwith "Can only handle single program" *)
  (* | [ cmd ] -> parse_command cmd *)

and flatten_strings entry_list = 
  match entry_list with
  S s1 :: S s2 :: r -> flatten_strings @@ S (s1 ^ s2) :: r
  | _ :: r -> (List.hd entry_list) :: flatten_strings r
  | _ -> entry_list

and morsmall_word_to_smoosh_entry (is_quoted : bool) ({ value; position } : Morsmall.AST.word') :
    Smoosh_prelude.entry =
  let entries = morsmall_wordval_to_smoosh_entries is_quoted value in
  assert (List.length entries = 1);
  List.hd entries

and morsmall_word_to_smoosh_entries (is_quoted : bool) ({ value; position } : Morsmall.AST.word') :
    Smoosh_prelude.entry list =
  let entries = morsmall_wordval_to_smoosh_entries is_quoted value in
  flatten_strings entries

and morsmall_words_to_smoosh_entries (is_quoted : bool) (words : Morsmall.AST.word' list) :
    Smoosh_prelude.entry list =
  let entries_lists = List.map (morsmall_word_to_smoosh_entries is_quoted) words in
  let entries = intercalate Smoosh_prelude.F entries_lists in
  entries

(* CASE ITEMS *)
and morsmall_wordvals_to_smoosh_words_list (is_quoted : bool) (words : Morsmall.AST.word list) :
    Smoosh_prelude.words list =
  let entries_lists = List.map (morsmall_wordval_to_smoosh_entries is_quoted) words in
  List.map flatten_strings entries_lists


and morsmall_wordvals_to_smoosh_entries (is_quoted : bool) (words : Morsmall.AST.word list) :
    Smoosh_prelude.entry list =
  let entries_lists = List.map (morsmall_wordval_to_smoosh_entries is_quoted) words in
  let entries = intercalate Smoosh_prelude.F entries_lists in
  entries

and morsmall_attribute_to_smoosh_format (is_quoted : bool) (attr : Morsmall.AST.attribute) =
  let get_words = morsmall_wordval_to_smoosh_entries is_quoted in
  match attr with
  | Morsmall.AST.NoAttribute -> Normal
  | Morsmall.AST.ParameterLength -> Length
  | Morsmall.AST.UseDefaultValues (word, ifNull) -> Default (get_words word)
  | Morsmall.AST.AssignDefaultValues (word, ifNull) -> 
    (match ifNull with
      | true -> NAssign (get_words word)
      | false -> Assign (get_words word))
  | Morsmall.AST.IndicateErrorifNullorUnset (word, ifNull) -> 
      (match ifNull with
      | true -> NError (get_words word)
      | false -> Error (get_words word))
  | Morsmall.AST.UseAlternativeValue (word, ifNull) -> 
      (match ifNull with
      | true -> NAlt (get_words word)
      | false -> Alt (get_words word))
  | Morsmall.AST.RemoveSmallestSuffixPattern word -> Substring (Suffix, Shortest, get_words word)
  | Morsmall.AST.RemoveLargestSuffixPattern word -> Substring (Suffix, Longest, get_words word)
  | Morsmall.AST.RemoveSmallestPrefixPattern word -> Substring (Prefix, Shortest, get_words word)
  | Morsmall.AST.RemoveLargestPrefixPattern word -> Substring (Prefix, Longest, get_words word)

and morsmall_wordval_to_smoosh_entries (is_quoted : bool) (w : Morsmall.AST.word) :
    Smoosh_prelude.entry list =
  let wc_to_substr (wc : Morsmall.AST.word_component) : Smoosh_prelude.entry =
    match wc with
    | Morsmall.AST.WLiteral s -> 
      let literal = if is_quoted then s else Str.(global_replace (Str.regexp "\\\\\\(.\\)") "\\1" s) in
      S literal
    | Morsmall.AST.WDoubleQuoted w -> K (Quote ([], morsmall_wordval_to_smoosh_entries true w))
    | Morsmall.AST.WVariable (name, attribute) ->
        K (Param (name, morsmall_attribute_to_smoosh_format is_quoted attribute))
    | Morsmall.AST.WSubshell p -> K (Backtick (parse_program false p))
    | Morsmall.AST.WGlobAll -> S "*"
    | Morsmall.AST.WGlobAny -> S "."
    | Morsmall.AST.WBracketExpression exp -> S "<BracketExpression>"
    | Morsmall.AST.WTildePrefix w -> K (Tilde w)
    | Morsmall.AST.WArith w -> K (Arith ([], morsmall_wordval_to_smoosh_entries is_quoted w))
  in
  List.map wc_to_substr w

and morsmall_to_smoosh_assignment
          ({ value; position } : Morsmall.AST.assignment') =
        let aName, aWord = value in
        (aName, morsmall_wordval_to_smoosh_entries false aWord)

and parse_command ({ value; position } : Morsmall.AST.command') :
    Smoosh_prelude.stmt =
  let command_opts =
    {
      ran_cmd_subst = false;
      should_fork = false;
      force_simple_command = false;
    }
  in
  match value with
  | Morsmall.AST.Simple (assignmentList, words) ->
      let assignments = List.map morsmall_to_smoosh_assignment assignmentList in
      let args = morsmall_words_to_smoosh_entries false words in
      Command (assignments, args, [], command_opts)
  | Morsmall.AST.Async cmd -> 
    let redir_state = ([], None, []) in
    (* Eat subshell if that is what cmd is *)
    let rec eat_subshells (c : Morsmall.AST.command') = match c.value with
      | Morsmall.AST.Subshell c -> eat_subshells c
      | _ -> c
    in
    Background (parse_command (eat_subshells cmd), redir_state)
  | Morsmall.AST.Seq (cmd1, cmd2) ->
      Semi (parse_command cmd1, parse_command cmd2)
  | Morsmall.AST.And (cmd1, cmd2) -> And (parse_command cmd1, parse_command cmd2)
  | Morsmall.AST.Or (cmd1, cmd2) -> Or (parse_command cmd1, parse_command cmd2)
  | Morsmall.AST.Not cmd -> Not (parse_command cmd)
  | Morsmall.AST.Pipe (cmd1, cmd2) ->
    let rec collect_piped_commands (c : Morsmall.AST.command') = 
      match c.value with 
      | Morsmall.AST.Pipe (c1, c2) -> collect_piped_commands c1 @ [c2]
      | _ -> [c] in
    let left_stmts = List.map parse_command (collect_piped_commands cmd1) in
    let right_stmt = parse_command cmd2 in
      Pipe (FG, left_stmts @ [right_stmt])
      (* TODO: ishaangandhi, All pipes are FG. When should we make them background *)
  | Morsmall.AST.Subshell cmd ->
      let redir_state = ([], None, []) in
      Subshell (parse_command cmd, redir_state)
  | Morsmall.AST.For (x, listOpt, c) -> (
      match listOpt with
      | None -> failwith "Empty list in for?"
      | Some l ->
          For (x, morsmall_words_to_smoosh_entries false l, parse_command c)
      )
  | Morsmall.AST.Case (var, cases) ->
      let morsmall_to_smoosh_case_item ({ value; _ } : Morsmall.AST.case_item')
          =
        let wl, cmdOpt = value in
        let smoosh_cmd =
          match cmdOpt with None -> Done | Some cmd -> parse_command cmd
        in
        let smoosh_wl =
            (* List.iter (fun x -> print_endline @@ Morsmall.AST.show_word x) wl.value; *)
          morsmall_wordvals_to_smoosh_words_list false wl.value
        in
        (smoosh_wl, smoosh_cmd)
      in
      let smoosh_words = morsmall_word_to_smoosh_entries false var in
      let smoosh_case_items = List.map morsmall_to_smoosh_case_item cases in
      Case (smoosh_words, smoosh_case_items)
  (* execute c1 and use its exit status to determine whether to execute c2 or c3.
     In fact, c3 is not mandatory and is thus an option. *)
  | Morsmall.AST.If (c1, c2, c3) ->
      let else_stmt =
        match c3 with 
          None -> Command ([], [], [], command_opts) 
        | Some c3val -> parse_command c3val
      in
      If (parse_command c1, parse_command c2, else_stmt)
  (* The while Loop. While (c1, c2) shall continuously execute c2 as long as c1
     has a zero exit status. *)
  | Morsmall.AST.While (c1, c2) -> While (parse_command c1, parse_command c2)
  (* The until Loop. Until (c1, c2) shall continuously execute c2 as long as c1
     has a non-zero exit status. *)
  | Morsmall.AST.Until (c1, c2) ->
      While (Not (parse_command c1), parse_command c2)
  (* A function is a user-defined name that is used as a simple command to call
     a compound command with new positional parameters. A function is defined with a
     function definition command, Function (name, body). *)
  (* This function definition command defines a function named name: string
     and with body body: command. The body shall be executed whenever name is
     specified as the name of a simple command. *)
  | Morsmall.AST.Function (name, body) -> Defun (name, parse_command body)
  (* Redirection is somewhat complicated.
  We want to make sure that the redirection (even when nested) of a simple
  command shows up as a "Command" in Smooosh's internal AST, but the redirection
  of anything else shows up as a "Redir" *)
  | Morsmall.AST.Redirection (c, desc, _, w) 
  | Morsmall.AST.HereDocument (c, desc, w) -> 
    let (c', redirs) = collect_redirs ({value; position}: Morsmall.AST.command') in 
    let ({value ; position} : Morsmall.AST.command') = c' in
    (match value with
      | Morsmall.AST.Simple (assignments, words) -> 
        let assignments = List.map morsmall_to_smoosh_assignment assignments in
        let args = morsmall_words_to_smoosh_entries false words in
        Command (assignments, args, redirs, command_opts)
      | _ -> Redir (parse_command c', ([], None, redirs)))

and morsmall_to_smoosh_redir desc kind w =
    let redir_words = morsmall_word_to_smoosh_entries false w in
    (match kind with
    | Morsmall.AST.Output -> RFile (To, desc, redir_words)
    | Morsmall.AST.OutputDuplicate -> RDup (ToFD, desc, redir_words)
    | Morsmall.AST.OutputAppend -> RFile (Append, desc, redir_words)
    | Morsmall.AST.OutputClobber -> RFile (Clobber, desc, redir_words)
    | Morsmall.AST.Input -> RFile (From, desc, redir_words)
    | Morsmall.AST.InputDuplicate -> RDup (FromFD, desc, redir_words)
    | Morsmall.AST.InputOutput -> RFile (FromTo, desc, redir_words))

and collect_redirs ({ value; position } : Morsmall.AST.command') 
  : Morsmall.AST.command' * redir list =
  match value with
  | Morsmall.AST.Redirection (c, desc, kind, w) ->
     let (c', rest) = collect_redirs c in
     (c', morsmall_to_smoosh_redir desc kind w :: rest)
  | Morsmall.AST.HereDocument (c, desc, w) -> 
    let (c', rest) = collect_redirs c in
    (c', RHeredoc (XHere, desc, morsmall_word_to_smoosh_entries false w) :: rest)
  | _ -> 
    ({ value; position}, [])

let morbig_cst_to_smoosh_ast cst =
  let ast = Morsmall.CST_to_AST.program__to__program cst in
  (* Morsmall.pp_print_debug Format.std_formatter ast; *)
  parse_program true ast
 
let parse_file_morbig (file : string) : Smoosh_prelude.stmt =
  try
    morbig_cst_to_smoosh_ast @@ Morbig.parse_file file
  with e -> 
    print_endline (Morbig.Errors.string_of_error e);
    Done


let parse_string_morbig (cmd : string) : Smoosh_prelude.stmt =
  try
    morbig_cst_to_smoosh_ast @@ Morbig.parse_string ("======" ^ cmd ^ "=====") cmd
  with e -> 
    print_endline (Morbig.Errors.string_of_error e);
    Done


module Vars = Map.Make(String)

let morbig_vars = ref Vars.empty

let on_ps1 () = Printf.eprintf "%s" @@ Vars.find "PS1" !morbig_vars

let on_ps2 () = Printf.eprintf "%s" @@ Vars.find "PS2" !morbig_vars

let lexer_state : Lexing.lexbuf option ref = ref None

let parser_state : Engine.state option ref = ref None

let input_source = ref None

let parse_next i : parse_result = 
  let res = match i with
  | Interactive -> (
    (* Call interactive mode API *)
    match !lexer_state with
      None -> failwith "No lexbuf to parse from"
    | Some buf ->
      try
        let next_lexbuf, next_parser_state, next_cst =
        Morbig.parse_string_interactive on_ps2 buf !parser_state in
        parser_state := Some next_parser_state;
        lexer_state := Some next_lexbuf;
        ParseStmt (morbig_cst_to_smoosh_ast next_cst.value)
      with End_of_file -> ParseDone
    )
  | Noninteractive ->
    (* Just parse from input_source with the normal Morbig API *)
    match !input_source with
    | None -> (
      match !unparsed_commands with
      | [] -> ParseDone
      | cmd :: rest ->
        ParseStmt (parse_program true !unparsed_commands)
    )
    | Some src ->
      input_source := None;
      match src with
      | ParseSTDIN -> failwith "Can not parse from STDIN non-interactively"
      | ParseString (mode, cmd) -> 
          let stmt = parse_string_morbig cmd in
          ParseStmt stmt
      | ParseFile (file, push) -> 
          let stmt = parse_file_morbig file in
          ParseStmt stmt
  in res

let bad_file file msg =
  let prog = Filename.basename Sys.executable_name in
  Printf.eprintf "%s: file '%s' %s\n%!" prog file msg;
  exit 3

let parse_init src = 
input_source := Some src;
unparsed_commands := [];
match src with
| ParseSTDIN -> 
    lexer_state := Some (Morbig__ExtPervasives.lexing_make_interactive "STDIN");
    None
| ParseString (mode, cmd) ->
    Some cmd
| ParseFile (file, push) -> 
    (* failwith "can't parse files"; *)
    if not (Sys.file_exists file)
    then bad_file file "not found"
    else try 
        Unix.access file [Unix.F_OK; Unix.R_OK];
        (* Dash.setinputfile ~push:(should_push_file push) file;  *)
        None
      with Unix.Unix_error(_,_,_) -> bad_file file "unreadable"

let parse_done m_ss m_smark = ()

let parse_string = parse_string_morbig

let morbig_setvar x v =
  match try_concrete v with
  (* don't copy over special variables *)
  | Some s when not (is_special_param x) -> 
      morbig_vars := Vars.add x s !morbig_vars;
  | _ -> ()