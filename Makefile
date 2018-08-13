LEMFILES=fsh_num.lem fsh_prelude.lem os.lem fsh.lem arith.lem pattern.lem path.lem builtin.lem semantics.lem

OCAMLOPTS=-w -a+3+8+10+14+21+24+29+31+46+47+48
OCAMLLIB=$(shell opam config var lib)
OCAMLINCLUDES=-I ocaml-lib -I ocaml-lib/dependencies/zarith -I ../libdash -I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes -I ocaml-lib
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa
OCAMLGENLIBS=zarith.cmxa nums.cmxa extract.cmxa

MLFILES=$(LEMFILES:.lem=.ml) shim.ml test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

expand : $(MLFILES) expand.ml
	ocamlopt.opt $(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLLIBS) $(OCAMLGENLIBS) dash.cmxa $^ -o $@ 

runtest : $(MLFILES) runtest.ml
	ocamlopt.opt $(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLLIBS) $(OCAMLGENLIBS) dash.cmxa $^ -o $@ 

test : runtest
	./runtest

../libdash/dash.cmxa :
	make -C ../libdash dash.cmxa

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo,cmx,o} *~
