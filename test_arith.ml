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
  checker (lexer instance_Arith_Read_Num_integer_dict) (listEqualBy (=)) (name, Xstring.explode input, expected_out)

let check_parser = checker (parse_arith_exp) (=)

let check_eval_big_num (name, input, expected_out) =
  checker arith_big_num (=) (name, Xstring.explode input, expected_out)

let check_eval_int32 (name, input, expected_out) =
  checker arith32 (=) (name, Xstring.explode input, expected_out)
let check_eval_int64 (name, input, expected_out) =
  checker arith64 (=) (name, Xstring.explode input, expected_out)

let lexer_tests:(string*string*(Nat_big_num.num arith_token)list)list=
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

let lex_string str = lexer instance_Arith_Read_Num_integer_dict (Xstring.explode str)
let num n = Num (Nat_big_num.of_int n)

let parser_tests:(string*(Nat_big_num.num arith_token)list*(string, Nat_big_num.num arith_exp)Either.either)list=
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

let eval_tests ofNumLiteral : (string * string * (string, 'a )Either.either)list=
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
  test_part "Lexer" check_lexer token_list_to_string lexer_tests test_count failed;

  (* Parser tests *)
  test_part "Parser" check_parser (Either.either_case id string_of_aexp) parser_tests test_count failed;

  (* Eval tests *)
  test_part "Eval Nat_big_num" check_eval_big_num (Either.either_case id Nat_big_num.to_string) (eval_tests Nat_big_num.of_int) test_count failed;
  test_part "Eval int32" check_eval_int32 (Either.either_case id Int32.to_string) (eval_tests Int32.of_int) test_count failed;
  test_part "Eval int64" check_eval_int64 (Either.either_case id Int64.to_string) (eval_tests Int64.of_int) test_count failed;

  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" !test_count !failed
