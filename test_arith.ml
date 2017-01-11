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

let rec token_list_to_string = function
  [] -> ""
  | [t] -> string_of_token t
  | t::ts -> (string_of_token t) ^ " " ^ (token_list_to_string ts)

let rec string_of_aexp aexp : string = "Aexp"

(* test_name expected got *)
type 'a result = Ok | Err of { msg : string;  expected : 'a; got : 'a }

let checker test_fn equal (test_name, input, expected_out) =
  let out = test_fn input in
  if equal out expected_out
  then Ok
  else Err {msg = test_name; expected = expected_out; got = out}

let check_lexer (name, input, expected_out) =
  checker (lexer instance_Arith_Read_Num_integer_dict) (=) (name, Xstring.explode input, expected_out)

let check_parser = checker (either_monad parse_arith_exp) (=)

let check_eval_big_num (name, input, expected_out) =
  checker arith_big_num (=) (name, Xstring.explode input, expected_out)

let check_eval_int32 (name, input, expected_out) =
  checker arith32 (=) (name, Xstring.explode input, expected_out)
let check_eval_int64 (name, input, expected_out) =
  checker arith64 (=) (name, Xstring.explode input, expected_out)

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

let lex_string str = lexer instance_Arith_Read_Num_integer_dict (Xstring.explode str)
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
 ])

(* let big_num = Int64.of_int Nat_big_num.of_int *)

let eval_tests ofNumLiteral mul : (string * string * (string, 'a )Either.either)list=
  [
    ("bare number", "47", Right (ofNumLiteral 47));

    ("addition two numbers", "23 + 24", Right (ofNumLiteral 47));
    ("addition three numbers", "15 + 15 + 17", Right (ofNumLiteral 47));
    ("addition three numbers parens left", "(15 + 15) + 17", Right (ofNumLiteral 47));
    ("addition three numbers parens right", "15 + (15 + 17)", Right (ofNumLiteral 47));

    ("subtraction two numbers", "53 - 6", Right (ofNumLiteral 47));
    ("subtraction three numbers", "47 - 15 - 17", Right (ofNumLiteral 15));
    ("subtraction three numbers parens left", "(47 - 15) - 17", Right (ofNumLiteral 15));
    ("subtraction three numbers parens right", "47 - (15 - 17)", Right (ofNumLiteral 49));

    ("multiplication two numbers", "3 * 7", Right (ofNumLiteral 21));
    ("multiplication three numbers", "2 * 3 * 4", Right (ofNumLiteral 24));
    ("multiplication three numbers parens left", "(2 * 3) * 4", Right (ofNumLiteral 24));
    ("multiplication three numbers parens right", "2 * (3 * 4)", Right (ofNumLiteral 24));

    ("division two numbers", "10 / 2", Right (ofNumLiteral 5));
    ("division three numbers", "12 / 3 / 2", Right (ofNumLiteral 2));
    ("division three numbers parens left", "(12 / 3) / 2", Right (ofNumLiteral 2));
    ("division three numbers parens right", "12 / (3 / 2)", Right (ofNumLiteral 12));

    ("modulo two numbers", "10 % 2", Right (ofNumLiteral 0));
    ("modulo three numbers", "12 % 3 % 2", Right (ofNumLiteral 0));
    ("modulo three numbers parens left", "(12 % 3) % 2", Right (ofNumLiteral 0));
    ("modulo three numbers parens right", "12 % (3 % 2)", Right (ofNumLiteral 0));

    ("left shift two numbers", "10 << 2", Right (ofNumLiteral 40));
    ("left shift three numbers", "12 << 3 << 2", Right (ofNumLiteral 384));
    ("left shift three numbers parens left", "(12 << 3) << 2", Right (ofNumLiteral 384));
    ("left shift three numbers parens right", "12 << (3 << 2)", Right (ofNumLiteral 49152));

    ("right shift two numbers", "10 >> 2", Right (ofNumLiteral 2));
    ("right shift three numbers", "200 >> 3 >> 2", Right (ofNumLiteral 6));
    ("right shift three numbers parens left", "(200 >> 3) >> 2", Right (ofNumLiteral 6));
    ("right shift three numbers parens right", "12 >> (3 >> 2)", Right (ofNumLiteral 12));

    ("bitwise and two numbers", "10 & 7", Right (ofNumLiteral 2));
    ("bitwise or two numbers", "10 | 7", Right (ofNumLiteral 15));

    ("bitwise and/or three numbers", "23 & 7 | 8", Right (ofNumLiteral 15));
    ("bitwise and/or three numbers parens left", "(23 & 7) | 8", Right (ofNumLiteral 15));
    ("bitwise and/or three numbers parens right", "23 & (7 | 8)", Right (ofNumLiteral 7));

    ("bitwise or/and three numbers", "4 | 19 & 11", Right (ofNumLiteral 7));
    ("bitwise or/and three numbers parens left", "(4 | 19) & 11", Right (ofNumLiteral 3));
    ("bitwise or/and three numbers parens right", "4 | (19 & 11)", Right (ofNumLiteral 7));

    ("bitwise xor two numbers", "10 ^ 7", Right (ofNumLiteral 13));
    ("bitwise xor three numbers", "12 ^ 9 ^ 8", Right (ofNumLiteral 13));
    ("bitwise xor three numbers parens left", "(12 ^ 9) ^ 8", Right (ofNumLiteral 13));
    ("bitwise xor three numbers parens right", "12 ^ (9 ^ 8)", Right (ofNumLiteral 13));

  ]

let eval_bignum_tests ofNumLiteral mul : (string * string * (string, Nat_big_num.num)Either.either)list =
  [
    ("large number 9223372036854775808", "9223372036854775808", Right (mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
    ("large hex number 0x8000000000000000", "0x8000000000000000", Right (mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
    ("large oct number 01000000000000000000000", "01000000000000000000000", Right (mul (mul (ofNumLiteral 65536) (ofNumLiteral 65536)) (mul (ofNumLiteral 65536) (ofNumLiteral 32768))));
  ]

let eval_int64_tests ofNumLiteral mul : (string * string * (string, Int64.t)Either.either)list =
  [
    ("large number 9223372036854775808", "9223372036854775808", Right int64Max);
    ("large hex number 0x8000000000000000", "0x8000000000000000", Right int64Max);
    ("large oct number 01000000000000000000000", "01000000000000000000000", Right int64Max);

    ("left shift by negative", "15 << -63", Right (ofNumLiteral 30));
    ("right shift by negative", "15 >> -63", Right (ofNumLiteral 7));

    ("right shift uses arithmetic shift", "(15 << -1) >> 1", Right (Int64.div int64Min (ofNumLiteral 2)));

  ]

let eval_int32_tests ofNumLiteral mul : (string * string * (string, Int32.t)Either.either)list =
  [
    ("large number 9223372036854775808", "9223372036854775808", Right int32Max);
    ("large hex number 0x8000000000000000", "0x8000000000000000", Right int32Max);
    ("large oct number 020000000000", "020000000000", Right int32Max);
    ("large oct number 01000000000000000000000", "01000000000000000000000", Right int32Max);

    ("left shift by negative", "15 << -31", Right (ofNumLiteral 30));
    ("right shift by negative", "15 >> -31", Right (ofNumLiteral 7));

    ("right shift uses arithmetic shift", "(15 << -1) >> 1", Right (Int32.div int32Min (ofNumLiteral 2)));
  ]

let test_part name checker stringOfExpected tests count failed =
  List.iter
    (fun t ->
      match checker t with
      | Ok -> incr count
      | Err e ->
         printf "%s test: %s failed: expected '%s' got '%s'\n"
                name e.msg (stringOfExpected e.expected) (stringOfExpected e.got);
         incr count; incr failed)
    tests

let run_tests () =
  let failed = ref 0 in
  let test_count = ref 0 in
  print_endline "\n=== Running arithmetic tests...";
  (* Lexer tests *)
  test_part "Lexer" check_lexer (Either.either_case id token_list_to_string) lexer_tests test_count failed;

  (* Parser tests *)
  test_part "Parser" check_parser (Either.either_case id string_of_aexp) parser_tests test_count failed;

  (* General eval tests *)
  test_part "General eval Nat_big_num" check_eval_big_num (Either.either_case id Nat_big_num.to_string) (eval_tests Nat_big_num.of_int Nat_big_num.mul) test_count failed;
  test_part "General eval int32" check_eval_int32 (Either.either_case id Int32.to_string) (eval_tests Int32.of_int Int32.mul) test_count failed;
  test_part "General eval int64" check_eval_int64 (Either.either_case id Int64.to_string) (eval_tests Int64.of_int Int64.mul) test_count failed;

  (* Type specific eval tests *)
  test_part "Eval Nat_big_num" check_eval_big_num (Either.either_case id Nat_big_num.to_string) (eval_bignum_tests Nat_big_num.of_int Nat_big_num.mul) test_count failed;
  test_part "Eval int32" check_eval_int32 (Either.either_case id Int32.to_string) (eval_int32_tests Int32.of_int Int32.mul) test_count failed;
  test_part "Eval int64" check_eval_int64 (Either.either_case id Int64.to_string) (eval_int64_tests Int64.of_int Int64.mul) test_count failed;

  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" !test_count !failed

