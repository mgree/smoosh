OCAMLOPTS=-g -w -a+3+8+10+14+21+24+29+31+46+47+48 -package dash,lem_num,extunix -linkpkg

SRCFILES=config.ml smoosh_num.lem signal.lem smoosh_prelude.lem signal_platform.lem \
	 shim.ml os.lem os_symbolic.lem system.ml os_system.lem smoosh.lem arith.lem \
	 pattern.lem path.lem fields.lem test.lem command.lem semantics.lem
MLFILES=$(SRCFILES:.lem=.ml)
LEMFILES=$(filter %.lem,$(SRCFILES))
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

.PHONY : all all.byte install test loc rebuild clean veryclean

all : shtepper smoosh runtest

all.byte : shtepper.byte smoosh.byte runtest.byte

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

smoosh.byte : $(MLFILES) shell.ml
	ocamlfind ocamlc $(OCAMLOPTS) -o $@ $^

signal_platform.lem : mk_signal_platform.sh
	./mk_signal_platform.sh >signal_platform.lem

loc :  $(SRCFILES)
	@echo "Source LOC: "
	wc -l $(SRCFILES) shtepper.ml shell.ml
	@echo "Test LOC: "
	wc -l $(TESTFILES) runtest.ml

%.ml : %.lem
	lem -ocaml $<

rebuild : 
	-rm shtepper smoosh runtest shtepper.byte smoosh.byte runtest.byte
	$(MAKE) all

clean :
	-rm -f $(LEMFILES:.lem=.ml)
	-rm shtepper smoosh runtest shtepper.byte smoosh.byte runtest.byte
	-rm *.{cmi,cmo,cmx,o} *~

veryclean : clean
	-rm -f signal_platform.lem
