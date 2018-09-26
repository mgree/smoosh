let main () =
  Test_arith.run_tests ();
  Test_path.run_tests ();
  Test_expansion.run_tests ();
  Test_evaluation.run_tests ()

let _ = main ();;
