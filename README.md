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

```ShellSession
$ docker run -it smoosh-test
... # TODO
$ make -C libdash/test test
$ make -C src/ test
$ make -C tests test
```

### Using the Shtepper

The [Shtepper](http://shell.cs.pomona.edu/shtepper) is a web-based visualization tool for symbolically running POSIX shell scripts. While available online, you can also run a local version of the Shtepper using the `smoosh-web` Docker image. To start the local Shtepper, run:

```ShellSession
$ docker run -p 80:2080 --name smoosh-web -t smoosh-web
... # TODO
```

You can then navigate to [http://localhost/](http://localhost/) in your web browser of choice. The Shtepper should work in any web browser, but has only undergone extensive testing in Firefox.

## Local installation (requires manual installation of dependencies)

To install Smoosh locally, you will need to manually configure your
system with the dependencies listed in the `Dockerfile`. In particular:

  - A C toolchain
  - Autoconf/autotools, libtool, pkg-config, libffi, and libgmp
  - OPAM

```ShellSession
$ sudo apt-get install -y autoconf autotools-dev libtool pkg-config libffi-dev libgmp-dev
... # TODO
$ sudo apt-get install -y opam
... # TODO
$ opam init
... # TODO
$ opam switch 4.07
... # TODO
$ eval `opam config env`
$ opam install ocamlfind ocamlbuild
... # TODO
$ opam pin add ctypes 0.11.5
... # TODO
$ opam install ctypes-foreign
... # TODO
$ opam install num
... # TODO
$ opam install extunix
... # TODO
$ git clone --recurse-submodules https://github.com/mgree/smoosh.git
Cloning into 'smoosh'...
... [lots of fetching] ...
Submodule path 'lem': checked out 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
Submodule path 'libdash': checked out 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
Submodule path 'modernish': checked out 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
Submodule path 'oil': checked out 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww'
$ cd smoosh
$ (cd lem/ocaml-lib; make install_dependencies)
... # TODO
$ (cd lem; make; make install)
... # TODO
$ (cd libdash; ./autogen.sh && ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu && make)
... # TODO
$ (cd libdash; sudo make install)
... # TODO
$ (cd libdash/ocaml; make && make install)
$ make -C src all all.byte
... # TODO
```

There are now three executables in `smoosh/src`: the Smoosh shell binary, `smoosh`; the Shtepper binary, `shtepper`; and a unit test runner, `runtest`.

### Running tests

With the Smoosh binaries built, there are two Smoosh test suites you can run. The unit tests are run directly via a binary, `smoosh/src/runtest`:

```ShellSession
$ pwd
[... some path ...]/smoosh
$ make -C src test
./runtest

=== Initializing Dash parser...
=== Running evaluation tests...
=== ...ran 229 evaluation tests with 0 failures.


=== Running word expansion tests...
=== ...ran 64 word expansion tests with 0 failures.


=== Running path/fs tests...
=== ...ran 27 path/fs tests with 0 failures.


=== Running arithmetic tests...
=== ...ran 253 arithmetic tests with 0 failures.
```

You can run the system tests using the `Makefile` in the `smoosh/tests` directory. These system tests are shell scripts paired with expected STDOUT, STDERR, and exit statuses.

```ShellSession
$ pwd
[... some path ...]/smoosh
$ make -C tests
== Running shell tests ===============================================
......................................................................
......................................................................
......................
shell_tests.sh: 162/162 tests passed
```
