open Morbig
open Smoosh_prelude

exception ParseException of string

let rec intercalate sep l =
  match l with
  | [] -> []
  | [elt] -> elt
  | elt::l -> elt @ [sep] @ intercalate sep l

let rec parse_program (program : Morsmall.AST.program) : Smoosh_prelude.stmt =
  match program with
  | [] -> failwith "No program"
  | _ :: _ :: _ -> failwith "Can only handle single program"
  | [ cmd ] -> parse_command cmd

and morsmall_word_to_smoosh_entry ({ value; position } : Morsmall.AST.word') :
    Smoosh_prelude.entry =
  let entries = morsmall_wordval_to_smoosh_entries value in
  assert (List.length entries = 1);
  List.hd entries

and morsmall_word_to_smoosh_entries ({ value; position } : Morsmall.AST.word') :
    Smoosh_prelude.entry list =
  let entries = morsmall_wordval_to_smoosh_entries value in
  entries

and morsmall_words_to_smoosh_entries (words : Morsmall.AST.word' list) :
    Smoosh_prelude.entry list =
  let entries_lists = List.map morsmall_word_to_smoosh_entries words in
  let entries = intercalate Smoosh_prelude.F entries_lists in
  entries

(* and morsmall_wordvals_to_smoosh_entry (words : Morsmall.AST.word list) :
    Smoosh_prelude.entry =
  let entries_lists = List.map morsmall_word_to_smoosh_entries words in
  let entries = List.flatten entries_lists in
  assert (List.length entries = 1);
  List.hd entries *)

(* CASE ITEMS *)
and morsmall_wordvals_to_smoosh_words_list (words : Morsmall.AST.word list) :
    Smoosh_prelude.words list =
  let entries_lists = List.map morsmall_wordval_to_smoosh_entries_no_sep words in
  let rec flatten_strings entry_list = 
    match entry_list with
    S s1 :: S s2 :: r -> flatten_strings @@ S (s1 ^ s2) :: r
    | _ :: r -> (List.hd entry_list) :: flatten_strings r
    | _ -> entry_list
  in
  (* let entries = List.flatten entries_lists in *)
  List.map flatten_strings entries_lists


and morsmall_wordvals_to_smoosh_entries (words : Morsmall.AST.word list) :
    Smoosh_prelude.entry list =
  let entries_lists = List.map morsmall_wordval_to_smoosh_entries words in
  let entries = intercalate Smoosh_prelude.F entries_lists in (* insert separating Fs HERE *)
  entries

(* TODO : Find mapping to smoosh_formats *)
and morsmall_attribute_to_smoosh_format (attr : Morsmall.AST.attribute) =
  match attr with
  | Morsmall.AST.NoAttribute -> Normal
  | Morsmall.AST.ParameterLength _w -> Length
  | Morsmall.AST.UseDefaultValues word -> Default (morsmall_wordval_to_smoosh_entries word)
  | Morsmall.AST.AssignDefaultValues word -> Assign (morsmall_wordval_to_smoosh_entries word)
  | Morsmall.AST.IndicateErrorifNullorUnset word -> Error (morsmall_wordval_to_smoosh_entries word)
  | Morsmall.AST.UseAlternativeValue word -> Alt (morsmall_wordval_to_smoosh_entries word)
  | Morsmall.AST.RemoveSmallestSuffixPattern _ -> Normal
  | Morsmall.AST.RemoveLargestSuffixPattern _ -> Normal
  | Morsmall.AST.RemoveSmallestPrefixPattern _ -> Normal
  | Morsmall.AST.RemoveLargestPrefixPattern _ -> Normal

and morsmall_wordval_to_smoosh_entries (w : Morsmall.AST.word) :
    Smoosh_prelude.entry list =
  let wc_to_substr (wc : Morsmall.AST.word_component) : Smoosh_prelude.entry =
    match wc with
    | Morsmall.AST.Literal s -> if s = "$((0-5))" then print_endline "literal"; S s
    | Morsmall.AST.DoubleQuoted w -> K (Quote ([], morsmall_wordval_to_smoosh_entries w))
    | Morsmall.AST.Variable (name, attribute) ->
        K (Param (name, morsmall_attribute_to_smoosh_format attribute))
    | Morsmall.AST.Subshell p -> K (Backtick (parse_program p))
    | Morsmall.AST.GlobAll -> S "*"
    | Morsmall.AST.GlobAny -> S "."
    | Morsmall.AST.BracketExpression exp -> S "<BracketExpression>"
  in
  List.map wc_to_substr w

(* If 2 S's in a row, insert F between them? *)
and separate_strings str_list =
  match str_list with
  | S s1 :: S s2 :: r -> S s1 :: F :: separate_strings (S s2 :: r)
  | S s :: K c :: r -> S s :: F :: separate_strings (K c :: r)
  | K c :: S s :: r -> K c :: F :: separate_strings (S s :: r)
  | K c1 :: K c2 :: r -> K c1 :: F :: separate_strings (K c2 :: r)
  | _ :: r -> (List.hd str_list) :: separate_strings r
  | [] -> []

and parse_command ({ value; position } : Morsmall.AST.command') :
    Smoosh_prelude.stmt =
  match value with
  | Morsmall.AST.Simple (assignmentList, words) ->
      let command_opts =
        {
          ran_cmd_subst = false;
          should_fork = false;
          force_simple_command = false;
        }
      in
      let morsmall_to_smoosh_assignment
          ({ value; position } : Morsmall.AST.assignment') =
        let aName, aWord = value in
        (aName, morsmall_wordval_to_smoosh_entries aWord)
      in
      let assignments = List.map morsmall_to_smoosh_assignment assignmentList in
      let args = morsmall_words_to_smoosh_entries words in
      Command (assignments, args, [], command_opts)
  | Morsmall.AST.Async cmd -> Done
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
          For (x, morsmall_wordvals_to_smoosh_entries l, parse_command c)
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
          morsmall_wordvals_to_smoosh_words_list wl.value
        in
        (smoosh_wl, smoosh_cmd)
      in
      let smoosh_words = morsmall_wordval_to_smoosh_entries var in
      let smoosh_case_items = List.map morsmall_to_smoosh_case_item cases in
      Case (smoosh_words, smoosh_case_items)
  (* execute c1 and use its exit status to determine whether to execute c2 or c3.
     In fact, c3 is not mandatory and is thus an option. *)
  | Morsmall.AST.If (c1, c2, c3) ->
      let else_stmt =
        match c3 with None -> Done | Some c3val -> parse_command c3val
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
  | Morsmall.AST.Redirection (c, desc, kind, w) -> 
  (* TODO, is this correct? *)
    let redir_words = morsmall_wordval_to_smoosh_entries w in
      let redirs = 
      (match kind with
      | Morsmall.AST.Output -> [RFile (To, desc, redir_words)]
      | Morsmall.AST.OutputDuplicate -> [RDup (ToFD, desc, redir_words)]
      | Morsmall.AST.OutputAppend -> [RFile (Append, desc, redir_words)]
      | Morsmall.AST.OutputClobber -> [RFile (Clobber, desc, redir_words)]
      | Morsmall.AST.Input -> [RFile (From, desc, redir_words)]
      | Morsmall.AST.InputDuplicate -> [RDup (FromFD, desc, redir_words)]
      | Morsmall.AST.InputOutput -> [RFile (FromTo, desc, redir_words)]) 
      in
      let redir_state = ([], None, redirs) in 
      Redir (parse_command c, redir_state)
  | Morsmall.AST.HereDocument (cmd, desc, w) -> 
    let redir_words = morsmall_word_to_smoosh_entries w in
    let redirs = [RHeredoc (Here, desc, redir_words)] in
    let redir_state = ([], None, redirs) in
    Redir (parse_command cmd, redir_state)

(*
let rec collect_redirs ({ value; position } : Morsmall.AST.command') : (MorSmall.AST.command' * _ list) =
  match value with
  | Morsmall.AST.Redirection (c, desc, kind, w) ->
     let (c', rest) = collect_redirs c in
     (c', rest ++ [(desc, kind, w)])
  | _ -> ({ value; position}, [])
 *)
let parse_string_morbig (cmd : string) : Smoosh_prelude.stmt =
  let ast =
    Morsmall.CST_to_AST.program__to__program
    @@ Morbig.parse_string "parse_string_morbig" cmd
  in
  print_endline @@ Morsmall.AST.show_program ast;
  print_endline "------------------------------";
  parse_program ast
  
