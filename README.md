[![Build Status](https://travis-ci.com/mgree/smoosh.svg?branch=master)](https://travis-ci.com/mgree/smoosh)

Smoosh (the Symbolic, Mechanized, Observable, Operational SHell) is a formalization of the [POSIX shell standard](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html); Smoosh is one part of [Michael Greenberg's](http://www.cs.pomona.edu/~michael/) broader [project on the POSIX shell](http://shell.cs.pomona.edu).

Smoosh is written in a mix of [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) and OCaml, using [libdash](https://github.com/mgree/libdash) to parse shell code.

# Installation

There are two ways to work with Smoosh: in a Vagrant VM, in a Docker
container, or natively. Because Smoosh depends on many parts and
specific versions of some libraries, it is much easier to install via
a VM or Docker.

## Building Smoosh in a Vagrant VM

In a system with Vagrant, you should be able to download the Smoosh VM
image from the Vagrant Cloud service (~1.3GB):

```ShellSession
~$ mkdir smoosh; cd smoosh
~/smoosh$ vagrant init mgree/smoosh --box-version 0.1.0
~/smoosh$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Box 'mgree/smoosh' could not be found. Attempting to find and install...
    default: Box Provider: virtualbox
    default: Box Version: 0.1.0
==> default: Loading metadata for box 'mgree/smoosh'
    default: URL: https://vagrantcloud.com/mgree/smoosh
==> default: Adding box 'mgree/smoosh' (v0.1.0) for provider: virtualbox
    default: Downloading: https://vagrantcloud.com/mgree/boxes/smoosh/versions/0.1.0/providers/virtualbox.box
...
~/smoosh$ vagrant ssh
vagrant@debian9:~$ cd smoosh
vagrant@debian9:~/smoosh$
```

You are now in a directory where you can run tests. The `smoosh`
executable should be on your path in any case.

## Building Smoosh in Docker

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

### Running tests using the Docker image

- To run the test suite after building, run: `docker build -t smoosh-test -f Dockerfile.test . && docker run smoosh-test`
- To explore the built image, run: `docker run -it smoosh`

To test by hand, there are three sets of relevant tests: the libdash tests (in `libdash/test`), the unit tests for symbolic smoosh (in `src`), and the shell test suite (in `tests`). All three directories have `Makefile`s with appropriate `test` targets, so you can test both by running the following:

```ShellSession
$ docker run -it smoosh-test
opam@XXXXXXXXXXXX:~$ make -C libdash/test test
opam@XXXXXXXXXXXX:~$ make -C src/ test
opam@XXXXXXXXXXXX:~$ make -C tests test
```

### Using the Shtepper

The [Shtepper](http://shell.cs.pomona.edu/shtepper) is a web-based visualization tool for symbolically running POSIX shell scripts. While available online, you can also run a local version of the Shtepper using the `smoosh-web` Docker image. To start the local Shtepper, run:

```ShellSession
$ docker run -p 80:2080 --name smoosh-web -t smoosh-web
Thin web server (v1.7.2 codename Bachmanity)
Maximum connections set to 1024
Listening on 0.0.0.0:2080, CTRL+C to stop
...
```

You can then navigate to [http://localhost/](http://localhost/) in your web browser of choice. The Shtepper should work in any web browser, but has only undergone extensive testing in Firefox.

## Building Smoosh locally (requires manual installation of dependencies)

To install Smoosh locally, you will need to manually configure your
system with the dependencies listed in the `Dockerfile`. In particular:

  - A C toolchain
  - Autoconf/autotools, libtool, pkg-config, libffi, and libgmp
  - OPAM

```ShellSession
$ sudo apt-get install -y autoconf autotools-dev libtool pkg-config libffi-dev libgmp-dev
...
$ sudo apt-get install -y opam
...
$ opam init
...
$ opam switch 4.07.0
...
$ eval `opam config env`
$ opam install ocamlfind ocamlbuild
...
$ opam pin add ctypes 0.11.5
...
$ opam install ctypes-foreign num extunix
...
$ git clone --recurse-submodules https://github.com/mgree/smoosh.git
Cloning into 'smoosh'...
... [lots of fetching] ...
Submodule path 'lem': checked out 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
Submodule path 'libdash': checked out 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
Submodule path 'modernish': checked out 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
Submodule path 'oil': checked out 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww'
$ cd smoosh
$ (cd lem/ocaml-lib; make install_dependencies)
...
$ (cd lem; make; make install)
...
$ (cd libdash; ./autogen.sh && ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu && make)
...
$ (cd libdash; sudo make install)
...
$ (cd libdash/ocaml; make && make install)
$ make -C src all all.byte
...
```

There are now three executables in `smoosh/src`: the Smoosh shell binary, `smoosh`; the Shtepper binary, `shtepper`; and a unit test runner, `runtest`.

# Running tests

However you've installed Smoosh, you can run the tests by going to the
appropriate Smoosh directory (the home directory in Docker; `~/smoosh`
in a Vagrant VM). There are three sets of local Smoosh tests: libdash
parser tests, unit tests, and system tests. You can run them in one go
as follows:

```ShellSession
vagrant@debian9:~/smoosh$ make -C libdash/test test && make -C src test && make -C tests
make: Entering directory '/home/vagrant/smoosh/libdash/test'
ocamlfind ocamlopt -g -package dash,ctypes,ctypes.foreign -linkpkg test.ml -o test.native
ocamlfind ocamlcp -p a -package dash,ctypes,ctypes.foreign -linkpkg test.ml -o test.byte
TESTING test.native
tests/braces_amp.sh OK
tests/builtin.trap.exitcode.test OK
tests/diverge.sh OK
tests/empty_case OK
tests/escaping OK
tests/for_spaces.sh OK
tests/grab_submissions.sh OK
tests/grade.sh OK
tests/redir_indirect OK
tests/run_grader.sh OK
tests/run_lda.sh OK
tests/send_emails.sh OK
tests/syntax OK
tests/test.sh OK
tests/tilde_arith OK
tests/timeout3 OK
TESTING test.byte
tests/braces_amp.sh OK
tests/builtin.trap.exitcode.test OK
tests/diverge.sh OK
tests/empty_case OK
tests/escaping OK
tests/for_spaces.sh OK
tests/grab_submissions.sh OK
tests/grade.sh OK
tests/redir_indirect OK
tests/run_grader.sh OK
tests/run_lda.sh OK
tests/send_emails.sh OK
tests/syntax OK
tests/test.sh OK
tests/tilde_arith OK
tests/timeout3 OK
make: Leaving directory '/home/vagrant/smoosh/libdash/test'
make: Entering directory '/home/vagrant/smoosh/src'
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

make: Leaving directory '/home/vagrant/smoosh/src'
make: Entering directory '/home/vagrant/smoosh/tests'
== Running shell tests ===============================================
......................................................................
......................................................................
......................
shell_tests.sh: 162/162 tests passed
make: Leaving directory '/home/vagrant/smoosh/tests'
```

The unit tests are run directly via a binary, `smoosh/src/runtest`;
the system tests use the `Makefile` in the `smoosh/tests`
directory. These system tests are shell scripts paired with expected
STDOUT, STDERR, and exit statuses. 

## Running tests on another shell

Both the Docker image and Vagrant VM will have other shells
installed. The versions are nearly the same as those mentioned in the
paper, but may have changed slightly due to rolling releases. (Numbers
may therefore differ slightly.)

|Shell|Version          |
|:----|:----------------|
|dash |0.5.8-2.4        |
|bash |4.4-5            |
|yash |2.43-1           |
|zsh  |5.3.1-4+b3       |
|ksh  |93u+20120801-3.1 |
|mksh |54-2+b4          |

You can run the system tests on any shell by setting `TEST_SHELL`. Some shells may not terminate on all tests.

```ShellSession
vagrant@debian9:~/smoosh$ TEST_SHELL=dash make -C tests
...
```

To get more detail on test failures, you should set the `TEST_DEBUG` variable, e.g.:

```ShellSession
vagrant@debian9:~/smoosh$ TEST_DEBUG=1 TEST_SHELL=dash make -C tests
...
```

## Running Modernish's tests/shell diagnostic

To run the Modernish tests, you must go to `smoosh/modernish` and
simulate an install as follows:

```ShellSession
vagrant@debian9:~/smoosh/modernish$ yes n | ./install.sh -s smoosh
Relaunching install.sh with /home/mgree/.local/bin/smoosh...
* Modernish version 0.15.2-dev, now running on /home/mgree/.local/bin/smoosh.
* This shell identifies itself as smoosh version 0.1.
  Modernish detected the following bugs, quirks and/or extra features on it:
... [weird noise on native Linux/VM; crash in Docker] ...
   LOCALVARS TRAPPRSUBSH BUG_MULTIBYTE BUG_HDOCMASK
* Running modernish test suite on /home/mgree/.local/bin/smoosh ...
* lib/modernish/tst/@sanitychecks.t 
  002: ASCII chars and control char constants   - FAIL
* WARNING: modernish has some bug(s) in combination with this shell.
           Run 'modernish --test' after installation for more details.
Are you happy with /home/mgree/.local/bin/smoosh as the default shell? (y/n) install.sh: Aborting.
```

To test another shell, run `yes n | smoosh/modernish/install.sh -s [shell name]`.

NB that the HDOCMASK bug seems to appear only in Linux and not on
macOS.

# POPL 2020 Artifact Evaluation

What can be reproduced from the Smoosh paper?

  - You should be able to build Smoosh on any computer that supports Docker.

  - The built Smoosh should pass all of its unit and system tests.

  - You should be able to run the Smoosh system tests on other shells. Due to rolling releases, your environment may have slightly different shell versions (which may then pass a different number of tests).

What can not be reproduced from the Smoosh paper?

  - The POSIX test suite cannot be distributed, so we cannot reproduce
    those tests.
  
  - As of 2019-10-19, Modernish on Linux (whether native, in Docker,
    or in a Vagrant VM) exposes a bug in Smoosh's interaction with the
    dash parser. This bug wasn't poked when running on macOS.
    
    The manifestations are different: in Docker, Smoosh crashes;
    natively or in a VM, some strange extra output appears but the
    Modernish completes. Modernish _should_ still complete without a
    problem on macOS, but I'm unable to test this (as my Mac is not
    booting).
    
  - As of 2019-10-19, Modernish on Linux diagnoses two bugs:
    `BUG_MULTIBYTE` as reported in the paper, but also
    `BUG_HDOCMASK`. This last is due to platform differences.
