[![Build Status](https://travis-ci.com/mgree/smoosh.svg?branch=master)](https://travis-ci.com/mgree/smoosh)

Smoosh (the Symbolic, Mechanized, Observable, Operational SHell) is a formalization of the [POSIX shell standard](http://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html); Smoosh is one part of [Michael Greenberg's](http://www.cs.pomona.edu/~michael/) broader [project on the POSIX shell](http://shell.cs.pomona.edu).

Smoosh is written in a mix of [Lem](https://www.cl.cam.ac.uk/~pes20/lem/) and OCaml, using [libdash](https://github.com/mgree/libdash) to parse shell code.

# Fetch the submodules

- The best way to clone this repository is via `git clone --recurse-submodules https://github.com/mgree/smoosh`. 
- If you didn't use `--recursive` or `--recurse-submodules`, before trying anything, run: `git submodule update --init --recursive`

If you don't load the git submodules, the libdash and Lem references won't resolve properly---the directories will be empty!

Whenever you pull, remember to run `git submodule update` to make sure that the submodules are at the correct versions.

# How to build and test it

- Run: `./build.sh`

## Building in more detail

- Run: `docker build -t smoosh .`

To build by hand, you should more or less follow the steps in the Dockerfile, adapting to your system. (For example, on OS X, you'll probably want to install directly to `/usr/local`.)

## Testing in more detail

- To run the test suite after building, run: `docker build -t smoosh-test -f Dockerfile.test . && docker run smoosh-test`
- To explore the built image, run: `docker run -it smoosh`

To test by hand, there are three sets of relevant tests: the libdash tests (in `libdash/test`), the unit tests for symbolic smoosh (in `src`), and the shell test suite (in `tests`). All three directories have `Makefile`s with appropriate `test` targets, so you can test both by running the following:

```
make -C libdash/test test
make -C src/ test
make -C tests test
```

You can do so by running `docker run -it smoosh` to get an interactive environment.

# How to use the web interface

- After building the `smoosh` image, build the web image: `docker build -t smoosh-web -f Dockerfile.web .`
- To run the web image `docker run -p 80:2080 --name smoosh-web -t smoosh-web` and go to [http://localhost/](http://localhost/).

