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
RUN sudo apt-get install -y zsh=5.3.1-4+b3 && echo 'emulate sh' >~/.zshrc
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

WORKDIR /home/opam

# set up lem
RUN opam install lem

# copy in repo files for libdash to the WORKDIR (should be /home/opam)
# we do this as late as possible so we don't have to redo the slow stuff above
ADD --chown=opam:opam libdash libdash

# build and install
RUN cd libdash; opam pin add .

# copy in repo files for smoosh to the WORKDIR

ADD --chown=opam:opam src src
ADD --chown=opam:opam README.md .

# build smoosh
RUN cd src; opam config exec -- make all all.byte

# install smoosh
RUN sudo cp /home/opam/src/smoosh /bin/smoosh

ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]
