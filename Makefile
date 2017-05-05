LEMFILES=fsh_prelude.lem arith.lem locale.lem pattern.lem expansion.lem

OCAMLOPTS=-w -a+3+10+14+21+24+29+31+46+47+48

MLFILES=$(LEMFILES:.lem=.ml) test_prelude.ml test_arith.ml test_expansion.ml runtest.ml

runtest : $(MLFILES)
	ocamlc $(OCAMLOPTS) -I ocaml-lib -I ocaml-lib/dependencies/zarith -I . -o $@ zarith.cma nums.cma extract.cma $^ 

test : runtest
	./runtest

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
