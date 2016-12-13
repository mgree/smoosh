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

let check_lexer (test_name, s_in, t_expected) : ((Nat_big_num.num arith_token) list) result=
  (let t_out = lexer instance_Arith_Read_Num_integer_dict (Xstring.explode s_in) in
  if (listEqualBy (=) t_out t_expected)
  then Ok
  else Err {msg = test_name; expected = t_expected; got = t_out})

let check_parser (test_name, token_list_in, aexp_expected) : ((string, Nat_big_num.num arith_exp) Either.either) result =
  (let aexp_out = parse_arith_exp token_list_in in
  if (aexp_out = aexp_expected)
  then Ok
  else Err {msg = test_name; expected = aexp_expected; got = aexp_out})

let arith_big_num = arith instance_Arith_Read_Num_integer_dict
                          instance_Num_NumAdd_Num_natural_dict
                          instance_Num_NumMinus_Num_natural_dict
                          instance_Num_NumMult_Num_natural_dict
                          instance_Num_NumIntegerDivision_Num_natural_dict
                          instance_Num_NumRemainder_Num_natural_dict

let check_eval (test_name, s_in, num_expected) : ((string, Nat_big_num.num) Either.either) result =
  let chars = Xstring.explode s_in in
  let num_out = arith_big_num chars in
  if (num_out = num_expected)
  then Ok
  else Err {msg = test_name; expected = num_expected; got = num_out}

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

let big_num = Nat_big_num.of_int

let eval_tests:(string * string * (string, Nat_big_num.num)Either.either)list=
  [
    ("bare number", "47", Right (big_num 47));

    ("addition two numbers", "23 + 24", Right (big_num 47));
    ("addition three numbers", "15 + 15 + 17", Right (big_num 47));
    ("addition three numbers parens left", "(15 + 15) + 17", Right (big_num 47));
    ("addition three numbers parens right", "15 + (15 + 17)", Right (big_num 47));

    ("subtraction two numbers", "53 - 6", Right (big_num 47));
    ("subtraction three numbers", "47 - 15 - 17", Right (big_num 15));
    ("subtraction three numbers parens left", "(47 - 15) - 17", Right (big_num 15));
    ("subtraction three numbers parens right", "47 - (15 - 17)", Right (big_num 49));

    ("multiplication two numbers", "3 * 7", Right (big_num 21));
    ("multiplication three numbers", "2 * 3 * 4", Right (big_num 24));
    ("multiplication three numbers parens left", "(2 * 3) * 4", Right (big_num 24));
    ("multiplication three numbers parens right", "2 * (3 * 4)", Right (big_num 24));

    ("division two numbers", "10 / 2", Right (big_num 5));
    ("division three numbers", "12 / 3 / 2", Right (big_num 2));
    ("division three numbers parens left", "(12 / 3) / 2", Right (big_num 2));
    ("division three numbers parens right", "12 / (3 / 2)", Right (big_num 12));

    ("modulo two numbers", "10 % 2", Right (big_num 0));
    ("modulo three numbers", "12 % 3 % 2", Right (big_num 0));
    ("modulo three numbers parens left", "(12 % 3) % 2", Right (big_num 0));
    ("modulo three numbers parens right", "12 % (3 % 2)", Right (big_num 0));
  ]

let test_part name checker stringOfExpected tests failed =
  List.iter
    (fun t ->
      match checker t with
      | Ok -> ()
      | Err e ->
         printf "%s test: %s failed: expected '%s' got '%s'\n"
                name e.msg (stringOfExpected e.expected) (stringOfExpected e.got);
         incr failed)
    tests

let run_tests () =
  let failed = ref 0 in
  print_endline "\n=== Running arithmetic tests...";
  (* Lexer tests *)
  test_part "Lexer" check_lexer token_list_to_string lexer_tests failed;

  (* Parser tests *)
  test_part "Parser" check_parser (Either.either_case id string_of_aexp) parser_tests failed;

  (* Eval tests *)
  test_part "Eval" check_eval (Either.either_case id Nat_big_num.to_string) eval_tests failed;

  printf "=== ...ran %d arithmetic tests with %d failures.\n\n" ((List.length lexer_tests)+(List.length parser_tests)+(List.length eval_tests)) !failed

