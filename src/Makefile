# change these paths as necessary
LIBDASH=../libdash

LEMOCAML=$(LEMLIB)/../ocaml-lib

PRELUDEFILES=fsh_num.lem signal.lem fsh_prelude.lem signal_platform.lem os.lem 
LEMFILES=fsh.lem arith.lem pattern.lem path.lem command.lem semantics.lem

OCAMLOPTS=-w -a+3+8+10+14+21+24+29+31+46+47+48
OCAMLLIB=$(shell opam config var lib)
# belt and suspenders here for the OCAML library directory... :(
OCAMLINCLUDES=-I $(LEMOCAML) -I $(LEMOCAML)/dependencies/zarith -I $(LEMOCAML)/_build_num -I $(LIBDASH)/ocaml -I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa
OCAMLGENLIBS=zarith.cmxa nums.cmxa extract.cmxa

MLFILES=config.ml system.ml $(PRELUDEFILES:.lem=.ml) shim.ml $(LEMFILES:.lem=.ml)
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

OCAMLARGS=$(OCAMLOPTS) $(OCAMLINCLUDES) $(OCAMLLIBS) $(OCAMLGENLIBS) dash.cmxa

.PHONY : all clean veryclean test dash.cmxa

all : expand shell runtest

test : runtest
	./runtest

expand : $(MLFILES) expand.ml
	$(MAKE) dash.cmxa
	ocamlopt.opt $(OCAMLARGS) $^ -o $@ 

shell : $(MLFILES) shell.ml
	$(MAKE) dash.cmxa
	ocamlopt.opt $(OCAMLARGS) $^ -o $@ 

runtest : $(MLFILES) $(TESTFILES) runtest.ml
	$(MAKE) dash.cmxa
	ocamlopt.opt $(OCAMLARGS) $^ -o $@

signal_platform.lem : mk_signal_platform.sh
	./mk_signal_platform.sh >signal_platform.lem

dash.cmxa : $(LIBDASH)/ocaml/dash.cmxa libdash.a

libdash.a : $(LIBDASH)/ocaml/libdash.a
	cp $< $@

$(LIBDASH)/ocaml/dash.cmxa :
	make -C $(LIBDASH)/ocaml dash.cmxa

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(PRELUDEFILES:.lem=.ml) $(LEMFILES:.lem=.ml)
	-rm expand shell runtest
	-rm *.{cmi,cmo,cmx,o} *~

veryclean : clean
	-rm -f signal_platform.lem
	-rm -f libdash.a
