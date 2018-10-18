# start with a reasonable image. Debian 9 stretch is what's on the POSIX testing VM
FROM ocaml/opam2:debian-9

# silence apt
# TODO this still isn't silencing it :(
ENV DEBIAN_FRONTEND=noninteractive

# system support for libdash; libgmp for zarith for lem
RUN sudo apt-get install -y autoconf autotools-dev libtool pkg-config libffi-dev libgmp-dev

# make sure we have ocamlfind and ocamlbuild
RUN opam install ocamlfind ocamlbuild

# set up FFI for libdash; num library for lem
RUN opam pin add ctypes 0.11.5
RUN opam install ctypes-foreign
RUN opam install num

WORKDIR /home/opam

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
RUN cd src; opam config exec -- make

ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]
