LEMFILES=fsh_prelude.lem arith.lem locale.lem pattern.lem expansion.lem

OCAMLOPTS=-w -a+3+10+14+21+24+29+31+46+47+48
OCAMLLIB=$(shell opam config var lib)
OCAMLINCLUDES=-I ocaml-lib -I ocaml-lib/dependencies/zarith -I ../libdash -I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes -I /usr/local/lib/ocaml -I ocaml-lib
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa
OCAMLGENLIBS=zarith.cmxa nums.cmxa extract.cmxa

MLFILES=$(LEMFILES:.lem=.ml) test_prelude.ml test_arith.ml test_expansion.ml

expand : $(MLFILES) expand.ml
	ocamlopt.opt $(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLLIBS) $(OCAMLGENLIBS) dash.cmxa $^ -o $@ 

runtest : $(MLFILES) runtest.ml
	ocamlopt.opt $(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLGENLIBS) $^ -o $@ 

test : runtest
	./runtest

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo} *~
