OCAMLOPTS=-w -a+3+8+10+14+21+24+29+31+46+47+48 -package dash,lem_num,extunix -linkpkg

SRCFILES=config.ml smoosh_num.lem signal.lem smoosh_prelude.lem signal_platform.lem \
	 shim.ml os.lem os_symbolic.lem system.ml os_system.lem smoosh.lem arith.lem \
	 pattern.lem path.lem fields.lem test.lem command.lem semantics.lem
MLFILES=$(SRCFILES:.lem=.ml)
LEMFILES=$(filter %.lem,$(SRCFILES))
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

.PHONY : all install test loc clean veryclean

all : shtepper smoosh runtest

install : shtepper smoosh
	cp shtepper /usr/local/bin/shtepper
	cp smoosh /usr/local/bin/smoosh

test : runtest
	./runtest

shtepper : $(MLFILES) shtepper.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

smoosh : $(MLFILES) shell.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

runtest : $(MLFILES) $(TESTFILES) runtest.ml
	ocamlfind ocamlopt $(OCAMLOPTS) $^ -o $@

signal_platform.lem : mk_signal_platform.sh
	./mk_signal_platform.sh >signal_platform.lem

loc :  $(SRCFILES)
	@echo "Source LOC: "
	wc -l $(SRCFILES) shtepper.ml shell.ml
	@echo "Test LOC: "
	wc -l $(TESTFILES) runtest.ml

%.ml : %.lem
	lem -ocaml $<

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm shtepper smoosh runtest
	-rm *.{cmi,cmo,cmx,o} *~

veryclean : clean
	-rm -f signal_platform.lem
