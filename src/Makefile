OCAMLOPTS=-g -w -a+3+8+10+14+21+24+29+31+46+47+48 -package libdash,lem_num,extunix -linkpkg

SRCFILES=version.lem smoosh_num.lem signal.lem smoosh_prelude.lem signal_platform.lem \
	 shim.ml os.lem os_symbolic.lem system.ml os_system.lem smoosh.lem arith.lem \
	 pattern.lem path.lem fields.lem test.lem command.lem semantics.lem
MLFILES=$(SRCFILES:.lem=.ml)
LEMFILES=$(filter %.lem,$(SRCFILES))
TESTFILES=test_prelude.ml test_arith.ml test_path.ml test_expansion.ml test_evaluation.ml

.PHONY : all all.byte install test loc bump rebuild clean veryclean

all : bump shtepper smoosh runtest

all.byte : smoosh.byte

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

version.lem : mk_version.sh
	./mk_version.sh >version.lem

signal_platform.lem : mk_signal_platform.sh
	./mk_signal_platform.sh >signal_platform.lem

loc :  $(SRCFILES)
	@echo "Source LOC $(SRCFILES):"
	@cloc --force-lang-def=cloc.def --by-file-by-lang $(SRCFILES) shtepper.ml shell.ml
	@echo
	@echo "Test LOC $(TESTFILES):"
	@cloc --force-lang-def=cloc.def --by-file-by-lang $(TESTFILES) runtest.ml

%.ml : %.lem
	lem -ocaml $<

bump :
	if [ -f version.lem ] && [ -d ../.git ] ; then rm version.lem; fi

rebuild : bump
	-rm shtepper smoosh runtest smoosh.byte
	$(MAKE) all

clean : bump
	-rm -f $(LEMFILES:.lem=.ml)
	-rm shtepper smoosh runtest smoosh.byte 
	-rm *.{cmi,cmo,cmx,o} *~

veryclean : clean
	-rm -f signal_platform.lem
