LEMFILES=arith.lem expansion.lem

MLFILES=$(LEMFILES:.lem=.ml) test_arith.ml test_expansion.ml runtest.ml

runtest : $(MLFILES)
	ocamlc -I ocaml-lib -I ocaml-lib/dependencies/zarith -I . -o $@ zarith.cma nums.cma extract.cma $^

test : runtest
	./runtest

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
