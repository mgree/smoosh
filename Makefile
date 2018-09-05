PRELUDEFILES=fsh_num.lem fsh_prelude.lem os.lem 
LEMFILES=fsh.lem arith.lem pattern.lem path.lem command.lem semantics.lem

OCAMLOPTS=-w -a+3+8+10+14+21+24+29+31+46+47+48
OCAMLLIB=$(shell opam config var lib)
OCAMLINCLUDES=-I ocaml-lib -I ocaml-lib/dependencies/zarith -I ../libdash -I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes -I ocaml-lib
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa
OCAMLGENLIBS=zarith.cmxa nums.cmxa extract.cmxa

MLFILES=config.ml system.ml $(PRELUDEFILES:.lem=.ml) shim.ml $(LEMFILES:.lem=.ml)
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

OCAMLARGS=$(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLLIBS) $(OCAMLGENLIBS) dash.cmxa

.PHONY : all clean test

all : expand shell runtest

test : runtest
	./runtest

expand : $(MLFILES) expand.ml
	ocamlopt.opt $(OCAMLARGS) $^ -o $@ 

shell : $(MLFILES) shell.ml
	ocamlopt.opt $(OCAMLARGS) $^ -o $@ 

runtest : $(MLFILES) $(TESTFILES) runtest.ml
	ocamlopt.opt $(OCAMLARGS) $^ -o $@ 

../libdash/dash.cmxa :
	make -C ../libdash dash.cmxa

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(PRELUDEFILES:.lem=.ml) $(LEMFILES:.lem=.ml)
	-rm *.{cmi,cmo,cmx,o} *~
