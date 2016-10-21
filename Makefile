LEMFILES=t_fs_prelude.lem expansion.lem

MLFILES=lem_support.mli lem_support.ml $(LEMFILES:.lem=.ml)

compile : $(MLFILES)
	ocamlc -c -I ocaml-lib -I . nums.cma extract.cma $^

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
