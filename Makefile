LEMFILES=expansion.lem test.lem

MLFILES=$(LEMFILES:.lem=.ml)

compile : $(MLFILES)
	ocamlc -I ocaml-lib -I ocaml-lib/dependencies/zarith -I . zarith.cma nums.cma extract.cma $^

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
