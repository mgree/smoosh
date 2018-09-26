.PHONY : all test

all : libdash/ocaml/dash.cmxa
	(cd src; $(MAKE))

test : libdash/ocaml/dash.cmxa src/runtest
	(cd libdash/ocaml; $(MAKE) test)
	(cd src; $(MAKE) test)

libdash/src/libdash.a : libdash/src/*.c libdash/src/*.h
	(cd libdash; ./autogen.sh && ./configure && $(MAKE))

libdash/ocaml/dash.cmxa : libdash/src/libdash.a
	(cd libdash/ocaml; $(MAKE))

clean :
	$(MAKE) -C src           clean
	$(MAKE) -C libdash/ocaml clean
	$(MAKE) -C libdash       clean
