# change these paths as necessary

PRELUDEFILES=smoosh_num.lem signal.lem smoosh_prelude.lem signal_platform.lem os.lem 
LEMFILES=smoosh.lem arith.lem pattern.lem path.lem command.lem semantics.lem

OCAMLOPTS=-w -a+3+8+10+14+21+24+29+31+46+47+48 -package dash,lem_num -linkpkg

MLFILES=config.ml system.ml $(PRELUDEFILES:.lem=.ml) shim.ml $(LEMFILES:.lem=.ml)
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

.PHONY : all test clean veryclean

all : expand shell runtest

test : runtest
	./runtest

expand : $(MLFILES) expand.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

shell : $(MLFILES) shell.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

runtest : $(MLFILES) $(TESTFILES) runtest.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

signal_platform.lem : mk_signal_platform.sh
	./mk_signal_platform.sh >signal_platform.lem

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(PRELUDEFILES:.lem=.ml) $(LEMFILES:.lem=.ml)
	-rm expand shell runtest
	-rm *.{cmi,cmo,cmx,o} *~

veryclean : clean
	-rm -f signal_platform.lem
