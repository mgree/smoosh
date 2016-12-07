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

let rec string_of_aexp aexp : string = "Aexp"

(* test_name expected got *)
type lex_res = LexOk | LexErr of string * (arith_token list) * (arith_token list)
type parse_res = ParseOk | ParseErr of string * (string,arith_exp)Either.either * (string,arith_exp)Either.either
let check_lexer (test_name, s_in, t_expected):lex_res=
  (let t_out = lexer (Xstring.explode s_in) in
  if (listEqualBy (=) t_out t_expected)
  then LexOk
  else LexErr (test_name, t_expected, t_out))

let check_parser (test_name, token_list_in, aexp_expected):parse_res=
  (let aexp_out = parse_arith_exp token_list_in in
  if (aexp_out = aexp_expected)
  then ParseOk
  else ParseErr (test_name, aexp_expected, aexp_out))

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

let lex_string str = lexer (Xstring.explode str)
let num n = Num (Nat_big_num.of_int n)

let parser_tests:(string*(arith_token)list*(string, arith_exp)Either.either)list=
 ([
   ("single number", lex_string "13", Right(Num (Nat_big_num. of_int 13)));
   ("two number additon 2 + 3", lex_string "2 + 3", Right(Plus (num 2, num 3)));
   ("two number subtraction 17 - 6", lex_string "17 - 6", Right(Minus (num 17, num 6)));
   ("two number multiplication 4 * 8", lex_string "4 * 8", Right(Times (num 4, num 8)));
   ("two number division 9 / 3", lex_string "9 / 3", Right(Div (num 9, num 3)));
   ("two number mod 5 % 2", lex_string "5 % 2", Right(Mod (num 5, num 2)));

   ("multiplication binds tighter than addition", lex_string "3+5*9", Right(Plus (num 3, (Times (num 5, num 9)))));
   ("division binds tighter than subtraction", lex_string "19-6 / 2", Right(Minus (num 19, Div (num 6, num 2))));

   ("single - parses as negation", lex_string "1 - -5", Right(Minus (num 1, Neg(num 5))));

   ("Bitwise not on number", lex_string "~16 + 279", Right(Plus (BitNot(num 16), num 279)));
   ("Bitwise not on expression", lex_string "~(16 - 279)", Right(BitNot (Minus (num 16, num 279))));

   ("Logical not on number", lex_string "!47 / 4", Right(Div (BoolNot(num 47), num 4)));
   ("Logical not on expression", lex_string "!(47 * 4)", Right(BoolNot(Times (num 47, num 4))));

   ("Bitwise shift on numbers", lex_string "4 << 2 >> 32", Right(RShift (LShift(num 4, num 2), num 32)));
   ("Bitwise shift precedence", lex_string "3*2 << 2 + 4", Right((LShift(Times(num 3, num 2), Plus(num 2, num 4)))));
 ])


let run_tests () =
  let failed = ref 0 in
  print_endline "\n=== Running arithmetic tests...";
  (* Lexer tests *)
  List.iter
    (fun t ->
      match check_lexer t with
      | LexOk -> ()
      | LexErr(name,expected,got) ->
         printf "Lexer test: %s failed: expected '%s' got '%s'\n"
                name (list_to_string expected) (list_to_string got);
         incr failed)
    lexer_tests;

  (* Parser tests *)
  List.iter
    (fun t ->
      match check_parser t with
      | ParseOk -> ()
      | ParseErr(name,expected,got) ->
         printf "Parser test: %s failed: expected '%s' got '%s'\n"
                name ((Either.either_case id string_of_aexp) expected) ((Either.either_case id string_of_aexp) got);
         incr failed)
    parser_tests;

  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" ((List.length lexer_tests)+(List.length parser_tests)) !failed
