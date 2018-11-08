open Test_prelude
open Smoosh_num
open Smoosh
open Os_symbolic
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

let rec token_list_to_string = function
  [] -> ""
  | [t] -> string_of_token t
  | t::ts -> (string_of_token t) ^ " " ^ (token_list_to_string ts)

let rec string_of_aexp aexp : string = "Aexp" (* TODO 2018-08-10 fixme *)

let check_lexer (name, input, expected_out) =
  checker 
    lexer_integer
    (Either.eitherEqualBy (=) (Lem_list.listEqualBy eq_token_integer))
    (name, Xstring.explode input, expected_out)

let check_parser = 
  checker 
    (either_monad parse_arith_exp) 
    (Either.eitherEqualBy (=) eq_arith_integer)
                 
let eval_equals out expected =
  match (out, expected) with
  | (Either.Right (s1, n1), Either.Right (s2, n2)) -> n1 = n2 && (Pmap.equal (=) s1.sh.env s2.sh.env)
  | (Either.Left e1, Either.Left e2) -> e1 = e2
  | _ -> false

let check_eval_big_num (name, state, input, expected_out) =
  checker (symbolic_arith_big_num state) eval_equals (name, List.map (fun c -> Smoosh.C c) (Xstring.explode input),
    either_monad (fun (st, n) -> Right (st, integerToFields n)) expected_out)

let check_eval_int32 (name, state, input, expected_out) =
  checker (symbolic_arith32 state) eval_equals (name, List.map (fun c -> Smoosh.C c) (Xstring.explode input),
    either_monad (fun (st, n) -> Right (st, int32ToFields n)) expected_out)

let check_eval_int64 (name, state, input, expected_out) =
  checker (symbolic_arith64 state) eval_equals (name, List.map (fun c -> Smoosh.C c) (Xstring.explode input),
    either_monad (fun (st, n) -> Right (st, int64ToFields n)) expected_out)

let lexer_tests:(string*string*(string, (Nat_big_num.num arith_token)list)Either.either)list=
 ([
   ("number 5", "5", Right [TNum (Nat_big_num.of_int 5)]);
   ("number 1234567890", "1234567890", Right [TNum (Nat_big_num.of_int 1234567890)]);
   ("octal 0755", "0755", Right [TNum (Nat_big_num.of_int 493)]);
   ("hex 0xFf", "0xFf", Right [TNum (Nat_big_num.of_int 255)]);

   ("large number 9223372036854775808", "9223372036854775808", Right [TNum (Nat_big_num.pow_int (Nat_big_num.of_int 2) 63)]);

   ("var x", "x", Right [TVar "x"]);
   ("var LongVarWithCaps", "LongVarWithCaps", Right [TVar "LongVarWithCaps"]);

   (* Arithmetic ops *)
   ("Plus operator", "+", Right [TPlus]);
   ("Minus operator", "-", Right [TMinus]);
   ("Times operator", "*", Right [TTimes]);
   ("Div operator", "/", Right [TDiv]);
   ("Mod operator", "%", Right [TMod]);

   ("Bitwise negation operator", "~", Right [TBitNot]);
   ("Logical not operator", "!", Right [TBoolNot]);

   ("Bitwise left shift operator", "<<", Right [TLShift]);
   ("Bitwise right shift operator", ">>", Right [TRShift]);

   (* Comparison ops *)
   ("Less than comparison operator", "<", Right [TLt]);
   ("Less than or equal comparison operator", "<=", Right [TLte]);
   ("Greater than comparison operator", ">", Right [TGt]);
   ("Greater than or equal comparison operator", ">=", Right [TGte]);
   ("Equal to comparison operator", "==", Right [TEq]);
   ("Not equal to comparison operator", "!=", Right [TNEq]);

   ("Bitwise and operator", "&", Right [TBitAnd]);
   ("Bitwise or operator", "|", Right [TBitOr]);
   ("Bitwise xor operator", "^", Right [TBitXOr]);

   ("Logical and operator", "&&", Right [TBoolAnd]);
   ("Logical or operator", "||", Right [TBoolOr]);

   ("", "? :", Right [TQuestion; TColon]);

   (* Assignment operators *)
   ("Assignment var equals operator", "=", Right [TVarEq]);
   ("Assignment var plus equals operator", "+=", Right [TVarPlusEq]);
   ("Assignment var minus equals operator", "-=", Right [TVarMinusEq]);
   ("Assignment var times equals operator", "*=", Right [TVarTimesEq]);
   ("Assignment var div equals operator", "/=", Right [TVarDivEq]);
   ("Assignment var mod equals operator", "%=", Right [TVarModEq]);

   ("Assignment var lshift equals operator", "<<=", Right [TVarLShiftEq]);
   ("Assignment var rshift equals operator", ">>=", Right [TVarRShiftEq]);

   ("Assignment var bitwise and equals operator", "&=", Right [TVarBitAndEq]);
   ("Assignment var bitwise or equals operator", "|=", Right [TVarBitOrEq]);
   ("Assignment var bitwise xor equals operator", "^=", Right [TVarBitXOrEq]);

   ("Left parenthesis", "(", Right [TLParen]);
   ("Right parenthesis", ")", Right [TRParen]);

  ])

let lex_string str = lexer_integer (Xstring.explode str)
let num n = Num (Nat_big_num.of_int n)

let parser_tests:(string*(string,(Nat_big_num.num arith_token)list)Either.either*(string, Nat_big_num.num arith_exp)Either.either)list=
 ([
   ("single number", lex_string "13", Right(Num (Nat_big_num. of_int 13)));
   ("two number additon 2 + 3", lex_string "2 + 3", Right(BinOp (Plus, num 2, num 3)));
   ("two number subtraction 17 - 6", lex_string "17 - 6", Right(BinOp (Minus, num 17, num 6)));
   ("two number multiplication 4 * 8", lex_string "4 * 8", Right(BinOp (Times, num 4, num 8)));
   ("two number division 9 / 3", lex_string "9 / 3", Right(BinOp (Div, num 9, num 3)));
   ("two number mod 5 % 2", lex_string "5 % 2", Right(BinOp (Mod, num 5, num 2)));

   ("multiplication binds tighter than addition", lex_string "3+5*9", Right(BinOp (Plus, num 3, (BinOp (Times, num 5, num 9)))));
   ("division binds tighter than subtraction", lex_string "19-6 / 2", Right(BinOp (Minus, num 19, BinOp (Div, num 6, num 2))));

   ("single - parses as negation", lex_string "1 - -5", Right(BinOp (Minus, num 1, Neg(num 5))));

   ("Bitwise not on number", lex_string "~16 + 279", Right(BinOp (Plus, BitNot(num 16), num 279)));
   ("Bitwise not on expression", lex_string "~(16 - 279)", Right(BitNot (BinOp (Minus, num 16, num 279))));

   ("Logical not on number", lex_string "!47 / 4", Right(BinOp (Div, BoolNot(num 47), num 4)));
   ("Logical not on expression", lex_string "!(47 * 4)", Right(BoolNot (BinOp (Times, num 47, num 4))));

   ("Bitwise shift on numbers", lex_string "4 << 2 >> 32", Right(BinOp (RShift, BinOp (LShift, num 4, num 2), num 32)));
   ("Bitwise shift precedence", lex_string "3*2 << 2 + 4", Right((BinOp (LShift, BinOp (Times, num 3, num 2), BinOp (Plus, num 2, num 4)))));

   ("Simple assignment with variables", lex_string "x=x+1", Right(AssignVar ("x", None, BinOp (Plus, Var "x", num 1))));

 ])

(* let big_num = Int64.of_int Nat_big_num.of_int *)

let eval_tests ofNumLiteral mul : (string * symbolic os_state * string * (string, symbolic os_state * 'a )Either.either)list=
  [
    ("bare number", os_empty, "47", Right (os_empty, ofNumLiteral 47));

    ("addition two numbers", os_empty, "23 + 24", Right (os_empty, ofNumLiteral 47));
    ("addition three numbers", os_empty, "15 + 15 + 17", Right (os_empty, ofNumLiteral 47));
    ("addition three numbers parens left", os_empty, "(15 + 15) + 17", Right (os_empty, ofNumLiteral 47));
    ("addition three numbers parens right", os_empty, "15 + (15 + 17)", Right (os_empty, ofNumLiteral 47));

    ("subtraction two numbers", os_empty, "53 - 6", Right (os_empty, ofNumLiteral 47));
    ("subtraction three numbers", os_empty, "47 - 15 - 17", Right (os_empty, ofNumLiteral 15));
    ("subtraction three numbers parens left", os_empty, "(47 - 15) - 17", Right (os_empty, ofNumLiteral 15));
    ("subtraction three numbers parens right", os_empty, "47 - (15 - 17)", Right (os_empty, ofNumLiteral 49));

    ("multiplication two numbers", os_empty, "3 * 7", Right (os_empty, ofNumLiteral 21));
    ("multiplication three numbers", os_empty, "2 * 3 * 4", Right (os_empty, ofNumLiteral 24));
    ("multiplication three numbers parens left", os_empty, "(2 * 3) * 4", Right (os_empty, ofNumLiteral 24));
    ("multiplication three numbers parens right", os_empty, "2 * (3 * 4)", Right (os_empty, ofNumLiteral 24));

    ("division two numbers", os_empty, "10 / 2", Right (os_empty, ofNumLiteral 5));
    ("division three numbers", os_empty, "12 / 3 / 2", Right (os_empty, ofNumLiteral 2));
    ("division three numbers parens left", os_empty, "(12 / 3) / 2", Right (os_empty, ofNumLiteral 2));
    ("division three numbers parens right", os_empty, "12 / (3 / 2)", Right (os_empty, ofNumLiteral 12));

    ("modulo two numbers", os_empty, "10 % 2", Right (os_empty, ofNumLiteral 0));
    ("modulo three numbers", os_empty, "12 % 3 % 2", Right (os_empty, ofNumLiteral 0));
    ("modulo three numbers parens left", os_empty, "(12 % 3) % 2", Right (os_empty, ofNumLiteral 0));
    ("modulo three numbers parens right", os_empty, "12 % (3 % 2)", Right (os_empty, ofNumLiteral 0));

    ("left shift two numbers", os_empty, "10 << 2", Right (os_empty, ofNumLiteral 40));
    ("left shift three numbers", os_empty, "12 << 3 << 2", Right (os_empty, ofNumLiteral 384));
    ("left shift three numbers parens left", os_empty, "(12 << 3) << 2", Right (os_empty, ofNumLiteral 384));
    ("left shift three numbers parens right", os_empty, "12 << (3 << 2)", Right (os_empty, ofNumLiteral 49152));

    ("right shift two numbers", os_empty, "10 >> 2", Right (os_empty, ofNumLiteral 2));
    ("right shift three numbers", os_empty, "200 >> 3 >> 2", Right (os_empty, ofNumLiteral 6));
    ("right shift three numbers parens left", os_empty, "(200 >> 3) >> 2", Right (os_empty, ofNumLiteral 6));
    ("right shift three numbers parens right", os_empty, "12 >> (3 >> 2)", Right (os_empty, ofNumLiteral 12));

    ("bitwise and two numbers", os_empty, "10 & 7", Right (os_empty, ofNumLiteral 2));
    ("bitwise or two numbers", os_empty, "10 | 7", Right (os_empty, ofNumLiteral 15));

    ("bitwise and/or three numbers", os_empty, "23 & 7 | 8", Right (os_empty, ofNumLiteral 15));
    ("bitwise and/or three numbers parens left", os_empty, "(23 & 7) | 8", Right (os_empty, ofNumLiteral 15));
    ("bitwise and/or three numbers parens right", os_empty, "23 & (7 | 8)", Right (os_empty, ofNumLiteral 7));

    ("bitwise or/and three numbers", os_empty, "4 | 19 & 11", Right (os_empty, ofNumLiteral 7));
    ("bitwise or/and three numbers parens left", os_empty, "(4 | 19) & 11", Right (os_empty, ofNumLiteral 3));
    ("bitwise or/and three numbers parens right", os_empty, "4 | (19 & 11)", Right (os_empty, ofNumLiteral 7));

    ("bitwise xor two numbers", os_empty, "10 ^ 7", Right (os_empty, ofNumLiteral 13));
    ("bitwise xor three numbers", os_empty, "12 ^ 9 ^ 8", Right (os_empty, ofNumLiteral 13));
    ("bitwise xor three numbers parens left", os_empty, "(12 ^ 9) ^ 8", Right (os_empty, ofNumLiteral 13));
    ("bitwise xor three numbers parens right", os_empty, "12 ^ (9 ^ 8)", Right (os_empty, ofNumLiteral 13));

    ("divide by zero ", os_empty, "47 / 0", Left "arithmetic parse error on 47 / 0: Divide by zero");

    ("conditional true", os_empty, "18 ? 47 : 42", Right (os_empty, ofNumLiteral 47));
    ("conditional false", os_empty, "0 ? 47 : 42", Right (os_empty, ofNumLiteral 42));

    ("bitwise negation", os_empty, "~(-48)", Right (os_empty, ofNumLiteral 47));
    ("boolean not", os_empty, "!47", Right (os_empty, ofNumLiteral 0));
    ("boolean not", os_empty, "!0", Right (os_empty, ofNumLiteral 1));

    ("assign x to 5", os_empty, "x=5", Right (os_var_x_five, ofNumLiteral 5));

    ("x plus equals 2, x is set to 5", os_var_x_five, "x+=2", Right (add_literal_env_string "x" "7" os_empty, ofNumLiteral 7));
    ("x minus equals 2, x is set to 5", os_var_x_five, "x-=2", Right (add_literal_env_string "x" "3" os_empty, ofNumLiteral 3));
    ("x times equals 2, x is set to 5", os_var_x_five, "x*=2", Right (add_literal_env_string "x" "10" os_empty, ofNumLiteral 10));
    ("x div equals 2, x is set to 5", os_var_x_five, "x/=2", Right (add_literal_env_string "x" "2" os_empty, ofNumLiteral 2));
    ("x mod equals 2, x is set to 5", os_var_x_five, "x%=2", Right (add_literal_env_string "x" "1" os_empty, ofNumLiteral 1));

    ("x lshift equals 2, x is set to 5", os_var_x_five, "x<<=2", Right (add_literal_env_string "x" "20" os_empty, ofNumLiteral 20));
    ("x rshift equals 2, x is set to 5", os_var_x_five, "x>>=2", Right (add_literal_env_string "x" "1" os_empty, ofNumLiteral 1));
    ("x & equals 2, x is set to 5", os_var_x_five, "x&=2", Right (add_literal_env_string "x" "0" os_empty, ofNumLiteral 0));
    ("x | equals 2, x is set to 5", os_var_x_five, "x|=2", Right (add_literal_env_string "x" "7" os_empty, ofNumLiteral 7));
    ("x ^ equals 2, x is set to 5", os_var_x_five, "x^=2", Right (add_literal_env_string "x" "7" os_empty, ofNumLiteral 7));

    ("x = x + 1, x is unset", os_empty, "x=x+1", Right (add_literal_env_string "x" "1" os_empty, ofNumLiteral 1));
  ]

let eval_bignum_tests ofNumLiteral mul : (string * symbolic os_state * string * (string, symbolic os_state * Nat_big_num.num)Either.either)list =
  [
    ("large number 9223372036854775808", os_empty, "9223372036854775808", Right (os_empty, mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
    ("large hex number 0x8000000000000000", os_empty, "0x8000000000000000", Right (os_empty, mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
    ("large oct number 01000000000000000000000", os_empty, "01000000000000000000000", Right (os_empty, mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
  ]

let eval_int64_tests ofNumLiteral mul : (string * symbolic os_state * string * (string, symbolic os_state * Int64.t)Either.either)list =
  [
    ("large number 9223372036854775808", os_empty, "9223372036854775808", Right (os_empty, int64Max));
    ("large hex number 0x8000000000000000", os_empty, "0x8000000000000000", Right (os_empty, int64Max));
    ("large oct number 01000000000000000000000", os_empty, "01000000000000000000000", Right (os_empty, int64Max));

   ("arithmetic overflow", os_empty, "1073741824 * 1073741824 * 8", Right (os_empty, int64Min));

    ("left shift by negative", os_empty, "15 << -63", Right (os_empty, ofNumLiteral 30));
    ("right shift by negative", os_empty, "15 >> -63", Right (os_empty, ofNumLiteral 7));

    ("right shift uses arithmetic shift", os_empty, "(15 << -1) >> 1", Right (os_empty, Int64.div int64Min (ofNumLiteral 2)));

    ("x minus equals 7 return -2 when x is set to 5", os_var_x_five, "x-=7", Right (add_literal_env_string "x" "-2" os_empty, Int64.neg (ofNumLiteral 2)));
  ]

let eval_int32_tests ofNumLiteral mul : (string * symbolic os_state * string * (string, symbolic os_state * Int32.t)Either.either)list =
  [
    ("large number 9223372036854775808", os_empty, "9223372036854775808", Right (os_empty, int32Max));
    ("large hex number 0x8000000000000000", os_empty, "0x8000000000000000", Right (os_empty, int32Max));
    ("large oct number 020000000000", os_empty, "020000000000", Right (os_empty, int32Max));
    ("large oct number 07777777777777777777777", os_empty, "07777777777777777777777", Right (os_empty, int32Max));

    ("arithmetic overflow", os_empty, "2147483647 + 1", Right (os_empty, int32Min));

    ("left shift by negative", os_empty, "15 << -31", Right (os_empty, ofNumLiteral 30));
    ("right shift by negative", os_empty, "15 >> -31", Right (os_empty, ofNumLiteral 7));

    ("right shift uses arithmetic shift", os_empty, "(15 << -1) >> 1", Right (os_empty, Int32.div int32Min (ofNumLiteral 2)));
  ]

(***********************************************************************)
(* DRIVER **************************************************************)
(***********************************************************************)

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  let prnt = fun (s, n) -> ("<| " ^ (printable_shell_env s) ^ "; " ^ (string_of_fields n) ^ " |>") in
  print_endline "\n=== Running arithmetic tests...";
  (* Lexer tests *)
  test_part "Lexer" check_lexer (Either.either_case id token_list_to_string) lexer_tests test_count failed;

  (* Parser tests *)
  test_part "Parser" check_parser (Either.either_case id string_of_aexp) parser_tests test_count failed;

  (* General eval tests *)
  test_part "General eval Nat_big_num" check_eval_big_num (Either.either_case id prnt) (eval_tests Nat_big_num.of_int Nat_big_num.mul) test_count failed;
  test_part "General eval int32" check_eval_int32 (Either.either_case id prnt) (eval_tests Int32.of_int Int32.mul) test_count failed;
  test_part "General eval int64" check_eval_int64 (Either.either_case id prnt) (eval_tests Int64.of_int Int64.mul) test_count failed;

  (* Type specific eval tests *)
  test_part "Eval Nat_big_num" check_eval_big_num (Either.either_case id prnt) (eval_bignum_tests Nat_big_num.of_int Nat_big_num.mul) test_count failed;
  test_part "Eval int32" check_eval_int32 (Either.either_case id prnt) (eval_int32_tests Int32.of_int Int32.mul) test_count failed;
  test_part "Eval int64" check_eval_int64 (Either.either_case id prnt) (eval_int64_tests Int64.of_int Int64.mul) test_count failed;

  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" !test_count !failed;
  !failed = 0

