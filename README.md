Smoosh (the Symbolic, Mechanized, Observable, Operational SHell) is a formalization of the [POSIX shell standard](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html).

Smoosh is written in a mix of [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) and OCaml, using [libdash](https://github.com/mgree/libdash) to parse shell code.

# How to build it

You'll need to have [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) installed. Wherever you put it, you'll need to edit `src/Makefile` so that `LEMLIB` is defined to point to the Lem `ocaml-lib` directory.

Smoosh depends on [libdash](https://github.com/mgree/libdash), but simply uses it as a submodule.

The default `all` target of the `Makefile` should compile the whole lot and run the unit tests. There will be two resulting executables of interest: `src/expand` is the symbolic expander and `src/shell` is a usable shell.

# How to test it

Run `make test`. It will run the tests in `libdash/ocaml` as well as those in `src/runtest`.
