open Lem_pervasives_extra
open Arith
open Printf

let string_of_token tkn : string =
  match tkn with
    TNum n -> "NUM " ^ (Nat_big_num.to_string n)
  | TVar s -> "VAR " ^ s
  | TPlus -> "PLUS"
  | TMinus -> "MINUS"
  | TTimes -> "TIMES"
  | TDiv -> "DIV"
  | TMod -> "MOD"
  | TBitNot -> "BITNOT"
  | TBoolNot -> "BOOLNOT"
  | TLShift -> "LSHIFT"
  | TRShift -> "RSHIFT"
  | TLt -> "LT"
  | TLte -> "LTE"
  | TGt -> "GT"
  | TGte -> "GTE"
  | TEq -> "EQ"
  | TNEq -> "NEQ"
  | TBitAnd -> "BITAND"
  | TBitOr -> "BITOR"
  | TBitXOr -> "BITXOR"
  | TBoolAnd -> "BOOLAND"
  | TBoolOr -> "BOOLOR"
  | TQuestion -> "Q"
  | TColon -> "COLON"
  | TVarEq -> "VEQ"
  | TVarPlusEq -> "VPEQ"
  | TVarMinusEq -> "VMEQ"
  | TVarTimesEq -> "VTEQ"
  | TVarDivEq -> "VDEQ"
  | TVarModEq -> "VMEQ"
  | TVarLShiftEq -> "VLShiftEQ"
  | TVarRShiftEq -> "VRShiftEQ"
  | TVarBitAndEq -> "VBANDEQ"
  | TVarBitOrEq -> "VBOREQ"
  | TVarBitXOrEq -> "VBXOREQ"
  | TLParen -> "LP"
  | TRParen -> "RP"

let rec list_to_string = function		
  [] -> ""		
  | [t] -> string_of_token t
  | t::ts -> (string_of_token t) ^ " " ^ (list_to_string ts)

(* test_name expected got *)
type lex_res = LexOk | LexErr of string * (arith_token list) * (arith_token list)
type parse_res = ParseOk | ParseErr of string * arith_exp * arith_exp

let check_lexer (test_name, s_in, t_expected):lex_res=
  (let t_out = lexer (Xstring.explode s_in) in
  if (listEqualBy (=) t_out t_expected)
  then LexOk
  else LexErr (test_name, t_expected, t_out))


let lexer_tests:(string*string*(arith_token)list)list=
 ([
   ("number 5", "5", [TNum (Nat_big_num.of_int 5)]);
   ("number 1234567890", "1234567890", [TNum (Nat_big_num.of_int 1234567890)]);

   ("var x", "x", [TVar "x"]);
   ("var LongVarWithCaps", "LongVarWithCaps", [TVar "LongVarWithCaps"]);

   (* Arithmetic ops *)
   ("Plus operator", "+", [TPlus]);
   ("Minus operator", "-", [TMinus]);
   ("Times operator", "*", [TTimes]);
   ("Div operator", "/", [TDiv]);
   ("Mod operator", "%", [TMod]);

   ("Bitwise negation operator", "~", [TBitNot]);
   ("Logical not operator", "!", [TBoolNot]);

   ("Bitwise left shift operator", "<<", [TLShift]);
   ("Bitwise right shift operator", ">>", [TRShift]);

   (* Comparison ops *)
   ("Less than comparison operator", "<", [TLt]);
   ("Less than or equal comparison operator", "<=", [TLte]);
   ("Greater than comparison operator", ">", [TGt]);
   ("Greater than or equal comparison operator", ">=", [TGte]);
   ("Equal to comparison operator", "==", [TEq]);
   ("Not equal to comparison operator", "!=", [TNEq]);
   
   ("Bitwise and operator", "&", [TBitAnd]);
   ("Bitwise or operator", "|", [TBitOr]);
   ("Bitwise xor operator", "^", [TBitXOr]);

   ("Logical and operator", "&&", [TBoolAnd]);
   ("Logical or operator", "||", [TBoolOr]);

   ("", "? :", [TQuestion; TColon]);

   (* Assignment operators *)
   ("Assignment var equals operator", "=", [TVarEq]);
   ("Assignment var plus equals operator", "+=", [TVarPlusEq]);
   ("Assignment var minus equals operator", "-=", [TVarMinusEq]);
   ("Assignment var times equals operator", "*=", [TVarTimesEq]);
   ("Assignment var div equals operator", "/=", [TVarDivEq]);
   ("Assignment var mod equals operator", "%=", [TVarModEq]);

   ("Assignment var lshift equals operator", "<<=", [TVarLShiftEq]);
   ("Assignment var rshift equals operator", ">>=", [TVarRShiftEq]);

   ("Assignment var bitwise and equals operator", "&=", [TVarBitAndEq]);
   ("Assignment var bitwise or equals operator", "|=", [TVarBitOrEq]);
   ("Assignment var bitwise xor equals operator", "^=", [TVarBitXOrEq]);

   ("Left parenthesis", "(", [TLParen]);
   ("Right parenthesis", ")", [TRParen]);

  ])

let run_tests () =
  let failed = ref 0 in
  print_endline "\n=== Running arithmetic tests...";
  List.iter
    (fun t ->
      match check_lexer t with
      | LexOk -> ()
      | LexErr(name,expected,got) ->
         printf "Lexer test: %s failed: expected '%s' got '%s'\n"
                name (list_to_string expected) (list_to_string got);
         incr failed)
    lexer_tests;
  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" (List.length lexer_tests) !failed
