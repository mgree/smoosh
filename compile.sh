#!/bin/sh

# build libdash
(cd libdash; ./autogen.sh && ./configure && make)
# build ocaml bindings
(cd libdash/ocaml; make && make test)
# build smoosh
(cd src; make && make test)
