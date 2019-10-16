[![Build Status](https://travis-ci.com/mgree/smoosh.svg?branch=master)](https://travis-ci.com/mgree/smoosh)

Smoosh (the Symbolic, Mechanized, Observable, Operational SHell) is a formalization of the [POSIX shell standard](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html); Smoosh is one part of [Michael Greenberg's](http://www.cs.pomona.edu/~michael/) broader [project on the POSIX shell](http://shell.cs.pomona.edu).

Smoosh is written in a mix of [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) and OCaml, using [libdash](https://github.com/mgree/libdash) to parse shell code.

# Installation

There are two ways to install Smoosh: in a Docker container or natively. Because Smoosh depends on many parts and specific versions of some libraries, it is much easier to install via Docker.

## Via Docker (recommended)

To build via Docker, you merely need to fetch the Smoosh repo and its submodules. The `build.sh` script in the base of the repo will invoke the appropriate Docker commands.

```ShellSession
$ git clone --recurse-submodules https://github.com/mgree/smoosh.git
Cloning into 'smoosh'...
... [lots of fetching] ...
Submodule path 'lem': checked out 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
Submodule path 'libdash': checked out 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
Submodule path 'modernish': checked out 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
Submodule path 'oil': checked out 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww'
$ cd smoosh
$ ./build.sh
... [long docker build] ...
Successfully tagged smoosh:latest
... [tests build] ...
Successfully tagged smoosh-test:latest
... [tests run] ...
========================================================================

smoosh v0.1 (build YYYY-MM-DD_HH:MM)

ALL TESTS PASSED
... [more docker builds] ...
Successfully tagged smoosh-web:latest
```

If the build process was successful, there are now three tagged Docker images, which can be run interactively via `docker run -it [image tag]`. The three images are:

  - `smoosh`, a Docker environment with Smoosh installed as `/bin/smoosh`
  - `smoosh-test`, an extension of the `smoosh` image with unit and system tests
  - `smoosh-web`, an extension of the `smoosh` image with a web-based interface to the Shtepper

### Running tests

- To run the test suite after building, run: `docker build -t smoosh-test -f Dockerfile.test . && docker run smoosh-test`
- To explore the built image, run: `docker run -it smoosh`

To test by hand, there are three sets of relevant tests: the libdash tests (in `libdash/test`), the unit tests for symbolic smoosh (in `src`), and the shell test suite (in `tests`). All three directories have `Makefile`s with appropriate `test` targets, so you can test both by running the following:

```
make -C libdash/test test
make -C src/ test
make -C tests test
```

You can do so by running `docker run -it smoosh` to get an interactive environment.

### Using the Shtepper

- After building the `smoosh` image, build the web image: `docker build -t smoosh-web -f Dockerfile.web .`
- To run the web image `docker run -p 80:2080 --name smoosh-web -t smoosh-web` and go to [http://localhost/](http://localhost/).

## Local installation (requires manual installation of dependencies)

To install Smoosh locally, you will need to manually configure your
system with the dependencies listed in the `Dockerfile`. You will need:

  - A C toolchain
  - Autoconf/autotools, libtool, pkg-config, libffi, and libgmp
  - OPAM

```ShellSession
$ git clone --recurse-submodules https://github.com/mgree/smoosh.git
Cloning into 'smoosh'...
... [lots of fetching] ...
Submodule path 'lem': checked out 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
Submodule path 'libdash': checked out 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
Submodule path 'modernish': checked out 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
Submodule path 'oil': checked out 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww'
$ cd smoosh
```
