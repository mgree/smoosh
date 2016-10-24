LEMFILES=expansion.lem test.lem

MLFILES=$(LEMFILES:.lem=.ml)

compile : $(MLFILES)
	ocamlc -I ocaml-lib -I . nums.cma extract.cma $^

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
