Smoosh (the Symbolic, Mechanized, Observable, Operational SHell) is a formalization of the [POSIX shell standard](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html).

Smoosh is written in a mix of [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) and OCaml, using [libdash](https://github.com/mgree/libdash) to parse shell code.

# How to build it

The easiest way to build the code is with Docker. The included `Dockerfile` will generate an image with Lem and all of the necessary libraries.

To build by hand, you should more or less follow the steps in the Dockerfile, adapting to your system. (For example, on OS X, you'll probably want to install directly to `/usr/local`.)

# How to test it

There are two sets of relevant tests: the libdash tests (in `libdash/test`) and the smoosh tests (in `src`). Both have directories have `Makefile`s with appropriate test targets, so you can test both by running:

```
make -C libdash/test test
make -C src/ test
```

