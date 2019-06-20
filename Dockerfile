# start with a reasonable image. Debian 9 stretch is what's on the POSIX testing VM
FROM ocaml/opam2:debian-9

# silence apt
# TODO this still isn't silencing it :(
ENV DEBIAN_FRONTEND=noninteractive

# we frontload installation so that things that inherit from us don't need network access
# we also (inadvisedly) do an update, but we'll ask for particular shell versions
RUN sudo apt-get update

# other shells we'll want
RUN sudo apt-get install -y dash=0.5.8-2.4
RUN sudo apt-get install -y --no-install-recommends bash=4.4-5
RUN sudo apt-get install -y yash=2.43-1
RUN sudo apt-get install -y zsh=5.3.1-4+b2 && echo 'emulate sh' >~/.zshrc
RUN sudo apt-get install -y ksh=93u+20120801-3.1
RUN sudo apt-get install -y mksh=54-2+b4

# for OSH
RUN sudo apt-get install -y python2.7 python python-dev time libreadline-dev

# system support for libdash; libgmp for zarith for lem
RUN sudo apt-get install -y autoconf autotools-dev libtool pkg-config libffi-dev libgmp-dev

# need expect for the POSIX test suite
RUN sudo apt-get install -y --no-install-recommends expect

# need gawk for POSIX test sutie tests tp448 and tp450; will be used POSIXLY_CORRECT
RUN sudo apt-get install -y gawk

# camlp4 won't work in 4.08 right now 2019-06-18
RUN opam switch 4.07

# make sure we have ocamlfind and ocamlbuild
RUN opam install ocamlfind ocamlbuild

# set up FFI for libdash; num library for lem; extunix for shell syscalls
RUN opam pin add ctypes 0.11.5
RUN opam install ctypes-foreign
RUN opam install num
RUN opam install extunix

################################################################################
# okay, we've downloaded and installed everything.
################################################################################

# build Oil...
WORKDIR /home/opam

ADD --chown=opam:opam oil oil
RUN cd oil; ./configure; build/dev.sh minimal
RUN sed -i 's#REPO_ROOT=.*#REPO_ROOT=/home/opam/oil#' /home/opam/oil/bin/osh
RUN sudo ln -sf /home/opam/oil/bin/osh /usr/local/bin/osh

# set up lem
ADD --chown=opam:opam lem lem
RUN cd lem/ocaml-lib; opam config exec -- make install_dependencies
RUN cd lem; opam config exec -- make
RUN cd lem; opam config exec -- make install
ENV PATH="/home/opam/lem/bin:${PATH}"
ENV LEMLIB="/home/opam/lem/library"

# copy in repo files for libdash to the WORKDIR (should be /home/opam)
# we do this as late as possible so we don't have to redo the slow stuff above
ADD --chown=opam:opam libdash libdash

# build libdash, expose shared object
RUN cd libdash; ./autogen.sh && ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu
RUN cd libdash; make
RUN cd libdash; sudo make install
# build ocaml bindings
RUN cd libdash/ocaml; opam config exec -- make && opam config exec -- make install

# copy in repo files for smoosh to the WORKDIR

ADD --chown=opam:opam src src
ADD --chown=opam:opam README.md .

# build smoosh
RUN cd src; opam config exec -- make all all.byte

# install smoosh
RUN sudo cp /home/opam/src/smoosh /bin/smoosh

ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]
