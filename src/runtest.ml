let main () =
  let results = [Test_arith.run_tests ();
                 Test_path.run_tests ();
                 Test_expansion.run_tests ();
                 Test_evaluation.run_tests ()] in
  let exit_code = List.length (List.filter not results) in
  exit exit_code;;

main ()
